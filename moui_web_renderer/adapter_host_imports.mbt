///|
fn raise_for_host_status(code : Int32) -> Unit raise WebGpuHostError {
  if code != 0 {
    raise host_status_to_error(code)
  }
}

///|
fn host_status_to_error(code : Int32) -> WebGpuHostError {
  match code {
    1 => Unavailable
    2 => AdapterUnavailable
    3 => DeviceUnavailable
    4 => SurfaceUnavailable
    5 => PipelineUnavailable
    6 => InvalidResource
    _ => HostError("webgpu host error code \{code}")
  }
}

///|
fn host_string(value : String) -> HostWebGpuString {
  let handle = host_begin_create_string()
  for ch in value {
    host_string_append_char(handle, ch.to_int())
  }
  host_finish_create_string(handle)
}

///|
fn host_begin_create_string() -> Int32 = "webgpu" "begin_create_string"

///|
fn host_string_append_char(handle : Int32, code_point : Int32) -> Unit = "webgpu" "string_append_char"

///|
fn host_finish_create_string(handle : Int32) -> HostWebGpuString = "webgpu" "finish_create_string"

///|
fn host_webgpu_available() -> Bool = "webgpu" "webgpu_available"

///|
fn host_adapter_ready() -> Bool = "webgpu" "adapter_ready"

///|
fn host_can_render() -> Bool = "webgpu" "can_render"

///|
fn host_measure_text_width(
  text : HostWebGpuString,
  family : HostWebGpuString,
  style : HostWebGpuString,
  size : Double,
  weight : Int32,
) -> Double = "webgpu" "measure_text_width"

///|
fn host_register_font_data(
  family : HostWebGpuString,
  base64_data : HostWebGpuString,
) -> Int32 = "webgpu" "register_font_data"

///|
fn host_create_surface(
  canvas_id : HostWebGpuString,
  width : Double,
  height : Double,
  scale_factor : Double,
) -> HostWebGpuSurface = "webgpu" "create_surface"

///|
fn host_surface_is_valid(surface : HostWebGpuSurface) -> Bool = "webgpu" "surface_is_valid"

///|
fn host_surface_resize(
  surface : HostWebGpuSurface,
  width : Double,
  height : Double,
  scale_factor : Double,
) -> Int32 = "webgpu" "surface_resize"

///|
fn host_surface_dispose(surface : HostWebGpuSurface) -> Unit = "webgpu" "surface_dispose"

///|
fn host_create_renderer(surface : HostWebGpuSurface) -> HostWebGpuRenderer = "webgpu" "create_renderer"

///|
fn host_renderer_is_valid(renderer : HostWebGpuRenderer) -> Bool = "webgpu" "renderer_is_valid"

///|
fn host_renderer_resize(
  renderer : HostWebGpuRenderer,
  width : Double,
  height : Double,
  scale_factor : Double,
) -> Int32 = "webgpu" "renderer_resize"

///|
fn host_begin_frame(
  renderer : HostWebGpuRenderer,
  width : Double,
  height : Double,
) -> Int32 = "webgpu" "begin_frame"

///|
fn host_clear(
  renderer : HostWebGpuRenderer,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
) -> Int32 = "webgpu" "clear"

///|
fn host_fill_rect(
  renderer : HostWebGpuRenderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
) -> Int32 = "webgpu" "fill_rect"

///|
fn host_stroke_rect(
  renderer : HostWebGpuRenderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
  stroke_width : Double,
) -> Int32 = "webgpu" "stroke_rect"

///|
fn host_fill_rounded_rect(
  renderer : HostWebGpuRenderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  radius : Double,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
) -> Int32 = "webgpu" "fill_rounded_rect"

///|
fn host_stroke_rounded_rect(
  renderer : HostWebGpuRenderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  radius : Double,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
  stroke_width : Double,
) -> Int32 = "webgpu" "stroke_rounded_rect"

///|
fn host_fill_rounded_rect_gradient(
  renderer : HostWebGpuRenderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  radius : Double,
  start_x : Double,
  start_y : Double,
  end_x : Double,
  end_y : Double,
  r0 : Double,
  g0 : Double,
  b0 : Double,
  a0 : Double,
  r1 : Double,
  g1 : Double,
  b1 : Double,
  a1 : Double,
) -> Int32 = "webgpu" "fill_rounded_rect_gradient"

///|
fn host_fill_rounded_rect_radial(
  renderer : HostWebGpuRenderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  radius : Double,
  center_x : Double,
  center_y : Double,
  gradient_radius : Double,
  r0 : Double,
  g0 : Double,
  b0 : Double,
  a0 : Double,
  r1 : Double,
  g1 : Double,
  b1 : Double,
  a1 : Double,
) -> Int32 = "webgpu" "fill_rounded_rect_radial"

///|
fn host_stroke_rounded_rect_gradient(
  renderer : HostWebGpuRenderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  radius : Double,
  stroke_width : Double,
  start_x : Double,
  start_y : Double,
  end_x : Double,
  end_y : Double,
  r0 : Double,
  g0 : Double,
  b0 : Double,
  a0 : Double,
  r1 : Double,
  g1 : Double,
  b1 : Double,
  a1 : Double,
) -> Int32 = "webgpu" "stroke_rounded_rect_gradient"

