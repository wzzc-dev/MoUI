///|
/// app 测试：纯状态转移（不含 UI 渲染与服务副作用）。

///|
fn apply(model : @app.Model, msg : @app.Msg) -> @app.Model {
  let (next, _effect) = @app.update_pure(model, msg)
  next
}

///|
/// 推进运行直到终止态（测试环境没有计时器订阅，手动 tick）。
fn drain(model : @app.Model) -> @app.Model {
  let mut stepped = model
  let mut i = 0
  while i < 60 {
    match stepped.run {
      Some(run) =>
        if run.state.status is @studio_lang.Running {
          stepped = apply(stepped, RunTick)
        } else {
          break
        }
      None => break
    }
    i = i + 1
  }
  stepped
}

///|
test "initial model loads hello sample in chinese" {
  let model = @app.initial_model()
  assert_true(model.language is ZhHans)
  assert_eq(model.program.window.title, "问候")
  assert_eq(model.selected_handler, "按钮@on_click")
  let t = @app.translator(model)
  assert_eq(@app.text(t, "app.mode.design"), "设计")
  assert_eq(@app.text(t, "app.mode.design"), "设计")
}

///|
test "english translation resolves" {
  let model = apply(@app.initial_model(), SwitchLanguage)
  assert_true(model.language is En)
  let t = @app.translator(model)
  assert_eq(@app.text(t, "app.mode.design"), "Design")
  assert_eq(@app.text(t, "control.button"), "Button")
  assert_eq(@app.text(t, "builtin.submit_data"), "submit_data")
  // 中文回退仍在
  assert_eq(@app.text(t, "app.templates.hello"), "Hello app")
}

///|
test "language switch commits parseable draft and re-renders" {
  let model = @app.initial_model()
  let switched = apply(model, SwitchLanguage)
  assert_true(switched.code_draft.contains("set_text"))
  let switched_back = apply(switched, SwitchLanguage)
  assert_true(
    switched_back.code_draft.contains("变量") ||
    switched_back.code_draft.contains("设置文本"),
  )
}

///|
test "add and delete control keeps handlers consistent" {
  let model = apply(@app.initial_model(), AddControl(@ir.Label))
  assert_eq(model.program.controls.length(), 3)
  assert_eq(model.selected_control, "标签")
  let renamed = apply(model, SetControlName("标签", "标题"))
  assert_true(@ir.find_control(renamed.program, "标题") is Some(_))
  assert_eq(renamed.selected_control, "标题")
  let deleted = apply(renamed, DeleteControl("标题"))
  assert_eq(deleted.program.controls.length(), 2)
  // Removing a different control must not clear the current selection.
  let keep_selection = apply(@app.initial_model(), DeleteControl("显示"))
  assert_eq(keep_selection.selected_control, "按钮")
  // Reserved DSL words cannot become control identifiers.
  let reserved = apply(@app.initial_model(), SetControlName("按钮", "if"))
  assert_true(@ir.find_control(reserved.program, "按钮") is Some(_))
  // Renaming a control also rewrites control-name arguments in handler IR.
  let renamed_label = apply(
    @app.initial_model(),
    SetControlName("显示", "标题"),
  )
  match @app.current_handler(renamed_label).unwrap().body[0] {
    @ir.Call("set_text", args) => assert_true(args[0] is @ir.Var("标题"))
    _ => fail("问候 handler 应保留 set_text")
  }
}

///|
test "code edit commits into program" {
  let model = @app.initial_model()
  let edited = apply(model, EditCode("设置文本(显示, \"新文本\")\n"))
  let committed = apply(edited, SelectHandler("按钮@on_click"))
  match @app.current_handler(committed) {
    Some(handler) => {
      assert_eq(handler.body.length(), 1)
      match handler.body[0] {
        @ir.Call("set_text", args) =>
          match args[1] {
            @ir.StrLit(text) => assert_eq(text, "新文本")
            _ => fail("提交后第二个参数应为字符串")
          }
        _ => fail("切换 handler 前应提交代码草稿")
      }
    }
    None => fail("提交后应仍有子程序")
  }
}

///|
test "mode switch commits the current code draft" {
  let edited = apply(
    apply(
      @app.initial_model(),
      EditCode("设置文本(显示, \"模式切换后\")\n"),
    ),
    SetMode(@app.ModeDesign),
  )
  match @app.current_handler(edited).unwrap().body[0] {
    @ir.Call("set_text", args) =>
      match args[1] {
        @ir.StrLit(text) => assert_eq(text, "模式切换后")
        _ => fail("提交后第二个参数应为字符串")
      }
    _ => fail("切换模式前应提交代码草稿")
  }
}

///|
test "syntax error surfaces localized message" {
  let model = @app.initial_model()
  let edited = apply(model, EditCode("如果 真的 则\n"))
  let started = apply(edited, RunStart)
  // 语法错误进 notice（本地化），且不进入运行态
  assert_true(started.notice != "")
  assert_true(started.run is None)
  let t = @app.translator(started)
  assert_eq(@app.text(t, "app.code.error"), "语法错误")
  // 正确的草稿可以运行
  let fixed = apply(edited, EditCode("设置文本(显示, \"新文本\")\n"))
  let run = apply(fixed, RunStart)
  assert_true(run.run is Some(_))
  assert_eq(run.notice, "")
}

///|
test "invalid draft never executes stale control handlers" {
  let started = apply(@app.initial_model(), RunStart)
  let broken = apply(started, EditCode("如果 真的 则\n"))
  let clicked = apply(broken, ControlClicked("按钮"))
  assert_true(clicked.code_error != "")
  assert_eq(clicked.run.unwrap().state.texts.get("显示").unwrap_or(""), "")
}

///|
test "invalid draft blocks runtime control events" {
  let started = apply(@app.initial_model(), RunStart)
  let before_steps = started.run.unwrap().state.steps
  let broken = apply(started, EditCode("如果 真的 则\n"))
  let clicked = apply(broken, ControlClicked("按钮"))
  assert_true(clicked.code_error != "")
  assert_eq(clicked.run.unwrap().state.steps, before_steps)
}

///|
test "run start executes hello handler to completion" {
  let model = apply(@app.initial_model(), RunStart)
  match model.run {
    None => fail("应进入运行态")
    Some(_run) => {
      let stepped = drain(model)
      let final_run = stepped.run.unwrap()
      assert_true(final_run.state.status is @studio_lang.Completed)
      assert_eq(
        final_run.state.texts.get("显示").unwrap_or(""),
        "你好，MoUI Studio！",
      )
    }
  }
}

