///|
using @views {
  badge,
  button,
  callout,
  column,
  custom_children_layout,
  divider,
  fill_rect,
  frame,
  row,
  stat_card,
  text,
}

///|
pub struct Model {
  tap_count : Int
  render_hint : Int
}

///|
pub(all) enum Msg {
  TapDemo
  Reset
  MarkRendered
}

///|
pub fn Model::new() -> Model {
  { tap_count: 0, render_hint: 0 }
}

///|
pub fn update(model : Model, msg : Msg) -> Model {
  match msg {
    TapDemo => { ..model, tap_count: model.tap_count + 1 }
    Reset => { ..model, tap_count: 0 }
    MarkRendered => { ..model, render_hint: model.render_hint + 1 }
  }
}

///|
pub fn view(model : Model, env : @moui.ViewEnvironment) -> @moui.View[Msg] {
  let theme = @views.light_theme()
  let viewport = env.viewport_size()
  let width = viewport.width.max(320.0)
  let height = viewport.height.max(320.0)
  let padding = 16.0
  let body_width = (width - padding * 2.0).max(288.0)
  let body_height = (height - padding * 2.0).max(0.0)
  let content = column(
    [
      row(
        [
          badge("Experimental", theme~, width=104.0),
          badge("HarmonyOS", theme~, width=92.0),
        ],
        spacing=8.0,
        align=@views.CrossAlign::Center,
      ),
      text("MoUI HarmonyOS Demo").title(),
      text("Standalone embedded Skia route", role=@views.TextRole::Subtitle),
      divider(theme~),
      callout(
        "Runtime proof pending",
        "This demo validates the package and host glue shape. Device or emulator smoke must prove first frame, pointer input, resize, and lifecycle before support is marked passed.",
        tone=@views.FeedbackTone::Warning,
        theme~,
        width=body_width,
      ),
      row(
        [
          stat_card(
            "Taps",
            model.tap_count.to_string(),
            caption="Button input routed through MoUI",
            theme~,
            width=(body_width - 8.0) / 2.0,
          ),
          stat_card(
            "Viewport",
            "\{viewport.width.to_int()} x \{viewport.height.to_int()}",
            caption="Updated by host resize events",
            theme~,
            width=(body_width - 8.0) / 2.0,
          ),
        ],
        spacing=8.0,
        align=@views.CrossAlign::Stretch,
      ),
      row(
        [button("Tap", on_click=TapDemo), button("Reset", on_click=Reset)],
        spacing=8.0,
      ),
      text("Render hint: \{model.render_hint}", role=@views.TextRole::Caption),
    ],
    spacing=12.0,
    align=@views.CrossAlign::Stretch,
  )
  fill_app_surface(
    frame(content, width=body_width, height=body_height),
    width~,
    height~,
    padding~,
    background=theme.palette.background,
  )
}

///|
fn[Msg] fill_app_surface(
  child : @moui.View[Msg],
  width~ : Double,
  height~ : Double,
  padding~ : Double,
  background~ : @graphics.Color,
) -> @moui.View[Msg] {
  custom_children_layout(
    children=[child],
    measure=ctx => {
      ctx.constraints.constrain(@geometry.Size::new(width~, height~))
    },
    place=ctx => {
      [
        @geometry.Rect::new(
          x=ctx.frame.origin.x + padding,
          y=ctx.frame.origin.y + padding,
          width=(ctx.frame.size.width - padding * 2.0).max(0.0),
          height=(ctx.frame.size.height - padding * 2.0).max(0.0),
        ),
      ]
    },
    paint=(ctx, bounds) => fill_rect(ctx, bounds, background),
    semantics_label="HarmonyOS demo surface",
  )
}

///|
pub fn program() -> @moui.Program[Model, Msg] {
  @moui.Program::simple_with_environment(init=Model::new(), update~, view~)
}
