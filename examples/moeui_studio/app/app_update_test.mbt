///|
/// 应用层 update 测试：设计交互、属性编辑、代码编辑、模式切换、AI 提案。

///|
fn model_for_test() -> Model {
  { ..Model::new(), project: sample_project(), }
}

///|
fn step(model : Model, msg : Msg) -> Model {
  let (next, _) = update_pure(model, msg)
  next
}

///|
test "初始模型包含示例项目" {
  let model = Model::new()
  assert_true(model.project.controls.length() == 3)
  assert_true(model.mode is Design)
  assert_true(model.fake_provider)
}

///|
test "添加控件：自动命名、级联摆放、选中" {
  let model = step(model_for_test(), AddControl(Button))
  assert_true(model.project.controls.length() == 4)
  let added = match model.selection {
    Some(id) => model.project.find_control(id)
    None => None
  }
  match added {
    Some(control) => {
      assert_true(control.name == "按钮1")
      assert_true(control.kind is Button)
      assert_true(control.width == 120.0)
    }
    None => abort("新控件应被选中")
  }
  // 再加一个同名自动递增
  let model2 = step(model, AddControl(Button))
  let count = model2.project.controls
    .filter(fn(c) { c.name.has_prefix("按钮") })
    .length()
  assert_true(count == 2)
}

///|
test "画布命中与拖动移动" {
  let model = model_for_test()
  // 问候按钮位于 (40, 160) 大小 120x40
  let pressed = step(model, CanvasPress(60.0, 170.0))
  match pressed.selection {
    Some(id) => {
      let control = pressed.project.find_control(id).unwrap()
      assert_true(control.name == "问候按钮")
      match pressed.drag {
        DraggingControl(_, offset_x, offset_y) => {
          // 偏移 = 控件位置 − 按点（保持抓取点）
          assert_true(offset_x == -20.0)
          assert_true(offset_y == -10.0)
        }
        _ => abort("按下命中后应进入拖动状态")
      }
      // 拖到 (200, 100)：控件位置 = 目标 + 偏移（抓取点跟随）
      let dragged = step(pressed, CanvasDragTo(200.0, 100.0))
      let control2 = dragged.project.find_control(id).unwrap()
      assert_true(control2.x == 180.0)
      assert_true(control2.y == 90.0)
      // 松开后拖动结束
      let released = step(dragged, CanvasRelease(220.0, 110.0))
      assert_true(released.drag is DragIdle)
    }
    None => abort("按下应选中按钮")
  }
  // 按空白取消选中
  let blank = step(model_for_test(), CanvasPress(500.0, 400.0))
  assert_true(blank.selection is None)
}

///|
test "拖动越界被夹在设计画布内" {
  let model = model_for_test()
  let pressed = step(model, CanvasPress(60.0, 170.0))
  let dragged = step(pressed, CanvasDragTo(-500.0, 900.0))
  let control = match dragged.selection {
    Some(id) => dragged.project.find_control(id).unwrap()
    None => abort("应保持选中")
  }
  assert_true(control.x == 0.0)
  assert_true(control.y == 480.0 - control.height)
}

///|
test "属性编辑：文本与数字、非法名称被拒" {
  let model = model_for_test()
  let id = model.project.find_control_by_name("问候按钮").unwrap().id
  let renamed = step(model, PropInput(id, PropName, "打招呼"))
  assert_true(renamed.project.find_control(id).unwrap().name == "打招呼")
  // 重名被拒
  let rejected = step(renamed, PropInput(id, PropName, "标题"))
  assert_true(rejected.project.find_control(id).unwrap().name == "打招呼")
  assert_true(rejected.notice.contains("不可用"))
  // 数字属性
  let moved = step(renamed, PropInput(id, PropX, "300"))
  assert_true(moved.project.find_control(id).unwrap().x == 300.0)
  // 非法数字被忽略
  let ignored = step(moved, PropInput(id, PropX, "abc"))
  assert_true(ignored.project.find_control(id).unwrap().x == 300.0)
  // 文本属性
  let texted = step(ignored, PropInput(id, PropText, "点我"))
  assert_true(texted.project.find_control(id).unwrap().text == "点我")
}

///|
test "删除控件连带删除其子程序" {
  let model = model_for_test()
  // 选中问候按钮（40,160 起 120x40）
  let selected = step(model, CanvasPress(60.0, 170.0))
  let deleted = step(selected, DeleteSelected)
  assert_true(deleted.project.find_control_by_name("问候按钮") is None)
  assert_true(deleted.project.handlers.is_empty())
}

