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
fn host_draw_3d_mesh_binary(
  renderer : Host3DRenderer,
  payload : Host3DString,
) -> Int = "webgpu" "three_d_draw_mesh_binary"

///|
fn host_update_3d_resources(
  renderer : Host3DRenderer,
  payload : Host3DString,
) -> Int = "webgpu" "three_d_update_resources"

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
      let resource_status = host_update_3d_resources(
        renderer,
        host_string(frame.packet().resource_payload()),
      )
      if resource_status != 0 {
        return @render.ThreeDRenderResult::Failed(
          "WebGPU 3D resource residency error {resource_status}",
        )
      }
      let status = host_draw_3d_mesh_binary(
        renderer,
        host_string(
          @base64.encode(frame.packet().vertex_payload_bytes(), padding=true),
        ),
      )
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
