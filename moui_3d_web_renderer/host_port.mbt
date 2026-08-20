///|
type Host3DSurface = Int

///|
type Host3DRenderer = Int

///|
type Host3DString = Int

///|
fn host_begin_string() -> Int = "webgpu" "begin_create_string"

///|
fn host_string_append(handle : Int, code_point : Int) -> Unit = "webgpu" "string_append_char"

///|
fn host_finish_string(handle : Int) -> Host3DString = "webgpu" "finish_create_string"

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
) -> Int = "webgpu" "three_d_surface_resize"

///|
fn host_draw_3d_mesh(renderer : Host3DRenderer, payload : Host3DString) -> Int = "webgpu" "three_d_draw_mesh"

///|
fn host_dispose_3d_renderer(renderer : Host3DRenderer) -> Unit = "webgpu" "three_d_renderer_dispose"

///|
fn host_dispose_3d_surface(surface : Host3DSurface) -> Unit = "webgpu" "three_d_surface_dispose"

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
        return @render.ThreeDRenderResult::Unavailable(
          "WebGPU device is unavailable",
        )
      }
      let payload = web_scene_payload(frame.snapshot(), frame.size())
      let status = host_draw_3d_mesh(renderer, host_string(payload))
      if status == 0 {
        @render.ThreeDRenderResult::Presented
      } else {
        @render.ThreeDRenderResult::Failed("WebGPU 3D host error {status}")
      }
    },
    dispose=() => {
      host_dispose_3d_renderer(renderer)
      host_dispose_3d_surface(surface)
    },
  )
  |> Some
}

///|
fn web_scene_payload(
  snapshot : @moui_3d.ViewportSnapshot,
  size : @render.ThreeDViewportSize,
) -> String {
  let scene = snapshot.scene()
  let camera = snapshot
    .camera()
    .with_aspect(size.width().to_double() / size.height().to_double())
  let vp = camera.projection().mul(camera.view())
  let output = StringBuilder::new()
  output.write_char('[')
  let mut first = true
  for node_id in 0..<scene.nodes().length() {
    match scene.node(@moui_3d.NodeId::new(node_id)) {
      Some(node) =>
        match node.mesh() {
          Some(mesh_id) =>
            match scene.mesh(mesh_id) {
              Some(mesh) => {
                let world = scene.world_transform(@moui_3d.NodeId::new(node_id))
                for primitive in mesh.primitives() {
                  let vertices = primitive.vertices()
                  let color = match primitive.material() {
                    Some(id) => scene.materials()[id.value()].base_color()
                    None => @moui_3d.Vec4::new(x=0.72, y=0.78, z=0.95, w=1.0)
                  }
                  for index in primitive.indices() {
                    match vertices.get(index) {
                      Some(vertex) => {
                        let world_position = world.transform_point(
                          vertex.position(),
                        )
                        let clip = vp.transform_point(world_position)
                        let normal = world
                          .transform_point(
                            vertex.position().add(vertex.normal()),
                          )
                          .sub(world_position)
                          .normalized()
                        let light = normal
                          .dot(
                            @moui_3d.Vec3::new(x=0.35, y=0.8, z=0.5).normalized(),
                          )
                          .max(0.18)
                        for
                          value in [
                            clip.x(),
                            clip.y(),
                            clip.z() * 0.5 + 0.5,
                            normal.x(),
                            normal.y(),
                            normal.z(),
                            color.x() * light,
                            color.y() * light,
                            color.z() * light,
                            color.w(),
                          ] {
                          if first {
                            first = false
                          } else {
                            output.write_char(',')
                          }
                          output.write_string(value.to_string())
                        }
                      }
                      None => ()
                    }
                  }
                }
              }
              None => ()
            }
          None => ()
        }
      None => ()
    }
  }
  output.write_char(']')
  output.to_string()
}
