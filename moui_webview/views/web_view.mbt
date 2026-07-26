///|
pub fn[Msg] web_view(
  id~ : String,
  url~ : String,
  width? : Double? = None,
  height? : Double? = None,
  title? : String = "",
  policy? : @host.WebViewNavigationPolicy = @host.WebViewNavigationPolicy::AllowHttpHttpsFile,
  on_event? : ((@host.WebViewEvent) -> Msg)? = None,
) -> @core.View[Msg] {
  @core.View::from_node(
    WebViewNode::{
      id,
      url,
      width,
      height,
      title,
      policy,
      has_on_event: on_event is Some(_),
    },
    event=(node, ctx) => {
      match (ctx.event, on_event) {
        (@core.AppEvent::PlatformView(event_id, event), Some(handler)) =>
          if event_id == node.id {
            match @host.WebViewEvent::from_platform_event(event) {
              Some(web_event) =>
                @core.ViewEventResult::message(handler(web_event))
              None => @core.ViewEventResult::ignored()
            }
          } else {
            @core.ViewEventResult::ignored()
          }
        _ => @core.ViewEventResult::ignored()
      }
    },
  )
}

///|
priv struct WebViewNode {
  id : String
  url : String
  width : Double?
  height : Double?
  title : String
  policy : @host.WebViewNavigationPolicy
  has_on_event : Bool
}

///|
impl @core.ViewNode for WebViewNode with fn identity(self) {
  @core.ViewIdentity::new(kind="WebView", key=Some(self.id))
}

///|
impl @core.ViewNode for WebViewNode with fn revision(self) {
  "web-view:\{self.id}:\{self.url}:\{web_view_double_option_revision(self.width)}:\{web_view_double_option_revision(self.height)}:\{self.title}:\{self.policy.revision_key()}:\{self.has_on_event}"
}

///|
impl @core.ViewNode for WebViewNode with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(
      @core.Size::new(
        width=self.width.unwrap_or(ctx.constraints.max.width),
        height=self.height.unwrap_or(ctx.constraints.max.height),
      ),
    ),
  )
}

///|
impl @core.ViewNode for WebViewNode with fn paint(self, ctx) {
  if ctx.frame.is_empty() {
    @core.ViewPaintPlan::empty()
  } else {
    let spec = @host.WebViewSpec::new(
      id=self.id,
      url=self.url,
      width=self.width,
      height=self.height,
      title=self.title,
      policy=self.policy,
    )
    {
      commands: [],
      child_layers: [],
      post_commands: [],
      overlay_commands: [],
      platform_views: [spec.platform_view_placement(frame=ctx.frame)],
      repaint_boundary: false,
      animating: false,
    }
  }
}

///|
impl @core.ViewNode for WebViewNode with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    role=@core.SemanticsRole::Group,
    label=self.title,
    value=self.url,
  )
}

///|
fn web_view_double_option_revision(value : Double?) -> String {
  match value {
    Some(value) => "\{value}"
    None => "none"
  }
}
