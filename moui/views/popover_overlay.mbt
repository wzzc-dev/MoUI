///|
pub fn[Msg] popover(
  anchor~ : @core.View[Msg],
  content~ : @core.View[Msg],
  expanded~ : Bool,
  placement? : PopoverPlacement = PopoverPlacement::BottomStart,
  theme? : @core.Theme = default_theme(),
  width? : Double = 240.0,
  height? : Double = 160.0,
  trap_focus? : Bool = false,
) -> @core.View[Msg] {
  let view = if expanded {
    let panel = container(
        content,
        width~,
        height~,
        variant=ContainerVariant::Overlay,
        theme~,
        padding=theme.spacing_scale.sm,
      )
      .shadow(theme.components.surface.overlay_shadow.unwrap_or(theme.shadow_scale.md))
      .align(alignment=popover_alignment(placement))
    let panel = if trap_focus { panel.focus_trap() } else { panel }
    stack([anchor, panel])
  } else {
    anchor
  }
  view
  .semantics_expanded(expanded~)
  .semantics_action(popover_toggle_action(expanded))
}

///|
fn popover_alignment(placement : PopoverPlacement) -> @core.Alignment {
  match placement {
    BottomStart => @core.Alignment::new(x=0.0, y=1.0)
    BottomEnd => @core.Alignment::new(x=1.0, y=1.0)
    TopStart => @core.Alignment::new(x=0.0, y=0.0)
    TopEnd => @core.Alignment::new(x=1.0, y=0.0)
  }
}

///|
fn popover_toggle_action(expanded : Bool) -> @core.SemanticsAction {
  if expanded {
    @core.SemanticsAction::Collapse
  } else {
    @core.SemanticsAction::Expand
  }
}
