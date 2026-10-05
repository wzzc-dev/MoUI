///|
/// 构建执行器的会话级测试(空闲取消 = 空操作;worker 循环的真进程链路
/// 在 M1-M3 预览/运行冒烟覆盖)。

///|
test "BuildOwner 入队与取消不炸(空闲取消 = 空操作)" {
  let owner = BuildOwner::new()
  build_cancel(owner)
  let ran : Ref[Bool] = Ref(false)
  build_submit(owner, @build.BuildRequest::{
    kind: BkFramePreview,
    root: "/nonexistent",
    entry_rel: ".studio/preview",
    on_result: _ => ran.val = true,
  })
  // 不启动 worker 循环,队列元素等待;取消空闲 owner 是空操作
  assert_false(ran.val)
}
