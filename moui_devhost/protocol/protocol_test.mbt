///|
fn test_rounded() -> @core.RoundedRect {
  @core.RoundedRect::{
    rect: @core.Rect::new(x=10.0, y=20.0, width=120.0, height=40.0),
    radius: 8.0,
  }
}

///|
fn test_text_run() -> @core.TextRun {
  @core.TextRun::{
    text: "MoUI Counter",
    frame: @core.Rect::new(x=12.0, y=14.0, width=180.0, height=24.0),
    font: @core.FontSpec::new(size=17.0, weight=600, line_height=22.0),
    color: @core.Color::rgba(r=0.1, g=0.2, b=0.3, a=1.0),
    align: @core.TextAlign::TextStart,
    stroke_color: None,
    stroke_width: 0.0,
  }
}

///|
test "frame round trip covers every counter draw variant" {
  let frame : @core.DrawFrame = {
    commands: [
      @core.DrawCommand::Clear(@core.Color::white()),
      @core.DrawCommand::FillRoundedRect(
        test_rounded(),
        @core.Color::rgba(r=0.9, g=0.9, b=0.9, a=1.0),
      ),
      @core.DrawCommand::StrokeRoundedRect(
        test_rounded(),
        @core.Color::rgba(r=0.1, g=0.1, b=0.1, a=1.0),
        1.5,
      ),
      @core.DrawCommand::DrawText(test_text_run()),
    ],
    platform_views: [],
    overlay_bounds: None,
    damage: @core.DamageRegion::Empty,
    clear_color: @core.Color::white(),
    semantics: None,
  }
  let encoded = @protocol.encode_frame(frame)
  let decoded = match @protocol.decode_frame(encoded) {
    Some(commands) => commands
    None => abort("valid bridge frame failed to decode")
  }
  assert_eq(decoded.length(), 3)
  match decoded[0] {
    @core.DrawCommand::FillRoundedRect(rounded, _) =>
      assert_eq(rounded.radius, 8.0)
    _ => abort("expected fill rounded rect")
  }
  match decoded[1] {
    @core.DrawCommand::StrokeRoundedRect(_, _, width) => assert_eq(width, 1.5)
    _ => abort("expected stroke rounded rect")
  }
  match decoded[2] {
    @core.DrawCommand::DrawText(run) => {
      assert_eq(run.text, "MoUI Counter")
      assert_eq(run.font.size, 17.0)
      assert_eq(run.font.weight, 600)
      assert_eq(run.font.line_height, Some(22.0))
    }
    _ => abort("expected text")
  }
}

///|
test "frame decoder rejects corruption and old ABI" {
  assert_eq(@protocol.decode_frame("not json"), None)
  assert_eq(@protocol.decode_frame("{\"version\":0,\"commands\":[]}"), None)
  assert_eq(@protocol.decode_frame("{\"version\":1}"), None)
  assert_eq(@protocol.decode_frame("{\"version\":1,\"commands\":[{\"kind\":\"text\"}]}"), None)
}

///|
test "event round trip" {
  let pointer = @core.AppEvent::Pointer(
    @core.PointerEvent::new(
      position=@core.Point::new(x=30.0, y=40.0),
      phase=@core.PointerPhase::Down,
      button=0,
      wheel_delta=@core.Point::new(x=1.0, y=2.0),
      modifiers=@core.KeyModifiers::new(shift=true, meta=true),
      id=2,
      pressure=0.5,
    ),
  )
  let encoded = match @protocol.encode_event(pointer) {
    Some(text) => text
    None => abort("pointer event failed to encode")
  }
  assert_eq(@protocol.decode_event(encoded), Some(pointer))
  let keyboard = @core.AppEvent::Keyboard(
    @core.KeyboardEvent::new(
      key="a",
      code="KeyA",
      text=Some("a"),
      pressed=true,
      repeat=false,
    ),
  )
  let encoded_keyboard = match @protocol.encode_event(keyboard) {
    Some(text) => text
    None => abort("keyboard event failed to encode")
  }
  assert_eq(@protocol.decode_event(encoded_keyboard), Some(keyboard))
  let text_input = @core.AppEvent::TextInput(
    @core.TextInputEvent::InsertText("你好"),
  )
  let encoded_text = match @protocol.encode_event(text_input) {
    Some(text) => text
    None => abort("text input failed to encode")
  }
  assert_eq(@protocol.decode_event(encoded_text), Some(text_input))
  let resize = @core.AppEvent::Resize(@core.Size::new(width=640.0, height=480.0))
  let encoded_resize = match @protocol.encode_event(resize) {
    Some(text) => text
    None => abort("resize failed to encode")
  }
  assert_eq(@protocol.decode_event(encoded_resize), Some(resize))
  assert_eq(@protocol.decode_event("{\"kind\":\"pointer\"}"), None)
  assert_eq(@protocol.decode_event("not json"), None)
}

///|
test "config round trip and invalid payload" {
  let config = @protocol.DevConfig::new(
    width=520.0,
    height=360.0,
    state_file=Some("/tmp/state.json"),
    transient_file=None,
  )
  let decoded = match @protocol.decode_config(@protocol.encode_config(config)) {
    Some(config) => config
    None => abort("config failed to decode")
  }
  assert_eq(decoded.width, 520.0)
  assert_eq(decoded.height, 360.0)
  assert_eq(decoded.state_file, Some("/tmp/state.json"))
  assert_eq(decoded.transient_file, None)
  assert_eq(@protocol.decode_config("{\"width\":10}"), None)
  assert_eq(@protocol.decode_config("not json"), None)
}
