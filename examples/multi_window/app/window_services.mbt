///|
/// Application-owned window identity. Platform host identifiers are converted
/// at the composition boundary.
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
pub fn WindowId::new(value : Int) -> WindowId {
  { value, }
}

///|
/// Serializable scene payload understood by this application.
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
pub fn WindowScene::new(
  scene_id~ : String,
  payload? : String = "",
) -> WindowScene {
  { scene_id, payload, }
}

///|
pub(all) struct WindowOpenRequest {
  title : String
  scene : WindowScene
  width : Double
  height : Double
} derive(Eq, Debug, ToJson)

///|
pub extend WindowOpenRequest with Debug::{to_repr}

///|
pub extend WindowOpenRequest with Eq::{not_equal, equal}

///|
pub extend WindowOpenRequest with ToJson::{to_json}

///|
pub fn WindowOpenRequest::new(
  title~ : String,
  scene~ : WindowScene,
  width~ : Double,
  height~ : Double,
) -> WindowOpenRequest {
  { title, scene, width, height, }
}

///|
pub(all) enum WindowRequest {
  Open(WindowOpenRequest)
  Focus(WindowId)
  Close(WindowId)
} derive(Eq, Debug, ToJson)

///|
pub extend WindowRequest with Debug::{to_repr}

///|
pub extend WindowRequest with Eq::{not_equal, equal}

///|
pub extend WindowRequest with ToJson::{to_json}

///|
pub(all) enum WindowEvent {
  Opened(WindowId)
  Updated(WindowId)
  Rejected(String)
} derive(Eq, Debug, ToJson)

///|
pub extend WindowEvent with Debug::{to_repr}

///|
pub extend WindowEvent with Eq::{not_equal, equal}

///|
pub extend WindowEvent with ToJson::{to_json}

///|
/// Neutral facade captured by the Program closure. It is deliberately absent
/// from Model so snapshots remain ordinary application data.
pub struct WindowActions {
  dispatch : (WindowRequest) -> Unit
  subscribe : ((WindowEvent) -> Unit) -> () -> Unit
}

///|
pub fn WindowActions::new(
  dispatch~ : (WindowRequest) -> Unit,
  subscribe? : ((WindowEvent) -> Unit) -> () -> Unit = _handle => () => (),
) -> WindowActions {
  { dispatch, subscribe, }
}

///|
pub fn WindowActions::unavailable() -> WindowActions {
  WindowActions::new(dispatch=_request => ())
}

///|
pub fn WindowActions::listen(
  self : WindowActions,
  handle : (WindowEvent) -> Unit,
) -> () -> Unit {
  (self.subscribe)(handle)
}

///|
pub fn[Msg] WindowActions::subscription(
  self : WindowActions,
  map~ : (WindowEvent) -> Msg,
) -> @moui.Subscription[Msg] {
  @moui.Subscription::window_event(
    key="multi-window:completions",
    label="Multi-window request completions",
    start=dispatch => Some(self.listen(event => dispatch(map(event)))),
  )
}

///|
pub fn[Msg] WindowActions::effect(
  self : WindowActions,
  request : WindowRequest,
  key~ : String,
  label~ : String,
) -> @moui.Effect[Msg] {
  @moui.Effect::run(key~, kind="window", label~, run=_dispatch => {
    (self.dispatch)(request)
  })
}
