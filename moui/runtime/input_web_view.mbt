///|
fn ElementNode::dispatch_web_view_event(
  self : ElementNode,
  id : String,
  event : WebViewEvent,
) -> Bool {
  match self.spec {
    WebViewHostSpec(data) =>
      if data.id == id {
        match data.on_event {
          Some(handler) => {
            handler(event)
            true
          }
          None => false
        }
      } else {
        false
      }
    WidgetSpec(data) => {
      let result = (data.event)({
        frame: Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
        child_frames: [],
        event: AppEvent::WebView(id, event),
        focused: false,
        state: data.state,
        text_system: TextSystem::fallback(),
        environment: Environment::default(),
      })
      result.activated || result.changed
    }
    _ => self.children.any(child => child.dispatch_web_view_event(id, event))
  }
}