///|
test "run gate pauses submit and confirm completes" {
  let model = apply(@app.initial_model(), SelectTemplate(3))
  let started = apply(model, RunStart)
  match started.run {
    None => fail("小卖部应能运行")
    Some(_run) => {
      // 直接运行卖铅笔 handler：无闸门，营业额 +1
      let sold = drain(apply(started, ControlClicked("卖铅笔")))
      let final_run = sold.run.unwrap()
      let revenue = final_run.state.vars
        .get("营业额")
        .unwrap_or(@studio_lang.VUnit)
      assert_eq(@studio_lang.value_to_text(revenue), "1")
      // 记账 handler：停在提交闸门
      let submitting = drain(apply(sold, ControlClicked("记账")))
      let gated = submitting.run.unwrap()
      assert_true(gated.state.status is @studio_lang.WaitingGate)
      match gated.state.gate {
        Some(gate) => {
          assert_true(gate.kind is @studio_lang.Submit)
          assert_eq(gate.prompt, "班级账本")
          assert_eq(gate.payload, "1")
        }
        None => fail("应停在闸门")
      }
      // 闸门未回答前，其他控件事件不能绕过确认启动新 handler。
      let blocked = apply(submitting, ControlClicked("卖铅笔"))
      assert_true(blocked.run.unwrap().state.status is @studio_lang.WaitingGate)
      assert_eq(
        @studio_lang.value_to_text(
          blocked.run.unwrap().state.vars
          .get("营业额")
          .unwrap_or(@studio_lang.VUnit),
        ),
        "1",
      )
    }
  }
}

///|
test "fake model proposal validates, diffs and applies" {
  let model = apply(
    @app.initial_model(),
    SetPrompt("帮我做一个随机点名"),
  )
  let generated = apply(model, GenerateProposal)
  match generated.pending {
    None => fail("应产生待采纳提案")
    Some(pending) => {
      assert_true(pending.valid)
      assert_true(pending.diff.length() > 0)
      assert_true(pending.summary != "")
      let accepted = apply(generated, AcceptProposal)
      assert_eq(accepted.program.window.title, "班级点名册")
      assert_eq(accepted.program.handlers.length(), 1)
      assert_true(accepted.pending is None)
    }
  }
}

///|
test "rejected proposal keeps program" {
  let model = apply(@app.initial_model(), SetPrompt("口算练习"))
  let generated = apply(model, GenerateProposal)
  let rejected = apply(generated, RejectProposal)
  assert_true(rejected.pending is None)
  assert_eq(rejected.program.window.title, "问候")
}

///|
test "invalid proposal from real model is rejected wholesale" {
  let model = apply(@app.initial_model(), SetPrompt("随便"))
  // 直接喂一个坏 JSON（绕过假模型）：整单拒绝
  let broken = @app.proposal_from_completion(model, "这不是提案")
  assert_true(broken.pending is None)
  assert_true(broken.prompt_error != "")
}

///|
test "templates switch program and selection" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  assert_eq(model.program.window.title, "口算训练营")
  assert_true(model.selected_handler != "")
}

///|
test "split lines helper" {
  let lines = @app.split_lines("铅笔 1元\n\n橡皮 2元\n  笔记本 5元  ")
  assert_eq(lines.length(), 3)
  assert_eq(lines[0], "铅笔 1元")
  assert_eq(lines[2], "笔记本 5元")
}

///|
test "runtime state accumulates across events" {
  let model = apply(@app.initial_model(), SelectTemplate(3))
  let once = drain(apply(model, ControlClicked("卖铅笔")))
  let twice = drain(apply(once, ControlClicked("卖铅笔")))
  let run = twice.run.unwrap()
  let revenue = run.state.vars.get("营业额").unwrap_or(@studio_lang.VUnit)
  assert_eq(@studio_lang.value_to_text(revenue), "2")
  // 活状态并回模型：下一次运行从 2 继续
  let thrice = drain(apply(twice, ControlClicked("卖铅笔")))
  let three = thrice.run.unwrap().state.vars
    .get("营业额")
    .unwrap_or(@studio_lang.VUnit)
  assert_eq(@studio_lang.value_to_text(three), "3")
  // 控件文本也跨事件保持
  let label = thrice.run.unwrap().state.texts
    .get("营业额标签")
    .unwrap_or("")
  assert_eq(label, "营业额：3")
}

///|
test "list selection survives the next handler run" {
  let started = apply(apply(@app.initial_model(), SelectTemplate(1)), RunStart)
  let picked = apply(started, ControlPicked("名单", 2))
  assert_eq(picked.runtime_selections.get("名单").unwrap_or(-1), 2)
  assert_eq(picked.run.unwrap().state.selections.get("名单").unwrap_or(-1), 2)
  let next = apply(picked, ControlClicked("点名按钮"))
  assert_eq(next.run.unwrap().state.selections.get("名单").unwrap_or(-1), 2)
}

///|
test "table row selection dispatches its supported click handler" {
  let model = apply(@app.initial_model(), SelectTemplate(3))
  let table = @ir.find_control(model.program, "商品表").unwrap()
  let with_handler = apply(model, CreateHandler(table.name, @ir.OnClick))
  let edited = apply(
    with_handler,
    EditCode("设置文本(营业额标签, \"点了商品\")\n"),
  )
  let started = apply(edited, RunStart)
  let picked = drain(apply(started, ControlPicked(table.name, 1)))
  assert_eq(
    picked.run.unwrap().state.texts.get("营业额标签").unwrap_or(""),
    "点了商品",
  )
}

///|
test "append row persists across handlers without changing the program" {
  let model = apply(@app.initial_model(), SelectTemplate(1))
  let edited = apply(model, EditCode("追加行(名单, \"新同学\")\n"))
  let finished = drain(apply(edited, RunStart))
  assert_eq(finished.run.unwrap().state.rows.get("名单").unwrap().length(), 6)
  assert_eq(
    @ir.find_control(finished.program, "名单").unwrap().items.length(),
    5,
  )
  let next = drain(apply(finished, ControlClicked("点名按钮")))
  assert_eq(next.run.unwrap().state.rows.get("名单").unwrap().length(), 7)
  assert_eq(@ir.find_control(next.program, "名单").unwrap().items.length(), 5)
}

