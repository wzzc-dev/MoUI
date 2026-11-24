///|
fn test_color(value : Double) -> @core.Color {
  @core.Color::rgba(r=value, g=value * 0.5, b=0.25, a=1.0)
}

///|
fn test_rect() -> @core.Rect {
  @core.Rect::new(x=10.0, y=20.0, width=120.0, height=40.0)
}

///|
fn test_rounded() -> @core.RoundedRect {
  @core.RoundedRect::{ rect: test_rect(), radius: 8.0 }
}

///|
fn test_linear_brush() -> @core.Brush {
  @core.Brush::LinearGradient(
    @core.LinearGradientSpec::{
      start: @core.Point::new(x=0.0, y=0.0),
      end: @core.Point::new(x=120.0, y=40.0),
      start_color: test_color(0.2),
      end_color: test_color(0.8),
    },
  )
}

///|
fn test_radial_brush() -> @core.Brush {
  @core.Brush::RadialGradient(
    @core.RadialGradientSpec::{
      center: @core.Point::new(x=60.0, y=40.0),
      radius: 80.0,
      center_color: test_color(0.9),
      edge_color: test_color(0.1),
    },
  )
}

///|
fn test_stops_brush(axis : @core.GradientAxis) -> @core.Brush {
  @core.Brush::StopsGradient(
    @core.StopsGradientSpec::new(
      axis~,
      stops=[
        @core.GradientStop::new(color=test_color(0.1), at=0.0),
        @core.GradientStop::new(color=test_color(0.5), at=0.5),
        @core.GradientStop::new(color=test_color(0.9), at=1.0),
      ],
      oklab=true,
    ),
  )
}

///|
fn test_text_run() -> @core.TextRun {
  @core.TextRun::{
    text: "MoUI Counter 你好",
    frame: @core.Rect::new(x=12.0, y=14.0, width=180.0, height=24.0),
    font: @core.FontSpec::new(
      families=@core.FontFamilyStack::new([
        @core.FontFamily::Name("Inter"),
        @core.FontFamily::UiSansSerif,
      ]),
      size=17.0,
      weight=600,
      style=@core.FontStyle::Italic,
      variations=[@core.FontVariation::new(axis="wght", value=650.0)],
      line_height=22.0,
      letter_spacing=0.5,
      features=[@core.FontFeature::new(tag="tnum", value=1)],
    ),
    color: test_color(0.3),
    align: @core.TextAlign::TextCenter,
    stroke_color: Some(test_color(0.05)),
    stroke_width: 0.75,
  }
}

///|
fn test_image_run(with_src_rect : Bool) -> @core.ImageRun {
  @core.ImageRun::{
    source: "resource/branding/moui-mark.png",
    frame: @core.Rect::new(x=8.0, y=8.0, width=48.0, height=48.0),
    opacity: 0.8,
    fit: @core.ImageFit::Cover,
    src_rect: if with_src_rect {
      Some(@core.Rect::new(x=2.0, y=3.0, width=16.0, height=16.0))
    } else {
      None
    },
  }
}

///|
fn test_path() -> @core.PathSpec {
  @core.PathSpec::{
    verbs: [
      @core.PathVerb::MoveTo(@core.Point::new(x=0.0, y=0.0)),
      @core.PathVerb::LineTo(@core.Point::new(x=40.0, y=0.0)),
      @core.PathVerb::QuadTo(
        @core.Point::new(x=50.0, y=20.0),
        @core.Point::new(x=40.0, y=40.0),
      ),
      @core.PathVerb::CubicTo(
        @core.Point::new(x=30.0, y=50.0),
        @core.Point::new(x=10.0, y=50.0),
        @core.Point::new(x=0.0, y=40.0),
      ),
      @core.PathVerb::Close,
    ],
    fill: Some(@core.Brush::Solid(test_color(0.4))),
    stroke: Some(test_stops_brush(@core.GradientAxis::ConicAxis(
      @core.Point::new(x=20.0, y=20.0),
      45.0,
    ))),
    stroke_width: 2.0,
    stroke_cap: Some(@core.StrokeCap::Round),
    stroke_join: Some(@core.StrokeJoin::Bevel),
  }
}

