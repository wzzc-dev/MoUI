// SheetPresentationMode lives in @style. Presentation composition is owned by
// the root `overlay_host` entrypoint.

///|
pub fn[Msg] sheet(
  content~ : @core.View[Msg],
  presentation_mode? : @style.SheetPresentationMode = @style.SheetPresentationMode::Modal,
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
