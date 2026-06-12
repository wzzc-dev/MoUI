///|
fn host_test_runtime(
  root~ : @core.View[Unit],
  size~ : @core.Size,
) -> @core.AppRuntime {
  @core.AppRuntime::new_view(root~, size~)
}

///|
fn host_test_text_field(
  value : @core.Binding[String],
  width? : Double = 240.0,
  height? : Double = 40.0,
  outlined? : Bool = false,
) -> @core.View[Unit] {
  let normal_border = if outlined {
    Some(
      @core.BorderStyle::new(
        brush=@core.Brush::solid(@core.Color::gray()),
        width=1.0,
      ),
    )
  } else {
    None
  }
  let focused_border = if outlined {
    Some(
      @core.BorderStyle::new(
        brush=@core.Brush::solid(@core.Color::blue()),
        width=2.0,
      ),
    )
  } else {
    None
  }
  @core.View::text_field(
    value~,
    placeholder="Type",
    size=@core.Size::new(width~, height~),
    font=@core.FontSpec::new(size=16.0, weight=400),
    foreground=@core.Color::black(),
    placeholder_color=@core.Color::gray(),
    background=@core.Brush::solid(@core.Color::white()),
    border=normal_border,
    focused_border~,
    cursor_color=@core.Color::blue(),
    corner_radius=0.0,
  )
}

///|
fn host_test_image_renderer(revision : Ref[Int]) -> HostWindowRenderer {
  HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image_resource_snapshot=Some(() => {
      @render.ImageResourceSnapshot::new(revision=revision.val, records=[])
    }),
  )
}