///|
test "checkbox change keeps its checked state while running on_change" {
  let added = apply(@app.initial_model(), AddControl(@ir.CheckBox))
  let checkbox = added.program.controls[added.program.controls.length() - 1]
  let handler = apply(added, CreateHandler(checkbox.name, @ir.OnChange))
  let edited = apply(handler, EditCode("设置文本(显示, \"已勾选\")\n"))
  let started = apply(edited, RunStart)
  let finished = drain(apply(started, RunToggle(checkbox.name, true)))
  let run = finished.run.unwrap()
  assert_true(run.checks.get(checkbox.name).unwrap_or(false))
  assert_eq(run.state.texts.get("显示").unwrap_or(""), "已勾选")
}

///|
test "local explanation walks the handler steps" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let explained = apply(model, ExplainHandler)
  assert_true(explained.explanation.contains("random"))
  assert_true(explained.explanation.contains("1."))
  let drill = explained
  assert_true(drill.explanation.contains("set_text"))
}

///|
/// 可读性验收：「解释这个程序」对全部模板 × 双语给出非空、带编号步骤、
/// note 头随界面语言切换的讲解（步骤行是语言无关的规范算子形式，
/// 双语差异只在 note 头；每个模板讲解的是其首个子程序）。
test "local explanation covers every template in both languages" {
  // (模板下标, 步骤必含规范算子, zh note 片段, en note 片段)
  let cases : Array[(Int, Array[String], String, String)] = [
    (0, ["set_text"], "问候语", "greeting"),
    (1, ["row_count", "random", "row_at"], "随机序号", "random row index"),
    (2, ["random", "to_text"], "随机出", "roll two numbers"),
    (3, ["to_text", "set_text"], "铅笔", "revenue per pencil"),
  ]
  for case in cases {
    let zh = apply(
      apply(@app.initial_model(), SelectTemplate(case.0)),
      ExplainHandler,
    )
    assert_true(zh.explanation.contains("\n1. "))
    for keyword in case.1 {
      assert_true(zh.explanation.contains(keyword))
    }
    assert_true(zh.explanation.contains(case.2))
    let en = apply(apply(zh, SwitchLanguage), ExplainHandler)
    assert_true(en.explanation.contains("\n1. "))
    for keyword in case.1 {
      assert_true(en.explanation.contains(keyword))
    }
    assert_true(en.explanation.contains(case.3))
    // 步骤行语言无关，双语差异只在 note 头
    assert_true(en.explanation != zh.explanation)
  }
}

///|
test "exported bundle never carries the provider key" {
  let model = apply(@app.initial_model(), SetProviderKey("SENTINEL-SECRET-KEY"))
  let encoded = @codec.encode_program(model.program)
  let bundle = @app.bundle_files(encoded, "x")
  assert_true(bundle.length() > 10)
  for pair in bundle {
    assert_true(!pair.1.contains("SENTINEL-SECRET-KEY"))
  }
}

///|
test "language loaded message switches without doubling" {
  // LanguageLoaded 走服务流；这里至少验证 @app.ui_language_from_tag 的映射
  let model = { ..@app.initial_model(), language: En, }
  let loaded = { ..model, language: @app.ui_language_from_tag("zh-Hans"), }
  assert_true(loaded.language is ZhHans)
  let bad = @app.ui_language_from_tag("not-a-locale")
  assert_true(bad is ZhHans)
  let en = @app.ui_language_from_tag("en")
  assert_true(en is En)
}

///|
test "every generated catalog key resolves in both locales" {
  // 生成器保证两语言 key 集合一致；这里保住言兜底：任何 key 在任一语言
  // 都不得回落到 [[key]] 缺失标记。
  for catalog in @app.generated_i18n_catalogs {
    let locale = catalog.locale
    let t = @app.translator_for(@app.ui_language_from_tag(locale))
    for pair in catalog.messages {
      let (key, _message) = pair
      let resolved = @app.text(t, key)
      assert_true(!resolved.has_prefix("[["))
    }
  }
}

///|
test "placeholder messages interpolate in both locales" {
  let zh = @app.translator_for(ZhHans)
  let en = @app.translator_for(En)
  let zh_gate = @app.text_with(zh, "app.run.gate.submit", [
    ("target", "班级账本"),
    ("payload", "3"),
  ])
  assert_true(zh_gate.contains("班级账本"))
  assert_true(zh_gate.contains("3"))
  let en_gate = @app.text_with(en, "app.run.gate.submit", [
    ("target", "ledger"),
    ("payload", "3"),
  ])
  assert_true(en_gate.contains("ledger"))
  let zh_err = @app.error_message(
    zh,
    @studio_lang.LangError(@studio_lang.NotDeclared, 2, "得分", ""),
  )
  assert_true(zh_err.contains("得分"))
  let en_err = @app.error_message(
    en,
    @studio_lang.LangError(@studio_lang.NotDeclared, 2, "score", ""),
  )
  assert_true(en_err.contains("score"))
}

///|
test "block view edits write back to the ir" {
  let model = apply(@app.initial_model(), SelectTemplate(1))
  // 点名册：handler 链 = [declare 人数, declare 序号, set_text]
  let blocks = @app.block_chain_of(model)
  assert_eq(blocks.length(), 3)
  // 选中第一条（declare 人数 = row_count(名单)）
  let selected = apply(model, SelectBlock(0))
  assert_true(selected.block_draft.contains("变量 人数"))
  assert_eq(selected.selected_block, 0)
  // 改成字符串字面量并应用
  let edited = apply(selected, EditBlock("变量 人数 = 42\n"))
  let committed = apply(edited, CommitBlock)
  match @app.current_handler(committed) {
    Some(handler) => {
      assert_eq(handler.body.length(), 3)
      match @blocks.stmt_at(handler.body, [0]) {
        Some(stmt) => assert_true(stmt is @ir.Declare(_, _))
        None => fail("第一条应仍是 declare")
      }
      assert_true(committed.code_draft.contains("变量 人数 = 42"))
    }
    None => fail("子程序应仍在")
  }
  // 删除第二条（declare 序号）→ 语句数 -1，代码视图同步
  let picked = apply(committed, SelectBlock(1))
  let deleted = apply(picked, DeleteBlock)
  match @app.current_handler(deleted) {
    Some(handler) => assert_eq(handler.body.length(), 2)
    None => fail("子程序应仍在")
  }
  assert_eq(deleted.selected_block, -1)
  assert_true(deleted.code_draft.contains("随机数") == false)
}

