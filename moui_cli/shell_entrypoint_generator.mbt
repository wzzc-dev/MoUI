///|
fn mobile_entrypoint_pkg_text(
  module_name : String,
  platform : String,
) -> String {
  let template =
    #|import {
    #|  "wzzc-dev/moui/runtime",
    #|  "wzzc-dev/moui/backend/host",
    #|  "wzzc-dev/moui/backend/__PLATFORM__" @platform_host,
    #|  "wzzc-dev/moui/backend/__PLATFORM__/skia" @platform_skia,
    #|  "wzzc-dev/moui/render",
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
  let (gpu_platform, options_type, gpu_available, preflight) = match platform {
    "android" =>
      (
        "Android", "AndroidSkiaAppOptions", "android_skia_gpu_available", "android_skia_provider_preflight_summary",
      )
    "ios" =>
      (
        "Ios", "IosSkiaAppOptions", "ios_skia_gpu_available", "ios_skia_provider_preflight_summary",
      )
    "harmonyos" =>
      (
        "HarmonyOs", "HarmonyOsSkiaAppOptions", "harmonyos_skia_gpu_available", "harmonyos_skia_provider_preflight_summary",
      )
    _ => abort("unsupported shell entrypoint platform: " + platform)
  }
  let template =
    #|///|
    #|/// Platform entrypoint: application program and renderer configuration only.
    #|/// The platform backend installs runtime callbacks; moui_shell owns the
    #|/// fixed Embedding API v1 exports consumed by the native shell.
    #|let _moui_embedding : Unit = @platform_host.install_embedding(
    #|  runtime_factory=metrics => {
    #|    @runtime.new_program(
    #|      program=@app.program(),
    #|      size=metrics.logical_size,
    #|    )
    #|  },
    #|  provider_factory=() => {
    #|    @platform_skia.renderer_provider(
    #|      options=@platform_skia.__OPTIONS_TYPE__::new(
    #|        surface_route=@host.shell_renderer_selection(
    #|            @render.NativeGpuPlatform::__GPU_PLATFORM__,
    #|            gpu_available=@platform_skia.__GPU_AVAILABLE__(),
    #|          ).surface_route,
    #|      ),
    #|    )
    #|  },
    #|  renderer_configure=@host.shell_renderer_configure,
    #|  renderer_status_json=() => {
    #|    @host.shell_renderer_status_json(
    #|      @render.NativeGpuPlatform::__GPU_PLATFORM__,
    #|      gpu_available=@platform_skia.__GPU_AVAILABLE__(),
    #|    )
    #|  },
    #|)
    #|
    #|///|
    #|fn main {
    #|  println(@platform_skia.__PREFLIGHT__())
    #|}
  template
  .replace_all(old="__GPU_PLATFORM__", new=gpu_platform)
  .replace_all(old="__OPTIONS_TYPE__", new=options_type)
  .replace_all(old="__GPU_AVAILABLE__", new=gpu_available)
  .replace_all(old="__PREFLIGHT__", new=preflight)
}
