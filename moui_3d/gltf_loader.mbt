///|
/// Decode the supported static glTF subset into the addon scene model.
///
/// This function accepts already-loaded bytes only. `binary` is the GLB BIN
/// chunk (or the single buffer supplied by an app); external JSON resources
/// are obtained through `resolve`.
pub fn load_gltf_scene(
  json : String,
  binary? : Bytes? = None,
  resolve? : GltfResourceResolver? = None,
) -> Scene raise GltfError {
  let root : GltfRoot = @json.from_json(@json.parse(json)) catch {
    err => raise GltfError::InvalidJson(err.to_string())
  }
  if root.asset.version != "2.0" {
    raise GltfError::UnsupportedAssetVersion(root.asset.version)
  }
  for extension in root.extensionsUsed.unwrap_or([]) {
    raise GltfError::UnsupportedExtension(extension)
  }

  let buffers = root.buffers.unwrap_or([])
  let buffer_views = root.bufferViews.unwrap_or([])
  let accessors = root.accessors.unwrap_or([])
  let buffer_data : Array[Bytes?] = Array::make(buffers.length(), None)
  for index, buffer in buffers {
    match buffer.uri {
      None => buffer_data[index] = binary
      Some(uri) =>
        match resolve {
          None => raise GltfError::ExternalResourceUnavailable(uri)
          Some(loader) =>
            match loader(uri) {
              None => raise GltfError::ExternalResourceUnavailable(uri)
              Some(bytes) => buffer_data[index] = Some(bytes)
            }
        }
    }
    match buffer_data[index] {
      None => raise GltfError::MissingBuffer(index)
      Some(bytes) =>
        if bytes.length() < buffer.byteLength {
          raise GltfError::MissingBuffer(index)
        }
    }
  }

  let scene = Scene::empty()
  let images = root.images.unwrap_or([])
  let texture_json = root.textures.unwrap_or([])
  let texture_ids : Array[TextureId?] = Array::make(texture_json.length(), None)
  for texture_index, texture in texture_json {
    let source_index = match texture.source {
      None => raise GltfError::InvalidTexture(texture_index)
      Some(value) => value
    }
    if source_index < 0 || source_index >= images.length() {
      raise GltfError::InvalidTexture(source_index)
    }
    let image = images[source_index]
    let texture_id = match image.uri {
      Some(uri) =>
        scene.add_texture(Texture::uri(uri, mime_type=image.mimeType))
      None =>
        match image.bufferView {
          None => raise GltfError::InvalidTexture(source_index)
          Some(view_index) => {
            let bytes = read_buffer_view(view_index, buffer_views, buffer_data)
            scene.add_texture(
              Texture::embedded(bytes, mime_type=image.mimeType),
            )
          }
        }
    }
    texture_ids[texture_index] = Some(texture_id)
  }

  let material_json = root.materials.unwrap_or([])
  let material_ids : Array[MaterialId?] = Array::make(
    material_json.length(),
    None,
  )
  for index, material in material_json {
    let pbr = material.pbrMetallicRoughness
    let base_color = match pbr {
      None => Vec4::new(x=1.0, y=1.0, z=1.0, w=1.0)
      Some(value) =>
        vec4_from_array(
          value.baseColorFactor,
          Vec4::new(x=1.0, y=1.0, z=1.0, w=1.0),
        )
    }
    let metallic = match pbr {
      None => 0.0
      Some(value) => value.metallicFactor.unwrap_or(1.0)
    }
    let roughness = match pbr {
      None => 1.0
      Some(value) => value.roughnessFactor.unwrap_or(1.0)
    }
    let base_color_texture = match pbr {
      None => None
      Some(value) =>
        match value.baseColorTexture {
          None => None
          Some(info) =>
            if info.index >= 0 && info.index < texture_ids.length() {
              texture_ids[info.index]
            } else {
              raise GltfError::InvalidTexture(info.index)
            }
        }
    }
    material_ids[index] = Some(
      scene.add_material(
        Material::pbr(base_color~, metallic~, roughness~, base_color_texture~),
      ),
    )
  }

  let mesh_json = root.meshes.unwrap_or([])
  for mesh in mesh_json {
    let primitives : Array[Primitive] = []
    for primitive in mesh.primitives {
      let mode = primitive.mode.unwrap_or(4)
      if mode != 4 {
        raise GltfError::UnsupportedPrimitiveMode(mode)
      }
      let position_accessor = match primitive.attributes.get("POSITION") {
        None => raise GltfError::MissingAttribute("POSITION")
        Some(value) => value
      }
      let positions = decode_vec3_accessor(
        position_accessor, accessors, buffer_views, buffer_data,
      )
      let normals = match primitive.attributes.get("NORMAL") {
        None => Array::make(positions.length(), Vec3::new(x=0.0, y=1.0, z=0.0))
        Some(value) =>
          decode_vec3_accessor(value, accessors, buffer_views, buffer_data)
      }
      let texcoords = match primitive.attributes.get("TEXCOORD_0") {
        None => Array::make(positions.length(), Vec2::zero())
        Some(value) =>
          decode_vec2_accessor(value, accessors, buffer_views, buffer_data)
      }
      if normals.length() != positions.length() ||
        texcoords.length() != positions.length() {
        raise GltfError::InvalidAccessor(position_accessor)
      }
      let vertices : Array[Vertex] = []
      for index in 0..<positions.length() {
        vertices.push(
          Vertex::new(
            position=positions[index],
            normal=normals[index],
            texcoord=texcoords[index],
          ),
        )
      }
      let indices = match primitive.indices {
        None => sequential_indices(vertices.length())
        Some(value) =>
          decode_indices_accessor(value, accessors, buffer_views, buffer_data)
      }
      let material = match primitive.material {
        None => None
        Some(value) =>
          if value >= 0 && value < material_ids.length() {
            material_ids[value]
          } else {
            raise GltfError::InvalidAccessor(value)
          }
      }
      primitives.push(Primitive::new(vertices~, indices~, material~))
    }
    ignore(scene.add_mesh(Mesh::new(name=mesh.name.unwrap_or(""), primitives~)))
  }

  let nodes = root.nodes.unwrap_or([])
  let parents : Array[Int?] = Array::make(nodes.length(), None)
  for parent_index, node in nodes {
    for child in node.children.unwrap_or([]) {
      if child >= 0 && child < parents.length() {
        parents[child] = Some(parent_index)
      }
    }
  }
  for index, node in nodes {
    let mesh = match node.mesh {
      None => None
      Some(value) =>
        if value >= 0 && value < mesh_json.length() {
          Some(MeshId::new(value))
        } else {
          raise GltfError::InvalidAccessor(value)
        }
    }
    let parent = parents[index].map(value => NodeId::new(value))
    ignore(
      scene.add_node(
        Node::new(
          name=node.name.unwrap_or(""),
          parent~,
          local_transform=node_transform(node),
          mesh~,
        ),
      ),
    )
  }
  scene
}