///|
test "block edit rejects unparseable draft" {
  let model = apply(@app.initial_model(), SelectTemplate(1))
  let selected = apply(model, SelectBlock(0))
  let broken = apply(selected, EditBlock("如果 真的 则\n"))
  let committed = apply(broken, CommitBlock)
  match @app.current_handler(committed) {
    Some(handler) =>
      // 原语句保持不动，notice 提示语法错误
      assert_true(handler.body.length() == 3)
    None => fail("子程序应仍在")
  }
  assert_true(committed.notice != "")
}

///|
test "block edit on nested statement path" {
  // 口算训练营：批改 handler = [If(cond, [set_text], [], [set_text])]
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let picked = apply(model, SelectHandler("批改按钮@on_click"))
  let blocks = @app.block_chain_of(picked)
  // if / then-set_text / else / else-set_text / end
  assert_eq(blocks.length(), 5)
  // 选 then 体里的 set_text（path [0,0,0]）
  let selected = apply(picked, SelectBlock(1))
  assert_true(selected.block_draft.contains("设置文本"))
  let edited = apply(
    selected,
    EditBlock("设置文本(判定, \"完全正确\")\n"),
  )
  let committed = apply(edited, CommitBlock)
  match @app.current_handler(committed) {
    Some(handler) =>
      match @blocks.stmt_at(handler.body, [0, 0, 0]) {
        Some(stmt) =>
          match stmt {
            @ir.Stmt::Call(name, args) => {
              assert_eq(name, "set_text")
              assert_true(args.length() == 2)
            }
            _ => fail("应为 call")
          }
        None => fail("then 体第一条应在")
      }
    None => fail("子程序应仍在")
  }
  assert_true(committed.code_draft.contains("完全正确"))
}

///|
test "@app.text field input lands in run state and live texts" {
  let added = apply(@app.initial_model(), AddControl(@ir.TextField))
  let field = added.program.controls[added.program.controls.length() - 1]
  assert_true(field.kind is @ir.TextField)
  // 无运行态：输入也进活状态（受控字段不回跳，取文本 可读到）
  let typed = apply(added, ControlChanged(field.name, "张三"))
  assert_eq(typed.runtime_texts.get(field.name).unwrap_or(""), "张三")
  // 运行态存在：输入同时进运行态文本表
  let running = apply(typed, RunStart)
  assert_true(running.run is Some(_))
  let typed_again = apply(running, ControlChanged(field.name, "李四"))
  assert_eq(
    typed_again.run.unwrap().state.texts.get(field.name).unwrap_or(""),
    "李四",
  )
}

///|
test "design drag moves control and clamps to canvas" {
  let added = apply(@app.initial_model(), AddControl(@ir.Button))
  let control = added.program.controls[added.program.controls.length() - 1]
  // 按下点在控件主体（距角 > 手柄命中半径），不触发角手柄缩放
  let cx = control.x.to_double() + 20.0
  let cy = control.y.to_double() + 15.0
  // 命中即选中并建立拖拽态
  let pressed = apply(added, CanvasPress(cx, cy))
  assert_true(pressed.selected_control == control.name)
  assert_true(pressed.drag is Some(_))
  // 拖向画布外：夹取规则保证控件完整落在 640x480 内
  let moved = apply(pressed, CanvasDragTo(cx + 5000.0, cy + 5000.0))
  let after = @ir.find_control(moved.program, control.name).unwrap()
  assert_eq(after.x, @ir.DESIGN_WIDTH - after.width)
  assert_eq(after.y, @ir.DESIGN_HEIGHT - after.height)
  // 松开清除拖拽态但保留选中
  let released = apply(moved, CanvasRelease(cx, cy))
  assert_true(released.drag is None)
  assert_true(released.selected_control == control.name)
}

///|
test "inspector rect edits clamp and reject bad input" {
  let model = @app.initial_model()
  // 高度超界 → 夹到画布高，y 随之夹回
  let resized = apply(model, SetControlRect("按钮", @ir.RectHeight, "9999"))
  let tall = @ir.find_control(resized.program, "按钮").unwrap()
  assert_eq(tall.height, @ir.DESIGN_HEIGHT)
  assert_eq(tall.y, 0)
  // 合法移动生效
  let moved = apply(resized, SetControlRect("按钮", @ir.RectX, "300"))
  assert_eq(@ir.find_control(moved.program, "按钮").unwrap().x, 300)
  // 非法输入（非数字/超长）被忽略，保持原值
  let bad = apply(moved, SetControlRect("按钮", @ir.RectY, "abc"))
  assert_eq(@ir.find_control(bad.program, "按钮").unwrap().y, 0)
  let bad2 = apply(bad, SetControlRect("按钮", @ir.RectY, "99999"))
  assert_eq(@ir.find_control(bad2.program, "按钮").unwrap().y, 0)
}

///|
test "canvas tap selects on click and stays quiet during drag release" {
  let added = apply(@app.initial_model(), AddControl(@ir.Button))
  let control = added.program.controls[added.program.controls.length() - 1]
  let cx = control.x.to_double() + 10.0
  let cy = control.y.to_double() + 10.0
  // 单击控件 → 选中
  let tapped = apply(added, CanvasTap(cx, cy))
  assert_true(tapped.selected_control == control.name)
  // 拖拽中松手也会产生 tap：drag 态还在时不改选中（消息顺序无关）
  let pressed = apply(tapped, CanvasPress(cx, cy))
  let dragged = apply(pressed, CanvasDragTo(cx + 40.0, cy + 30.0))
  let tap_during_drag = apply(dragged, CanvasTap(cx + 40.0, cy + 30.0))
  assert_true(tap_during_drag.selected_control == control.name)
  // 松开清除拖拽态；随后落在移动后控件上的 tap 选中同一控件
  let released = apply(tap_during_drag, CanvasRelease(cx + 40.0, cy + 30.0))
  assert_true(released.drag is None)
  let tap_after_release = apply(released, CanvasTap(cx + 40.0, cy + 30.0))
  assert_true(tap_after_release.selected_control == control.name)
  // 单击空白处取消选中
  let empty = apply(tap_after_release, CanvasTap(600.0, 450.0))
  assert_true(empty.selected_control == "")
}

