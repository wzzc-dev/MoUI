///|
test "sun pixel frame rows are top-down" {
  let frames : Array[SunPixelFrame] = []
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=8.0),
    ),
    SunPresentTarget::new(description="orientation", present=frame => {
      frames.push(frame)
      true
    }),
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=8.0, height=2.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0),
    ),
  ])
  let frame = frames[0]
  let first = frame.pixels()[0].to_int()
  let green = frame.pixels()[1].to_int()
  let blue = frame.pixels()[2].to_int()
  assert_true(first > 200 && green < 60 && blue < 60)
}

///|
test "direct placeholder call places text at the top" {
  let frames : Array[SunPixelFrame] = []
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=100.0, height=64.0),
    ),
    SunPresentTarget::new(description="placeholder-direct", present=frame => {
      frames.push(frame)
      true
    }),
  )
  renderer.canvas.clear(@sun_graphics.Color::white())
  renderer.draw_text_placeholder(
    @core.TextRun::new(
      text="A",
      frame=@core.Rect::new(x=10.0, y=0.0, width=80.0, height=64.0),
      font=@core.FontSpec::new(size=13.0, weight=600),
      color=@core.Color::rgba(r=0.0, g=0.0, b=0.0),
      align=TextStart,
    ),
    1.0,
  )
  let frame = renderer.read_frame()
  let mut first_dark = -1
  for y in 0..<frame.height() {
    for x in 0..<frame.width() {
      let offset = y * frame.row_bytes() + x * 4
      if frame.pixels()[offset].to_int() < 64 {
        if first_dark < 0 {
          first_dark = y
        }
      }
    }
  }
  println("direct placeholder first dark row: \{first_dark}")
  assert_true(first_dark >= 0 && first_dark < 10)
}