///|
fn node_transform(node : GltfNodeJson) -> Mat4 {
  match node.matrix {
    Some(values) =>
      if values.length() == 16 {
        // glTF matrices are column-major; the public Mat4 is row-major.
        Mat4::from_values([
          values[0],
          values[4],
          values[8],
          values[12],
          values[1],
          values[5],
          values[9],
          values[13],
          values[2],
          values[6],
          values[10],
          values[14],
          values[3],
          values[7],
          values[11],
          values[15],
        ])
      } else {
        trs_transform(node)
      }
    None => trs_transform(node)
  }
}

///|
fn trs_transform(node : GltfNodeJson) -> Mat4 {
  let translation = vec3_from_array(node.translation, Vec3::zero())
  let scale = vec3_from_array(node.scale, Vec3::new(x=1.0, y=1.0, z=1.0))
  let rotation = match node.rotation {
    Some(values) =>
      if values.length() == 4 {
        Quat::new(x=values[0], y=values[1], z=values[2], w=values[3])
      } else {
        Quat::identity()
      }
    None => Quat::identity()
  }
  Mat4::translation(translation)
  .mul(rotation.to_mat4())
  .mul(
    Mat4::from_values([
      scale.x,
      0.0,
      0.0,
      0.0,
      0.0,
      scale.y,
      0.0,
      0.0,
      0.0,
      0.0,
      scale.z,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
    ]),
  )
}

