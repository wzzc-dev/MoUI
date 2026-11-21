///|
using @views {card, column, slider, text}

///|
#derive(Eq, Debug)
pub(all) struct SliderDragModel {
  value : Double
}

///|
pub extend SliderDragModel with Debug::{to_repr}

///|
pub extend SliderDragModel with Eq::{not_equal, equal}

///|
#derive(Eq, Debug)
pub(all) enum SliderDragMsg {
  ValueChanged(Double)
}

///|
pub extend SliderDragMsg with Debug::{to_repr}

///|
pub extend SliderDragMsg with Eq::{not_equal, equal}

///|
pub fn SliderDragModel::new() -> SliderDragModel {
  { value: 0.5, }
}

///|
pub fn update(_model : SliderDragModel, msg : SliderDragMsg) -> SliderDragModel {
  match msg {
    ValueChanged(value) => { value, }
  }
}

///|
/// The page is deliberately heavy — roughly the Showcase first screen's
/// command density (90 rounded fills, 110 text runs) — so the drag smoke
/// measures the interaction loop against a realistic frame, not a one-widget
/// toy page.
pub fn view(model : SliderDragModel) -> @core.View[SliderDragMsg] {
  let theme = @views.default_theme()
  let rows : Array[@core.View[SliderDragMsg]] = [
    slider(
      model.value,
      min=0.0,
      max=1.0,
      width=560.0,
      height=48.0,
      theme~,
      on_change=Some(value => ValueChanged(value)),
    ),
  ]
  for index in 0..<30 {
    let lines : Array[@core.View[SliderDragMsg]] = []
    for line in 0..<12 {
      lines.push(
        text(
          "Row \{index} line \{line}: catalog overview with a live canvas",
          theme~,
          width=520.0,
        ),
      )
    }
    rows.push(card(column(lines, spacing=4.0), theme~, width=560.0))
  }
  column(rows, spacing=8.0)
}

///|
pub fn runtime(
  width~ : Double = 640.0,
  height~ : Double = 480.0,
) -> @runtime.AppRuntime {
  @runtime.AppRuntime::new_program(
    program=@core.Program::simple(init=SliderDragModel::new(), update~, view~),
    size=@core.Size::new(width~, height~),
  )
}
