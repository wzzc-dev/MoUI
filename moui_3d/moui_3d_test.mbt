///|
test "GLB parser validates header, version and chunks" {
  let json = b"{\"asset\":{\"version\":\"2.0\"},\"meshes\":[],\"nodes\":[]}"
  let padded_length = (json.length() + 3) / 4 * 4
  let total_length = 12 + 8 + padded_length
  let bytes : Array[Byte] = []
  bytes.append([b'g', b'l', b'T', b'F', 2, 0, 0, 0])
  bytes.append(glb_u32(total_length))
  bytes.append(glb_u32(padded_length))
  bytes.append([b'J', b'S', b'O', b'N'])
  bytes.append(json.to_array())
  while bytes.length() < total_length {
    bytes.push(32)
  }
  let document = parse_glb(Bytes::from_array(bytes)) catch {
    _ => fail("valid GLB should parse")
  }
  assert_eq(document.mesh_count(), 0)
  assert_eq(document.node_count(), 0)
  assert_eq(document.sampler_count(), 0)
  assert_eq(document.camera_count(), 0)
  assert_eq(document.scene_count(), 0)
  assert_true(document.binary() is None)
}

///|
test "GLB parser rejects malformed input and unsupported asset versions" {
  assert_true(glb_short_input_fails())
  let json = "{\"asset\":{\"version\":\"1.0\"}}"
  assert_true(gltf_v1_fails(json))
}

///|
test "scene bounds and CPU picking choose the nearest primitive" {
  let scene = Scene::empty()
  let mesh = Mesh::new(primitives=[
    Primitive::new(
      vertices=[
        Vertex::new(position=Vec3::new(x=-1.0, y=-1.0, z=0.0)),
        Vertex::new(position=Vec3::new(x=1.0, y=-1.0, z=0.0)),
        Vertex::new(position=Vec3::new(x=0.0, y=1.0, z=0.0)),
      ],
      indices=[0, 1, 2],
    ),
  ])
  let mesh_id = scene.add_mesh(mesh)
  let node_id = scene.add_node(Node::new(mesh=Some(mesh_id)))
  let bounds = scene.bounds()
  assert_true(bounds.is_valid())
  assert_eq(bounds.center(), Vec3::new(x=0.0, y=0.0, z=0.0))
  let hit = scene.pick(
    Ray::new(
      origin=Vec3::new(x=0.0, y=0.0, z=2.0),
      direction=Vec3::new(x=0.0, y=0.0, z=-1.0),
    ),
  )
  match hit {
    Some(value) => {
      assert_eq(value.node(), node_id)
      assert_eq(value.primitive_index(), 0)
      assert_eq(value.distance(), 2.0)
    }
    None => fail("ray should hit triangle")
  }
}

///|
test "viewport binding rejects stale snapshots" {
  let binding = ThreeDViewportBinding::new()
  let camera = OrbitCamera::new()
  let scene = Scene::empty()
  assert_true(
    binding.publish(ViewportSnapshot::new(scene_revision=2L, scene~, camera~)),
  )
  assert_eq(binding.status(), ViewportStatus::Loading)
  assert_false(
    binding.publish(ViewportSnapshot::new(scene_revision=1L, scene~, camera~)),
  )
  assert_eq(binding.snapshot().unwrap().scene_revision(), 2L)
}

///|
test "perspective projection maps the camera target into clip depth" {
  let camera = OrbitCamera::new(
    target=Vec3::zero(),
    radius=3.0,
    azimuth=0.0,
    polar=@math.PI / 2.0,
  )
  let clip = camera
    .projection()
    .mul(camera.view())
    .transform_point(Vec3::zero())
  assert_true(clip.x().abs() < 1.0e-9)
  assert_true(clip.y().abs() < 1.0e-9)
  assert_true(clip.z() > -1.0 && clip.z() < 1.0)
}

///|
test "viewport event decoder preserves pick node ids" {
  let event = @core.PlatformViewEvent::Named(
    name="pick",
    value="7",
    detail="",
    flag=false,
  )
  match decode_viewport_event(event) {
    Some(ViewportEvent::Pick(node)) => assert_eq(node, NodeId::new(7))
    _ => assert_true(false)
  }
}

///|
test "viewport event decoder recognizes renderer status invalidation" {
  let event = @core.PlatformViewEvent::Named(
    name="renderer_status",
    value="",
    detail="",
    flag=false,
  )
  assert_true(
    decode_viewport_event(event) is Some(ViewportEvent::RendererStatus),
  )
}

