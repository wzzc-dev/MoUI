///|
/// Styled panel shell for control popups: overlay surface, shadow, padding.
/// This is a content shell only — placement, clipping escape, semantics, and
/// dismissal belong to `@presentation.popup_host` and the runtime placement pass.
fn[Msg] popover_panel(
  content~ : @core.View[Msg],
  width~ : Double,
  height? : Double,
  theme~ : @core.Theme,
) -> @core.View[Msg] {
  @container.container(
    content,
    width~,
    height?,
    variant=@style.ContainerVariant::Overlay,
    theme~,
    padding=theme.spacing_scale.sm,
  ).shadow(
    @style.views_ambient_control_theme(theme).surface.overlay_shadow.unwrap_or(
      theme.shadow_scale.md,
    ),
  )
}

///|
/// Build a control-popup presentation spec anchored to the enclosing
/// `@presentation.popup_host` base child. Candidates fall back around the anchor and clamp
/// to the viewport; the popup escapes ancestor clipping through the runtime
/// placement pass.
pub fn[Msg] popup_spec(
  id~ : String,
  content~ : @core.View[Msg],
  theme~ : @core.Theme,
  width~ : Double,
  height? : Double,
  candidates? : Array[@presentation.PresentationPlacementCandidate] = [
    @presentation.PresentationPlacementCandidate::BelowStart,
    @presentation.PresentationPlacementCandidate::AboveStart,
    @presentation.PresentationPlacementCandidate::BelowEnd,
    @presentation.PresentationPlacementCandidate::AboveEnd,
  ],
) -> @presentation.PresentationSpec[Msg] {
  @presentation.PresentationSpec::new(
    id~,
    kind=@presentation.PresentationKind::Popover,
    anchor=@presentation.PresentationAnchor::HostBase,
    placement=Some(
      @presentation.PresentationPlacement::new(
        candidates~,
        viewport_insets=@core.Insets::all(0.0),
      ),
    ),
    content=popover_panel(content~, width~, height?, theme~),
  )
}
