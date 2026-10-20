///|
/// A toy plugin: a counter that draws its own value.
///
/// Deliberately the smallest thing that still exercises the real pipeline
/// (`view → layout → paint → DrawCommand`). Two of these stand in for two
/// isolated wasm instances during the P2.5 decision gate.

///|
pub(all) struct CounterModel {
  label : String
  value : Int
}

///|
pub(all) enum CounterMsg {
  Bump
}

///|
pub fn CounterModel::new(label : String) -> CounterModel {
  { label, value: 0, }
}

///|
pub fn counter_update(model : CounterModel, msg : CounterMsg) -> CounterModel {
  match msg {
    Bump => { ..model, value: model.value + 1, }
  }
}

///|
/// The plugin's own view. In the real design this never crosses the boundary:
/// the instance renders it and emits commands.
pub fn counter_view(model : CounterModel) -> @moui.View[CounterMsg] {
  let width = 120.0
  @views.column(
    [
      @views.text(
        model.label,
        role=Caption,
        width~,
        height=16.0,
        align=TextCenter,
      ),
      @views.text(
        model.value.to_string(),
        role=Body,
        width~,
        height=28.0,
        align=TextCenter,
      ),
      @views.button("+", on_click=Bump, variant=Tonal, width=48.0, height=22.0),
    ],
    spacing=4.0,
  )
}