///|
test "glTF loader decodes positions into a scene" {
  let json = "{\"asset\":{\"version\":\"2.0\"},\"buffers\":[{\"byteLength\":42}],\"bufferViews\":[{\"buffer\":0,\"byteLength\":36},{\"buffer\":0,\"byteOffset\":36,\"byteLength\":6}],\"accessors\":[{\"bufferView\":0,\"componentType\":5126,\"count\":3,\"type\":\"VEC3\"},{\"bufferView\":1,\"componentType\":5123,\"count\":3,\"type\":\"SCALAR\"}],\"meshes\":[{\"primitives\":[{\"attributes\":{\"POSITION\":0},\"indices\":1}]}],\"nodes\":[{\"mesh\":0}]}"
  let bytes : Array[Byte] = []
  append_f32(bytes, 0.0)
  append_f32(bytes, 0.0)
  append_f32(bytes, 0.0)
  append_f32(bytes, 1.0)
  append_f32(bytes, 0.0)
  append_f32(bytes, 0.0)
  append_f32(bytes, 0.0)
  append_f32(bytes, 1.0)
  append_f32(bytes, 0.0)
  bytes.append([0, 0, 2, 0, 1, 0])
  let scene = load_gltf_scene(json, binary=Some(Bytes::from_array(bytes))) catch {
    _ => fail("valid glTF scene should load")
  }
  assert_eq(scene.meshes().length(), 1)
  assert_eq(scene.nodes().length(), 1)
  assert_eq(scene.meshes()[0].primitives()[0].vertices().length(), 3)
  assert_eq(scene.meshes()[0].primitives()[0].indices(), [0, 2, 1])
  assert_eq(scene.bounds().max(), Vec3::new(x=1.0, y=1.0, z=0.0))
}

///|
test "glTF loader reports unsupported primitive mode" {
  let json = "{\"asset\":{\"version\":\"2.0\"},\"meshes\":[{\"primitives\":[{\"attributes\":{},\"mode\":1}]}]}"
  try {
    ignore(load_gltf_scene(json))
    assert_true(false)
  } catch {
    GltfError::UnsupportedPrimitiveMode(mode) => assert_eq(mode, 1)
    _ => assert_true(false)
  } noraise {
    _ => fail("loader should raise a typed error")
  }
}

///|
test "glTF material keeps material-level texture and alpha fields" {
  let json = "{\"asset\":{\"version\":\"2.0\"},\"images\":[{\"uri\":\"albedo.png\"},{\"uri\":\"normal.png\"},{\"uri\":\"occ.png\"},{\"uri\":\"emit.png\"}],\"textures\":[{\"source\":0},{\"source\":1},{\"source\":2},{\"source\":3}],\"materials\":[{\"pbrMetallicRoughness\":{\"baseColorFactor\":[0.2,0.3,0.4,0.5],\"baseColorTexture\":{\"index\":0}},\"normalTexture\":{\"index\":1},\"occlusionTexture\":{\"index\":2},\"emissiveTexture\":{\"index\":3},\"emissiveFactor\":[0.1,0.2,0.3],\"alphaMode\":\"MASK\",\"alphaCutoff\":0.25,\"doubleSided\":true}]}"
  let scene = load_gltf_scene(json) catch {
    _ => fail("material-only glTF should load")
  }
  let material = scene.materials()[0]
  assert_true(assert_texture_id(material.base_color_texture(), 0))
  assert_true(assert_texture_id(material.normal_texture(), 1))
  assert_true(assert_texture_id(material.occlusion_texture(), 2))
  assert_true(assert_texture_id(material.emissive_texture(), 3))
  assert_eq(material.alpha_mode(), AlphaMode::Mask)
  assert_eq(material.alpha_cutoff(), 0.25)
  assert_true(material.double_sided())
  assert_eq(material.emissive_factor(), Vec3::new(x=0.1, y=0.2, z=0.3))
}

