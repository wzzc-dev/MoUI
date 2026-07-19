///|
/// Platform entrypoint: application program and renderer configuration only.
/// The HarmonyOS backend installs runtime callbacks; `moui_shell/embedding`
/// owns the ABI implementation, and `embedding_exports.mbt` is a linker shim.
fn install_harmonyos_demo_embedding() -> Unit {
  @harmonyos_host.install_embedding(
    runtime_factory=metrics => {
      @runtime.new_program(
        program=@harmonyos_demo_app.program(),
        size=metrics.logical_size,
      )
    },
    provider_factory=() => {
      @harmonyos_skia_backend.renderer_provider(
        options=@harmonyos_skia_backend.HarmonyOsSkiaAppOptions::new(
          surface_route=@harmonyos_host.harmonyos_shell_renderer_selection(
              gpu_available=@harmonyos_skia_backend.harmonyos_skia_gpu_available(),
            ).surface_route,
        ),
      )
    },
    renderer_configure=@harmonyos_host.harmonyos_shell_renderer_configure,
    renderer_status_json=() => {
      @harmonyos_host.harmonyos_shell_renderer_status_json(
        gpu_available=@harmonyos_skia_backend.harmonyos_skia_gpu_available(),
      )
    },
  )
}

///|
fn main {
  install_harmonyos_demo_embedding()
  println(@harmonyos_skia_backend.harmonyos_skia_provider_preflight_summary())
}
