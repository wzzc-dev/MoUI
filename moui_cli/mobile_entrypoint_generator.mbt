///|
fn mobile_entrypoint_pkg_text(
  module_name : String,
  platform : String,
) -> String {
  let template =
    #|import {
    #|  "wzzc-dev/moui/runtime",
    #|  "wzzc-dev/moui/backend/__PLATFORM__" @platform_host,
    #|  "wzzc-dev/moui/backend/__PLATFORM__/skia" @platform_skia,
    #|  "wzzc-dev/window/__PLATFORM__" @window_host,
    #|  "__MODULE__/app" @app,
    #|}
    #|
    #|supported_targets = "native"
    #|
    #|pkgtype(kind: "executable")
    #|
    #|options(
    #|  targets: { "main.mbt": [ "native" ] },
    #|)
  template
  .replace_all(old="__MODULE__", new=module_name)
  .replace_all(old="__PLATFORM__", new=platform)
}

///|
fn mobile_entrypoint_main_text(platform : String) -> String {
  let app_type = match platform {
    "android" => "AndroidWindowHostedApp"
    "ios" => "IosWindowHostedApp"
    "harmonyos" => "HarmonyOsWindowHostedApp"
    _ => abort("unsupported window-hosted mobile platform: " + platform)
  }
  let template =
    #|///|
    #|/// Window-hosted mobile entrypoint: `window` owns lifecycle, surface,
    #|/// and input callbacks; this package supplies the MoUI program and renderer.
    #|fn main {
    #|  let app = @platform_host.__APP_TYPE__::new(
    #|    title="MoUI app (window-hosted)",
    #|    runtime_factory=metrics => {
    #|      @runtime.new_program(
    #|        program=@app.program(),
    #|        size=metrics.logical_size,
    #|      )
    #|    },
    #|    provider_factory=() => @platform_skia.renderer_provider(),
    #|    auto_exit_after_frames=None,
    #|  )
    #|  let event_loop = @window_host.EventLoop::new()
    #|  event_loop.run_app(app)
    #|}
  template.replace_all(old="__APP_TYPE__", new=app_type)
}
