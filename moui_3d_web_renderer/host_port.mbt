///|
type Host3DSurface = Int32

///|
type Host3DRenderer = Int32

///|
type Host3DString = Int32

///|
fn host_begin_string() -> Int32 = "webgpu" "begin_create_string"

///|
fn host_string_append(handle : Int32, code_point : Int32) -> Unit = "webgpu" "string_append_char"

///|
fn host_finish_string(handle : Int32) -> Host3DString = "webgpu" "finish_create_string"

///|
fn host_string(value : String) -> Host3DString {
  let handle = host_begin_string()
  for index in 0..<value.length() {
    host_string_append(
      handle,
      value.code_unit_at(index).unsafe_to_char().to_int(),
    )
  }
  host_finish_string(handle)
}

///|
fn host_webgpu_available() -> Bool = "webgpu" "three_d_available"

///|
fn host_create_3d_surface(
  canvas_id : Host3DString,
  width : Double,
  height : Double,
  scale : Double,
) -> Host3DSurface = "webgpu" "create_3d_surface"

///|
fn host_create_3d_renderer(surface : Host3DSurface) -> Host3DRenderer = "webgpu" "create_3d_renderer"

///|
fn host_resize_3d_surface(
  surface : Host3DSurface,
  width : Double,
  height : Double,
  scale : Double,
) -> Int32 = "webgpu" "three_d_surface_resize"

///|
fn host_draw_3d_mesh_binary(
  renderer : Host3DRenderer,
  payload : Host3DString,
) -> Int32 = "webgpu" "three_d_draw_mesh_binary"

///|
fn host_update_3d_resources(
  renderer : Host3DRenderer,
  payload : Host3DString,
) -> Int32 = "webgpu" "three_d_update_resources"

///|
fn host_dispose_3d_renderer(renderer : Host3DRenderer) -> Unit = "webgpu" "three_d_renderer_dispose"

///|
fn host_dispose_3d_surface(surface : Host3DSurface) -> Unit = "webgpu" "three_d_surface_dispose"

///|
/// GPU-skinned host port. Geometry is uploaded once per mesh key through the
/// begin/push/end triple; each frame then ships only the view-projection,
/// bone palette and per-item model/color, and presents.
fn host_3d_skin_available(renderer : Host3DRenderer) -> Bool =
  "webgpu" "three_d_skin_available"

///|
fn host_3d_skin_mesh_begin(renderer : Host3DRenderer) -> Int32 =
  "webgpu" "three_d_skin_mesh_begin"

///|
fn host_3d_skin_mesh_push(
  mesh : Int32,
  x : Double,
  y : Double,
  z : Double,
  w : Double,
  nx : Double,
  ny : Double,
  nz : Double,
  cr : Double,
  cg : Double,
  cb : Double,
  ca : Double,
  j0 : Double,
  j1 : Double,
  j2 : Double,
  j3 : Double,
  w0 : Double,
  w1 : Double,
  w2 : Double,
  w3 : Double,
) -> Int32 = "webgpu" "three_d_skin_mesh_push"

///|
fn host_3d_skin_mesh_end(mesh : Int32) -> Int32 =
  "webgpu" "three_d_skin_mesh_end"

///|
fn host_3d_skin_mesh_release(mesh : Int32) -> Unit =
  "webgpu" "three_d_skin_mesh_release"

///|
fn host_3d_skin_frame(
  renderer : Host3DRenderer,
  vp0 : Double,
  vp1 : Double,
  vp2 : Double,
  vp3 : Double,
  vp4 : Double,
  vp5 : Double,
  vp6 : Double,
  vp7 : Double,
  vp8 : Double,
  vp9 : Double,
  vp10 : Double,
  vp11 : Double,
  vp12 : Double,
  vp13 : Double,
  vp14 : Double,
  vp15 : Double,
  lx : Double,
  ly : Double,
  lz : Double,
  lw : Double,
  cx : Double,
  cy : Double,
  cz : Double,
  cw : Double,
) -> Int32 = "webgpu" "three_d_skin_frame"

