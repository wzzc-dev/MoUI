///|
pub(all) struct WindowId {
  value : Int
} derive(Eq, Debug, ToJson)

///|
pub extend WindowId with Debug::{to_repr}

///|
pub extend WindowId with Eq::{not_equal, equal}

///|
pub extend WindowId with ToJson::{to_json}

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
pub extend WindowLifecyclePhase with Debug::{to_repr}

///|
pub extend WindowLifecyclePhase with Eq::{not_equal, equal}

///|
pub extend WindowLifecyclePhase with ToJson::{to_json}

///|
pub(all) struct WindowScene {
  scene_id : String
  payload : String
} derive(Eq, Debug, ToJson)

///|
pub extend WindowScene with Debug::{to_repr}

///|
pub extend WindowScene with Eq::{not_equal, equal}

///|
pub extend WindowScene with ToJson::{to_json}

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
pub extend WindowRecord with Debug::{to_repr}

///|
pub extend WindowRecord with Eq::{not_equal, equal}

///|
pub extend WindowRecord with ToJson::{to_json}

///|
pub(all) struct WindowOpenRequest {
  title : String
  scene : WindowScene
  metrics : @core.SurfaceMetrics
  primary : Bool
} derive(Eq, Debug, ToJson)

///|
pub extend WindowOpenRequest with Debug::{to_repr}

///|
pub extend WindowOpenRequest with Eq::{not_equal, equal}

///|
pub extend WindowOpenRequest with ToJson::{to_json}

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
pub extend WindowRequest with Debug::{to_repr}

///|
pub extend WindowRequest with Eq::{not_equal, equal}

///|
pub extend WindowRequest with ToJson::{to_json}

///|
pub(all) enum WindowRequestResult {
  WindowOpened(WindowId)
  WindowUpdated(WindowId)
  WindowRejected(String)
} derive(Eq, Debug, ToJson)

///|
pub extend WindowRequestResult with Debug::{to_repr}

///|
pub extend WindowRequestResult with Eq::{not_equal, equal}

///|
pub extend WindowRequestResult with ToJson::{to_json}

///|
pub(all) struct WindowRequestCompletion {
  request : WindowRequest
  result : WindowRequestResult
} derive(Eq, Debug, ToJson)

///|
pub extend WindowRequestCompletion with Debug::{to_repr}

///|
pub extend WindowRequestCompletion with Eq::{not_equal, equal}

///|
pub extend WindowRequestCompletion with ToJson::{to_json}

///|
pub fn WindowId::new(value : Int) -> WindowId {
  { value, }
}

///|
pub fn WindowScene::new(
  scene_id~ : String,
  payload? : String = "",
) -> WindowScene {
  { scene_id, payload, }
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
  { id, title, scene, metrics, phase, primary, }
}

///|
pub fn WindowOpenRequest::new(
  title~ : String,
  scene? : WindowScene = WindowScene::main(),
  metrics~ : @core.SurfaceMetrics,
  primary? : Bool = false,
) -> WindowOpenRequest {
  { title, scene, metrics, primary, }
}
