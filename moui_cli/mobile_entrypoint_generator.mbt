///|
fn mobile_entrypoint_pkg_text(
  module_name : String,
  platform : String,
) -> String {
  let template =
    #|import {
    #|  "wzzc-dev/moui/runtime",
    #|  "wzzc-dev/moui/backend/__PLATFORM__" @platform_host,
    #|  "wzzc-dev/moui/render/skia" @render_skia,
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
  match platform {
    "android" | "ios" | "harmonyos" => ()
    _ => abort("unsupported embedded-runtime platform: " + platform)
  }
  let template =
    #|///|
    #|/// Embedded runtime composition root.
    #|fn main {
    #|  let runtime = @runtime.new_program_with_dimensions(
    #|    program=@app.program(),
    #|    width=320.0,
    #|    height=640.0,
    #|  )
    #|  @runtime.run_app("MoUI app (window-hosted)", runtime)
    #|    .render_all(@render_skia.from_env())
    #|    .backend(@platform_host.entry())
    #|    .run()
    #|}
  template
}