///|
test "design canvas plan draws grid, handles and alignment guides" {
  let program = @proposals.sample_hello()
  // 无拖拽：网格点阵 + 选中描边 + 4 角手柄，无参考线
  let plan = @app.design_backdrop_plan()
  // 覆盖层：选中描边/名牌/手柄（无拖拽时无参考线）
  let overlay = @app.design_overlay_plan(program, "按钮", None)
  let mut grid_dots = 0
  let mut handles = 0
  let mut guides = 0
  for op in plan {
    match op {
      @app.DesignDrawOp::GridDot(_) => grid_dots = grid_dots + 1
      _ => ()
    }
  }
  for op in overlay {
    match op {
      @app.DesignDrawOp::SelectionHandle(_) => handles = handles + 1
      @app.DesignDrawOp::GuideV(_) | @app.DesignDrawOp::GuideH(_) =>
        guides = guides + 1
      _ => ()
    }
  }
  assert_true(grid_dots > 200)
  assert_eq(handles, 4)
  assert_eq(guides, 0)
  // 拖拽中：被拖控件左缘与其他控件左缘差 ≤4px 时画竖向参考线
  let base = @ir.empty_program()
  let anchor = @ir.Control::{
    id: 1,
    kind: @ir.Label,
    name: "锚点",
    text: "",
    x: 100,
    y: 100,
    width: 30,
    height: 30,
    items: [],
  }
  let dragged = @ir.Control::{ ..anchor, id: 2, name: "拖块", x: 103, y: 40, }
  let pair = @ir.StudioProgram::{ ..base, controls: [anchor, dragged], }
  let dragging = @app.design_overlay_plan(pair, "拖块", Some("拖块"))
  let mut vertical_guides = 0
  for op in dragging {
    match op {
      @app.DesignDrawOp::GuideV(x) => {
        vertical_guides = vertical_guides + 1
        // 同宽控件整体偏移 3px：左缘/中心/右缘三条参考线全部命中
        // （100/115/130），push_unique 保证位置不重复
        assert_true(x == 100.0 || x == 115.0 || x == 130.0)
      }
      _ => ()
    }
  }
  assert_eq(vertical_guides, 3)
}

///|
test "handle hit test resolves corners within radius" {
  let control : @ir.Control = {
    id: 1,
    kind: @ir.Button,
    name: "按钮",
    text: "",
    x: 100,
    y: 100,
    width: 60,
    height: 40,
    items: [],
  }
  match @app.hit_test_handle(control, 100.0, 100.0) {
    Some(corner) => assert_true(corner is @ir.CornerNW)
    None => fail("左上角手柄应命中")
  }
  match @app.hit_test_handle(control, 160.0, 140.0) {
    Some(corner) => assert_true(corner is @ir.CornerSE)
    None => fail("右下角手柄应命中")
  }
  // 半径外（10px）与控件中心不命中
  assert_true(@app.hit_test_handle(control, 110.0, 100.0) is None)
  assert_true(@app.hit_test_handle(control, 130.0, 120.0) is None)
}

///|
test "design handle press resizes with opposite corner fixed" {
  let added = apply(@app.initial_model(), AddControl(@ir.Button))
  let control = added.program.controls[added.program.controls.length() - 1]
  let se_x = (control.x + control.width).to_double()
  let se_y = (control.y + control.height).to_double()
  // 按上右下角手柄 → 缩放拖拽态
  let pressed = apply(added, CanvasPress(se_x, se_y))
  match pressed.drag {
    Some(drag) =>
      match drag.kind {
        Resize(corner) => assert_true(corner is @ir.CornerSE)
        Move(_, _) => fail("按手柄应进入缩放而非移动")
      }
    None => fail("按上手柄应建立拖拽态")
  }
  // 向右下拖：左上角不动，移动边落 32px 网格（290→288，252→256）
  let dragged = apply(pressed, CanvasDragTo(se_x + 60.0, se_y + 100.0))
  let after = @ir.find_control(dragged.program, control.name).unwrap()
  assert_eq(after.x, control.x)
  assert_eq(after.y, control.y)
  assert_eq(after.width, 288 - control.x)
  assert_eq(after.height, 256 - control.y)
  // 松手清除拖拽态但保留选中
  let released = apply(dragged, CanvasRelease(se_x + 60.0, se_y + 100.0))
  assert_true(released.drag is None)
  assert_true(released.selected_control == control.name)
}

///|
test "snap move position aligns near edges only within tolerance" {
  let anchor : @ir.Control = {
    id: 1,
    kind: @ir.Label,
    name: "锚点",
    text: "",
    x: 100,
    y: 100,
    width: 30,
    height: 30,
    items: [],
  }
  let dragged : @ir.Control = {
    ..anchor,
    id: 2,
    name: "拖块",
    x: 102,
    y: 40,
  }
  let pair = [anchor, dragged]
  // 左缘距锚点左缘 2px（≤4 容差）→ 吸附精确对齐；y 无参考线命中 → 落网格
  let (sx, sy) = @app.snap_move_position(
    pair, "拖块", 102.0, 40.0, 30.0, 30.0,
  )
  assert_eq(sx, 100.0)
  assert_eq(sy, 32.0)
  // 双轴均超参考线容差 → 双轴落网格（106 → 96，40 → 32）
  let (fx, fy) = @app.snap_move_position(
    pair, "拖块", 106.0, 40.0, 30.0, 30.0,
  )
  assert_eq(fx, 96.0)
  assert_eq(fy, 32.0)
}

///|
test "design drag snaps onto alignment guide" {
  let base = apply(@app.initial_model(), AddControl(@ir.Label))
  let label = base.program.controls[base.program.controls.length() - 1]
  // 固定几何：锚点按钮 x=100；标签 x=103（与锚点左缘差 3px ≤ 容差）
  let anchored = apply(base, SetControlRect("按钮", @ir.RectX, "100"))
  let placed_y = apply(anchored, SetControlRect(label.name, @ir.RectY, "200"))
  let placed = apply(placed_y, SetControlRect(label.name, @ir.RectX, "103"))
  let placed_label = @ir.find_control(placed.program, label.name).unwrap()
  // 先点空白取消选中，避免按在选中控件手柄附近误入缩放
  let deselected = apply(placed, CanvasTap(600.0, 450.0))
  let press_x = placed_label.x.to_double() + 20.0
  let press_y = placed_label.y.to_double() + 10.0
  let pressed = apply(deselected, CanvasPress(press_x, press_y))
  match pressed.drag {
    Some(drag) =>
      match drag.kind {
        Move(_, _) => ()
        Resize(_) => fail("按控件主体应进入移动而非缩放")
      }
    None => fail("按控件主体应建立拖拽态")
  }
  // 拖 1px：候选原点 x=102，距按钮左缘 100 差 2px → 吸附到 100
  let dragged = apply(pressed, CanvasDragTo(press_x - 1.0, press_y))
  let after = @ir.find_control(dragged.program, label.name).unwrap()
  assert_eq(after.x, 100)
  // y 无参考线命中 → 落 32px 网格（200 → 192）
  assert_eq(after.y, 192)
}

