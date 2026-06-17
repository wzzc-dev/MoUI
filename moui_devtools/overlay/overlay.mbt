///|
pub fn snapshot_overlay(
  snapshot : @runtime.InspectorSnapshot,
  theme? : @core.Theme = @core.Theme::default(),
) -> @core.View[Unit] {
  @views.text(
    @devtools.snapshot_debug_text(snapshot),
    role=@views.TextRole::Caption,
    theme~,
    width=520.0,
    height=24.0,
  )
}