///|
fn host_3d_skin_bone(
  renderer : Host3DRenderer,
  index : Int32,
  m0 : Double,
  m1 : Double,
  m2 : Double,
  m3 : Double,
  m4 : Double,
  m5 : Double,
  m6 : Double,
  m7 : Double,
  m8 : Double,
  m9 : Double,
  m10 : Double,
  m11 : Double,
  m12 : Double,
  m13 : Double,
  m14 : Double,
  m15 : Double,
) -> Int32 = "webgpu" "three_d_skin_bone"

///|
fn host_3d_skin_item(
  renderer : Host3DRenderer,
  mesh : Int32,
  count : Int32,
  m0 : Double,
  m1 : Double,
  m2 : Double,
  m3 : Double,
  m4 : Double,
  m5 : Double,
  m6 : Double,
  m7 : Double,
  m8 : Double,
  m9 : Double,
  m10 : Double,
  m11 : Double,
  m12 : Double,
  m13 : Double,
  m14 : Double,
  m15 : Double,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
  metal : Double,
  rough : Double,
) -> Int32 = "webgpu" "three_d_skin_item"

///|
fn host_3d_skin_present(renderer : Host3DRenderer) -> Int32 =
  "webgpu" "three_d_skin_present"

///|
/// Bone palette slots retained by the host pipeline.
let host_3d_skin_max_bones : Int32 = 256

///|
fn render_skinned_frame(
  renderer : Host3DRenderer,
  frame : @render.ThreeDFrame,
  uploaded : Map[@render.ThreeDSkinMeshKey, Int32],
) -> (@render.ThreeDRenderResult, Map[@render.ThreeDSkinMeshKey, Int32]) {
  let known : Array[@render.ThreeDSkinMeshKey] = []
  for key, _handle in uploaded {
    known.push(key)
  }
  let packet = @render.ThreeDSkinPacket::from_snapshot(
    frame.snapshot(),
    size=frame.size(),
    uploaded=known,
  )
  if packet.bone_count() > host_3d_skin_max_bones {
    return (
      Failed("WebGPU 3D skin palette overflow (\{packet.bone_count()} bones)"),
      uploaded,
    )
  }
  let vp = packet.view_projection().values()
  let cam = packet.camera_position()
  let fail : (String, Map[@render.ThreeDSkinMeshKey, Int32]) -> (
    @render.ThreeDRenderResult,
    Map[@render.ThreeDSkinMeshKey, Int32],
  ) = (message, map) => (Failed(message), map)
  if host_3d_skin_frame(
    renderer,
    vp[0],
    vp[1],
    vp[2],
    vp[3],
    vp[4],
    vp[5],
    vp[6],
    vp[7],
    vp[8],
    vp[9],
    vp[10],
    vp[11],
    vp[12],
    vp[13],
    vp[14],
    vp[15],
    0.35,
    0.8,
    0.5,
    0.0,
    cam.x(),
    cam.y(),
    cam.z(),
    1.0,
  ) != 0 {
    return fail("WebGPU 3D skin frame begin failed", uploaded)
  }
  let map = uploaded.copy()
  for index, bone in packet.bones() {
    let m = bone.values()
    if host_3d_skin_bone(
      renderer,
      index,
      m[0],
      m[1],
      m[2],
      m[3],
      m[4],
      m[5],
      m[6],
      m[7],
      m[8],
      m[9],
      m[10],
      m[11],
      m[12],
      m[13],
      m[14],
      m[15],
    ) != 0 {
      return fail("WebGPU 3D skin bone upload failed", map)
    }
  }
  for mesh in packet.meshes() {
    let vertices = mesh.vertices()
    let handle = host_3d_skin_mesh_begin(renderer)
    if handle == 0 {
      return fail("WebGPU 3D skin mesh begin failed", map)
    }
    let vertex_count = vertices.length() / 19
    let mut offset = 0
    while offset < vertex_count {
      let base = offset * 19
      let status = host_3d_skin_mesh_push(
        handle,
        vertices[base],
        vertices[base + 1],
        vertices[base + 2],
        vertices[base + 3],
        vertices[base + 4],
        vertices[base + 5],
        vertices[base + 6],
        vertices[base + 7],
        vertices[base + 8],
        vertices[base + 9],
        vertices[base + 10],
        vertices[base + 11],
        vertices[base + 12],
        vertices[base + 13],
        vertices[base + 14],
        vertices[base + 15],
        vertices[base + 16],
        vertices[base + 17],
        vertices[base + 18],
      )
      if status != 0 {
        host_3d_skin_mesh_release(handle)
        return fail("WebGPU 3D skin mesh push failed", map)
      }
      offset = offset + 1
    }
    if host_3d_skin_mesh_end(handle) != 0 {
      host_3d_skin_mesh_release(handle)
      return fail("WebGPU 3D skin mesh upload failed", map)
    }
    map.set(mesh.key(), handle)
  }
  for item in packet.items() {
    match map.get(item.key()) {
      None => return fail("WebGPU 3D skin mesh handle missing", map)
      Some(handle) => {
        let m = item.model().values()
        let color = item.color()
        if host_3d_skin_item(
          renderer,
          handle,
          item.vertex_count(),
          m[0],
          m[1],
          m[2],
          m[3],
          m[4],
          m[5],
          m[6],
          m[7],
          m[8],
          m[9],
          m[10],
          m[11],
          m[12],
          m[13],
          m[14],
          m[15],
          color.x(),
          color.y(),
          color.z(),
          color.w(),
          item.metallic(),
          item.roughness(),
        ) != 0 {
          return fail("WebGPU 3D skin item rejected", map)
        }
      }
    }
  }
  let status = host_3d_skin_present(renderer)
  if status == 0 {
    (Presented, map)
  } else {
    fail("WebGPU 3D skin present error {status}", map)
  }
}

