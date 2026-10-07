///|
/// 代码工程生成器测试（M6①）：SelectTemplate 重定向为代码工程生成器，
/// 产出 form.mbt + handlers.mbt 骨架。契约：两条腿都从同一次 IR 快照
/// 派生、form 腿过 parse∘render 往返门、handlers 腿与导出 bundle 同源、
/// on_click 绑定与 handlers 函数名同源、form 子集边界诚实跳过。

///|
test "code project files derive form and handlers from the same ir" {
  let program = @proposals.sample_hello()
  let files = @app.code_project_files(program)
  // handlers 腿 = generate_source 逐字节同源
  assert_eq(files.handlers_mbt, @export.generate_source(program).source)
  assert_true(files.handlers_mbt.contains("fn studio_"))
  // form 腿 = render_form 产物，含舞台与控件
  assert_true(files.form_mbt.contains("stage(640, 480, ["))
  assert_true(files.form_mbt.contains("点我"))
  assert_true(files.form_mbt.contains("place(@views.button("))
  // 往返硬门：parse ∘ render == id（form_designer 同一门）
  match @form_designer.parse_form(files.form_mbt) {
    Ok(parsed) =>
      assert_true(
        @form_designer.form_model_eq(parsed.model, { ..parsed.model, }),
      )
    Err(message) => fail("form.mbt 应可解析: \{message}")
  }
}

///|
test "form skeleton binds on_click to the same handler function name" {
  // 带点击 handler 的程序：问候样例的按钮有点击子程序
  let program = @proposals.sample_hello()
  let files = @app.code_project_files(program)
  // handlers.mbt 里的函数名（与 export 的命名同源）
  let index = 1
  let handler = program.handlers[index - 1]
  let name = @export.handler_function_name(handler, index)
  assert_true(files.handlers_mbt.contains("fn \{name}(rt :"))
  // form.mbt 的 on_click 绑定同一名字
  assert_true(files.form_mbt.contains("on_click=\{name}"))
}

///|
test "form subset boundary skips non form controls honestly" {
  // 点名册含列表框（不在 form 子集内）：按钮/标签进 form.mbt，列表框跳过
  let program = @proposals.sample_roll_call()
  let files = @app.code_project_files(program)
  assert_true(files.form_mbt.contains("place(@views."))
  assert_false(files.form_mbt.contains("list_box"))
  // handlers.mbt 仍完整覆盖全部子程序（跳过只是 form 投影的边界）
  assert_true(files.handlers_mbt.contains("fn studio_"))
  match @form_designer.parse_form(files.form_mbt) {
    Ok(_) => ()
    Err(message) =>
      fail("含跳过控件的 form.mbt 仍应可解析: \{message}")
  }
}

///|
test "select template emits code project write only with a write target" {
  // 无在册工程、无迁移目录：与旧「置位后组合根静默清位」同语义——不发事件
  let applied = apply(@app.initial_model(), SelectTemplate(1))
  assert_eq(applied.outbox.length(), 0)
  // 有在册工程：事件带目标目录与双腿全文（M1 事件化，组合根监听器写盘）
  let imported = @app.update_with_services(
      @app.initial_model(compile_track_available=true),
      ProjectScanCompleted(Success(Ok(Single(counter_source())))),
      @services.AppServices::new(),
    ).0
  let emitted = apply(imported, SelectTemplate(1))
  match emitted.outbox {
    // import 步已入队 EvProjectsDirty(真实程序每趟排空),这里断言尾部事件
    [.., EvCodeProjectWrite(dir, form_mbt, handlers_mbt)] => {
      assert_true(dir.contains("/"))
      assert_true(form_mbt.contains("place(@views."))
      assert_true(handlers_mbt.contains("fn studio_"))
    }
    _ => fail("应发出代码工程写盘事件")
  }
}

///|
/// M6③：.studio.json 一次性迁移器——解码 → 代码工程骨架 → 写盘目标
/// 在旧文件所在目录；旧格式解码失败给结构化报错并指向迁移器口径。
test "migrator converts studio json to code project files" {
  let program = @proposals.sample_hello()
  let studio_json = @codec.encode_program(program)
  match @app.migrate_studio_source("/tmp/legacy", studio_json) {
    Ok(outcome) => {
      // IR 无损：迁移不改程序语义（签名一致）
      assert_eq(
        @ir.program_signature(outcome.program),
        @ir.program_signature(program),
      )
      // 写盘目标在旧文件所在目录
      assert_eq(outcome.form_path, "/tmp/legacy/form.mbt")
      assert_eq(outcome.handlers_path, "/tmp/legacy/handlers.mbt")
      // 内容与 code_project_files 同源
      let direct = @app.code_project_files(program)
      assert_eq(outcome.files.form_mbt, direct.form_mbt)
      assert_eq(outcome.files.handlers_mbt, direct.handlers_mbt)
      // handlers 腿与导出 bundle 同源
      assert_eq(
        outcome.files.handlers_mbt,
        @export.generate_source(program).source,
      )
    }
    Err(message) => fail("合法 .studio.json 应迁移成功: \{message}")
  }
}

///|
test "migrator rejects broken studio json with migration-directed error" {
  // JSON 语法坏
  match @app.migrate_studio_source("/tmp/legacy", "不是 JSON") {
    Err(message) => {
      assert_true(message.contains("迁移器"))
      assert_true(message.contains("JSON 语法无效"))
    }
    Ok(_) => fail("坏 JSON 应被拒绝")
  }
  // 好 JSON 但程序非法（handler 指向不存在的控件）→ 结构化原因
  let program = @proposals.sample_hello()
  let broken = {
    ..program,
    handlers: [
      @ir.Handler::{
        control_name: "不存在的控件",
        event: @ir.OnClick,
        note_zh: "",
        note_en: "",
        body: [],
      },
    ],
  }
  match
    @app.migrate_studio_source("/tmp/legacy", @codec.encode_program(broken)) {
    Err(message) => assert_true(message.contains("迁移器"))
    Ok(_) => fail("结构非法应被拒绝")
  }
}

///|
test "dirname of opened file is the migration target" {
  assert_eq(
    @app.dirname_of("/Users/tea/projects/counter/project.studio.json"),
    "/Users/tea/projects/counter",
  )
  assert_eq(@app.dirname_of("project.studio.json"), ".")
}
