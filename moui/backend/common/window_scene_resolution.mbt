///|
/// Resolve a runtime scene and register its backend window atomically.
pub fn resolve_open_request(
  registry : WindowRegistry,
  request : @backend_host.WindowOpenRequest,
  resolver : @runtime.WindowSceneResolver,
) -> @runtime.WindowOpenResolution {
  match resolver.resolve(request) {
    @runtime.WindowSceneResolution::SceneResolved(instance) => {
      let id = registry.open(
        title=request.title,
        scene=request.scene,
        metrics=request.metrics,
        primary=request.primary,
      )
      match registry.lookup(id) {
        Some(record) =>
          @runtime.WindowOpenResolution::OpenResolved(
            @runtime.WindowResolvedOpen::new(id~, record~, instance~),
          )
        None =>
          @runtime.WindowOpenResolution::OpenRejected(
            "resolved window was not registered: \{id.value}",
          )
      }
    }
    @runtime.WindowSceneResolution::SceneRejected(message) =>
      @runtime.WindowOpenResolution::OpenRejected(message)
  }
}
