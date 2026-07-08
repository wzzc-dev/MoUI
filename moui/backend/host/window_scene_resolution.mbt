///|
pub(all) struct HostWindowSceneInstance {
  request : HostWindowOpenRequest
  runtime : @runtime.AppRuntime
}

///|
pub(all) enum HostWindowSceneResolution {
  SceneResolved(HostWindowSceneInstance)
  SceneRejected(String)
}

///|
pub(all) struct HostWindowResolvedOpen {
  id : HostWindowId
  record : HostWindowRecord
  instance : HostWindowSceneInstance
}

///|
pub(all) enum HostWindowOpenResolution {
  OpenResolved(HostWindowResolvedOpen)
  OpenRejected(String)
}

///|
pub struct HostWindowSceneResolver {
  resolve : (HostWindowOpenRequest) -> HostWindowSceneResolution
}

///|
pub fn HostWindowSceneInstance::new(
  request~ : HostWindowOpenRequest,
  runtime~ : @runtime.AppRuntime,
) -> HostWindowSceneInstance {
  { request, runtime }
}

///|
pub fn HostWindowSceneResolver::new(
  resolve~ : (HostWindowOpenRequest) -> HostWindowSceneResolution,
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
  request : HostWindowOpenRequest,
) -> HostWindowSceneResolution {
  (self.resolve)(request)
}

///|
pub fn HostWindowResolvedOpen::new(
  id~ : HostWindowId,
  record~ : HostWindowRecord,
  instance~ : HostWindowSceneInstance,
) -> HostWindowResolvedOpen {
  { id, record, instance }
}

///|
pub fn HostWindowRegistry::resolve_open_request(
  self : HostWindowRegistry,
  request : HostWindowOpenRequest,
  resolver : HostWindowSceneResolver,
) -> HostWindowOpenResolution {
  match resolver.resolve(request) {
    HostWindowSceneResolution::SceneResolved(instance) => {
      let id = self.open(
        title=request.title,
        scene=request.scene,
        metrics=request.metrics,
        primary=request.primary,
      )
      match self.lookup(id) {
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
