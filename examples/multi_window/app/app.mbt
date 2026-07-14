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
  windows : @host.HostWindowActions
}

///|
pub(all) enum Msg {
  OpenInspector
  Increment
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
pub fn Model::new(scene : Scene, windows : @host.HostWindowActions) -> Model {
  { scene, count: 0, windows }
}

///|
pub fn program(scene : Scene, windows : @host.HostWindowActions) -> @moui.Program[Model, Msg] {
  @moui.Program::simple(
    init=Model::new(scene, windows),
    update=update,
    view=view,
  )
}

///|
pub fn update(model : Model, msg : Msg) -> Model {
  match msg {
    OpenInspector => {
      model.windows.open(
        title="MoUI Inspector",
        scene=@host.HostWindowScene::new(scene_id="inspector", payload="main"),
        metrics=@host.HostSurfaceMetrics::from_logical(
          size=@geometry.Size::new(width=420.0, height=320.0),
        ),
      )
      model
    }
    Increment => { ..model, count: model.count + 1 }
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
        text("The inspector opens with an independent runtime."),
        text("Main counter: \{model.count}"),
        row([
          button("Increment", on_click=Increment),
          button("Open Inspector", on_click=OpenInspector),
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
        button("Increment", on_click=Increment),
      ]),
    ),
  )
}