///|
fn test_shadow() -> @core.ShadowSpec {
  @core.ShadowSpec::{
    rect: test_rounded(),
    color: test_color(0.0).with_alpha(0.35),
    offset: @core.Point::new(x=0.0, y=4.0),
    blur_radius: 12.0,
    spread: 1.0,
  }
}

///|
fn test_layer(mask : @core.LayerMask) -> @core.LayerSpec {
  @core.LayerSpec::{
    opacity: 0.75,
    blend_mode: @core.BlendMode::Multiply,
    mask,
    offscreen: true,
  }
}

///|
fn test_transform() -> @core.Transform2D {
  @core.Transform2D::{
    a: 1.0,
    b: 0.0,
    c: 0.0,
    d: 1.0,
    tx: 12.0,
    ty: -4.0,
  }
}

///|
fn every_draw_command() -> Array[@core.DrawCommand] {
  [
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::FillRect(test_rect(), test_color(0.6)),
    @core.DrawCommand::StrokeRect(test_rect(), test_color(0.2), 2.0),
    @core.DrawCommand::FillRoundedRect(test_rounded(), test_color(0.9)),
    @core.DrawCommand::StrokeRoundedRect(test_rounded(), test_color(0.1), 1.5),
    @core.DrawCommand::FillRoundedRectBrush(
      test_rounded(),
      @core.Brush::Solid(test_color(0.55)),
    ),
    @core.DrawCommand::FillRoundedRectBrush(test_rounded(), test_linear_brush()),
    @core.DrawCommand::FillRoundedRectBrush(test_rounded(), test_radial_brush()),
    @core.DrawCommand::FillRoundedRectBrush(
      test_rounded(),
      test_stops_brush(@core.GradientAxis::LinearAxis(
        @core.Point::new(x=0.0, y=0.0),
        @core.Point::new(x=1.0, y=1.0),
      )),
    ),
    @core.DrawCommand::FillRoundedRectBrush(
      test_rounded(),
      test_stops_brush(@core.GradientAxis::RadialAxis(
        @core.Point::new(x=50.0, y=50.0),
        90.0,
      )),
    ),
    @core.DrawCommand::StrokeRoundedRectBrush(
      test_rounded(),
      test_stops_brush(@core.GradientAxis::ConicAxis(
        @core.Point::new(x=10.0, y=10.0),
        30.0,
      )),
      3.0,
    ),
    @core.DrawCommand::DrawShadow(test_shadow()),
    @core.DrawCommand::DrawText(test_text_run()),
    @core.DrawCommand::DrawImage(test_image_run(true)),
    @core.DrawCommand::DrawImage(test_image_run(false)),
    @core.DrawCommand::PushClip(test_rect()),
    @core.DrawCommand::PopClip,
    @core.DrawCommand::PushRoundedClip(test_rounded()),
    @core.DrawCommand::PopRoundedClip,
    @core.DrawCommand::PushPathClip(test_path()),
    @core.DrawCommand::PopPathClip,
    @core.DrawCommand::PushTransform(test_transform()),
    @core.DrawCommand::PopTransform,
    @core.DrawCommand::PushOpacity(0.5),
    @core.DrawCommand::PopOpacity,
    @core.DrawCommand::PushLayer(test_layer(@core.LayerMask::NoMask)),
    @core.DrawCommand::PushLayer(
      test_layer(@core.LayerMask::RectMask(test_rect())),
    ),
    @core.DrawCommand::PushLayer(
      test_layer(@core.LayerMask::RoundedMask(test_rounded())),
    ),
    @core.DrawCommand::PopLayer,
    @core.DrawCommand::BeginRetainedLayer(
      @core.RetainedLayerSpec::{
        key: "sidebar",
        frame: test_rect(),
        content_revision: 7,
        scale_factor: 2.0,
      },
    ),
    @core.DrawCommand::EndRetainedLayer("sidebar"),
    @core.DrawCommand::PushFilter(@core.FilterEffect::Blur(4.0)),
    @core.DrawCommand::PushFilter(@core.FilterEffect::Saturate(1.5)),
    @core.DrawCommand::PushFilter(@core.FilterEffect::Brightness(0.9)),
    @core.DrawCommand::PushFilter(@core.FilterEffect::Contrast(1.1)),
    @core.DrawCommand::PushFilter(
      @core.FilterEffect::ColorMatrix([
        1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0,
        0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0,
      ]),
    ),
    @core.DrawCommand::PopFilter,
    @core.DrawCommand::DrawPath(test_path()),
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::{
        name: "grain",
        frame: test_rect(),
        uniforms: [0.5, 12.0, 3.0],
        fallback: @core.Brush::Solid(test_color(0.7)),
      },
    ),
  ]
}

