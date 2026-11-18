///|
/// TEA shell around four p5 sketches.
using @views {button, center, column, row, spacer, text}

///|
pub struct Model {
  demo : Int32
  paused : Bool
}

///|
pub(all) enum Msg {
  Select(Int32)
  TogglePause
  Reset
  Canvas(@p5m.CanvasInput)
}

///|
fn title_for(demo : Int32) -> String {
  match demo {
    1 => "Flow field"
    2 => "Bouncing balls"
    3 => "Introduction"
    _ => "Generative shapes"
  }
}

///|
fn tab_label(demo : Int32, selected : Int32, label : String) -> String {
  if demo == selected {
    "● " + label
  } else {
    "  " + label
  }
}

///|
fn app_view(model : Model, bank : DemoBank) -> @moui.View[Msg] {
  let canvas = bank.view(model.demo).map(input => Canvas(input))
  let controls = row(
    [
      button(
        tab_label(0, model.demo, "Shapes"),
        on_click=Select(0),
        variant=if model.demo == 0 {
          @views.ButtonVariant::Primary
        } else {
          @views.ButtonVariant::Outline
        },
      ),
      button(
        tab_label(1, model.demo, "Flow"),
        on_click=Select(1),
        variant=if model.demo == 1 {
          @views.ButtonVariant::Primary
        } else {
          @views.ButtonVariant::Outline
        },
      ),
      button(
        tab_label(2, model.demo, "Balls"),
        on_click=Select(2),
        variant=if model.demo == 2 {
          @views.ButtonVariant::Primary
        } else {
          @views.ButtonVariant::Outline
        },
      ),
      button(
        tab_label(3, model.demo, "Intro"),
        on_click=Select(3),
        variant=if model.demo == 3 {
          @views.ButtonVariant::Primary
        } else {
          @views.ButtonVariant::Outline
        },
      ),
      spacer(weight=1.0),
      button(
        if model.paused {
          "Resume"
        } else {
          "Pause"
        },
        on_click=TogglePause,
        variant=@views.ButtonVariant::Outline,
      ),
      button("Reset", on_click=Reset, variant=@views.ButtonVariant::Ghost),
    ],
    spacing=8,
  )
  center(
    column(
      [
        row(
          [text("p5 core × MoUI").title(), text(title_for(model.demo))],
          spacing=12,
        ),
        controls,
        canvas,
        text(
          "MoonBit sketch API on the native MoUI renderer · drag / click on the canvas",
        ),
      ],
      spacing=12,
    ).padding(16),
  )
}

///|
pub fn program() -> @moui.Program[Model, Msg] {
  let bank = DemoBank::new(900.0, 540.0)
  @moui.Program::simple(
    init=Model::{ demo: 0, paused: false, },
    update=(model, msg) => {
      match msg {
        Select(demo) => {
          let next = { ..model, demo, }
          bank.set_paused(demo, next.paused)
          next
        }
        TogglePause => {
          let next = { ..model, paused: !model.paused, }
          bank.set_paused(model.demo, next.paused)
          next
        }
        Reset => {
          bank.reset(model.demo)
          model
        }
        Canvas(input) => {
          bank.handle_input(model.demo, input)
          model
        }
      }
    },
    view=model => app_view(model, bank),
  )
}
