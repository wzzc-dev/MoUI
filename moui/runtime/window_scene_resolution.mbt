///|
pub(all) struct HostWindowSceneInstance {
  request : @backend_host.HostWindowOpenRequest
  runtime : AppRuntime
}

///|
pub(all) enum HostWindowSceneResolution {
  SceneResolved(HostWindowSceneInstance)
  SceneRejected(String)
}

///|
pub(all) struct HostWindowResolvedOpen {
  id : @backend_host.HostWindowId
  record : @backend_host.HostWindowRecord
  instance : HostWindowSceneInstance
}

///|
pub(all) enum HostWindowOpenResolution {
  OpenResolved(HostWindowResolvedOpen)
  OpenRejected(String)
}

///|
pub struct HostWindowSceneResolver {
  resolve : (@backend_host.HostWindowOpenRequest) -> HostWindowSceneResolution
}

///|
pub fn HostWindowSceneInstance::new(
  request~ : @backend_host.HostWindowOpenRequest,
  runtime~ : AppRuntime,
) -> HostWindowSceneInstance {
  { request, runtime }
}

///|
pub fn HostWindowSceneResolver::new(
  resolve~ : (@backend_host.HostWindowOpenRequest) -> HostWindowSceneResolution,
) -> HostWindowSceneResolver {
  { resolve, }
}

///|
pub fn HostWindowSceneResolver::unavailable(
  reason? : String = "window scene resolver is unavailable",
) -> HostWindowSceneResolver {
  HostWindowSceneResolver::new(resolve=_request => {
    HostWindowSceneResolution::SceneRejected(reason)
  })
}

///|
pub fn HostWindowSceneResolver::resolve(
  self : HostWindowSceneResolver,
  request : @backend_host.HostWindowOpenRequest,
) -> HostWindowSceneResolution {
  (self.resolve)(request)
}

///|
pub fn HostWindowResolvedOpen::new(
  id~ : @backend_host.HostWindowId,
  record~ : @backend_host.HostWindowRecord,
  instance~ : HostWindowSceneInstance,
) -> HostWindowResolvedOpen {
  { id, record, instance }
}

///|
pub fn resolve_open_request(
  registry : @backend_host.HostWindowRegistry,
  request : @backend_host.HostWindowOpenRequest,
  resolver : HostWindowSceneResolver,
) -> HostWindowOpenResolution {
  match resolver.resolve(request) {
    HostWindowSceneResolution::SceneResolved(instance) => {
      let id = registry.open(
        title=request.title,
        scene=request.scene,
        metrics=request.metrics,
        primary=request.primary,
      )
      match registry.lookup(id) {
        Some(record) =>
          HostWindowOpenResolution::OpenResolved(
            HostWindowResolvedOpen::new(id~, record~, instance~),
          )
        None =>
          HostWindowOpenResolution::OpenRejected(
            "resolved window was not registered: \{id.value}",
          )
      }
    }
    HostWindowSceneResolution::SceneRejected(message) =>
      HostWindowOpenResolution::OpenRejected(message)
  }
}
