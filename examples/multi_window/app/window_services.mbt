///|
/// Application-owned window identity. Platform host identifiers are converted
/// at the composition boundary.
pub(all) struct WindowId {
  value : Int
} derive(Eq, Debug, ToJson)

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
pub fn WindowScene::new(
  scene_id~ : String,
  payload? : String = "",
) -> WindowScene {
  { scene_id, payload }
}

///|
pub(all) struct WindowOpenRequest {
  title : String
  scene : WindowScene
  width : Double
  height : Double
} derive(Eq, Debug, ToJson)

///|
pub fn WindowOpenRequest::new(
  title~ : String,
  scene~ : WindowScene,
  width~ : Double,
  height~ : Double,
) -> WindowOpenRequest {
  { title, scene, width, height }
}

///|
pub(all) enum WindowRequest {
  Open(WindowOpenRequest)
  Focus(WindowId)
  Close(WindowId)
} derive(Eq, Debug, ToJson)

///|
pub(all) enum WindowEvent {
  Opened(WindowId)
  Updated(WindowId)
  Rejected(String)
} derive(Eq, Debug, ToJson)

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
  { dispatch, subscribe }
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
