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
  windows : @host.HostWindowActions
  /// Last known inspector window id after open, when the host reports it.
  inspector_window_id : @host.HostWindowId?
  status : String
}

///|
pub(all) enum Msg {
  OpenInspector
  CloseInspector
  FocusInspector
  Increment
  IncrementShared
}

///|
pub fn scene_from_host(scene : @host.HostWindowScene) -> Scene? {
  match scene.scene_id {
    "main" => Some(Main)
    "inspector" => Some(Inspector(scene.payload))
    _ => None
  }
}

///|
pub fn Model::new(
  scene : Scene,
  windows : @host.HostWindowActions,
  shared_count? : Int = 0,
) -> Model {
  {
    scene,
    count: 0,
    shared_count,
    windows,
    inspector_window_id: None,
    status: "Ready",
  }
}

///|
pub fn program(
  scene : Scene,
  windows : @host.HostWindowActions,
  shared_count? : Int = 0,
) -> @moui.Program[Model, Msg] {
  @moui.Program::simple(
    init=Model::new(scene, windows, shared_count~),
    update~,
    view~,
  )
}

///|
pub fn update(model : Model, msg : Msg) -> Model {
  match msg {
    OpenInspector => {
      model.windows.open(
        title="MoUI Inspector",
        scene=@host.HostWindowScene::new(
          scene_id="inspector",
          payload="shared:" + model.shared_count.to_string(),
        ),
        metrics=@host.HostSurfaceMetrics::from_logical(
          size=@geometry.Size::new(width=420.0, height=320.0),
        ),
      )
      {
        ..model,
        status: "Open inspector requested (independent AppRuntime per scene)",
      }
    }
    CloseInspector =>
      match model.inspector_window_id {
        Some(id) => {
          model.windows.close(id)
          {
            ..model,
            inspector_window_id: None,
            status: "Close inspector requested for window \{id.value}",
          }
        }
        None => {
          // Demo fallback: close a provisional id when the host has not
          // reported one back into the model yet.
          model.windows.close(@host.HostWindowId::new(2))
          {
            ..model,
            status: "Close requested for provisional window id 2 (host may reject)",
          }
        }
      }
    FocusInspector =>
      match model.inspector_window_id {
        Some(id) => {
          model.windows.focus(id)
          { ..model, status: "Focus inspector requested for window \{id.value}" }
        }
        None => {
          model.windows.focus(@host.HostWindowId::new(2))
          {
            ..model,
            status: "Focus requested for provisional window id 2 (host may reject)",
          }
        }
      }
    Increment => { ..model, count: model.count + 1 }
    IncrementShared => {
      ..model,
      shared_count: model.shared_count + 1,
      status: "Shared counter is app-owned; reopen inspector to snapshot a new payload",
    }
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
        text("Each scene is an independent AppRuntime. Shared state is app-owned."),
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
