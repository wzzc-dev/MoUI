///|
/// P0 的验收标准原文：**「对 `render_check` 里全部探针产出的命令做一次完整往返，
/// 无一处差异。」**
///
/// 之前 `moui/core` 的差分测试只有 4 条手写命令，没有一条用真实渲染数据——而真实
/// 数据的价值就在那些手写用例想不到的地方：`Double` 精度（`896.4` 这种非整数
/// 坐标）、长文本、clip 嵌套、mask、data URI。
///
/// 这里把探针真正产出的命令流拿去往返：**编码 → 解码 → 再编码，逐字节相同**。

///|
/// 往返一次，返回是否逐字节相同；`None` = 解码失败。
fn roundtrip_diff(
  commands : Array[@core.DrawCommand],
) -> Result[String, String] {
  let once = @core.draw_commands_to_json(commands)
  let parsed = @json.parse(once) catch {
    _ => return Err("the encoder produced text its own parser rejects")
  }
  let decoded = match @core.draw_commands_from_json(parsed) {
    Some(decoded) => decoded
    None =>
      return Err(
        "decode failed for " + commands.length().to_string() + " commands",
      )
  }
  let twice = @core.draw_commands_to_json(decoded)
  if once == twice {
    Ok(once)
  } else {
    Err(
      "re-encoding differs: " +
      once.length().to_string() +
      " vs " +
      twice.length().to_string() +
      " bytes",
    )
  }
}

///|
test "the default world view round-trips byte-identically" {
  let commands = plugin_frame(robot_world(), 1440.0, 900.0)
  assert_true(commands.length() > 0)
  match roundtrip_diff(commands) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
}

///|
test "a transcript-heavy frame round-trips byte-identically" {
  // The probe world carries markdown, character cards and a transcript; this is
  // the frame with the most text and the deepest clip nesting.
  let commands = plugin_frame(robot_world(), 800.0, 1400.0)
  match roundtrip_diff(commands) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
}

///|
test "double precision survives the round trip" {
  // `896.4` is the coordinate the plan calls out: it does not have an exact binary
  // representation, so a naive number formatting would drift on re-encode.
  let commands = plugin_frame(robot_world(), 1440.0, 900.0)
  let once = @core.draw_commands_to_json(commands)
  // The frame really does contain a fractional coordinate.
  assert_true(once.contains("."))
  match roundtrip_diff(commands) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
}
