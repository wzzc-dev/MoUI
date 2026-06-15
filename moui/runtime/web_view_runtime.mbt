///|
fn WebViewHostViewSpec::to_core_spec(
  self : WebViewHostViewSpec,
) -> @core.WebViewSpec {
  @core.WebViewSpec::new(
    id=self.id,
    url=self.url,
    width=self.width,
    height=self.height,
    title=self.title,
    policy=self.policy,
    on_event=self.on_event,
  )
}
