///|
/// notice 漏斗与入口补齐回归：
/// 1) `notice` 此前**只写不画**——保存/打开/导出成败、解析失败、预算超限、
///    Web 端编译轨不可达十几条路径全部静默。所有写入现在收口到
///    `with_notice`（写字段 + 补推 toast），本文件钉住「成功/失败必须可见」。
/// 2) 模板命令（drill/store）与 `studio.file.new` 此前有处理器无表项——
///    「口算训练营 / 班级小卖部」（提交数据闸门核心教案）没有任何 UI 入口。
///    本文件钉住「命令表与处理器成对出现」。
/// 3) Web 端导出目录「选择」返回文件名列表，25 个文件全部写不进去——
///    现在与编译轨同一口径：`export_available=false` 时显式声明不可用。

///|
fn contains_id(commands : Array[@app.StudioCommand], id : String) -> Bool {
  for command in commands {
    if command.id == id {
      return true
    }
  }
  false
}

///|
test "SetNotice routes through the toast funnel" {
  let model = @app.initial_model()
  assert_eq(model.toasts.length(), 0)
  // 空串是 settings 写入的哑回调：只清字段，不弹 toast
  let (cleared, _) = @app.update_pure(model, SetNotice(""))
  assert_eq(cleared.toasts.length(), 0)
  // 非空 notice 必须同时可见（toast 是唯一被渲染的瞬时通道）
  let (notified, _) = @app.update_pure(model, SetNotice("导出完成"))
  assert_eq(notified.toasts.length(), 1)
  assert_eq(notified.notice, "导出完成")
}

///|
test "save and open failures surface a toast" {
  let services = @services.AppServices::new()
  // 每个场景用**全新模型**：push_toast 是就地追加（共享数组），同一基线
  // 模型反复派发会把各场景的 toast 计到一起（compile_ui_test 同款告诫）。
  let pick_failed = @app.update_with_services(
      @app.initial_model(),
      SavePathPicked(
        Failure(@services.ServiceError::unavailable("对话框不可用")),
      ),
      services,
    ).0
  assert_eq(pick_failed.toasts.length(), 1)
  let write_failed = @app.update_with_services(
      @app.initial_model(),
      SaveCompleted(
        Failure(@services.ServiceError::unavailable("磁盘只读")),
      ),
      services,
    ).0
  assert_eq(write_failed.toasts.length(), 1)
  let open_failed = @app.update_with_services(
      @app.initial_model(),
      OpenReadCompleted(Success("不是合法的项目 JSON")),
      services,
    ).0
  assert_eq(open_failed.toasts.length(), 1)
  // M6③：旧格式读取失败是结构化报错，指向迁移器口径而非笼统「打开失败」
  assert_true(open_failed.notice.contains("迁移器"))
}

///|
test "save success toasts once and aligns the saved baseline" {
  let services = @services.AppServices::new()
  let model = @app.initial_model()
  let (saved, _) = @app.update_with_services(
    model,
    SaveCompleted(Success(())),
    services,
  )
  assert_eq(saved.toasts.length(), 1)
  // 基线对齐当前程序：脏标由 program() 的集中包装清除
  assert_eq(saved.saved_encoding, @codec.encode_program(saved.program))
}

///|
test "export on web declares unavailability instead of failing silently" {
  // Web 入口不传 export_available（默认 false）
  let model = @app.initial_model()
  let (next, effect) = @app.update_with_services(
    model,
    ExportRequested,
    @services.AppServices::new(),
  )
  ignore(effect)
  assert_eq(next.toasts.length(), 1)
  assert_true(next.notice.contains("不可用"))
  assert_eq(next.export_pending, 0)
}

