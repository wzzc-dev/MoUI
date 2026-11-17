/// Chrome demo app: the two surfaces PR #26 adds, driven by real controls.
///
/// - Cursor declarations: hover zones for `CursorPointer` / `CursorText` /
///   `CursorGrabbing` plus a `CursorColResize` splitter whose press-frozen
///   style survives dragging out of the 16px gutter.
/// - Window chrome controls: Maximize / Restore / Fullscreen buttons wired to
///   `services.WindowControlSource`, plus the live observed state in the
///   status line.
///
/// The platform host (`examples/chrome_demo/linux_sun`) wires the source into
/// the Linux entry and provides the `WindowRequestQueue` port.

///|
pub(all) enum Msg {
  SplitDrag(@core.DragGestureEvent)
  Maximize
  Restore
  ToggleFullscreen
  Refresh
}

///|
pub struct Model {
  priv panel_width : Double
  priv drag_base : Double?
}

///|
pub fn Model::new() -> Model {
  { panel_width: 320.0, drag_base: None, }
}

///|
fn clamp_width(width : Double) -> Double {
  if width < 160.0 {
    160.0
  } else if width > 700.0 {
    700.0
  } else {
    width
  }
}

///|
pub fn apply_msg(
  model : Model,
  msg : Msg,
  controls : @services.WindowControlSource,
) -> Model {
  match msg {
    SplitDrag(event) =>
      match event.phase {
        Started => { ..model, drag_base: Some(model.panel_width), }
        Changed =>
          match model.drag_base {
            Some(base) =>
              { ..model, panel_width: clamp_width(base + event.translation.x), }
            None => model
          }
        Ended | Cancelled => { ..model, drag_base: None, }
        _ => model
      }
    Maximize => {
      controls.maximize()
      model
    }
    Restore => {
      controls.restore()
      model
    }
    ToggleFullscreen => {
      controls.toggle_fullscreen()
      model
    }
    Refresh => model
  }
}

///|
fn hover_zone(
  label : String,
  hint : String,
  width : Double,
  background : @core.Color,
  style : @core.CursorStyle,
) -> @moui.View[Msg] {
  @views.center(
    @views.column([@views.text(label).title(), @views.text(hint)]),
    width~,
    height=120.0,
    background~,
  ).cursor(style)
}

///|
pub fn render(
  model : Model,
  controls : @services.WindowControlSource,
) -> @moui.View[Msg] {
  let status = "panel=\{model.panel_width} maximized=\{controls.maximized()} fullscreen=\{controls.fullscreen()}"
  @views.column([
    @views.row([
      @views.column([
        hover_zone(
          "A pointer",
          "CursorPointer",
          model.panel_width - 24.0,
          @core.Color::from_argb(0xFF2B6CB0U),
          @core.CursorStyle::Icon(@core.CursorIcon::CursorPointer),
        ),
        hover_zone(
          "B text",
          "CursorText",
          model.panel_width - 24.0,
          @core.Color::from_argb(0xFF2F855AU),
          @core.CursorStyle::Icon(@core.CursorIcon::CursorText),
        ),
      ]).frame(width=model.panel_width, height=420.0),
      @views.frame(@views.text(""), width=16.0, height=420.0)
      .background(@core.Color::from_argb(0xFF718096U))
      .cursor(@core.CursorStyle::Icon(@core.CursorIcon::CursorColResize))
      .on_drag(event => SplitDrag(event)),
      @views.column([
        hover_zone(
          "C grabbing",
          "CursorGrabbing",
          180.0,
          @core.Color::from_argb(0xFFB7791FU),
          @core.CursorStyle::Icon(@core.CursorIcon::CursorGrabbing),
        ),
        @views.text(status),
        @views.row([
          @views.button("Maximize", on_click=Maximize, width=120.0),
          @views.button("Restore", on_click=Restore, width=120.0),
          @views.button("Fullscreen", on_click=ToggleFullscreen, width=130.0),
          @views.button("Refresh", on_click=Refresh, width=110.0),
        ]),
      ]).expanded(),
    ]),
  ])
}

///|
pub fn program(
  controls : @services.WindowControlSource,
) -> @moui.Program[Model, Msg] {
  @moui.Program::simple(
    init=Model::new(),
    update=(model, msg) => apply_msg(model, msg, controls),
    view=model => render(model, controls),
  )
}
