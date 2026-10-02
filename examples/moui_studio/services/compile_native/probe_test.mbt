///|
async test "probe real shape moon version" {
  let (out_reader, out_w) = @process.read_from_process()
  let (err_reader, err_w) = @process.read_from_process()
  let out_box = Ref("")
  let err_box = Ref("")
  let code_box = Ref(0)
  @async.with_task_group(async fn(group) {
    group.spawn_bg(async fn() {
      defer out_reader.close()
      out_box.val = out_reader.read_all().text() catch { _ => "" }
    })
    group.spawn_bg(async fn() {
      defer err_reader.close()
      err_box.val = err_reader.read_all().text() catch { _ => "" }
    })
    let child = @process.spawn(
      group,
      "/Users/zc/.moon/bin/moon",
      ["--version"],
      stdout=out_w,
      stderr=err_w,
      cwd="/tmp",
      no_console_window=true,
    )
    code_box.val = child.wait()
  })
  inspect(code_box.val, content="0")
  assert_true(out_box.val.contains("moon") || err_box.val.contains("moon"))
}
