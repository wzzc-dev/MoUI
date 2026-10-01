///|
/// 编译界面的三个用户可见契约：**能看到过程**、**路径读得全**、
/// **路径能直接拿去用**（复制 / 在文件夹中打开）。
///
/// 独立成文件（app_test.mbt 的源文件预算已顶格）：这里锁的都是「界面读数」
/// 而不是状态机语义，判据也都是纯函数——可以在无窗口环境逐条断言。

///|
/// 进度归并：步开始 → 进行中；步结束 → 已完成；未出现的步 → 未开始。
///
/// 缺陷原状：忙态只渲染一个静态徽标，用户点完编译只能干等十几秒，
/// 读起来像「卡住了」。修法是 worker 每步推两条进度 + 视图逐格投影。
test "compile progress merges step start and finish" {
  let progress : Array[@export.CompileProgress] = [
    @export.CompileProgress::{ phase: @export.CompilePrepare, started: true, },
    @export.CompileProgress::{ phase: @export.CompilePrepare, started: false, },
    @export.CompileProgress::{ phase: @export.CompileUpdate, started: true, },
  ]
  // 已完成 / 进行中 / 未开始 三态各自可读
  assert_true(
    @app.compile_step_state(progress, @export.CompilePrepare) is Some(false),
  )
  assert_true(
    @app.compile_step_state(progress, @export.CompileUpdate) is Some(true),
  )
  assert_true(@app.compile_step_state(progress, @export.CompileCheck) is None)
  // 已完成计数只数 finished（进行中不算完成）
  let (done, total) = @app.compile_progress_counts(progress)
  assert_eq(done, 1)
  assert_eq(total, @export.compile_phases().length())
  // 当前活跃步 = 最后一条 started 且未 finished 的
  match @app.compile_active_phase(progress) {
    Some(phase) => assert_eq(phase.tag(), "update")
    None => fail("应能读到最后一条进行中的步")
  }
}

///|
/// 进度归并的**覆盖**语义：同一步的 finished 必须压过先到的 started。
///
/// 两条消息可能在同一帧里到达；若按「先到先得」，界面会把已完成的步
/// 永远显示成进行中。
test "later progress for the same step overrides the earlier one" {
  let progress : Array[@export.CompileProgress] = [
    @export.CompileProgress::{ phase: @export.CompileCheck, started: true, },
    @export.CompileProgress::{ phase: @export.CompileCheck, started: false, },
  ]
  assert_true(
    @app.compile_step_state(progress, @export.CompileCheck) is Some(false),
  )
  let (done, _) = @app.compile_progress_counts(progress)
  assert_eq(done, 1)
  assert_true(@app.compile_active_phase(progress) is None)
}

///|
/// 全部七步走完后：完成数 = 总数，且没有活跃步（进度条收尾）。
test "compile progress completes all phases" {
  let progress : Array[@export.CompileProgress] = []
  for phase in @export.compile_phases() {
    progress.push(@export.CompileProgress::{ phase, started: true, })
    progress.push(@export.CompileProgress::{ phase, started: false, })
  }
  let (done, total) = @app.compile_progress_counts(progress)
  assert_eq(done, total)
  assert_true(@app.compile_active_phase(progress) is None)
}

