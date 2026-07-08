///|
pub(all) enum SheetPresentationMode {
  Modal
  BottomSheet
} derive(Eq, Debug, ToJson)

///|
pub fn[Msg] sheet(
  content~ : @core.View[Msg],
  presentation_mode? : SheetPresentationMode = SheetPresentationMode::Modal,
  theme? : @core.Theme,
  background? : @core.Color,
  corner_radius? : Double,
  shadow? : @core.ShadowStyle? = None,
  on_dismiss? : Msg? = None,
) -> @core.View[Msg] {
  // The surface brush is resolved ambient-ly inside sheet_shell (an explicit
  // theme? overrides ctx.environment.theme) so the sheet tracks dark-mode /
  // palette changes without the caller rebuilding the view tree.
  let background_brush : @core.Brush? = match background {
    Some(color) => Some(@core.Brush::solid(color))
    None => None
  }
  sheet_shell(
    content~,
    presentation_mode~,
    theme?,
    background?=background_brush,
    corner_radius?,
    shadow~,
    on_dismiss~,
  )
}

///|
pub fn[Msg] sheet_host(
  child~ : @core.View[Msg],
  sheet? : @core.View[Msg]? = None,
  presented? : Bool = false,
  presentation_mode? : SheetPresentationMode = SheetPresentationMode::Modal,
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
      SheetPresentationMode::Modal =>
        sheet_spec
        .frame(width=400.0, height=400.0)
        .corner_radius(resolved_theme.radius_scale.lg)
        .align()
      SheetPresentationMode::BottomSheet =>
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
