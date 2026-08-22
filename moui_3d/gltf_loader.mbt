///|
/// Decode the supported glTF subset into the addon scene model.
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
  for extension in root.extensionsRequired.unwrap_or([]) {
    raise GltfError::UnsupportedRequiredExtension(extension)
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
        match decode_data_uri(uri) {
          Some(bytes) => buffer_data[index] = Some(bytes)
          None =>
            match resolve {
              None => raise GltfError::ExternalResourceUnavailable(uri)
              Some(loader) =>
                match loader(uri) {
                  None => raise GltfError::ExternalResourceUnavailable(uri)
                  Some(bytes) => buffer_data[index] = Some(bytes)
                }
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
  let sampler_json = root.samplers.unwrap_or([])
  let sampler_ids : Array[SamplerId?] = Array::make(sampler_json.length(), None)
  for index, sampler in sampler_json {
    let mag_filter = filter_from_gltf(sampler.magFilter, false)
    let min_filter = filter_from_gltf(sampler.minFilter, true)
    let wrap_s = wrap_from_gltf(sampler.wrapS)
    let wrap_t = wrap_from_gltf(sampler.wrapT)
    sampler_ids[index] = Some(
      scene.add_sampler(
        Sampler::new(mag_filter~, min_filter~, wrap_s~, wrap_t~),
      ),
    )
  }
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
    let sampler = match texture.sampler {
      None => None
      Some(value) =>
        if value >= 0 && value < sampler_ids.length() {
          sampler_ids[value]
        } else {
          raise GltfError::InvalidSampler(value)
        }
    }
    let texture_id = match image.uri {
      Some(uri) =>
        scene.add_texture(Texture::uri(uri, mime_type=image.mimeType, sampler~))
      None =>
        match image.bufferView {
          None => raise GltfError::InvalidTexture(source_index)
          Some(view_index) => {
            let bytes = read_buffer_view(view_index, buffer_views, buffer_data)
            scene.add_texture(
              Texture::embedded(bytes, mime_type=image.mimeType, sampler~),
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
      None => 1.0
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
    let normal_texture = texture_info_id(material.normalTexture, texture_ids)
    let occlusion_texture = texture_info_id(
      material.occlusionTexture,
      texture_ids,
    )
    let emissive_texture = texture_info_id(
      material.emissiveTexture,
      texture_ids,
    )
    let emissive_factor = vec3_from_array(material.emissiveFactor, Vec3::zero())
    let alpha_mode = match material.alphaMode.unwrap_or("OPAQUE") {
      "MASK" => AlphaMode::Mask
      "BLEND" => AlphaMode::Blend
      _ => AlphaMode::Opaque
    }
    material_ids[index] = Some(
      scene.add_material(
        Material::pbr(
          base_color~,
          metallic~,
          roughness~,
          base_color_texture~,
          normal_texture~,
          occlusion_texture~,
          emissive_texture~,
          emissive_factor~,
          alpha_mode~,
          alpha_cutoff=material.alphaCutoff.unwrap_or(0.5),
          double_sided=material.doubleSided.unwrap_or(false),
        ),
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
      let joints = match primitive.attributes.get("JOINTS_0") {
        None => Array::make(positions.length(), (0, 0, 0, 0))
        Some(value) =>
          decode_joints_accessor(value, accessors, buffer_views, buffer_data)
      }
      let weights = match primitive.attributes.get("WEIGHTS_0") {
        None => Array::make(positions.length(), Vec4::zero())
        Some(value) =>
          decode_vec4_accessor(value, accessors, buffer_views, buffer_data)
      }
      if normals.length() != positions.length() ||
        texcoords.length() != positions.length() ||
        joints.length() != positions.length() ||
        weights.length() != positions.length() {
        raise GltfError::InvalidAccessor(position_accessor)
      }
      let vertices : Array[Vertex] = []
      for index in 0..<positions.length() {
        vertices.push(
          Vertex::new(
            position=positions[index],
            normal=normals[index],
            texcoord=texcoords[index],
            joints=joints[index],
            weights=weights[index],
          ),
        )
      }
      let morph_targets : Array[Array[VertexDelta]] = []
      for target in primitive.targets.unwrap_or([]) {
        let positions_delta = match target.get("POSITION") {
          None => Array::make(positions.length(), Vec3::zero())
          Some(value) =>
            decode_vec3_accessor(value, accessors, buffer_views, buffer_data)
        }
        let normals_delta = match target.get("NORMAL") {
          None => Array::make(positions.length(), Vec3::zero())
          Some(value) =>
            decode_vec3_accessor(value, accessors, buffer_views, buffer_data)
        }
        let tangents_delta = match target.get("TANGENT") {
          None => Array::make(positions.length(), Vec3::zero())
          Some(value) =>
            decode_vec3_accessor(value, accessors, buffer_views, buffer_data)
        }
        if positions_delta.length() != positions.length() ||
          normals_delta.length() != positions.length() ||
          tangents_delta.length() != positions.length() {
          raise GltfError::InvalidAccessor(position_accessor)
        }
        let deltas : Array[VertexDelta] = []
        for vertex_index in 0..<positions.length() {
          deltas.push(
            VertexDelta::new(
              position=positions_delta[vertex_index],
              normal=normals_delta[vertex_index],
              tangent=tangents_delta[vertex_index],
            ),
          )
        }
        morph_targets.push(deltas)
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
      primitives.push(
        Primitive::new(vertices~, indices~, material~, morph_targets~),
      )
    }
    ignore(
      scene.add_mesh(
        Mesh::new(
          name=mesh.name.unwrap_or(""),
          primitives~,
          weights=mesh.weights.unwrap_or([]),
        ),
      ),
    )
  }

  let nodes = root.nodes.unwrap_or([])
  let skin_json = root.skins.unwrap_or([])
  for skin in skin_json {
    let joints : Array[NodeId] = []
    for joint in skin.joints {
      if joint < 0 || joint >= nodes.length() {
        raise GltfError::InvalidNode(joint)
      }
      joints.push(NodeId::new(joint))
    }
    let inverse_bind_matrices = match skin.inverseBindMatrices {
      None => []
      Some(value) =>
        decode_mat4_accessor(value, accessors, buffer_views, buffer_data)
    }
    if inverse_bind_matrices.length() != 0 &&
      inverse_bind_matrices.length() != joints.length() {
      raise GltfError::InvalidSkin(0)
    }
    let skeleton = match skin.skeleton {
      None => None
      Some(value) =>
        if value >= 0 && value < nodes.length() {
          Some(NodeId::new(value))
        } else {
          raise GltfError::InvalidNode(value)
        }
    }
    ignore(
      scene.add_skin(
        Skin::new(
          name=skin.name.unwrap_or(""),
          joints~,
          inverse_bind_matrices~,
          skeleton~,
        ),
      ),
    )
  }
  let parents : Array[Int?] = Array::make(nodes.length(), None)
  for parent_index, node in nodes {
    for child in node.children.unwrap_or([]) {
      if child < 0 || child >= parents.length() {
        raise GltfError::InvalidNode(child)
      }
      match parents[child] {
        Some(previous) if previous != parent_index =>
          raise GltfError::InvalidNode(child)
        _ => parents[child] = Some(parent_index)
      }
    }
  }
  for index in 0..<nodes.length() {
    let seen : Array[Int] = []
    let mut current = index
    while current >= 0 {
      if seen.contains(current) {
        raise GltfError::InvalidNodeCycle(index)
      }
      seen.push(current)
      current = match parents[current] {
        Some(parent) => parent
        None => -1
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
    let camera = match node.camera {
      None => None
      Some(value) =>
        if value >= 0 && value < root.cameras.unwrap_or([]).length() {
          Some(value)
        } else {
          raise GltfError::InvalidCamera(value)
        }
    }
    let skin = match node.skin {
      None => None
      Some(value) =>
        if value >= 0 && value < skin_json.length() {
          Some(value)
        } else {
          raise GltfError::InvalidSkin(value)
        }
    }
    ignore(
      scene.add_node(
        Node::new(
          name=node.name.unwrap_or(""),
          parent~,
          local_transform=node_transform(node),
          mesh~,
          camera~,
          skin~,
          weights=node.weights,
        ),
      ),
    )
  }

  let camera_json = root.cameras.unwrap_or([])
  for camera in camera_json {
    let projection = match camera.camera_type {
      "perspective" =>
        match camera.perspective {
          None => raise GltfError::InvalidCamera(0)
          Some(value) =>
            CameraProjection::Perspective(
              value.yfov,
              value.aspectRatio.unwrap_or(0.0),
              value.znear,
              value.zfar.unwrap_or(0.0),
            )
        }
      "orthographic" =>
        match camera.orthographic {
          None => raise GltfError::InvalidCamera(0)
          Some(value) =>
            CameraProjection::Orthographic(
              value.xmag,
              value.ymag,
              value.znear,
              value.zfar,
            )
        }
      _ => raise GltfError::InvalidCamera(0)
    }
    ignore(
      scene.add_camera(Camera::new(name=camera.name.unwrap_or(""), projection~)),
    )
  }
  let scene_json = root.scenes.unwrap_or([])
  for definition in scene_json {
    let roots : Array[NodeId] = []
    for node in definition.nodes.unwrap_or([]) {
      if node < 0 || node >= nodes.length() {
        raise GltfError::InvalidScene(node)
      }
      roots.push(NodeId::new(node))
    }
    ignore(
      scene.add_scene_definition(
        SceneDefinition::new(name=definition.name.unwrap_or(""), roots~),
      ),
    )
  }
  match root.scene {
    None => ()
    Some(value) =>
      if value < 0 || value >= scene_json.length() {
        raise GltfError::InvalidScene(value)
      } else {
        scene.set_default_scene(Some(value))
      }
  }

  let animation_json = root.animations.unwrap_or([])
  for animation in animation_json {
    let channels : Array[AnimationChannel] = []
    for channel in animation.channels {
      let node_index = match channel.target.node {
        Some(value) => value
        None => raise GltfError::InvalidAnimation(0)
      }
      if node_index < 0 || node_index >= nodes.length() {
        raise GltfError::InvalidAnimation(node_index)
      }
      if channel.sampler < 0 || channel.sampler >= animation.samplers.length() {
        raise GltfError::InvalidAnimation(channel.sampler)
      }
      let sampler = animation.samplers[channel.sampler]
      let path = match channel.target.path {
        "translation" => AnimationPath::Translation
        "rotation" => AnimationPath::Rotation
        "scale" => AnimationPath::Scale
        "weights" => AnimationPath::Weights
        value => raise GltfError::UnsupportedAnimationPath(value)
      }
      let components = match path {
        AnimationPath::Rotation => 4
        AnimationPath::Weights => 1
        _ => 3
      }
      let times = decode_accessor_values(
        sampler.input,
        accessors,
        buffer_views,
        buffer_data,
        1,
      )
      let outputs = decode_accessor_values(
        sampler.output,
        accessors,
        buffer_views,
        buffer_data,
        components,
      )
      if times.length() != outputs.length() &&
        sampler.interpolation.unwrap_or("LINEAR") != "CUBICSPLINE" {
        raise GltfError::InvalidAnimation(channel.sampler)
      }
      let interpolation = match sampler.interpolation.unwrap_or("LINEAR") {
        "STEP" => AnimationInterpolation::Step
        "CUBICSPLINE" => AnimationInterpolation::CubicSpline
        _ => AnimationInterpolation::Linear
      }
      let keyframes : Array[AnimationKeyframe] = []
      let key_count = times.length()
      for index in 0..<key_count {
        let value_index = if interpolation ==
          AnimationInterpolation::CubicSpline {
          index * 3 + 1
        } else {
          index
        }
        if value_index >= outputs.length() {
          raise GltfError::InvalidAnimation(channel.sampler)
        }
        let incoming = if interpolation == AnimationInterpolation::CubicSpline &&
          index * 3 < outputs.length() {
          outputs[index * 3]
        } else {
          []
        }
        let outgoing = if interpolation == AnimationInterpolation::CubicSpline &&
          index * 3 + 2 < outputs.length() {
          outputs[index * 3 + 2]
        } else {
          []
        }
        keyframes.push(
          AnimationKeyframe::new(
            time=times[index][0],
            value=outputs[value_index],
            in_tangent=incoming,
            out_tangent=outgoing,
          ),
        )
      }
      channels.push(
        AnimationChannel::new(
          node=NodeId::new(node_index),
          path~,
          interpolation~,
          keyframes~,
        ),
      )
    }
    ignore(
      scene.add_animation(
        AnimationClip::new(name=animation.name.unwrap_or(""), channels~),
      ),
    )
  }
  scene
}

///|
fn texture_info_id(
  info : GltfTextureInfo?,
  texture_ids : Array[TextureId?],
) -> TextureId? raise GltfError {
  match info {
    None => None
    Some(value) =>
      if value.index >= 0 && value.index < texture_ids.length() {
        texture_ids[value.index]
      } else {
        raise GltfError::InvalidTexture(value.index)
      }
  }
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
fn decode_data_uri(uri : String) -> Bytes? {
  if !uri.has_prefix("data:") {
    return None
  }
  let mut comma = -1
  for index in 0..<uri.length() {
    if uri[index] == ',' {
      comma = index
      break
    }
  }
  if comma < 0 {
    return None
  }
  let metadata = uri[:comma]
  if !metadata.has_suffix(";base64") {
    return None
  }
  Some(@base64.decode(uri[comma + 1:]) catch { _ => return None })
}

///|
fn filter_from_gltf(
  value : Int?,
  mipmap : Bool,
) -> SamplerFilter raise GltfError {
  match value {
    None =>
      if mipmap {
        SamplerFilter::LinearMipmapLinear
      } else {
        SamplerFilter::Linear
      }
    Some(9728) => SamplerFilter::Nearest
    Some(9729) => SamplerFilter::Linear
    Some(9984) => SamplerFilter::NearestMipmapNearest
    Some(9985) => SamplerFilter::LinearMipmapNearest
    Some(9986) => SamplerFilter::NearestMipmapLinear
    Some(9987) => SamplerFilter::LinearMipmapLinear
    Some(_) => raise GltfError::InvalidSampler(0)
  }
}

///|
fn wrap_from_gltf(value : Int?) -> SamplerWrap raise GltfError {
  match value {
    None => SamplerWrap::Repeat
    Some(10497) => SamplerWrap::Repeat
    Some(33648) => SamplerWrap::MirroredRepeat
    Some(33071) => SamplerWrap::ClampToEdge
    Some(_) => raise GltfError::InvalidSampler(0)
  }
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
fn decode_vec4_accessor(
  accessor_index : Int,
  accessors : Array[GltfAccessorJson],
  views : Array[GltfBufferView],
  buffers : Array[Bytes?],
) -> Array[Vec4] raise GltfError {
  let accessor = accessor_at(accessor_index, accessors)
  if accessor.accessor_kind != "VEC4" {
    raise GltfError::UnsupportedAccessorType(accessor.accessor_kind)
  }
  decode_accessor_values(accessor_index, accessors, views, buffers, 4).map(item => {
    Vec4::new(x=item[0], y=item[1], z=item[2], w=item[3])
  })
}

///|
fn decode_joints_accessor(
  accessor_index : Int,
  accessors : Array[GltfAccessorJson],
  views : Array[GltfBufferView],
  buffers : Array[Bytes?],
) -> Array[(Int, Int, Int, Int)] raise GltfError {
  let accessor = accessor_at(accessor_index, accessors)
  if accessor.accessor_kind != "VEC4" ||
    (accessor.componentType != 5121 && accessor.componentType != 5123) {
    raise GltfError::UnsupportedAccessorType(accessor.accessor_kind)
  }
  decode_accessor_values(accessor_index, accessors, views, buffers, 4).map(item => {
    (item[0].to_int(), item[1].to_int(), item[2].to_int(), item[3].to_int())
  })
}

///|
fn decode_mat4_accessor(
  accessor_index : Int,
  accessors : Array[GltfAccessorJson],
  views : Array[GltfBufferView],
  buffers : Array[Bytes?],
) -> Array[Mat4] raise GltfError {
  let accessor = accessor_at(accessor_index, accessors)
  if accessor.accessor_kind != "MAT4" || accessor.componentType != 5126 {
    raise GltfError::UnsupportedAccessorType(accessor.accessor_kind)
  }
  decode_accessor_values(accessor_index, accessors, views, buffers, 16).map(item => {
    Mat4::from_values([
      item[0],
      item[4],
      item[8],
      item[12],
      item[1],
      item[5],
      item[9],
      item[13],
      item[2],
      item[6],
      item[10],
      item[14],
      item[3],
      item[7],
      item[11],
      item[15],
    ])
  })
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
  let component_size = component_size_for(accessor.componentType)
  if component_size == 0 {
    raise GltfError::UnsupportedComponentType(accessor.componentType)
  }
  let element_size = component_size * components
  if accessor.count < 0 {
    raise GltfError::InvalidAccessor(accessor_index)
  }
  let result : Array[Array[Double]] = Array::make(
    accessor.count,
    Array::make(components, 0.0),
  )
  match accessor.bufferView {
    None =>
      match accessor.sparse {
        None => raise GltfError::InvalidAccessor(accessor_index)
        Some(_) => ()
      }
    Some(view_index) => {
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
      let stride = view.byteStride.unwrap_or(element_size)
      if stride < element_size {
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
        result[index] = values
      }
    }
  }
  match accessor.sparse {
    None => ()
    Some(sparse) => {
      if sparse.count < 0 || sparse.count > accessor.count {
        raise GltfError::InvalidAccessor(accessor_index)
      }
      if sparse.indices.componentType != 5121 &&
        sparse.indices.componentType != 5123 &&
        sparse.indices.componentType != 5125 {
        raise GltfError::UnsupportedComponentType(sparse.indices.componentType)
      }
      let index_bytes = read_buffer_view(
        sparse.indices.bufferView,
        views,
        buffers,
      )
      let value_bytes = read_buffer_view(
        sparse.values.bufferView,
        views,
        buffers,
      )
      let index_size = component_size_for(sparse.indices.componentType)
      let values_start = sparse.values.byteOffset.unwrap_or(0)
      let indices_start = sparse.indices.byteOffset.unwrap_or(0)
      let values_required = values_start + sparse.count * element_size
      let indices_required = indices_start + sparse.count * index_size
      if values_start < 0 ||
        indices_start < 0 ||
        values_required > value_bytes.length() ||
        indices_required > index_bytes.length() {
        raise GltfError::InvalidAccessor(accessor_index)
      }
      for sparse_index in 0..<sparse.count {
        let index = read_component(
          index_bytes,
          indices_start + sparse_index * index_size,
          sparse.indices.componentType,
          false,
        ).to_int()
        if index < 0 || index >= accessor.count {
          raise GltfError::InvalidAccessor(accessor_index)
        }
        let values : Array[Double] = []
        let base = values_start + sparse_index * element_size
        for component in 0..<components {
          values.push(
            read_component(
              value_bytes,
              base + component * component_size,
              accessor.componentType,
              accessor.normalized.unwrap_or(false),
            ),
          )
        }
        result[index] = values
      }
    }
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