///|
test "frame round trip covers every draw command variant" {
  let commands = every_draw_command()
  let clear_color = @core.Color::rgba(r=0.12, g=0.18, b=0.22, a=1.0)
  let frame = @core.DrawFrame::new(
    commands~,
    damage=@core.DamageRegion::empty(),
    clear_color~,
  )
  let encoded = @protocol.encode_frame(frame)
  let payload = match @protocol.decode_frame_payload(encoded) {
    Some(payload) => payload
    None => abort("valid full bridge frame failed to decode")
  }
  assert_eq(payload.clear_color, clear_color)
  assert_eq(payload.unsupported, 0)
  assert_eq(payload.commands.length(), commands.length())
  assert_eq(payload.commands, commands)
  // `decode_frame` keeps its command-only contract.
  let command_only = match @protocol.decode_frame(encoded) {
    Some(commands) => commands
    None => abort("command-only decode failed")
  }
  assert_eq(command_only, commands)
}

///|
test "each draw command survives its own round trip" {
  for command in every_draw_command() {
    let frame = @core.DrawFrame::new(
      commands=[command],
      damage=@core.DamageRegion::empty(),
    )
    let decoded = match @protocol.decode_frame(@protocol.encode_frame(frame)) {
      Some(commands) => commands
      None => abort("single-command frame failed to decode")
    }
    assert_eq(decoded.length(), 1)
    assert_eq(decoded[0], command)
  }
}

///|
test "frame decoder accepts the original v1 text shape" {
  let legacy = "{\"version\":1,\"commands\":[{\"kind\":\"text\",\"text\":\"hi\",\"rect\":{\"x\":0,\"y\":0,\"width\":20,\"height\":10},\"font\":{\"family\":\"Arial\",\"size\":14,\"weight\":400,\"italic\":true,\"line_height\":null,\"letter_spacing\":null},\"color\":{\"r\":0,\"g\":0,\"b\":0,\"a\":1},\"align\":\"TextStart\",\"stroke_color\":null,\"stroke_width\":0}]}"
  let commands = match @protocol.decode_frame(legacy) {
    Some(commands) => commands
    None => abort("legacy v1 text frame failed to decode")
  }
  assert_eq(commands.length(), 1)
  match commands[0] {
    @core.DrawCommand::DrawText(run) => {
      assert_eq(run.text, "hi")
      assert_eq(run.font.style, @core.FontStyle::Italic)
      assert_eq(
        run.font.families.families[0],
        @core.FontFamily::Name("Arial"),
      )
    }
    _ => abort("expected DrawText")
  }
}

///|
test "frame decoder rejects corruption and old ABI" {
  assert_eq(@protocol.decode_frame("not json"), None)
  assert_eq(@protocol.decode_frame("{\"version\":0,\"commands\":[]}"), None)
  assert_eq(@protocol.decode_frame("{\"version\":1}"), None)
  assert_eq(
    @protocol.decode_frame("{\"version\":1,\"commands\":[{\"kind\":\"text\"}]}"),
    None,
  )
  assert_eq(
    @protocol.decode_frame(
      "{\"version\":1,\"commands\":[{\"kind\":\"draw_image\",\"run\":{}}]}",
    ),
    None,
  )
}

///|
fn encode_some(event : @core.AppEvent) -> String {
  match @protocol.encode_event(event) {
    Some(text) => text
    None => abort("event failed to encode")
  }
}

///|
fn assert_event_round_trip(event : @core.AppEvent) -> Unit {
  let encoded = encode_some(event)
  if @protocol.decode_event(encoded) != Some(event) {
    abort("event failed to round trip")
  }
}

