///|
test "commands_json serializes the p5 command subset" {
  let commands : Array[@core.DrawCommand] = [
    @core.Clear(@core.Color::rgba(r=0.1, g=0.2, b=0.3)),
    @core.FillRect(
      @core.Rect::new(x=1.0, y=2.0, width=3.0, height=4.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0),
    ),
    @core.PushPathClip(
      @core.PathSpec::new(verbs=[
        @core.MoveTo(@core.Point::new(x=0.0, y=0.0)),
        @core.LineTo(@core.Point::new(x=4.0, y=0.0)),
        @core.Close,
      ]),
    ),
    @core.PopPathClip,
    @core.DrawText(
      @core.TextRun::new(
        text="Hi",
        frame=@core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
        font=@core.FontSpec::new(size=12.0, weight=400),
        color=@core.Color::black(),
        stroke_color=Some(@core.Color::black()),
        stroke_width=2.0,
      ),
    ),
    @core.PushLayer(@core.LayerSpec::new(blend_mode=@core.BlendMode::Source)),
    @core.PopLayer,
  ]
  let json = commands_json(commands, 8.0, 4.0)
  assert_true(json.contains("\"w\":8,\"h\":4"))
  assert_true(json.contains("\"op\":\"clear\",\"c\":[0.1,0.2,0.3,1]"))
  assert_true(json.contains("\"op\":\"rect\",\"x\":1,\"y\":2,\"w\":3,\"h\":4"))
  assert_true(json.contains("\"op\":\"clip\",\"x\":0,\"y\":0,\"w\":4,\"h\":0"))
  assert_true(json.contains("\"op\":\"text\",\"t\":\"Hi\""))
  assert_true(json.contains("\"sc\":[0,0,0,1],\"sw\":2"))
  assert_true(json.contains("{\"op\":\"layer\",\"mode\":\"copy\"}"))
  assert_true(json.contains("{\"op\":\"endlayer\"}"))
}

///|
test "commands_json escapes text payloads" {
  let commands : Array[@core.DrawCommand] = [
    @core.DrawText(
      @core.TextRun::new(
        text="a\"b\\c",
        frame=@core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
        font=@core.FontSpec::new(size=12.0, weight=400),
        color=@core.Color::black(),
      ),
    ),
  ]
  let json = commands_json(commands, 8.0, 4.0)
  assert_true(json.contains("\"t\":\"a\\\"b\\\\c\""))
}
