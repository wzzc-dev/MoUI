///|
test "paint layer bounds follow an inset heading through the viewport origin" {
  let mut previous_bounds : Rect? = None
  let mut previous_y = 0.0
  for y in [80.0, 20.0, 8.0, 0.0, -8.0, -16.0, -24.0, -60.0] {
    let frame = Rect::new(x=14.0, y~, width=600.0, height=60.0)
    let text_frame = Rect::new(x=20.0, y=y + 17.0, width=140.0, height=34.0)
    let node = view_paint_layer_render_node(
      ElementId::new(1),
      @core.ViewPaintLayer::new(
        frame~,
        cache_key="heading",
        content_revision=1,
        commands=[
          DrawText(
            @core.TextRun::new(
              text="列表与任务",
              frame=text_frame,
              font=@core.FontSpec::new(size=24.0),
              color=Color::black(),
            ),
          ),
        ],
      ),
    )
    let spec = node.cached_layer_spec().unwrap()
    assert_eq(spec.frame, frame)
    assert_eq(text_frame.origin.y - spec.frame.origin.y, 17.0)
    match previous_bounds {
      Some(previous) => {
        assert_eq(spec.frame.size, previous.size)
        assert_eq(spec.frame.origin.y - previous.origin.y, y - previous_y)
      }
      None => ()
    }
    previous_bounds = Some(spec.frame)
    previous_y = y
  }
}

///|
test "paint layer bounds include overflowing commands in the owning view coordinates" {
  let frame = Rect::new(x=14.0, y=-8.0, width=600.0, height=60.0)
  let overflow = Rect::new(x=10.0, y=-12.0, width=608.0, height=68.0)
  let node = view_paint_layer_render_node(
    ElementId::new(1),
    @core.ViewPaintLayer::new(
      frame~,
      cache_key="overflow",
      content_revision=1,
      commands=[FillRect(overflow, Color::black())],
    ),
  )
  assert_eq(node.cached_layer_spec().unwrap().frame, overflow.inflate(1.0))
}
