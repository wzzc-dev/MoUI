///|
/// 构建服务的纯逻辑测试:命令序列、输出截断、kind 标签。
/// 真实 moon 进程链路在 M1-M3 的预览/运行冒烟中覆盖(与 compile_native
/// 的 runner_test 同策略:纯逻辑单测 + 真工具链冒烟分层)。

///|
test "build_commands 按 kind 生成 moon 命令" {
  let web = build_commands(BkWebPreview, "web_wasm")
  assert_eq(web.length(), 1)
  assert_eq(web[0][0], moon_bin())
  assert_eq(web[0][1], "build")
  assert_eq(web[0][2], "web_wasm")
  assert_eq(web[0][4], "wasm-gc")
  let native = build_commands(BkRunNative, "macos_skia")
  assert_eq(native[0][2], "macos_skia")
  assert_eq(native[0][4], "native")
  // 模式一是 moon run(harness 直接执行出帧,不是 build)
  let frame = build_commands(BkFramePreview, ".studio/preview")
  assert_eq(frame[0][1], "run")
  assert_eq(frame[0][2], ".studio/preview")
}

///|
test "tail_output 截断超大日志保留尾部" {
  let small = "ok\n"
  assert_eq(tail_output(small), small)
  let big = String::make(BUILD_OUTPUT_LIMIT + 100, 'x')
  let trimmed = tail_output(big)
  assert_eq(trimmed.length(), BUILD_OUTPUT_LIMIT)
}

///|
test "BuildKind::tag 稳定 token" {
  assert_eq(BkFramePreview.tag(), "frame-preview")
  assert_eq(BkWebPreview.tag(), "web-preview")
  assert_eq(BkRunNative.tag(), "run-native")
}
