///|
pub(all) struct WindowId {
  value : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) enum WindowLifecyclePhase {
  WindowCreated
  WindowVisible
  WindowFocused
  WindowMinimized
  WindowCloseRequested
  WindowClosed
} derive(Eq, Debug, ToJson)

///|
pub(all) struct WindowScene {
  scene_id : String
  payload : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct WindowRecord {
  id : WindowId
  title : String
  scene : WindowScene
  metrics : @core.SurfaceMetrics
  phase : WindowLifecyclePhase
  primary : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct WindowOpenRequest {
  title : String
  scene : WindowScene
  metrics : @core.SurfaceMetrics
  primary : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) enum WindowRequest {
  OpenWindow(WindowOpenRequest)
  FocusWindow(WindowId)
  CloseWindow(WindowId)
  ResizeWindow(WindowId, @core.SurfaceMetrics)
  MinimizeWindow(WindowId)
  ShowWindow(WindowId)
  SetPrimaryWindow(WindowId)
} derive(Eq, Debug, ToJson)

///|
pub(all) enum WindowRequestResult {
  WindowOpened(WindowId)
  WindowUpdated(WindowId)
  WindowRejected(String)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct WindowRequestCompletion {
  request : WindowRequest
  result : WindowRequestResult
} derive(Eq, Debug, ToJson)

///|
pub fn WindowId::new(value : Int) -> WindowId {
  { value, }
}

///|
pub fn WindowScene::new(
  scene_id~ : String,
  payload? : String = "",
) -> WindowScene {
  { scene_id, payload }
}

///|
pub fn WindowScene::main() -> WindowScene {
  WindowScene::new(scene_id="main")
}

///|
pub fn WindowRecord::new(
  id~ : WindowId,
  title~ : String,
  scene? : WindowScene = WindowScene::main(),
  metrics~ : @core.SurfaceMetrics,
  phase? : WindowLifecyclePhase = WindowCreated,
  primary? : Bool = false,
) -> WindowRecord {
  { id, title, scene, metrics, phase, primary }
}

///|
pub fn WindowOpenRequest::new(
  title~ : String,
  scene? : WindowScene = WindowScene::main(),
  metrics~ : @core.SurfaceMetrics,
  primary? : Bool = false,
) -> WindowOpenRequest {
  { title, scene, metrics, primary }
}