///|
test "create handler builds empty body and selects it" {
  let added = apply(@app.initial_model(), AddControl(@ir.TextField))
  let field = added.program.controls[added.program.controls.length() - 1]
  let created = apply(added, CreateHandler(field.name, @ir.OnChange))
  assert_eq(created.selected_handler, @app.handler_key(field.name, "on_change"))
  match @app.current_handler(created) {
    Some(handler) => {
      assert_eq(handler.control_name, field.name)
      assert_eq(handler.body.length(), 0)
    }
    None => fail("新建子程序应被选中")
  }
  // 重复创建被忽略（(控件, 事件) 唯一）
  let again = apply(created, CreateHandler(field.name, @ir.OnChange))
  assert_eq(again.program.handlers.length(), created.program.handlers.length())
  // 不支持的事件被忽略
  let unsupported = apply(created, CreateHandler("按钮", @ir.OnChange))
  assert_eq(
    unsupported.program.handlers.length(),
    created.program.handlers.length(),
  )
}

///|
test "add control enforces budget and surfaces notice" {
  let model = apply(@app.initial_model(), AddControl(@ir.Label))
  let mut iter = model
  let mut safety = 0
  while iter.program.controls.length() < @ir.MAX_CONTROLS && safety < 300 {
    iter = apply(iter, AddControl(@ir.Label))
    safety = safety + 1
  }
  assert_eq(iter.program.controls.length(), @ir.MAX_CONTROLS)
  let over = apply(iter, AddControl(@ir.Label))
  assert_eq(over.program.controls.length(), @ir.MAX_CONTROLS)
  assert_true(over.notice != "")
}

///|
test "delete control clears stale draft only for its own handler" {
  let model = @app.initial_model()
  // 选中子程序是 按钮@on_click：删除按钮 → 选中清空、草稿同步清空
  assert_true(model.code_draft != "")
  let deleted = apply(model, DeleteControl("按钮"))
  assert_eq(deleted.selected_handler, "")
  assert_eq(deleted.code_draft, "")
  // 删除别的控件不动草稿（未提交的编辑不丢失）
  let kept = apply(model, DeleteControl("显示"))
  assert_true(kept.code_draft != "")
}

///|
test "deleting an unselected control preserves the current selection" {
  let model = apply(@app.initial_model(), SelectControl("按钮"))
  let deleted = apply(model, DeleteControl("显示"))
  assert_eq(deleted.selected_control, "按钮")
}

///|
test "real generation result becomes pending proposal, failure surfaces" {
  let model = apply(@app.initial_model(), SetProviderKey("k"))
  // 真实生成成功：与假模型同走校验链 → 待采纳提案；busy 复位
  let completion = @proposals.fake_model_completion(
    "帮我做一个随机点名",
    model.program,
  )
  let next = apply(model, RealGenerationFinished(Ok(completion)))
  assert_true(next.pending is Some(_))
  assert_false(next.ai_busy)
  // 失败：错误进面板提示，不留半成品提案
  let failed = apply(
    model,
    RealGenerationFinished(Err("provider 返回 HTTP 500")),
  )
  assert_true(failed.prompt_error.contains("500"))
  assert_true(failed.pending is None)
  assert_false(failed.ai_busy)
}

///|
test "undo and redo revert and replay control add" {
  let base = @app.initial_model()
  let added = apply(base, AddControl(@ir.Button))
  assert_eq(added.program.controls.length(), base.program.controls.length() + 1)
  // 撤销 → 控件消失、选中清空
  let undone = apply(added, Undo)
  assert_eq(undone.program.controls.length(), base.program.controls.length())
  assert_eq(undone.selected_control, base.selected_control)
  // 重做 → 控件回来
  let redone = apply(undone, Redo)
  assert_eq(redone.program.controls.length(), added.program.controls.length())
  assert_eq(redone.selected_control, added.selected_control)
}

///|
test "drag gesture coalesces into one undo point" {
  let base = apply(@app.initial_model(), AddControl(@ir.Button))
  let control = base.program.controls[base.program.controls.length() - 1]
  let stack_after_add = base.undo_stack.length()
  let cx = control.x.to_double() + 20.0
  let cy = control.y.to_double() + 15.0
  let pressed = apply(base, CanvasPress(cx, cy))
  // 一段手势内的多次 DragTo 合并：撤销栈只长 1
  let dragged = apply(
    apply(
      apply(pressed, CanvasDragTo(cx + 30.0, cy + 10.0)),
      CanvasDragTo(cx + 50.0, cy + 20.0),
    ),
    CanvasDragTo(cx + 70.0, cy + 30.0),
  )
  assert_eq(dragged.undo_stack.length(), stack_after_add + 1)
  // 一次撤销回到拖拽前位置
  let undone = apply(dragged, Undo)
  let after = @ir.find_control(undone.program, control.name).unwrap()
  assert_eq(after.x, control.x)
  assert_eq(after.y, control.y)
}

///|
test "consecutive text edits share one undo point" {
  let base = apply(@app.initial_model(), AddControl(@ir.Label))
  let label = base.program.controls[base.program.controls.length() - 1]
  let stack_after_add = base.undo_stack.length()
  let once = apply(base, SetControlText(label.name, "第一版"))
  let twice = apply(once, SetControlText(label.name, "第二版"))
  assert_eq(twice.undo_stack.length(), stack_after_add + 1)
  // 一次撤销同时回到两版之前
  let undone = apply(twice, Undo)
  let after = @ir.find_control(undone.program, label.name).unwrap()
  assert_eq(after.text, "")
}

