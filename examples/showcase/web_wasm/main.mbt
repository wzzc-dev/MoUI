///|
fn showcase_initial_section_code() -> Int = "showcase" "initial_section"

///|
fn main {
  let routes = @services.RouteSource::new()
  let bindings = @webgpu_adapter.provider_bindings(
    canvas_id="moonbit-window-web-showcase",
  )
  let runtime = @showcase.runtime(
    host_summary=@web.web_capability_summary(),
    environment=@web.app_environment(routes~),
    renderer_providers=@render.renderer_provider_binding_providers(bindings),
    route_host=Some(
      @showcase.route_host(
        source=routes,
        push=@web.web_history_push_route,
        replace=@web.web_history_replace_route,
        back=@web.web_history_back,
        forward=@web.web_history_forward,
      ),
    ),
    initial_section_code=showcase_initial_section_code(),
  )
  @runtime.run_app("MoUI Showcase Wasm Host", runtime)
  .render_all(@webgpu_adapter.from_env())
  .backend(
    @web.entry(options=@web.WebAppOptions::new(route_source=Some(routes))),
  )
  .run()
}
