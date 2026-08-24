///|
fn[Msg] popover_surface(
  anchor~ : @core.View[Msg],
  content~ : @core.View[Msg],
  expanded~ : Bool,
  placement? : PopoverPlacement = PopoverPlacement::BottomStart,
  theme? : @core.Theme,
  width? : Double = 240.0,
  height? : Double = 160.0,
  trap_focus? : Bool = false,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let view = if expanded {
    let panel = @container.container(
        content,
        width~,
        height~,
        variant=@style.ContainerVariant::Overlay,
        theme=resolved_theme,
        padding=resolved_theme.spacing_scale.sm,
      )
      .shadow(
        @style.views_ambient_control_theme(resolved_theme).surface.overlay_shadow.unwrap_or(
          resolved_theme.shadow_scale.md,
        ),
      )
      .align(alignment=popover_alignment(placement))
    let panel = if trap_focus { panel.focus_trap() } else { panel }
    @layout.stack([anchor, panel])
  } else {
    anchor
  }
  view.semantics_expanded(expanded~)
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