///|
fn vec3_from_array(values : Array[Double]?, fallback : Vec3) -> Vec3 {
  match values {
    Some(items) =>
      if items.length() >= 3 {
        Vec3::new(x=items[0], y=items[1], z=items[2])
      } else {
        fallback
      }
    None => fallback
  }
}

///|
fn vec4_from_array(values : Array[Double]?, fallback : Vec4) -> Vec4 {
  match values {
    Some(items) =>
      if items.length() >= 4 {
        Vec4::new(x=items[0], y=items[1], z=items[2], w=items[3])
      } else {
        fallback
      }
    None => fallback
  }
}

///|
fn sequential_indices(length : Int) -> Array[Int] {
  let result : Array[Int] = []
  for index in 0..<length {
    result.push(index)
  }
  result
}

///|
fn decode_vec3_accessor(
  accessor_index : Int,
  accessors : Array[GltfAccessorJson],
  views : Array[GltfBufferView],
  buffers : Array[Bytes?],
) -> Array[Vec3] raise GltfError {
  let accessor = accessor_at(accessor_index, accessors)
  if accessor.accessor_kind != "VEC3" {
    raise GltfError::UnsupportedAccessorType(accessor.accessor_kind)
  }
  let values = decode_accessor_values(
    accessor_index, accessors, views, buffers, 3,
  )
  let result : Array[Vec3] = []
  for item in values {
    result.push(Vec3::new(x=item[0], y=item[1], z=item[2]))
  }
  result
}

///|
fn decode_vec2_accessor(
  accessor_index : Int,
  accessors : Array[GltfAccessorJson],
  views : Array[GltfBufferView],
  buffers : Array[Bytes?],
) -> Array[Vec2] raise GltfError {
  let accessor = accessor_at(accessor_index, accessors)
  if accessor.accessor_kind != "VEC2" {
    raise GltfError::UnsupportedAccessorType(accessor.accessor_kind)
  }
  let values = decode_accessor_values(
    accessor_index, accessors, views, buffers, 2,
  )
  let result : Array[Vec2] = []
  for item in values {
    result.push(Vec2::new(x=item[0], y=item[1]))
  }
  result
}

///|
fn decode_indices_accessor(
  accessor_index : Int,
  accessors : Array[GltfAccessorJson],
  views : Array[GltfBufferView],
  buffers : Array[Bytes?],
) -> Array[Int] raise GltfError {
  let accessor = accessor_at(accessor_index, accessors)
  if accessor.accessor_kind != "SCALAR" {
    raise GltfError::UnsupportedAccessorType(accessor.accessor_kind)
  }
  if accessor.componentType != 5121 &&
    accessor.componentType != 5123 &&
    accessor.componentType != 5125 {
    raise GltfError::UnsupportedComponentType(accessor.componentType)
  }
  let values = decode_accessor_values(
    accessor_index, accessors, views, buffers, 1,
  )
  values.map(item => item[0].to_int())
}

