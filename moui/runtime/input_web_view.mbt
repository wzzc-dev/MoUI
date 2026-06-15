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
    _ => self.children.any(child => child.dispatch_web_view_event(id, event))
  }
}
