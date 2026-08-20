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
