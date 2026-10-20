///|
/// P2.5 的验收条件原文：**「单帧编解码 + 传输在 1 ms 内（用 P0 的真实命令数据）」**。
///
/// 之前没有任何一条测试测过这个数。用真实帧而不是合成数据，因为编码开销与命令
/// 数量、文本长度直接相关——合成一个 3 条命令的帧测出来的数字没有意义。
///
/// 门控：`MOUI_CODEC_TIMING=1`。默认不跑，避免在慢机器/CI 上抖动。

///|
fn codec_timing_enabled() -> Bool {
  @env.get_env_var("MOUI_CODEC_TIMING") == Some("1")
}

///|
test "a real frame encodes and decodes within 1 ms" {
  if !codec_timing_enabled() {
    return
  }
  let commands = plugin_frame(robot_world(), 1440.0, 900.0)
  let iterations = 50
  // Warm up: the first encode allocates buffers and pays for any lazy setup.
  let _ = @core.draw_commands_to_json(commands)
  let _ = @core.draw_commands_from_json(
    @json.parse(@core.draw_commands_to_json(commands)),
  )
  let start = @bench.monotonic_clock_start()
  for _ in 0..<iterations {
    let text = @core.draw_commands_to_json(commands)
    let parsed = @json.parse(text)
    let _ = @core.draw_commands_from_json(parsed)
  }
  let total_us = @bench.monotonic_clock_end(start)
  let per_frame_us = total_us / iterations.to_double()
  println(
    "codec.roundtrip_us_per_frame=\{per_frame_us} commands=\{commands.length()}",
  )
  assert_true(per_frame_us < 1000.0)
}