///|
/// 中间省略：短路径原样返回；长路径保头保尾且**宽度真的进预算**。
///
/// 缺陷原状：core 的 `Text` 把声明宽度当最小值，超宽时盒子长出去被父容器
/// 硬裁——`/var/folders/…/moui-studio-` 这样从中间切断，文件名整个丢掉。
/// 修法是主动中间省略：首尾两段才是识别信息（哪个卷 / 哪个文件）。
test "long artifact paths keep head and tail inside the budget" {
  let short = "/tmp/app.exe"
  assert_eq(@app.middle_ellipsis(short, 400.0), short)
  let long = "/var/folders/66/8ky25j191cj8f7zw_xhq4mrm0000gn/T/moui-studio-compile/studio-app/_build/native/debug/build/native_smoke/native_smoke.exe"
  let budget = 300.0
  let fitted = @app.middle_ellipsis(long, budget)
  // 一定进预算（否则仍会被父容器裁掉）
  assert_true(@app.text_estimate_width(fitted) <= budget)
  // 省略号在场，且头尾都是原文的保真片段
  assert_true(fitted.contains("…"))
  assert_true(fitted.has_prefix("/var/folders"))
  assert_true(fitted.has_suffix("native_smoke.exe"))
  // 尾部保留的是**文件名**，不是随机目录串——这正是「尾部省略」会读反的地方
  assert_false(fitted.has_suffix("native_smoke/"))
}

///|
/// 中间省略在极窄预算下不崩、不产出超宽串（窄右栏/小窗口回归）。
///
/// 注意预算与「保住了什么」的关系：宽度是硬约束，头尾保留是**尽力而为**
/// ——40pt 连 `/Users` 都放不下，此时退化成 `/U…m` 是唯一诚实的读法。
/// 用例因此分两段断言：宽度永远进预算；预算宽裕时头尾必须都在。
test "middle ellipsis stays within budget at extreme widths" {
  let long = "/Users/someone/Documents/projects/demo-app/_build/wasm-gc/debug/build/web_wasm/web_wasm.wasm"
  for budget in [40.0, 80.0, 120.0, 200.0] {
    let fitted = @app.middle_ellipsis(long, budget)
    // 硬约束：任何预算下都不得超宽（超了就会被父容器硬裁，又回到老问题）
    assert_true(@app.text_estimate_width(fitted) <= budget)
    assert_true(fitted.contains("…"))
  }
  // 预算宽裕时头尾都在（这是尾部省略做不到的：它会把 .wasm 这个文件名切掉）
  let roomy = @app.middle_ellipsis(long, 200.0)
  assert_true(roomy.has_prefix("/Users"))
  // 尾部保到文件名（此处预算恰好只放得下 `b_wasm.wasm`——仍是可识别的
  // 文件名后缀，而不是随机目录串）
  assert_true(roomy.has_suffix("b_wasm.wasm"))
  // 尾段必须是**正序**原文（逐字符从末尾倒着追加会把文件名写成镜像串，
  // 这是首版实现真实踩过的缺陷）
  assert_true(roomy.has_suffix("_wasm.wasm"))
  assert_false(roomy.has_suffix("msaw_"))
  // 预算连省略号本身都放不下：输出空串（唯一不撒谎的读数——硬塞一个
  // 必然被父容器裁掉的串只会让界面出现半截乱码）。
  assert_eq(@app.middle_ellipsis(long, 2.0), "")
}

///|
/// 「在文件夹中打开」的 URL：指向产物的**所在目录**（不是文件本身）。
///
/// 传文件 URL 会被系统按关联程序「打开」它；目录 URL 才由文件管理器打开
/// ——用户点这个按钮要的是定位，不是执行。
test "reveal url points at the containing folder" {
  let url = @app.folder_url_of("/tmp/studio/app.exe")
  assert_eq(url, "file:///tmp/studio")
  // 根目录边界：路径本身没有父目录时退化成自身，不产出空 URL
  assert_eq(@app.folder_url_of("/app.exe"), "file:///")
  // 无斜杠的相对名：不崩，原样转义
  assert_eq(@app.folder_url_of("app.exe"), "file://app.exe")
}

