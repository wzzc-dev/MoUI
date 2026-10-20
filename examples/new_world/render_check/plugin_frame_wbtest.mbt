///|
/// P5.3 的帧适配层：给定插件矩形，必须产出该矩形下的绘制命令。
///
/// 这条不需要 wasm 实例——它断言的正是 `plugin_init(w,h)` 之后宿主应当看到的
/// 东西。真正的实例化在 RFC 0007 之后，但「矩形换了，帧必须跟着换」这件事现在
/// 就能钉死。

///|
test "the frame follows the rectangle the host hands over" {
  let model = robot_world()
  let wide = plugin_frame(model, 1600.0, 900.0)
  let narrow = plugin_frame(model, 600.0, 900.0)
  // Both produce a real frame…
  assert_true(wide.length() > 0)
  assert_true(narrow.length() > 0)
  // …and a different width must not yield an identical frame, or the plugin is
  // ignoring the rectangle it was given (the "letterbox / clipped" failure).
  assert_true(wide.length() != narrow.length() || wide != narrow)
}

///|
test "the encoded frame round-trips through the host codec" {
  // The plugin encodes; the host decodes. Those two halves live in different
  // packages and different instances, so byte-identity is the contract.
  let model = robot_world()
  let json = plugin_frame_json(model, 1280.0, 720.0)
  assert_true(json.length() > 0)
  let parsed = @json.parse(json)
  let decoded = match @core.draw_commands_from_json(parsed) {
    Some(commands) => commands
    None => fail("host must be able to decode what the plugin encoded")
  }
  assert_true(decoded.length() > 0)
  // Re-encoding the decoded frame must be stable, otherwise a host that forwards
  // a frame would corrupt it.
  assert_eq(@core.draw_commands_to_json(decoded), json)
}

///|
test "a zero-size rectangle still yields a valid frame" {
  // Before first layout the host may hand over an empty rect; the plugin must
  // produce *something* decodable rather than crash or emit garbage.
  let model = robot_world()
  let json = plugin_frame_json(model, 0.0, 0.0)
  let parsed = @json.parse(json)
  // An empty rect can legitimately produce zero draw commands; what matters is
  // that the host can still decode the frame.
  let decoded = match @core.draw_commands_from_json(parsed) {
    Some(commands) => commands
    None => fail("a zero-size frame must still decode")
  }
  assert_true(decoded.length() >= 0)
}