///|
test "glTF sampler camera and scene metadata are preserved" {
  let json = "{\"asset\":{\"version\":\"2.0\"},\"images\":[{\"uri\":\"albedo.png\"}],\"textures\":[{\"source\":0,\"sampler\":0}],\"samplers\":[{\"magFilter\":9728,\"minFilter\":9987,\"wrapS\":33648,\"wrapT\":33071}],\"cameras\":[{\"name\":\"Main\",\"type\":\"perspective\",\"perspective\":{\"yfov\":1.0,\"znear\":0.1,\"zfar\":100.0}}],\"nodes\":[{\"camera\":0}],\"scenes\":[{\"name\":\"Root\",\"nodes\":[0]}],\"scene\":0}"
  let scene = load_gltf_scene(json) catch {
    _ => fail("sampler and camera metadata should load")
  }
  assert_eq(scene.samplers().length(), 1)
  assert_eq(scene.samplers()[0].mag_filter(), SamplerFilter::Nearest)
  assert_eq(scene.samplers()[0].min_filter(), SamplerFilter::LinearMipmapLinear)
  assert_eq(scene.samplers()[0].wrap_s(), SamplerWrap::MirroredRepeat)
  assert_eq(scene.samplers()[0].wrap_t(), SamplerWrap::ClampToEdge)
  assert_eq(scene.cameras().length(), 1)
  assert_eq(scene.cameras()[0].name(), "Main")
  assert_eq(scene.scene_definitions().length(), 1)
  assert_eq(scene.default_scene(), Some(0))
  assert_eq(scene.nodes()[0].camera(), Some(0))
}

///|
test "glTF sparse accessor overlays values onto a zero base" {
  let json = "{\"asset\":{\"version\":\"2.0\"},\"buffers\":[{\"byteLength\":13}],\"bufferViews\":[{\"buffer\":0,\"byteLength\":1},{\"buffer\":0,\"byteOffset\":1,\"byteLength\":12}],\"accessors\":[{\"componentType\":5126,\"count\":2,\"type\":\"VEC3\",\"sparse\":{\"count\":1,\"indices\":{\"bufferView\":0,\"componentType\":5121},\"values\":{\"bufferView\":1}}}],\"meshes\":[{\"primitives\":[{\"attributes\":{\"POSITION\":0}}]}],\"nodes\":[{\"mesh\":0}]}"
  let bytes : Array[Byte] = [1]
  append_f32(bytes, 1.0)
  append_f32(bytes, 2.0)
  append_f32(bytes, 3.0)
  let scene = load_gltf_scene(json, binary=Some(Bytes::from_array(bytes))) catch {
    _ => fail("sparse accessor should load")
  }
  let positions = scene.meshes()[0].primitives()[0]
    .vertices()
    .map(vertex => vertex.position())
  assert_eq(positions[0], Vec3::zero())
  assert_eq(positions[1], Vec3::new(x=1.0, y=2.0, z=3.0))
}

///|
test "glTF required extensions fail with a distinct diagnostic" {
  let json = "{\"asset\":{\"version\":\"2.0\"},\"extensionsRequired\":[\"KHR_draco_mesh_compression\"]}"
  try {
    ignore(load_gltf_scene(json))
    assert_true(false)
  } catch {
    GltfError::UnsupportedRequiredExtension(value) =>
      assert_eq(value, "KHR_draco_mesh_compression")
    _ => assert_true(false)
  } noraise {
    _ => fail("required extension should raise a typed error")
  }
}

