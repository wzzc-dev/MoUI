///|
fn desktop_icon(
  icon : @views.IconName,
  size : Double,
  color : @graphics.Color,
) -> @moui.View[Msg] {
  @views.icon(icon, size~, color~, weight=1.8)
}

///|
/// Apple-menu glyph: rendered as the Unicode Apple logo character (U+F8FF).
/// On macOS the system font draws this as the native Apple silhouette. This
/// approach is simpler and visually more accurate than approximating the
/// Apple shape with hand-coded cubic bezier curves.
fn apple_logo_glyph(size : Double, color : @graphics.Color) -> @moui.View[Msg] {
  // The Apple menu mark: a bold "Mo" monogram that sits cleanly inside the
  // 28px menu bar.  The real Apple logo (U+F8FF) is too tall for such a
  // tight vertical space — its glyph bounds extend beyond the menu bar's
  // clip region.  A styled monogram is the de-facto fallback used by many
  // macOS menu bars when the system logo is unavailable.
  @views.text(
    "Mo",
    role=@views.TextRole::Label,
    width=size,
    height=size,
    align=@text.TextAlign::TextCenter,
  )
  .font(@text.FontSpec::new(size=size * 0.56, weight=680))
  .foreground(color)
  .accessibility_label("Apple menu")
}