///|
test "undo restores selection and code draft" {
  let model = @app.initial_model()
  let draft = model.code_draft
  // 删除「按钮」：选中子程序被清、草稿清空
  let deleted = apply(model, DeleteControl("按钮"))
  assert_eq(deleted.selected_handler, "")
  assert_eq(deleted.code_draft, "")
  // 撤销：子程序与草稿一起回来
  let undone = apply(deleted, Undo)
  assert_eq(undone.selected_handler, model.selected_handler)
  assert_eq(undone.code_draft, draft)
}

///|
test "new edit clears redo stack" {
  let base = @app.initial_model()
  let added = apply(base, AddControl(@ir.Button))
  let undone = apply(added, Undo)
  assert_true(undone.redo_stack.length() > 0)
  // 新变更（非重做）清空重做栈
  let edited = apply(undone, AddControl(@ir.Label))
  assert_eq(edited.redo_stack.length(), 0)
  assert_eq(
    apply(edited, Redo).program.controls.length(),
    edited.program.controls.length(),
  )
}

///|
test "undo depth is capped" {
  let mut iter = @app.initial_model()
  let mut i = 0
  while i < @app.UNDO_DEPTH + 10 {
    iter = apply(iter, AddControl(@ir.Label))
    i = i + 1
  }
  assert_eq(iter.undo_stack.length(), @app.UNDO_DEPTH)
}

///|
test "duplicate control copies props with offset and undo removes it" {
  let added = apply(@app.initial_model(), AddControl(@ir.ListBox))
  let source = added.program.controls[added.program.controls.length() - 1]
  let with_items = apply(added, SetControlItems(source.name, "铅笔\n橡皮"))
  let copied = apply(with_items, DuplicateControl(source.name))
  assert_true(copied.selected_control != source.name)
  let copy = @ir.find_control(copied.program, copied.selected_control).unwrap()
  assert_eq(copy.kind.tag(), source.kind.tag())
  assert_eq(copy.x, source.x + 16)
  assert_eq(copy.y, source.y + 16)
  assert_eq(copy.items.length(), 2)
  // 撤销复制 → 控件消失、选中回到原件
  let undone = apply(copied, Undo)
  assert_true(@ir.find_control(undone.program, copy.name) is None)
  assert_eq(undone.selected_control, source.name)
}

///|
test "undo reverts accepted proposal" {
  let model = @app.initial_model()
  let prompted = apply(model, SetPrompt("做一个查询成绩的表单"))
  let generated = apply(prompted, GenerateProposal)
  // 假模型确定性：样例相关 prompt 应产出待采纳提案
  match generated.pending {
    None => fail("假模型应产出待采纳提案")
    Some(_) => ()
  }
  let accepted = apply(generated, AcceptProposal)
  assert_true(accepted.pending is None)
  assert_true(accepted.undo_stack.length() > model.undo_stack.length())
  let undone = apply(accepted, Undo)
  assert_eq(
    @ir.program_signature(undone.program),
    @ir.program_signature(model.program),
  )
}

///|
test "template switch is undoable" {
  let model = @app.initial_model()
  let switched = apply(model, SelectTemplate(2))
  assert_true(
    @ir.program_signature(switched.program) !=
    @ir.program_signature(model.program),
  )
  let undone = apply(switched, Undo)
  assert_eq(
    @ir.program_signature(undone.program),
    @ir.program_signature(model.program),
  )
}

///|
test "single step pauses auto-advance and walks one instruction" {
  let model = apply(@app.initial_model(), RunStart)
  let started = match model.run {
    Some(run) => run
    None => fail("应进入运行态")
  }
  let steps_at_start = started.state.steps
  // 单步：恰好走一条指令
  let stepped = apply(model, RunStep)
  let after_step = stepped.run.unwrap()
  assert_eq(after_step.state.steps, steps_at_start + 1)
  assert_true(after_step.single_step)
  assert_true(after_step.state.status is @studio_lang.Running)
  // 计时器 tick 在单步模式下不推进
  let ticked = apply(stepped, RunTick)
  assert_eq(ticked.run.unwrap().state.steps, steps_at_start + 1)
  // 再走一步仍只 +1
  let stepped_again = apply(ticked, RunStep)
  assert_eq(stepped_again.run.unwrap().state.steps, steps_at_start + 2)
  // 继续：恢复自动推进直至完成
  let resumed = apply(stepped_again, RunResume)
  assert_true(!resumed.run.unwrap().single_step)
  let finished = drain(resumed)
  assert_true(finished.run.unwrap().state.status is @studio_lang.Completed)
}

///|
test "variables table data fills as the run declares variables" {
  // 点名册样例声明了变量：运行到完成后 vars 非空
  let model = apply(@app.initial_model(), SelectTemplate(1))
  let started = apply(model, RunStart)
  let finished = drain(started)
  match finished.run {
    None => fail("点名册应可运行")
    Some(run) => {
      let mut count = 0
      for _name in run.state.vars.keys() {
        count = count + 1
      }
      assert_true(count > 0)
    }
  }
}

///|
test "proposal history records accept and reject" {
  let model = @app.initial_model()
  assert_eq(model.proposal_history.length(), 0)
  // 采纳一条
  let accepted = apply(
    apply(
      apply(model, SetPrompt("做一个查询成绩的表单")),
      GenerateProposal,
    ),
    AcceptProposal,
  )
  assert_eq(accepted.proposal_history.length(), 1)
  assert_true(accepted.proposal_history[0].accepted)
  assert_eq(accepted.proposal_history[0].seq, 1)
  // 再生成并拒绝一条
  let rejected = apply(
    apply(
      apply(accepted, SetPrompt("做一个借书登记的表单")),
      GenerateProposal,
    ),
    RejectProposal,
  )
  assert_eq(rejected.proposal_history.length(), 2)
  assert_true(!rejected.proposal_history[1].accepted)
  assert_eq(rejected.proposal_history[1].seq, 2)
  // 摘要非空（来自提案 summary）
  assert_true(rejected.proposal_history[1].summary != "")
}

///|
test "help cheatsheet is generated from the keyword catalog" {
  let model = @app.initial_model()
  // 模式可切换且视图可构建（帮助页数据来自 studio_lang 关键字目录）
  let helped = apply(model, SetMode(@app.ModeHelp))
  assert_true(helped.mode is ModeHelp)
  let view = @app.view(helped)
  ignore(view)
  // 内建目录条目数（14 个内建，含 2 个闸门）
  assert_eq(@studio_lang.builtin_catalog().length(), 14)
}

