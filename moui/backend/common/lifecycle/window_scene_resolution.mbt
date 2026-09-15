///|
pub(all) struct WindowSceneInstance {
  request : @backend_host.WindowOpenRequest
  runtime : @runtime.AppRuntime
}

///|
pub(all) enum WindowSceneResolution {
  SceneResolved(WindowSceneInstance)
  SceneRejected(String)
}

///|
pub(all) struct WindowResolvedOpen {
  id : @backend_host.WindowId
  record : @backend_host.WindowRecord
  instance : WindowSceneInstance
}

///|
pub(all) enum WindowOpenResolution {
  OpenResolved(WindowResolvedOpen)
  OpenRejected(String)
}

///|
pub struct WindowSceneResolver {
  resolve : (@backend_host.WindowOpenRequest) -> WindowSceneResolution
}

///|
pub fn WindowSceneInstance::new(
  request~ : @backend_host.WindowOpenRequest,
  runtime~ : @runtime.AppRuntime,
) -> WindowSceneInstance {
  { request, runtime }
}

///|
pub fn WindowSceneResolver::new(
  resolve~ : (@backend_host.WindowOpenRequest) -> WindowSceneResolution,
) -> WindowSceneResolver {
  { resolve, }
}

///|
pub fn WindowSceneResolver::unavailable(
  reason? : String = "window scene resolver is unavailable",
) -> WindowSceneResolver {
  WindowSceneResolver::new(resolve=_request => {
    WindowSceneResolution::SceneRejected(reason)
  })
}

///|
pub fn WindowSceneResolver::resolve(
  self : WindowSceneResolver,
  request : @backend_host.WindowOpenRequest,
) -> WindowSceneResolution {
  (self.resolve)(request)
}

///|
pub fn WindowResolvedOpen::new(
  id~ : @backend_host.WindowId,
  record~ : @backend_host.WindowRecord,
  instance~ : WindowSceneInstance,
) -> WindowResolvedOpen {
  { id, record, instance }
}

///|
/// Resolve a runtime scene and register its backend window atomically.
pub fn resolve_open_request(
  registry : WindowRegistry,
  request : @backend_host.WindowOpenRequest,
  resolver : WindowSceneResolver,
) -> WindowOpenResolution {
  match resolver.resolve(request) {
    WindowSceneResolution::SceneResolved(instance) => {
      let id = registry.open(
        title=request.title,
        scene=request.scene,
        metrics=request.metrics,
        primary=request.primary,
      )
      match registry.lookup(id) {
        Some(record) =>
          WindowOpenResolution::OpenResolved(
            WindowResolvedOpen::new(id~, record~, instance~),
          )
        None =>
          WindowOpenResolution::OpenRejected(
            "resolved window was not registered: \{id.value}",
          )
      }
    }
    WindowSceneResolution::SceneRejected(message) =>
      WindowOpenResolution::OpenRejected(message)
  }
}
