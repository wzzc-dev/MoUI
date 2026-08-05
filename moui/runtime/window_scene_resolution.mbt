///|
pub(all) struct WindowSceneInstance {
  request : @backend_host.WindowOpenRequest
  runtime : AppRuntime
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
  runtime~ : AppRuntime,
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
