///|
pub fn external_consumer_view() -> @moui.View[Unit] {
  @views.column([
    @views.text("External MoUI consumer"),
    @views.text("Resolved without monorepo source overrides"),
  ])
}

///|
test "published public facade builds for an external consumer" {
  ignore(external_consumer_view())
}