///|
test "event round trip covers every app event variant" {
  let range = @core.TextRange::new(start=2, end=5)
  let composition_cursor = @core.TextRange::new(start=1, end=1)
  assert_event_round_trip(
    @core.AppEvent::FrameTick(
      @core.Frame::new(time_ms=1234.0, delta_ms=16.0),
    ),
  )
  assert_event_round_trip(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=30.0, y=40.0),
        phase=@core.PointerPhase::Down,
        button=1,
        wheel_delta=@core.Point::new(x=1.0, y=2.0),
        modifiers=@core.KeyModifiers::new(shift=true, meta=true),
        id=2,
        pressure=0.5,
      ),
    ),
  )
  assert_event_round_trip(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="a",
        code="KeyA",
        text=Some("a"),
        pressed=true,
        repeat=false,
      ),
    ),
  )
  assert_event_round_trip(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("你好")),
  )
  assert_event_round_trip(
    @core.AppEvent::TextInput(
      @core.TextInputEvent::ReplaceText(range, "replacement"),
    ),
  )
  assert_event_round_trip(
    @core.AppEvent::TextInput(@core.TextInputEvent::SetSelection(range)),
  )
  assert_event_round_trip(
    @core.AppEvent::TextInput(@core.TextInputEvent::CompositionStart),
  )
  assert_event_round_trip(
    @core.AppEvent::TextInput(
      @core.TextInputEvent::CompositionUpdate(
        @core.CompositionUpdate::new(
          text="にほん",
          cursor=Some(composition_cursor),
        ),
      ),
    ),
  )
  assert_event_round_trip(
    @core.AppEvent::TextInput(
      @core.TextInputEvent::CompositionUpdate(
        @core.CompositionUpdate::new(text="日本"),
      ),
    ),
  )
  assert_event_round_trip(
    @core.AppEvent::TextInput(
      @core.TextInputEvent::CompositionEnd("日本"),
    ),
  )
  assert_event_round_trip(
    @core.AppEvent::TextInput(@core.TextInputEvent::DeleteRange(range)),
  )
  assert_event_round_trip(
    @core.AppEvent::TextInput(
      @core.TextInputEvent::DeleteSurrounding(1, 2),
    ),
  )
  assert_event_round_trip(
    @core.AppEvent::DragDrop(
      @core.DragDropEvent::new(
        phase=@core.DragDropPhase::Entered,
        paths=["/tmp/a.png"],
        position=Some(@core.Point::new(x=4.0, y=5.0)),
      ),
    ),
  )
  assert_event_round_trip(
    @core.AppEvent::DragDrop(
      @core.DragDropEvent::new(phase=@core.DragDropPhase::Moved),
    ),
  )
  assert_event_round_trip(
    @core.AppEvent::DragDrop(
      @core.DragDropEvent::new(
        phase=@core.DragDropPhase::Dropped,
        paths=["/tmp/a.png", "/tmp/b.png"],
      ),
    ),
  )
  assert_event_round_trip(
    @core.AppEvent::DragDrop(
      @core.DragDropEvent::new(phase=@core.DragDropPhase::Left),
    ),
  )
  assert_event_round_trip(
    @core.AppEvent::PlatformView(
      "composer",
      @core.PlatformViewEvent::Named(
        name="renderer_status",
        value="ready",
        detail="metal",
        flag=true,
      ),
    ),
  )
  assert_event_round_trip(
    @core.AppEvent::Resize(@core.Size::new(width=640.0, height=480.0)),
  )
  for reason in [
    @core.RedrawReason::Initial,
    @core.RedrawReason::Input,
    @core.RedrawReason::Resize,
    @core.RedrawReason::Explicit,
  ] {
    assert_event_round_trip(@core.AppEvent::Redraw(reason))
  }
  assert_event_round_trip(
    @core.AppEvent::Gesture(
      @core.GestureEvent::new(
        kind=@core.GestureKind::Pinch,
        phase=@core.GesturePhase::Moved,
        scale_delta=0.05,
        rotation_delta=0.1,
        pan_delta=@core.Point::new(x=2.0, y=-3.0),
        pressure=0.6,
        pressure_stage=2,
      ),
    ),
  )
  for kind in [
    @core.GestureKind::Rotate,
    @core.GestureKind::Pan,
    @core.GestureKind::DoubleTap,
    @core.GestureKind::Pressure,
  ] {
    assert_event_round_trip(
      @core.AppEvent::Gesture(
        @core.GestureEvent::new(kind~, phase=@core.GesturePhase::Started),
      ),
    )
  }
  assert_event_round_trip(@core.AppEvent::CloseRequested)
  assert_eq(
    @protocol.decode_event("{\"kind\":\"frame_tick\"}"),
    None,
  )
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