///|
fn decode_accessor_values(
  accessor_index : Int,
  accessors : Array[GltfAccessorJson],
  views : Array[GltfBufferView],
  buffers : Array[Bytes?],
  components : Int,
) -> Array[Array[Double]] raise GltfError {
  let accessor = accessor_at(accessor_index, accessors)
  let view_index = match accessor.bufferView {
    None => raise GltfError::InvalidAccessor(accessor_index)
    Some(value) => value
  }
  if view_index < 0 || view_index >= views.length() {
    raise GltfError::MissingBufferView(view_index)
  }
  let view = views[view_index]
  if view.buffer < 0 || view.buffer >= buffers.length() {
    raise GltfError::MissingBuffer(view.buffer)
  }
  let bytes = match buffers[view.buffer] {
    None => raise GltfError::MissingBuffer(view.buffer)
    Some(value) => value
  }
  let component_size = component_size_for(accessor.componentType)
  if component_size == 0 {
    raise GltfError::UnsupportedComponentType(accessor.componentType)
  }
  let element_size = component_size * components
  let stride = view.byteStride.unwrap_or(element_size)
  if stride < element_size || accessor.count < 0 {
    raise GltfError::InvalidAccessor(accessor_index)
  }
  let view_start = view.byteOffset.unwrap_or(0)
  let start = view_start + accessor.byteOffset.unwrap_or(0)
  let required = if accessor.count == 0 {
    start
  } else {
    start + (accessor.count - 1) * stride + element_size
  }
  if start < 0 ||
    required > bytes.length() ||
    required > view_start + view.byteLength {
    raise GltfError::InvalidAccessor(accessor_index)
  }
  let result : Array[Array[Double]] = []
  for index in 0..<accessor.count {
    let values : Array[Double] = []
    let base = start + index * stride
    for component in 0..<components {
      values.push(
        read_component(
          bytes,
          base + component * component_size,
          accessor.componentType,
          accessor.normalized.unwrap_or(false),
        ),
      )
    }
    result.push(values)
  }
  result
}

///|
fn accessor_at(
  index : Int,
  accessors : Array[GltfAccessorJson],
) -> GltfAccessorJson raise GltfError {
  if index < 0 || index >= accessors.length() {
    raise GltfError::MissingAccessor(index)
  }
  accessors[index]
}

///|
fn component_size_for(component_type : Int) -> Int {
  if component_type == 5120 || component_type == 5121 {
    1
  } else if component_type == 5122 || component_type == 5123 {
    2
  } else if component_type == 5125 || component_type == 5126 {
    4
  } else {
    0
  }
}

///|
fn read_component(
  bytes : Bytes,
  offset : Int,
  component_type : Int,
  normalized : Bool,
) -> Double {
  if component_type == 5126 {
    Float::reinterpret_from_uint(read_u32_le_unsigned(bytes, offset)).to_double()
  } else if component_type == 5121 {
    let value = bytes[offset].to_int().to_double()
    if normalized {
      value / 255.0
    } else {
      value
    }
  } else if component_type == 5123 {
    let value = read_u16_le(bytes, offset).to_double()
    if normalized {
      value / 65535.0
    } else {
      value
    }
  } else if component_type == 5125 {
    read_u32_le_unsigned(bytes, offset).to_double()
  } else if component_type == 5120 {
    let raw = bytes[offset].to_int()
    let value = if raw > 127 { raw - 256 } else { raw }
    if normalized {
      (value.to_double() / 127.0).max(-1.0)
    } else {
      value.to_double()
    }
  } else if component_type == 5122 {
    let raw = read_u16_le(bytes, offset)
    let value = if raw > 32767 { raw - 65536 } else { raw }
    if normalized {
      (value.to_double() / 32767.0).max(-1.0)
    } else {
      value.to_double()
    }
  } else {
    0.0
  }
}

///|
fn read_u16_le(bytes : Bytes, offset : Int) -> Int {
  bytes[offset].to_int() | (bytes[offset + 1].to_int() << 8)
}

///|
fn read_u32_le_unsigned(bytes : Bytes, offset : Int) -> UInt {
  bytes[offset].to_uint() |
  (bytes[offset + 1].to_uint() << 8) |
  (bytes[offset + 2].to_uint() << 16) |
  (bytes[offset + 3].to_uint() << 24)
}

///|
fn read_buffer_view(
  index : Int,
  views : Array[GltfBufferView],
  buffers : Array[Bytes?],
) -> Bytes raise GltfError {
  if index < 0 || index >= views.length() {
    raise GltfError::MissingBufferView(index)
  }
  let view = views[index]
  if view.buffer < 0 || view.buffer >= buffers.length() {
    raise GltfError::MissingBuffer(view.buffer)
  }
  let bytes = match buffers[view.buffer] {
    None => raise GltfError::MissingBuffer(view.buffer)
    Some(value) => value
  }
  let start = view.byteOffset.unwrap_or(0)
  let end = start + view.byteLength
  if start < 0 || end > bytes.length() {
    raise GltfError::InvalidAccessor(index)
  }
  bytes[start:end].to_owned()
}
