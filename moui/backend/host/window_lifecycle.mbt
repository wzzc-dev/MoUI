///|
pub(all) struct HostWindowId {
  value : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostWindowLifecyclePhase {
  WindowCreated
  WindowVisible
  WindowFocused
  WindowMinimized
  WindowCloseRequested
  WindowClosed
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostWindowScene {
  scene_id : String
  payload : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostWindowRecord {
  id : HostWindowId
  title : String
  scene : HostWindowScene
  metrics : HostSurfaceMetrics
  phase : HostWindowLifecyclePhase
  primary : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostWindowOpenRequest {
  title : String
  scene : HostWindowScene
  metrics : HostSurfaceMetrics
  primary : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostWindowRequest {
  OpenWindow(HostWindowOpenRequest)
  FocusWindow(HostWindowId)
  CloseWindow(HostWindowId)
  ResizeWindow(HostWindowId, HostSurfaceMetrics)
  MinimizeWindow(HostWindowId)
  ShowWindow(HostWindowId)
  SetPrimaryWindow(HostWindowId)
} derive(Eq, Debug, ToJson)

///|
pub(all) enum HostWindowRequestResult {
  WindowOpened(HostWindowId)
  WindowUpdated(HostWindowId)
  WindowRejected(String)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostWindowRequestCompletion {
  request : HostWindowRequest
  result : HostWindowRequestResult
} derive(Eq, Debug, ToJson)

///|
pub fn HostWindowId::new(value : Int) -> HostWindowId {
  { value, }
}

///|
pub fn HostWindowScene::new(
  scene_id~ : String,
  payload? : String = "",
) -> HostWindowScene {
  { scene_id, payload }
}

///|
pub fn HostWindowScene::main() -> HostWindowScene {
  HostWindowScene::new(scene_id="main")
}

///|
pub fn HostWindowRecord::new(
  id~ : HostWindowId,
  title~ : String,
  scene? : HostWindowScene = HostWindowScene::main(),
  metrics~ : HostSurfaceMetrics,
  phase? : HostWindowLifecyclePhase = WindowCreated,
  primary? : Bool = false,
) -> HostWindowRecord {
  { id, title, scene, metrics, phase, primary }
}

///|
pub fn HostWindowOpenRequest::new(
  title~ : String,
  scene? : HostWindowScene = HostWindowScene::main(),
  metrics~ : HostSurfaceMetrics,
  primary? : Bool = false,
) -> HostWindowOpenRequest {
  { title, scene, metrics, primary }
}
