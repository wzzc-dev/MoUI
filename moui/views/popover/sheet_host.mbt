///|
fn[Msg] modal_scrim(alpha~ : Double) -> @core.View[Msg] {
  @container.empty().background_brush(
    @core.Brush::solid(@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=alpha)),
  )
}

///|
pub fn[Msg] sheet_host(
  child~ : @core.View[Msg],
  sheet? : @core.View[Msg]? = None,
  presented? : Bool = false,
  presentation_mode? : @style.SheetPresentationMode = @style.SheetPresentationMode::Modal,
  theme? : @core.Theme,
  on_dismiss? : Msg? = None,
  trap_focus? : Bool = true,
) -> @core.View[Msg] {
  if presented && sheet is Some(sheet_spec) {
    let resolved_theme = theme.unwrap_or(@core.Theme::neutral())
    let scrim = modal_scrim(alpha=0.28)
    let scrim_with_tap = match on_dismiss {
      Some(message) => scrim.on_tap(message)
      None => scrim
    }
    // The sheet content
    let aligned_sheet = match presentation_mode {
      @style.SheetPresentationMode::Modal =>
        sheet_spec
        .frame(width=400.0, height=400.0)
        .corner_radius(resolved_theme.radius_scale.lg)
        .align()
      @style.SheetPresentationMode::BottomSheet =>
        sheet_spec
        .corner_radius(resolved_theme.radius_scale.lg)
        .align(alignment=@core.Alignment::new(x=0.0, y=1.0))
    }
    let aligned_sheet = if trap_focus {
      aligned_sheet.focus_trap()
    } else {
      aligned_sheet
    }
    stack([child, scrim_with_tap, aligned_sheet])
  } else {
    child
  }
}
