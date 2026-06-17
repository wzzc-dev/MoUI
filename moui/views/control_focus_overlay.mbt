///|
pub fn[Msg] focus_ring(
  child : @core.View[Msg],
  focused~ : Bool,
  label? : String = "Focused item",
  theme? : @core.Theme = default_theme(),
  width? : Double,
  height? : Double,
  padding? : Double = 3.0,
  radius? : Double = 8.0,
) -> @core.View[Msg] {
  let ring = @core.BorderStyle::new(
    brush=@core.Brush::solid(
      if focused {
        theme.palette.primary
      } else {
        theme.palette.outline.multiply_alpha(0.42)
      },
    ),
    width=if focused { 2.0 } else { 1.0 },
  )
  let wrapped = raw_container(
    child=Some(child.padding(padding)),
    size=None,
    border=Some(ring),
    corner_radius=radius,
  )
  let framed = match (width, height) {
    (None, None) => wrapped
    _ => wrapped.frame(width?, height?)
  }
  framed
  .focusable()
  .semantics_selected(selected=focused)
  .semantics_description(if focused { "Focused" } else { "Not focused" })
  .accessibility_label(label)
}

///|
pub fn[Msg] menu_button(
  label : String,
  on_click? : Msg,
  variant? : ButtonVariant = ButtonVariant::Tonal,
  theme? : @core.Theme = default_theme(),
  width? : Double = 160.0,
  height? : Double = 40.0,
) -> @core.View[Msg] {
  let spec = match on_click {
    Some(message) =>
      button(label, on_click=message, variant~, theme~, width~, height~)
    None => button(label, variant~, theme~, width~, height~)
  }
  spec.semantics_role(@core.SemanticsRole::Menu)
}

///|
pub fn[Msg] tooltip(
  child : @core.View[Msg],
  message : String,
  visible? : Bool = false,
) -> @core.View[Msg] {
  if visible {
    stack([
      child,
      surface(
        text(message, width=180.0, height=24.0).semantics_role(
          @core.SemanticsRole::Tooltip,
        ),
        variant=SurfaceVariant::Raised,
      ).align(alignment=@core.Alignment::top_trailing()),
    ])
  } else {
    child
  }
}