///|
test "代码编辑直接写回项目并联动语法检查" {
  let model = step(model_for_test(), EditHandler("问候按钮", "被单击"))
  match model.editing_handler {
    Some((control, event)) => {
      assert_true(control == "问候按钮")
      assert_true(event == "被单击")
      assert_true(model.mode is Code)
    }
    None => abort("应进入编辑状态")
  }
  let written = step(
    model,
    HandlerCodeInput("问候按钮", "被单击", "信息框(\"改好了\")"),
  )
  assert_true(
    written.project.handler_of("问候按钮", "被单击") ==
    Some("信息框(\"改好了\")"),
  )
}

///|
test "新建子程序带起始代码" {
  let model = model_for_test()
  let created = step(model, NewHandler("姓名框", "内容改变"))
  assert_true(created.project.handler_of("姓名框", "内容改变").is_some())
  assert_true(created.mode is Code)
}

///|
test "运行模式：按钮触发子程序，信息框进横幅，状态独立" {
  let model = step(model_for_test(), StartRun)
  assert_true(model.mode is Run)
  let clicked = step(model, RunButtonClicked("问候按钮"))
  // 姓名框初始为空 → 陌生人
  let session = clicked.run.unwrap()
  match session.message {
    Some(content) => assert_true(content == "你好，陌生人！")
    None => abort("信息框应显示问候")
  }
  // 设计模型未被污染
  assert_true(
    model.project.handler_of("问候按钮", "被单击") ==
    clicked.project.handler_of("问候按钮", "被单击"),
  )
  // 关闭横幅
  let dismissed = step(clicked, DismissMessage)
  assert_true(dismissed.run.unwrap().message is None)
  // 停止丢弃会话
  let stopped = step(dismissed, StopRun)
  assert_true(stopped.run is None)
  assert_true(stopped.mode is Design)
}

///|
test "运行模式：设置文本联动取文本" {
  let model = step(model_for_test(), StartRun)
  let typed = step(model, RunTextChanged("姓名框", "小易"))
  let clicked = step(typed, RunButtonClicked("问候按钮"))
  match clicked.run.unwrap().message {
    Some(content) => assert_true(content == "你好，小易！")
    None => abort("应读到输入的名字")
  }
}

///|
test "内容改变事件被触发" {
  let model = model_for_test()
  let model = step(model, NewHandler("姓名框", "内容改变"))
  let model = step(
    model,
    HandlerCodeInput(
      "姓名框", "内容改变", "设置文本(\"标题\", 取文本(\"姓名框\"))",
    ),
  )
  let model = step(model, StartRun)
  let typed = step(model, RunTextChanged("姓名框", "小易"))
  assert_true(typed.run.unwrap().text_of("标题", "") == "小易")
}

///|
test "AI 提案：生成、采纳、取消" {
  let model = step(model_for_test(), PromptInput("做一个加法计算器"))
  let generated = step(model, GenerateFromPrompt)
  assert_true(generated.pending_proposal is Some(_))
  assert_true(generated.notice.contains("校验通过"))
  let accepted = step(generated, AcceptProposal)
  assert_true(accepted.project.name == "加法计算器")
  assert_true(accepted.pending_proposal is None)
  let cancelled = step(step(accepted, GenerateFromPrompt), CancelProposal)
  assert_true(cancelled.pending_proposal is None)
}

///|
test "真实 provider 回路收尾" {
  let model = model_for_test()
  let text = "{\"version\":1,\"window\":{\"title\":\"建议\"},\"controls\":[{\"id\":1,\"name\":\"按钮1\",\"kind\":\"Button\",\"x\":40,\"y\":40,\"width\":120,\"height\":40,\"text\":\"好\"}],\"handlers\":[{\"control\":\"按钮1\",\"event\":\"被单击\",\"source\":\"信息框(\\\"好\\\")\"}],\"next_id\":2}"
  let finished = step(model, RealGenerationFinished(Ok(text)))
  assert_true(finished.pending_proposal is Some(_))
  let failed = step(model, RealGenerationFinished(Err("网络错误")))
  assert_true(failed.notice.contains("网络错误"))
}

///|
test "模式切换与运行会话生命周期" {
  let model = step(model_for_test(), SwitchMode(Code))
  assert_true(model.mode is Code)
  let back = step(model, SwitchMode(Design))
  assert_true(back.mode is Design)
  assert_true(back.run is None)
}