///|
test "audit jump lands on the matching block" {
  let model = apply(@app.initial_model(), RunStart)
  let finished = drain(model)
  // 运行完成后：点击第一条审计 → 积木视图 + 对应语句被选中
  let jumped = apply(finished, AuditJump(0))
  assert_true(jumped.mode is ModeBlocks)
  // 链条即语句列表（事件头单独渲染）→ 应选中下标 0
  assert_eq(jumped.selected_block, 0)
  // 草稿预填该语句的 DSL
  assert_true(jumped.block_draft.contains("设置文本"))
  // 越界索引：切视图但不选中
  let safe = apply(finished, AuditJump(99))
  assert_true(safe.mode is ModeBlocks)
  assert_eq(safe.selected_block, -1)
}

///|
test "redo on empty stack is a safe no-op" {
  // 键盘快捷键（Ctrl/Cmd+Z）在无撤销历史时误触也必须无害
  let model = @app.initial_model()
  let redone = apply(model, Redo)
  assert_eq(
    @ir.program_signature(redone.program),
    @ir.program_signature(model.program),
  )
  assert_true(redone.redo_stack.is_empty())
  let undone_twice = apply(
    apply(apply(model, AddControl(@ir.Label)), Undo),
    Undo,
  )
  // 只有一条撤销历史时，第二次 Undo 也是 no-op
  assert_eq(
    @ir.program_signature(undone_twice.program),
    @ir.program_signature(model.program),
  )
}

///|
test "undo after block commit reverts the statement (snapshot not poisoned)" {
  let model = @app.initial_model()
  // 积木编辑：把唯一语句改成另一条并提交
  let committed = apply(
    apply(
      apply(model, SelectBlock(0)),
      EditBlock("设置文本(显示, \"改过\")"),
    ),
    CommitBlock,
  )
  match @app.current_handler(committed).unwrap().body[0] {
    @ir.Call(_, args) =>
      match args[1] {
        @ir.StrLit(text) => assert_true(text.contains("改过"))
        _ => fail("提交后应为新字符串字面量")
      }
    _ => fail("提交后应仍是 Call")
  }
  // 撤销：程序应与最初逐字段一致
  // （若快照被就地手术污染，这里会拿到提交后的语句而失败）
  let undone = apply(committed, Undo)
  assert_eq(
    @ir.program_signature(undone.program),
    @ir.program_signature(model.program),
  )
}

///|
test "blocks canvas layout, hit test and drop slot" {
  // 找一个选中子程序含嵌套语句的样例（深度 ≥ 1 才能断言缩进）
  let samples = @proposals.all_samples()
  let mut chosen : @app.Model? = None
  let mut idx = 0
  for sample in samples {
    // 扫描该样例全部 handler，找到第一个有嵌套语句的
    for handler in sample.handlers {
      let keyed = @app.handler_key(handler.control_name, handler.event.tag())
      let chain = @blocks.block_chain(handler.body)
      let mut has_depth = false
      for item in chain {
        if item.depth >= 1 {
          has_depth = true
        }
      }
      if has_depth {
        chosen = Some(
          apply(
            apply(@app.initial_model(), SelectTemplate(idx)),
            SelectHandler(keyed),
          ),
        )
        break
      }
    }
    if chosen is Some(_) {
      break
    }
    idx = idx + 1
  }
  let model = match chosen {
    Some(m) => m
    None => fail("样例里应存在含嵌套的子程序")
  }
  ignore(idx)
  let blocks = @app.block_chain_of(model)
  assert_true(blocks.length() > 3)
  let rects = @app.blocks_item_rects(blocks)
  // 布局：逐行 40px 步进，深度缩进
  assert_eq(rects[0].origin.y, 10.0)
  assert_eq(rects[1].origin.y, 50.0)
  let mut deepest = 0
  let mut deep_index = 0
  let mut i = 0
  for item in blocks {
    if item.depth > deepest {
      deepest = item.depth
    }
    if item.depth == deepest {
      deep_index = i
    }
    i = i + 1
  }
  assert_true(rects[deep_index].origin.x > rects[0].origin.x)
  // 命中：第一行中心命中 0；画布右上角空白命中 -1
  assert_eq(
    @app.blocks_hit_index(
      blocks,
      rects[0].origin.x + 10.0,
      rects[0].origin.y + 10.0,
    ),
    0,
  )
  assert_eq(@app.blocks_hit_index(blocks, 460.0, 5.0), -1)
  // 落槽：同层列表内按兄弟中心线计数
  let first_path = blocks[0].path
  let list_path = @app.blocks_parent_of(first_path)
  assert_eq(
    @app.blocks_drop_slot(blocks, list_path, rects[0].origin.y + 1.0, rects),
    0,
  )
  assert_eq(
    @app.blocks_drop_slot(blocks, list_path, rects[1].origin.y + 30.0, rects),
    1,
  )
}

///|
test "blocks canvas drag reorders siblings and is undoable" {
  // 口算训练营：取一个有 ≥2 条顶层语句的子程序
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let blocks = @app.block_chain_of(model)
  assert_true(blocks.length() >= 2)
  let first_text = blocks[0].text
  let second_text = blocks[1].text
  // 按上第一块 → 拖到落槽 2（原下标 1 之后）→ 松手
  let rects = @app.blocks_item_rects(blocks)
  let pressed = apply(
    model,
    BlocksCanvasPress(rects[0].origin.x + 10.0, rects[0].origin.y + 10.0),
  )
  assert_true(pressed.block_drag is Some(_))
  let dragged = apply(
    pressed,
    BlocksCanvasDragTo(rects[1].origin.x + 10.0, rects[1].origin.y + 38.0),
  )
  assert_eq(dragged.block_drag.unwrap().to, 2)
  let released = apply(dragged, BlocksCanvasRelease)
  // 重排生效：原第二块现在在最前
  let after = @app.block_chain_of(released)
  assert_eq(after[0].text, second_text)
  assert_eq(after[1].text, first_text)
  // 选中跟随被移动的语句（新链下标 1）
  assert_eq(released.selected_block, 1)
  // 撤销恢复原序
  let undone = apply(released, Undo)
  assert_eq(@app.block_chain_of(undone)[0].text, first_text)
}
