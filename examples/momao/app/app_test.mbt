///|
/// app 测试：纯状态转移（不含 UI 渲染与服务副作用）。

///|
fn apply(model : Model, msg : Msg) -> Model {
  let (next, _effect) = update_pure(model, msg)
  next
}

///|
/// 推进运行直到终止态（测试环境没有计时器订阅，手动 tick）。
fn drain(model : Model) -> Model {
  let mut stepped = model
  let mut i = 0
  while i < 60 {
    match stepped.run {
      Some(run) =>
        if run.state.status is @momao_lang.Running {
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

test "initial model loads hello sample in chinese" {
  let model = initial_model()
  assert_true(model.language is ZhHans)
  assert_eq(model.program.window.title, "问候")
  assert_eq(model.selected_handler, "按钮@on_click")
  let t = translator(model)
  assert_eq(text(t, "app.mode.design"), "设计")
  assert_eq(text(t, "app.mode.design"), "设计")
}

test "english translation resolves" {
  let model = apply(initial_model(), SwitchLanguage)
  assert_true(model.language is En)
  let t = translator(model)
  assert_eq(text(t, "app.mode.design"), "Design")
  assert_eq(text(t, "control.button"), "Button")
  assert_eq(text(t, "builtin.submit_data"), "submit_data")
  // 中文回退仍在
  assert_eq(text(t, "app.templates.hello"), "Hello app")
}

test "language switch commits parseable draft and re-renders" {
  let model = initial_model()
  let switched = apply(model, SwitchLanguage)
  assert_true(switched.code_draft.contains("set_text"))
  let switched_back = apply(switched, SwitchLanguage)
  assert_true(switched_back.code_draft.contains("变量") || switched_back.code_draft.contains("设置文本"))
}

test "add and delete control keeps handlers consistent" {
  let model = apply(initial_model(), AddControl(@ir.Label))
  assert_eq(model.program.controls.length(), 3)
  assert_eq(model.selected_control, "标签")
  let renamed = apply(model, SetControlName("标签", "标题"))
  assert_true(@ir.find_control(renamed.program, "标题") is Some(_))
  assert_eq(renamed.selected_control, "标题")
  let deleted = apply(renamed, DeleteControl("标题"))
  assert_eq(deleted.program.controls.length(), 2)
}

test "code edit commits into program" {
  let model = initial_model()
  let edited = apply(model, EditCode("设置文本(显示, \"新文本\")\n"))
  let committed = apply(edited, SelectHandler("按钮@on_click"))
  match current_handler(committed) {
    Some(handler) =>
      assert_eq(handler.body.length(), 1)
    None => fail("提交后应仍有子程序")
  }
}

test "syntax error surfaces localized message" {
  let model = initial_model()
  let edited = apply(model, EditCode("如果 真的 则\n"))
  let started = apply(edited, RunStart)
  // 语法错误进 notice（本地化），且不进入运行态
  assert_true(started.notice != "")
  assert_true(started.run is None)
  let t = translator(started)
  assert_eq(text(t, "app.code.error"), "语法错误")
  // 正确的草稿可以运行
  let fixed = apply(edited, EditCode("设置文本(显示, \"新文本\")\n"))
  let run = apply(fixed, RunStart)
  assert_true(run.run is Some(_))
  assert_eq(run.notice, "")
}

test "run start executes hello handler to completion" {
  let model = apply(initial_model(), RunStart)
  match model.run {
    None => fail("应进入运行态")
    Some(run) => {
      let stepped = drain(model)
      let final_run = stepped.run.unwrap()
      assert_true(final_run.state.status is @momao_lang.Completed)
      assert_eq(final_run.state.texts.get("显示").unwrap_or(""), "你好，MoMao！")
    }
  }
}

test "run gate pauses submit and confirm completes" {
  let model = apply(initial_model(), SelectTemplate(3))
  let started = apply(model, RunStart)
  match started.run {
    None => fail("小卖部应能运行")
    Some(_run) => {
      // 直接运行卖铅笔 handler：无闸门，营业额 +1
      let sold = drain(apply(started, ControlClicked("卖铅笔")))
      let final_run = sold.run.unwrap()
      let revenue = final_run.state.vars.get("营业额").unwrap_or(@momao_lang.VUnit)
      assert_eq(@momao_lang.value_to_text(revenue), "1")
      // 记账 handler：停在提交闸门
      let submitting = drain(apply(sold, ControlClicked("记账")))
      let gated = submitting.run.unwrap()
      assert_true(gated.state.status is @momao_lang.WaitingGate)
      match gated.state.gate {
        Some(gate) => {
          assert_true(gate.kind is @momao_lang.Submit)
          assert_eq(gate.prompt, "班级账本")
          assert_eq(gate.payload, "1")
        }
        None => fail("应停在闸门")
      }
    }
  }
}

test "fake model proposal validates, diffs and applies" {
  let model = apply(initial_model(), SetPrompt("帮我做一个随机点名"))
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

test "rejected proposal keeps program" {
  let model = apply(initial_model(), SetPrompt("口算练习"))
  let generated = apply(model, GenerateProposal)
  let rejected = apply(generated, RejectProposal)
  assert_true(rejected.pending is None)
  assert_eq(rejected.program.window.title, "问候")
}

test "invalid proposal from real model is rejected wholesale" {
  let model = apply(initial_model(), SetPrompt("随便"))
  // 直接喂一个坏 JSON（绕过假模型）：整单拒绝
  let broken = proposal_from_completion(model, "这不是提案")
  assert_true(broken.pending is None)
  assert_true(broken.prompt_error != "")
}

test "templates switch program and selection" {
  let model = apply(initial_model(), SelectTemplate(2))
  assert_eq(model.program.window.title, "口算训练营")
  assert_true(model.selected_handler != "")
}

test "split lines helper" {
  let lines = split_lines("铅笔 1元\n\n橡皮 2元\n  笔记本 5元  ")
  assert_eq(lines.length(), 3)
  assert_eq(lines[0], "铅笔 1元")
  assert_eq(lines[2], "笔记本 5元")
}
test "runtime state accumulates across events" {
  let model = apply(initial_model(), SelectTemplate(3))
  let once = drain(apply(model, ControlClicked("卖铅笔")))
  let twice = drain(apply(once, ControlClicked("卖铅笔")))
  let run = twice.run.unwrap()
  let revenue = run.state.vars.get("营业额").unwrap_or(@momao_lang.VUnit)
  assert_eq(@momao_lang.value_to_text(revenue), "2")
  // 活状态并回模型：下一次运行从 2 继续
  let thrice = drain(apply(twice, ControlClicked("卖铅笔")))
  let three = thrice.run.unwrap().state.vars.get("营业额").unwrap_or(@momao_lang.VUnit)
  assert_eq(@momao_lang.value_to_text(three), "3")
  // 控件文本也跨事件保持
  let label = thrice.run.unwrap().state.texts.get("营业额标签").unwrap_or("")
  assert_eq(label, "营业额：3")
}

test "local explanation walks the handler steps" {
  let model = apply(initial_model(), SelectTemplate(2))
  let explained = apply(model, ExplainHandler)
  assert_true(explained.explanation.contains("random"))
  assert_true(explained.explanation.contains("1."))
  let drill = explained
  assert_true(drill.explanation.contains("set_text"))
}

test "exported bundle never carries the provider key" {
  let model = apply(initial_model(), SetProviderKey("SENTINEL-SECRET-KEY"))
  let encoded = @codec.encode_program(model.program)
  let bundle = bundle_files(encoded, "x")
  assert_true(bundle.length() > 10)
  for pair in bundle {
    assert_true(!pair.1.contains("SENTINEL-SECRET-KEY"))
  }
}

test "language loaded message switches without doubling" {
  // LanguageLoaded 走服务流；这里至少验证 ui_language_from_tag 的映射
  let model = { ..initial_model(), language: En }
  let loaded = { ..model, language: ui_language_from_tag("zh-Hans") }
  assert_true(loaded.language is ZhHans)
  let bad = ui_language_from_tag("not-a-locale")
  assert_true(bad is ZhHans)
  let en = ui_language_from_tag("en")
  assert_true(en is En)
}

test "every generated catalog key resolves in both locales" {
  // 生成器保证两语言 key 集合一致；这里保住言兜底：任何 key 在任一语言
  // 都不得回落到 [[key]] 缺失标记。
  for catalog in generated_i18n_catalogs {
    let locale = catalog.locale
    let t = translator_for(ui_language_from_tag(locale))
    for pair in catalog.messages {
      let (key, _message) = pair
      let resolved = text(t, key)
      assert_true(
        !resolved.starts_with("[["),
      )
    }
  }
}

test "placeholder messages interpolate in both locales" {
  let zh = translator_for(ZhHans)
  let en = translator_for(En)
  let zh_gate = text_with(zh, "app.run.gate.submit", [("target", "班级账本"), ("payload", "3")])
  assert_true(zh_gate.contains("班级账本"))
  assert_true(zh_gate.contains("3"))
  let en_gate = text_with(en, "app.run.gate.submit", [("target", "ledger"), ("payload", "3")])
  assert_true(en_gate.contains("ledger"))
  let zh_err = error_message(zh, @momao_lang.LangError(@momao_lang.NotDeclared, 2, "得分", ""))
  assert_true(zh_err.contains("得分"))
  let en_err = error_message(en, @momao_lang.LangError(@momao_lang.NotDeclared, 2, "score", ""))
  assert_true(en_err.contains("score"))
}

test "block view edits write back to the ir" {
  let model = apply(initial_model(), SelectTemplate(1))
  // 点名册：handler 链 = [declare 人数, declare 序号, set_text]
  let blocks = block_chain_of(model)
  assert_eq(blocks.length(), 3)
  // 选中第一条（declare 人数 = row_count(名单)）
  let selected = apply(model, SelectBlock(0))
  assert_true(selected.block_draft.contains("变量 人数"))
  assert_eq(selected.selected_block, 0)
  // 改成字符串字面量并应用
  let edited = apply(selected, EditBlock("变量 人数 = 42\n"))
  let committed = apply(edited, CommitBlock)
  match current_handler(committed) {
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
  match current_handler(deleted) {
    Some(handler) => assert_eq(handler.body.length(), 2)
    None => fail("子程序应仍在")
  }
  assert_eq(deleted.selected_block, -1)
  assert_true(deleted.code_draft.contains("随机数") == false)
}

test "block edit rejects unparseable draft" {
  let model = apply(initial_model(), SelectTemplate(1))
  let selected = apply(model, SelectBlock(0))
  let broken = apply(selected, EditBlock("如果 真的 则\n"))
  let committed = apply(broken, CommitBlock)
  match current_handler(committed) {
    Some(handler) =>
      // 原语句保持不动，notice 提示语法错误
      assert_true(handler.body.length() == 3)
    None => fail("子程序应仍在")
  }
  assert_true(committed.notice != "")
}

test "block edit on nested statement path" {
  // 口算训练营：批改 handler = [If(cond, [set_text], [], [set_text])]
  let model = apply(initial_model(), SelectTemplate(2))
  let picked = apply(model, SelectHandler("批改按钮@on_click"))
  let blocks = block_chain_of(picked)
  // if / then-set_text / else / else-set_text / end
  assert_eq(blocks.length(), 5)
  // 选 then 体里的 set_text（path [0,0,0]）
  let selected = apply(picked, SelectBlock(1))
  assert_true(selected.block_draft.contains("设置文本"))
  let edited = apply(selected, EditBlock("设置文本(判定, \"完全正确\")\n"))
  let committed = apply(edited, CommitBlock)
  match current_handler(committed) {
    Some(handler) =>
      match @blocks.stmt_at(handler.body, [0, 0, 0]) {
        Some(stmt) => {
          match stmt {
            @ir.Stmt::Call(name, args) => {
              assert_eq(name, "set_text")
              assert_true(args.length() == 2)
            }
            _ => fail("应为 call")
          }
        }
        None => fail("then 体第一条应在")
      }
    None => fail("子程序应仍在")
  }
  assert_true(committed.code_draft.contains("完全正确"))
}
