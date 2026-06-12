///|
test "web view constructor exposes platform placement and events" {
  let seen = Ref("")
  let runtime = @core.AppRuntime::new_view(
    root=@views.web_view(
      id="docs",
      url="https://wzzc-dev.github.io/MoUI/",
      width=Some(320.0),
      height=Some(180.0),
      title="MoUI docs",
      on_event=Some(event => {
        match event {
          @core.WebViewEvent::NavigationRequested(url) => "nav:" + url
          _ => "other"
        }
      }),
    ),
    size=@core.Size::new(width=480.0, height=320.0),
    on_message=Some(message => seen.val = message),
  )
  let frame = runtime.draw_frame()
  inspect(frame.platform_views.length(), content="1")
  inspect(frame.platform_views[0].id, content="docs")
  inspect(
    frame.platform_views[0].url,
    content="https://wzzc-dev.github.io/MoUI/",
  )
  inspect(frame.commands.length(), content="1")
  guard runtime.semantics().role == @core.SemanticsRole::WebView else {
    fail("expected web view semantics role")
  }
  runtime.dispatch_event(
    @core.AppEvent::WebView(
      "docs",
      @core.WebViewEvent::NavigationRequested("https://example.com/"),
    ),
  )
  inspect(seen.val, content="nav:https://example.com/")
}