///|
test "native export counts bundle writes and toasts once at completion" {
  let model = @app.initial_model(export_available=true)
  let json = @codec.encode_program(model.program)
  let bundle = @app.bundle_files(json, "demo")
  assert_true(bundle.length() > 1)
  let (picked, _) = @app.update_with_services(
    model,
    ExportDirPicked(Success("/tmp/demo-export")),
    @services.AppServices::unavailable(),
  )
  assert_eq(picked.export_pending, bundle.length())
  // 逐文件回执：最后一个落盘之前不许报「已导出」（bundle 有几十个文件，
  // 逐文件报成功会把一次导出说成几十次）
  let mut cursor = picked
  let mut i = 0
  while i < bundle.length() - 1 {
    let (next, _) = @app.update_with_services(
      cursor,
      ExportFileWritten(Success(())),
      @services.AppServices::unavailable(),
    )
    assert_eq(next.toasts.length(), 0)
    cursor = next
    i = i + 1
  }
  let (done, _) = @app.update_with_services(
    cursor,
    ExportFileWritten(Success(())),
    @services.AppServices::unavailable(),
  )
  assert_eq(done.export_pending, 0)
  assert_eq(done.toasts.length(), 1)
  // 单文件写失败：告警 toast + 计数归零（后续回执不再累积报成功）。
  // 全新模型重走 picked：push_toast 就地追加，别把上面 done 的 toast 计进来。
  let (picked_fresh, _) = @app.update_with_services(
    @app.initial_model(export_available=true),
    ExportDirPicked(Success("/tmp/demo-export")),
    @services.AppServices::unavailable(),
  )
  let (failed, _) = @app.update_with_services(
    picked_fresh,
    ExportFileWritten(
      Failure(@services.ServiceError::unavailable("路径不可写")),
    ),
    @services.AppServices::unavailable(),
  )
  assert_eq(failed.export_pending, 0)
  assert_eq(failed.toasts.length(), 1)
}

///|
test "new blank program starts empty and stays undoable" {
  let model = @app.initial_model()
  let blanked = @app.update_pure(model, NewBlankProgram).0
  assert_eq(blanked.program.controls.length(), 0)
  assert_eq(blanked.program.handlers.length(), 0)
  assert_eq(blanked.selected_control, "")
  // 旧程序可经撤销找回——新建不能是断路
  let restored = @app.update_pure(blanked, Undo).0
  assert_true(restored.program.controls.length() > 0)
}

///|
test "command palette carries templates, new, help and preview" {
  let model = @app.initial_model()
  let commands = @app.studio_commands(@app.translator(model))
  assert_true(contains_id(commands, "studio.template.hello"))
  assert_true(contains_id(commands, "studio.template.roll_call"))
  assert_true(contains_id(commands, "studio.template.drill"))
  assert_true(contains_id(commands, "studio.template.store"))
  assert_true(contains_id(commands, "studio.file.new"))
  assert_true(contains_id(commands, "studio.help"))
  assert_true(contains_id(commands, "studio.preview"))
}

///|
test "studio commands really execute: templates, blank, help, preview" {
  let model = @app.initial_model()
  // 教案核心样例必须可达（此前 SelectTemplate(2)/(3) 零构造点）
  let drill = @app.update_pure(model, StudioCommandRun("studio.template.drill")).0
  assert_eq(drill.program.window.title, "口算训练营")
  let store = @app.update_pure(model, StudioCommandRun("studio.template.store")).0
  assert_eq(store.program.window.title, "班级小卖部")
  // 新建空白程序
  let blank = @app.update_pure(model, StudioCommandRun("studio.file.new")).0
  assert_eq(blank.program.controls.length(), 0)
  // 帮助 / 预览全屏页可达，且有返回出口（SetMode(ModeDesign)）
  let help = @app.update_pure(model, StudioCommandRun("studio.help")).0
  assert_true(help.mode is ModeHelp)
  let back = @app.update_pure(help, SetMode(ModeDesign)).0
  assert_true(back.mode is ModeDesign)
  let preview = @app.update_pure(model, StudioCommandRun("studio.preview")).0
  assert_true(preview.mode is ModePreview)
}
