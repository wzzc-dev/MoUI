///|
/// 预览 harness 生成器测试:生成物要能直接 moon run——
/// moon.pkg 的用户包路径/别名、main 的 program 调用、哨兵行、
/// 双数组(绘制命令 + 语义树)都必须在文本里可断言。

///|
test "harness 引用用户程序包并携带哨兵与双数组" {
  let files = preview_harness_files("examples/counter", "app")
  // 两份文件:moon.pkg + main.mbt
  assert_eq(files.length(), 2)
  assert_eq(files[0].0, "moon.pkg")
  assert_eq(files[1].0, "main.mbt")
  // moon.pkg:用户包以 @user_app 别名导入(模块名 + 包相对路径)
  let pkg = files[0].1
  assert_true(pkg.contains("\"examples/counter/app\" @user_app"), msg=pkg)
  assert_true(pkg.contains("wzzc-dev/moui/runtime"))
  assert_true(pkg.contains("wzzc-dev/moui/core"))
  assert_true(pkg.contains("moonbitlang/core/json"))
  assert_true(pkg.contains("supported_targets = \"native\""))
  // main:program 入口、舞台尺寸、双数组、哨兵行
  let main = files[1].1
  assert_true(main.contains("@user_app.program()"), msg=main)
  assert_true(main.contains("new_program_with_dimensions"))
  assert_true(main.contains("draw_commands()"))
  assert_true(main.contains("read_semantics()"))
  assert_true(main.contains("to_json()"))
  assert_true(main.contains("__STUDIO_PREVIEW_V1__"))
  // 版本戳写入文件头
  assert_true(main.contains("harness v1"))
}

///|
test "harness 根包情形:program_rel 为空时路径 = 模块名" {
  let files = preview_harness_files("a/b", "")
  assert_true(files[0].1.contains("\"a/b\" @user_app"), msg=files[0].1)
}

///|
test "哨兵与版本常量同源" {
  assert_eq(
    PREVIEW_SENTINEL,
    "__STUDIO_PREVIEW_V" + PREVIEW_HARNESS_VERSION.to_string() + "__",
  )
}
