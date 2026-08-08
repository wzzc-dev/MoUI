///|
pub fn external_consumer_view() -> @moui.View[Unit] {
  ignore(@render_web.from_env())
  @views.column([
    @views.text("External MoUI Web consumer"),
    @views.text("Resolved renderer and base from published archives"),
  ])
}

///|
test "published Web renderer builds for an external consumer" {
  ignore(external_consumer_view())
}
