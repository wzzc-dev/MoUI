///|
extern "wasm" fn wechat_screen_width() -> Double = "canvas2d" "screen_width"
extern "wasm" fn wechat_screen_height() -> Double = "canvas2d" "screen_height"
extern "wasm" fn wechat_pixel_ratio() -> Double = "canvas2d" "pixel_ratio"

///|
fn main {
  let app = @showcase_app.ShowcaseApp::new()
  let w = wechat_screen_width()
  let h = wechat_screen_height()
  let scale = wechat_pixel_ratio()
  @wechat.run_app(
    canvas_id="moui-canvas",
    runtime=@runtime.new_program_with_dimensions(
      program=app.program(),
      width=w,
      height=h,
    ),
    logical_width=w,
    logical_height=h,
    scale_factor=scale,
  )
}

///|
pub fn wechat_dispatch_event(
  kind : Int,
  raw_id : Int,
  arg0 : Int,
  arg1 : Int,
  argd : Double,
  text_id : Int,
) -> Unit {
  @wechat.wechat_dispatch_event(kind, raw_id, arg0, arg1, argd, text_id)
}

///|
pub fn wechat_dispatch_pointer_input(
  raw_id : Int,
  kind : Int,
  x_px : Double,
  y_px : Double,
  delta_x_px : Double,
  delta_y_px : Double,
  button : Int,
  modifiers : Int,
) -> Int {
  @wechat.wechat_dispatch_pointer_input(
    raw_id, kind, x_px, y_px, delta_x_px, delta_y_px, button, modifiers,
  )
}

///|
pub fn wechat_render_frame() -> Unit {
  @wechat.wechat_render_frame()
}

///|
pub fn wechat_surface_created(
  width : Double,
  height : Double,
  scale_factor : Double,
) -> Unit {
  @wechat.wechat_surface_created(width, height, scale_factor)
}

///|
pub fn wechat_surface_destroyed() -> Unit {
  @wechat.wechat_surface_destroyed()
}

///|
pub fn wechat_app_show() -> Unit {
  @wechat.wechat_app_show()
}

///|
pub fn wechat_app_hide() -> Unit {
  @wechat.wechat_app_hide()
}