///|
test "glTF loader ingests skin joints weights and morph targets" {
  let json = "{\"asset\":{\"version\":\"2.0\"},\"buffers\":[{\"byteLength\":132}],\"bufferViews\":[{\"buffer\":0,\"byteLength\":36},{\"buffer\":0,\"byteOffset\":36,\"byteLength\":12},{\"buffer\":0,\"byteOffset\":48,\"byteLength\":48},{\"buffer\":0,\"byteOffset\":96,\"byteLength\":36}],\"accessors\":[{\"bufferView\":0,\"componentType\":5126,\"count\":3,\"type\":\"VEC3\"},{\"bufferView\":1,\"componentType\":5121,\"count\":3,\"type\":\"VEC4\"},{\"bufferView\":2,\"componentType\":5126,\"count\":3,\"type\":\"VEC4\"},{\"bufferView\":3,\"componentType\":5126,\"count\":3,\"type\":\"VEC3\"}],\"meshes\":[{\"primitives\":[{\"attributes\":{\"POSITION\":0,\"JOINTS_0\":1,\"WEIGHTS_0\":2},\"targets\":[{\"POSITION\":3}]}]}],\"nodes\":[{\"mesh\":0,\"skin\":0},{\"name\":\"joint\"}],\"skins\":[{\"name\":\"Armature\",\"joints\":[1]}]}"
  let bytes : Array[Byte] = []
  for value in [0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0] {
    append_f32(bytes, value)
  }
  bytes.append([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
  for value in [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0] {
    append_f32(bytes, value)
  }
  for value in [0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0] {
    append_f32(bytes, value)
  }
  assert_eq(bytes.length(), 132)
  let scene = load_gltf_scene(json, binary=Some(Bytes::from_array(bytes))) catch {
    _ => fail("skin and morph glTF should load")
  }
  assert_eq(scene.skins().length(), 1)
  assert_eq(scene.skins()[0].joints(), [NodeId::new(1)])
  let node = scene.nodes()[0]
  assert_eq(node.skin(), Some(0))
  let primitive = scene.meshes()[0].primitives()[0]
  assert_eq(primitive.vertices()[0].joints(), (0, 0, 0, 0))
  assert_eq(
    primitive.vertices()[1].weights(),
    Vec4::new(x=1.0, y=0.0, z=0.0, w=0.0),
  )
  assert_eq(primitive.morph_targets().length(), 1)
  let delta = primitive.morph_targets()[0][0].position()
  assert_true((delta.x() - 0.1).abs() < 1.0e-6)
}

///|
test "glTF loader decodes animation channels from accessors" {
  let json = "{\"asset\":{\"version\":\"2.0\"},\"buffers\":[{\"byteLength\":32}],\"bufferViews\":[{\"buffer\":0,\"byteLength\":8},{\"buffer\":0,\"byteOffset\":8,\"byteLength\":24}],\"accessors\":[{\"bufferView\":0,\"componentType\":5126,\"count\":2,\"type\":\"SCALAR\"},{\"bufferView\":1,\"componentType\":5126,\"count\":2,\"type\":\"VEC3\"}],\"nodes\":[{}],\"animations\":[{\"name\":\"move\",\"samplers\":[{\"input\":0,\"output\":1,\"interpolation\":\"LINEAR\"}],\"channels\":[{\"sampler\":0,\"target\":{\"node\":0,\"path\":\"translation\"}}]}]}"
  let bytes : Array[Byte] = []
  append_f32(bytes, 0.0)
  append_f32(bytes, 1.0)
  append_f32(bytes, 0.0)
  append_f32(bytes, 0.0)
  append_f32(bytes, 0.0)
  append_f32(bytes, 2.0)
  append_f32(bytes, 0.0)
  append_f32(bytes, 0.0)
  let scene = load_gltf_scene(json, binary=Some(Bytes::from_array(bytes))) catch {
    _ => fail("valid animation glTF should load")
  }
  assert_eq(scene.animations().length(), 1)
  let clip = scene.animations()[0]
  assert_eq(clip.name(), "move")
  assert_eq(clip.duration(), 1.0)
  let channel = clip.channels()[0]
  assert_eq(channel.node(), NodeId::new(0))
  assert_eq(sample_animation_channel(channel, 0.5), [1.0, 0.0, 0.0])
}

///|
test "scene applies sampled translation, rotation and scale without mutation" {
  let scene = Scene::empty()
  let node = scene.add_node(
    Node::new(local_transform=Mat4::translation(Vec3::new(x=2.0, y=3.0, z=4.0))),
  )
  let translated = scene.apply_animation_samples([
    AnimationSample::new(node~, path=AnimationPath::Translation, value=[
      7.0, 8.0, 9.0,
    ]),
  ])
  assert_eq(
    translated
    .node(node)
    .unwrap()
    .local_transform()
    .transform_point(Vec3::zero()),
    Vec3::new(x=7.0, y=8.0, z=9.0),
  )
  assert_eq(
    scene.node(node).unwrap().local_transform().transform_point(Vec3::zero()),
    Vec3::new(x=2.0, y=3.0, z=4.0),
  )
}

///|
fn assert_texture_id(value : TextureId?, expected : Int) -> Bool {
  match value {
    Some(id) => id.value() == expected
    None => false
  }
}

///|
fn glb_u32(value : Int) -> Array[Byte] {
  [
    (value & 0xFF).to_byte(),
    ((value >> 8) & 0xFF).to_byte(),
    ((value >> 16) & 0xFF).to_byte(),
    ((value >> 24) & 0xFF).to_byte(),
  ]
}

///|
fn append_f32(out : Array[Byte], value : Double) -> Unit {
  let bits = Float::from_double(value).reinterpret_as_uint()
  out.push((bits & 0xFFU).to_byte())
  out.push(((bits >> 8) & 0xFFU).to_byte())
  out.push(((bits >> 16) & 0xFFU).to_byte())
  out.push(((bits >> 24) & 0xFFU).to_byte())
}

///|
fn glb_short_input_fails() -> Bool {
  try {
    ignore(parse_glb(b"bad"))
    false
  } catch {
    GltfError::EmptyInput => true
    _ => false
  } noraise {
    _ => false
  }
}

///|
fn gltf_v1_fails(json : String) -> Bool {
  try {
    ignore(parse_gltf_json(json))
    false
  } catch {
    GltfError::UnsupportedAssetVersion(version) => version == "1.0"
    _ => false
  } noraise {
    _ => false
  }
}