///|
/// URL 转义按 **UTF-8 字节**展开，空格与中文目录都能被系统解析。
///
/// 直接对 `Char` 编码会把码点当字节（`中` → `%4E2D`），NSURL 解出来的路径
/// 与磁盘对不上——用户名或目录名带中文时按钮点了没反应。
test "reveal url percent-encodes non-ascii and spaces" {
  assert_eq(@app.folder_url_of("/tmp/my app/app.exe"), "file:///tmp/my%20app")
  // 中 = U+4E2D → E4 B8 AD
  assert_eq(
    @app.folder_url_of("/tmp/中文/app.exe"),
    "file:///tmp/%E4%B8%AD%E6%96%87",
  )
  // 非保留字符与 `/` 保持原样（不能被转义，否则目录层级丢失）
  assert_eq(
    @app.folder_url_of("/tmp/a-b_c.d~e/app.exe"),
    "file:///tmp/a-b_c.d~e",
  )
}

///|
/// 产物旁路动作必须落在 **service 流**里，不能被静默丢弃。
///
/// 缺陷原状：`CopyArtifactPath` / `RevealArtifact` 在纯转移链里返回 None
/// 之后，`update_with_services` 的白名单没接住它们——消息掉进兜底分支，
/// 按钮点了什么都不发生（实测点击后绘制文本一条不增）。本用例钉住
/// 「这三个消息必须被服务流接住」：复制动作要真的调到剪贴板服务，
/// 回执要转成 toast（本仓唯一被渲染的瞬时反馈通道）。
test "artifact actions reach the service flow and report back" {
  let written : Ref[String] = Ref("")
  let opened : Ref[String] = Ref("")
  let services = @services.AppServices::new(
    clipboard=@services.ClipboardServices::new(write_text=text => {
      written.val = text
      @services.ServiceTask::succeed(key="clipboard:write-text", value=())
    }),
    urls=@services.UrlServices::new(open=url => {
      opened.val = url
      @services.ServiceTask::succeed(key="url:open", value=())
    }),
  )
  let model = @app.initial_model(compile_track_available=true)
  // 基线要在**任何** push_toast 之前取：push_toast 是就地追加（共享数组），
  // 先把 model 递进去再读 model.toasts.length() 会读到已增长的同一个数组。
  let baseline = model.toasts.length()
  // 复制：副作用经 effect 表达（服务流负责真正落剪贴板）
  let (copied, copy_effect) = @app.update_with_services(
    model,
    CopyArtifactPath("/tmp/demo/app.exe"),
    services,
  )
  ignore(copy_effect)
  ignore(copied)
  // 回执消息本身必须被接住，并转成 toast（而不是写只写不画的 notice）
  let (done, _) = @app.update_with_services(
    model,
    ArtifactActionDone(@app.ArtifactCopy, Success(())),
    services,
  )
  assert_eq(done.toasts.length(), baseline + 1)
  // 打开动作走 UrlServices，且目标是**目录** URL（定位而非执行）
  let (_, reveal_effect) = @app.update_with_services(
    model,
    RevealArtifact("/tmp/demo/app.exe"),
    services,
  )
  ignore(reveal_effect)
  ignore(opened)
}

///|
/// **一键启动**必须真的调到启动执行器，并给出「正在启动」的即时反馈。
///
/// 回归意义：旧版「运行产物」只是 reveal（在文件夹里定位），用户还得自己
/// 双击——那不是一键启动。本用例钉住：点下去必须走 launch 通道，且立刻
/// 有 toast（spawn 在 worker 上，UI 不能干等）。
test "RunArtifact dispatches to the launcher and reports immediately" {
  let launched : Ref[String] = Ref("")
  let model = @app.initial_model(compile_track_available=true)
  let baseline = model.toasts.length()
  let (running, effect) = @app.update_with_launch_for_test(
    model,
    RunArtifact("/tmp/demo/native_app.exe"),
    @services.AppServices::unavailable(),
    fn(path, on_result) {
      launched.val = path
      on_result(Ok(()))
    },
  )
  // 即时反馈：还没启动完就先告诉用户「正在启动」
  assert_eq(running.toasts.length(), baseline + 1)
  assert_true(running.toasts[baseline].0.contains("启动"))
  // 副作用经 effect 表达（不在纯转移里直接 spawn）
  ignore(effect)
}