///|
fn host_stroke_rounded_rect_radial(
  renderer : HostWebGpuRenderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  radius : Double,
  stroke_width : Double,
  center_x : Double,
  center_y : Double,
  gradient_radius : Double,
  r0 : Double,
  g0 : Double,
  b0 : Double,
  a0 : Double,
  r1 : Double,
  g1 : Double,
  b1 : Double,
  a1 : Double,
) -> Int32 = "webgpu" "stroke_rounded_rect_radial"

///|
fn host_draw_shadow(
  renderer : HostWebGpuRenderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  radius : Double,
  offset_x : Double,
  offset_y : Double,
  blur_radius : Double,
  spread : Double,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
) -> Int32 = "webgpu" "draw_shadow"

///|
fn host_draw_text(
  renderer : HostWebGpuRenderer,
  text : HostWebGpuString,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  family : HostWebGpuString,
  style : HostWebGpuString,
  size : Double,
  weight : Int32,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
  align : Int32,
) -> Int32 = "webgpu" "draw_text"

///|
fn text_align_host_code(align : @core.TextAlign) -> Int32 {
  match align {
    TextStart => 0
    TextCenter => 1
    TextEnd => 2
  }
}

///|
fn host_draw_image(
  renderer : HostWebGpuRenderer,
  source : HostWebGpuString,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  opacity : Double,
  fit : Int32,
) -> Int32 = "webgpu" "draw_image"

///|
fn host_draw_path_mesh(
  renderer : HostWebGpuRenderer,
  mesh_payload : HostWebGpuString,
) -> Int32 = "webgpu" "draw_path_mesh"

///|
fn host_image_resource_status(
  renderer : HostWebGpuRenderer,
  source : HostWebGpuString,
) -> Int32 = "webgpu" "image_resource_status"

///|
fn host_image_resource_width(
  renderer : HostWebGpuRenderer,
  source : HostWebGpuString,
) -> Int32 = "webgpu" "image_resource_width"

///|
fn host_image_resource_height(
  renderer : HostWebGpuRenderer,
  source : HostWebGpuString,
) -> Int32 = "webgpu" "image_resource_height"

///|
fn image_fit_host_code(fit : @core.ImageFit) -> Int32 {
  match fit {
    Contain => 0
    Cover => 1
    Stretch => 2
    ScaleDown => 3
    FitWidth => 4
    FitHeight => 5
  }
}

///|
fn host_push_clip(
  renderer : HostWebGpuRenderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Int32 = "webgpu" "push_clip"

///|
fn host_pop_clip(renderer : HostWebGpuRenderer) -> Int32 = "webgpu" "pop_clip"

///|
fn host_push_transform(
  renderer : HostWebGpuRenderer,
  a : Double,
  b : Double,
  c : Double,
  d : Double,
  tx : Double,
  ty : Double,
) -> Int32 = "webgpu" "push_transform"

///|
fn host_pop_transform(renderer : HostWebGpuRenderer) -> Int32 = "webgpu" "pop_transform"

///|
fn host_push_opacity(renderer : HostWebGpuRenderer, opacity : Double) -> Int32 = "webgpu" "push_opacity"

///|
fn host_pop_opacity(renderer : HostWebGpuRenderer) -> Int32 = "webgpu" "pop_opacity"

///|
fn host_push_layer(
  renderer : HostWebGpuRenderer,
  opacity : Double,
  blend_mode : Int32,
  mask_kind : Int32,
  mask_x : Double,
  mask_y : Double,
  mask_width : Double,
  mask_height : Double,
  mask_radius : Double,
  offscreen : Bool,
) -> Int32 = "webgpu" "push_layer"

///|
fn host_pop_layer(renderer : HostWebGpuRenderer) -> Int32 = "webgpu" "pop_layer"

///|
fn host_push_filter(
  renderer : HostWebGpuRenderer,
  filter_kind : Int32,
  amount : Double,
  matrix_values : HostWebGpuString,
) -> Int32 = "webgpu" "push_filter"

///|
fn host_pop_filter(renderer : HostWebGpuRenderer) -> Int32 = "webgpu" "pop_filter"

///|
fn host_draw_shader_effect(
  renderer : HostWebGpuRenderer,
  name : HostWebGpuString,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  uniforms : HostWebGpuString,
  start_x : Double,
  start_y : Double,
  end_x : Double,
  end_y : Double,
  r0 : Double,
  g0 : Double,
  b0 : Double,
  a0 : Double,
  r1 : Double,
  g1 : Double,
  b1 : Double,
  a1 : Double,
) -> Int32 = "webgpu" "draw_shader_effect"

///|
fn host_present(renderer : HostWebGpuRenderer) -> Int32 = "webgpu" "present"

///|
fn host_renderer_dispose(renderer : HostWebGpuRenderer) -> Unit = "webgpu" "renderer_dispose"
