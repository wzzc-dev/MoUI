///|
extern "wasm" fn wechat_screen_width() -> Double = "canvas2d" "screen_width"

///|
extern "wasm" fn wechat_screen_height() -> Double = "canvas2d" "screen_height"

///|
extern "wasm" fn wechat_pixel_ratio() -> Double = "canvas2d" "pixel_ratio"

///|
fn main {
  let width = wechat_screen_width()
  let height = wechat_screen_height()
  let runtime = @composition.runtime(
    host_summary=@wechat.wechat_capability_summary(),
    environment=@wechat.app_environment(),
    width~,
    height~,
  )
  @runtime.run_app("MoUI Showcase", runtime)
  .render(@render_canvas2d.canvas())
  .backend(
    @wechat.entry(
      @wechat.WechatAppOptions::new(
        canvas_id="moui-canvas",
        logical_width=width,
        logical_height=height,
        scale_factor=wechat_pixel_ratio(),
      ),
    ),
  )
  .run()
}
