///|
using @views {button, card, center, column, row, text}

///|
pub(all) enum Scene {
  Main
  Inspector(String)
} derive(Eq)

///|
pub struct Model {
  scene : Scene
  count : Int
  /// Shared logical counter mirrored into scene payloads for demos.
  shared_count : Int
  /// Last known inspector window id after open, when the host reports it.
  inspector_window_id : WindowId?
  status : String
}

///|
pub(all) enum Msg {
  OpenInspector
  CloseInspector
  FocusInspector
  WindowCompleted(WindowEvent)
  Increment
  IncrementShared
}

///|
pub fn scene_from_window(scene : WindowScene) -> Scene? {
  match scene.scene_id {
    "main" => Some(Main)
    "inspector" => Some(Inspector(scene.payload))
    _ => None
  }
}

///|
pub fn Model::new(scene : Scene, shared_count? : Int = 0) -> Model {
  { scene, count: 0, shared_count, inspector_window_id: None, status: "Ready" }
}

///|
pub fn program(
  scene : Scene,
  windows : WindowActions,
  shared_count? : Int = 0,
) -> @moui.Program[Model, Msg] {
  @moui.Program::new(
    init=() => (Model::new(scene, shared_count~), @moui.Effect::none()),
    update=(model, msg) => update(model, msg, windows~),
    view~,
    subscriptions=_model => {
      windows.subscription(map=event => Msg::WindowCompleted(event))
    },
  )
}

///|
pub fn update(
  model : Model,
  msg : Msg,
  windows? : WindowActions = WindowActions::unavailable(),
) -> (Model, @moui.Effect[Msg]) {
  match msg {
    OpenInspector =>
      (
        {
          ..model,
          status: "Open inspector requested (independent AppRuntime per scene)",
        },
        windows.effect(
          WindowRequest::Open(
            WindowOpenRequest::new(
              title="MoUI Inspector",
              scene=WindowScene::new(
                scene_id="inspector",
                payload="shared:" + model.shared_count.to_string(),
              ),
              width=420.0,
              height=320.0,
            ),
          ),
          key="window:open-inspector",
          label="Open inspector window",
        ),
      )
    CloseInspector =>
      match model.inspector_window_id {
        Some(id) =>
          (
            {
              ..model,
              inspector_window_id: None,
              status: "Close inspector requested for window \{id.value}",
            },
            windows.effect(
              WindowRequest::Close(id),
              key="window:close-inspector",
              label="Close inspector window",
            ),
          )
        None =>
          (
            { ..model, status: "Inspector window id is not available" },
            @moui.Effect::none(),
          )
      }
    FocusInspector =>
      match model.inspector_window_id {
        Some(id) =>
          (
            {
              ..model,
              status: "Focus inspector requested for window \{id.value}",
            },
            windows.effect(
              WindowRequest::Focus(id),
              key="window:focus-inspector",
              label="Focus inspector window",
            ),
          )
        None =>
          (
            { ..model, status: "Inspector window id is not available" },
            @moui.Effect::none(),
          )
      }
    WindowCompleted(event) =>
      match event {
        Opened(id) =>
          (
            {
              ..model,
              inspector_window_id: Some(id),
              status: "Inspector window \{id.value} opened",
            },
            @moui.Effect::none(),
          )
        Updated(id) =>
          (
            { ..model, status: "Window \{id.value} updated" },
            @moui.Effect::none(),
          )
        Rejected(message) =>
          (
            { ..model, status: "Window request rejected: " + message },
            @moui.Effect::none(),
          )
      }
    Increment => ({ ..model, count: model.count + 1 }, @moui.Effect::none())
    IncrementShared =>
      (
        {
          ..model,
          shared_count: model.shared_count + 1,
          status: "Shared counter is app-owned; reopen inspector to snapshot a new payload",
        },
        @moui.Effect::none(),
      )
  }
}

///|
pub fn view(model : Model) -> @moui.View[Msg] {
  match model.scene {
    Main => main_view(model)
    Inspector(source) => inspector_view(model, source)
  }
}

///|
fn main_view(model : Model) -> @moui.View[Msg] {
  center(
    card(
      column([
        text("MoUI Multi-Window").title(),
        text(
          "Each scene is an independent AppRuntime. Shared state is app-owned.",
        ),
        text("Local counter: \{model.count}"),
        text("Shared counter snapshot: \{model.shared_count}"),
        text(model.status),
        row([
          button("Increment local", on_click=Increment),
          button("Increment shared", on_click=IncrementShared),
        ]),
        row([
          button("Open Inspector", on_click=OpenInspector),
          button("Focus Inspector", on_click=FocusInspector),
          button("Close Inspector", on_click=CloseInspector),
        ]),
      ]),
    ),
  )
}

///|
fn inspector_view(model : Model, source : String) -> @moui.View[Msg] {
  center(
    card(
      column([
        text("Inspector").title(),
        text("Opened from: \{source}"),
        text("Independent counter: \{model.count}"),
        text("Shared snapshot in payload is fixed at open time."),
        button("Increment local", on_click=Increment),
      ]),
    ),
  )
}
