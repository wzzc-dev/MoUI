///|
pub fn[Msg] web_view(
  id~ : String,
  url~ : String,
  width? : Double? = None,
  height? : Double? = None,
  title? : String = "",
  policy? : WebViewNavigationPolicy = WebViewNavigationPolicy::AllowHttpHttpsFile,
  on_event? : ((WebViewEvent) -> Msg)? = None,
) -> @core.View[Msg] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="WebView", key=Some(id)),
    revision=() => {
      "web-view:\{id}:\{url}:\{web_view_double_option_revision(width)}:\{web_view_double_option_revision(height)}:\{title}:\{policy.revision_key()}:\{on_event is Some(_)}"
    },
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(
          @core.Size::new(
            width=width.unwrap_or(640.0),
            height=height.unwrap_or(360.0),
          ),
        ),
      )
    },
    paint=ctx => {
      if ctx.frame.is_empty() {
        @core.ViewPaintPlan::empty()
      } else {
        let spec = @host.WebViewSpec::new(
          id~,
          url~,
          width~,
          height~,
          title~,
          policy~,
        )
        {
          commands: [],
          child_layers: [],
          post_commands: [],
          overlay_commands: [],
          platform_views: [spec.platform_view_placement(frame=ctx.frame)],
          repaint_boundary: false,
        }
      }
    },
    event=ctx => {
      match (ctx.event, on_event) {
        (@core.AppEvent::PlatformView(event_id, event), Some(handler)) =>
          if event_id == id {
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
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        role=@core.SemanticsRole::Group,
        label=title,
        value=url,
      )
    },
  )
}

///|
fn web_view_double_option_revision(value : Double?) -> String {
  match value {
    Some(value) => "\{value}"
    None => "none"
  }
}
