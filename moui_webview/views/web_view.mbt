///|
pub fn[Msg] web_view(
  controller~ : @host.WebViewController,
  width? : Double? = None,
  height? : Double? = None,
  title? : String = "",
  background_color? : @core.Color? = None,
  color_scheme? : @core.ColorScheme? = None,
  on_event? : ((@host.WebViewEvent) -> Msg)? = None,
) -> @core.View[Msg] {
  let id = controller.id()
  @core.View::from_node(
    WebViewNode::{ id, width, height, title, background_color, color_scheme },
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
  width : Double?
  height : Double?
  title : String
  background_color : @core.Color?
  color_scheme : @core.ColorScheme?
}

///|
impl @core.ViewNode for WebViewNode with fn identity(self) {
  @core.ViewIdentity::new(kind="WebView", key=Some(self.id))
}

///|
impl @core.ViewNode for WebViewNode with fn declaration(self) {
  let size_key = @core.DeclarationKey::record(type_tag="WebView.layout", fields=[
    (
      "width",
      @core.DeclarationKey::option(self.width.map(@core.DeclarationKey::double)),
    ),
    (
      "height",
      @core.DeclarationKey::option(
        self.height.map(@core.DeclarationKey::double),
      ),
    ),
  ])
  let content_key = @core.DeclarationKey::record(type_tag="WebView.content", fields=[
    ("title", @core.DeclarationKey::string(self.title)),
    (
      "background-color",
      @core.DeclarationKey::string(
        match self.background_color {
          Some(color) => @host.web_view_color_wire_value(color)
          None => ""
        },
      ),
    ),
    (
      "color-scheme",
      @core.DeclarationKey::string(
        match self.color_scheme {
          Some(@core.ColorScheme::Dark) => "dark"
          Some(@core.ColorScheme::Light) => "light"
          None => ""
        },
      ),
    ),
  ])
  @core.ViewDeclaration::channels(
    layout=@core.DeclarationChannel::Exact(size_key),
    paint=@core.DeclarationChannel::Constant,
    semantics=@core.DeclarationChannel::Exact(
      @core.DeclarationKey::record(type_tag="WebView.semantics", fields=[
        ("title", @core.DeclarationKey::string(self.title)),
      ]),
    ),
    platform=@core.DeclarationChannel::Exact(content_key),
  )
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
impl @core.ViewNode for WebViewNode with fn platform_views(self, ctx) {
  if ctx.frame.is_empty() {
    []
  } else {
    let spec = @host.WebViewSpec::new(
      id=self.id,
      width=self.width,
      height=self.height,
      title=self.title,
      background_color=self.background_color,
      color_scheme=self.color_scheme,
    )
    [spec.platform_view_placement(frame=ctx.frame)]
  }
}

///|
impl @core.ViewNode for WebViewNode with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Boundary,
    role=@core.SemanticsRole::Group,
    label=self.title,
    value="",
  )
}
