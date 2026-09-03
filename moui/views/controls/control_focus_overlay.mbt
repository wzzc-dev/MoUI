///|
pub fn[Msg] focus_ring(
  child : @core.View[Msg],
  focused~ : Bool,
  label? : String = "Focused item",
  theme? : @core.Theme,
  width? : Double,
  height? : Double,
  padding? : Double = 3.0,
  radius? : Double = 8.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let ring = @core.BorderStyle::new(
    brush=@core.Brush::solid(
      if focused {
        resolved_theme.palette.primary
      } else {
        resolved_theme.palette.outline.multiply_alpha(0.42)
      },
    ),
    width=if focused { 2.0 } else { 1.0 },
  )
  let wrapped = @layout.container_box(
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
  variant? : @style.ButtonVariant = @style.ButtonVariant::Tonal,
  theme? : @core.Theme,
  width? : Double = 160.0,
  height? : Double = 40.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let spec = match on_click {
    Some(message) =>
      @button.button(
        label,
        on_click=message,
        variant~,
        theme=resolved_theme,
        width~,
        height~,
      )
    None =>
      @button.button(label, variant~, theme=resolved_theme, width~, height~)
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
    @presentation.popup_host(child, [
      @presentation.PresentationSpec::new(
        id="tooltip:\{message}",
        kind=@presentation.PresentationKind::Tooltip,
        anchor=@presentation.PresentationAnchor::HostBase,
        placement=Some(
          @presentation.PresentationPlacement::new(
            candidates=[
              @presentation.PresentationPlacementCandidate::AboveEnd,
              @presentation.PresentationPlacementCandidate::BelowEnd,
              @presentation.PresentationPlacementCandidate::AboveStart,
              @presentation.PresentationPlacementCandidate::BelowStart,
            ],
            viewport_insets=@core.Insets::all(0.0),
          ),
        ),
        content=@container.container(
          @text.text(message, width=180.0, height=24.0).semantics_role(
            @core.SemanticsRole::Tooltip,
          ),
          variant=@style.ContainerVariant::Raised,
        ),
      ),
    ])
  } else {
    child
  }
}
