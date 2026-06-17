///|
pub fn[Msg] sheet(
  content~ : @core.View[Msg],
  presentation_mode? : @core.SheetPresentationMode = @core.SheetPresentationMode::Modal,
  background? : @core.Color = @core.Color::white(),
  corner_radius? : Double = default_theme().radius_scale.lg,
  shadow? : @core.ShadowStyle? = None,
  on_dismiss? : Msg? = None,
) -> @core.View[Msg] {
  raw_sheet(
    content~,
    presentation_mode~,
    background=@core.Brush::solid(background),
    corner_radius~,
    shadow~,
    on_dismiss~,
  )
}

///|
pub fn[Msg] sheet_host(
  child~ : @core.View[Msg],
  sheet? : @core.View[Msg]? = None,
  presented? : Bool = false,
  presentation_mode? : @core.SheetPresentationMode = @core.SheetPresentationMode::Modal,
  on_dismiss? : Msg? = None,
  trap_focus? : Bool = true,
) -> @core.View[Msg] {
  if presented && sheet is Some(sheet_spec) {
    let theme = default_theme()
    let scrim = modal_scrim(alpha=0.28)
    let scrim_with_tap = match on_dismiss {
      Some(message) => scrim.on_tap(message)
      None => scrim
    }
    // The sheet content
    let aligned_sheet = match presentation_mode {
      @core.SheetPresentationMode::Modal =>
        sheet_spec
        .frame(width=400.0, height=400.0)
        .corner_radius(theme.radius_scale.lg)
        .align()
      @core.SheetPresentationMode::BottomSheet =>
        sheet_spec
        .corner_radius(theme.radius_scale.lg)
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