///|
/// True when any rendered node references a skin, which selects the GPU
/// skinning path over the legacy CPU-expanded triangle path.
fn snapshot_needs_skinning(frame : @render.ThreeDFrame) -> Bool {
  let scene = frame.snapshot().scene()
  scene.skins().length() > 0 && scene.nodes().any(node => node.skin() is Some(_))
}

///|
fn create_webgpu_3d_session(
  window : UInt64,
  size : @render.ThreeDViewportSize,
) -> @render.ThreeDRendererSession? {
  if !host_webgpu_available() {
    return None
  }
  let surface = host_create_3d_surface(
    host_string("moui-3d-viewport-\{window}"),
    size.width().to_double(),
    size.height().to_double(),
    size.scale_factor(),
  )
  if surface == 0 {
    return None
  }
  let renderer = host_create_3d_renderer(surface)
  if renderer == 0 {
    host_dispose_3d_surface(surface)
    return None
  }
  let skin_meshes : @ref.Ref[Map[@render.ThreeDSkinMeshKey, Int32]] = Ref({})
  @render.ThreeDRendererSession::new(
    descriptor=descriptor(),
    resize=next => {
      ignore(
        host_resize_3d_surface(
          surface,
          next.width().to_double(),
          next.height().to_double(),
          next.scale_factor(),
        ),
      )
    },
    render=frame => {
      if !host_webgpu_available() {
        return Unavailable("WebGPU device is unavailable")
      }
      if snapshot_needs_skinning(frame) && host_3d_skin_available(renderer) {
        let (result, next_map) = render_skinned_frame(
          renderer,
          frame,
          skin_meshes.val,
        )
        skin_meshes.val = next_map
        return result
      }
      let resource_status = host_update_3d_resources(
        renderer,
        host_string(frame.packet().resource_payload()),
      )
      if resource_status != 0 {
        return Failed("WebGPU 3D resource residency error {resource_status}")
      }
      let status = host_draw_3d_mesh_binary(
        renderer,
        host_string(
          @base64.encode(frame.packet().vertex_payload_bytes(), padding=true),
        ),
      )
      if status == 0 {
        Presented
      } else {
        Failed("WebGPU 3D host error {status}")
      }
    },
    dispose=() => {
      for _key, handle in skin_meshes.val {
        host_3d_skin_mesh_release(handle)
      }
      skin_meshes.val = {}
      host_dispose_3d_renderer(renderer)
      host_dispose_3d_surface(surface)
    },
  )
  |> Some
}

///|
