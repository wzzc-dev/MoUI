///|
pub fn external_consumer_view() -> @moui.View[Unit] {
  ignore(
    @render_skia.from_env(platform=@render_skia.NativeGpuPlatform::MacOS),
  )
  @views.column([
    @views.text("External MoUI Skia consumer"),
    @views.text("Resolved renderer and base from published archives"),
  ])
}

///|
test "published Skia renderer builds for an external consumer" {
  ignore(external_consumer_view())
}
