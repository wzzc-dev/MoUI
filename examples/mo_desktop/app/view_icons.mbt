///|
fn desktop_icon(
  icon : @views.IconName,
  size : Double,
  color : @graphics.Color,
) -> @moui.View[Msg] {
  @views.icon(icon, size~, color~, weight=1.8)
}
