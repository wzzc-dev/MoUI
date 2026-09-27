///|
test "假模型：关键词路由到计算器并校验通过" {
  match fake_generate_from_prompt("做一个加法计算器") {
    Ok(project) => {
      assert_true(project.name == "加法计算器")
      assert_true(project.controls.length() == 5)
      match project.handler_of("计算按钮", "被单击") {
        Some(source) => assert_true(check_source(source) is None)
        None => abort("计算器应有被单击子程序")
      }
    }
    Err(errors) =>
      abort("假模型提案应通过校验：\{validation_summary(errors)}")
  }
}

///|
test "假模型：兜底问候模板" {
  match fake_generate_from_prompt("随便做个应用") {
    Ok(project) => assert_true(project.name == "问候应用")
    Err(errors) =>
      abort("兜底模板应通过校验：\{validation_summary(errors)}")
  }
}

///|
test "提案解码：合法提案接受" {
  let proposal = "{\"version\":1,\"window\":{\"title\":\"计算器\"},\"controls\":[{\"id\":1,\"name\":\"数1\",\"kind\":\"TextField\",\"x\":40,\"y\":40,\"width\":120,\"height\":36,\"text\":\"0\"},{\"id\":2,\"name\":\"按钮1\",\"kind\":\"Button\",\"x\":40,\"y\":100,\"width\":120,\"height\":40,\"text\":\"算\"}],\"handlers\":[{\"control\":\"按钮1\",\"event\":\"被单击\",\"source\":\"设置文本(\\\"数1\\\", \\\"3\\\")\"}],\"next_id\":3}"
  match decode_proposal(proposal) {
    Ok(project) => {
      assert_true(project.window_title == "计算器")
      assert_true(project.controls.length() == 2)
    }
    Err(errors) =>
      abort("合法提案应通过：\{validation_summary(errors)}")
  }
}

///|
test "提案解码：未知类型与非法语法拒绝" {
  let bad_kind = "{\"version\":1,\"controls\":[{\"id\":1,\"name\":\"神秘\",\"kind\":\"WebView\",\"x\":0,\"y\":0,\"width\":10,\"height\":10,\"text\":\"\"}],\"handlers\":[]}"
  match decode_proposal(bad_kind) {
    Err(errors) =>
      assert_true(errors.any(fn(error) { error is UnknownKind(_) }))
    Ok(_) => abort("未知类型应被拒绝")
  }
  let bad_syntax = "{\"version\":1,\"controls\":[{\"id\":1,\"name\":\"按钮1\",\"kind\":\"Button\",\"x\":0,\"y\":0,\"width\":10,\"height\":10,\"text\":\"好\"}],\"handlers\":[{\"control\":\"按钮1\",\"event\":\"被单击\",\"source\":\"如果 真 则\"}]}"
  match decode_proposal(bad_syntax) {
    Err(errors) =>
      assert_true(errors.any(fn(error) { error is BadSyntax(_, _, _) }))
    Ok(_) => abort("非法语法应被拒绝")
  }
  match decode_proposal("{\"version\":2}") {
    Err(errors) => assert_true(errors[0] is UnsupportedVersion)
    Ok(_) => abort("版本不符应被拒绝")
  }
}

///|
test "真实生成回路：从带围栏散文中提取提案" {
  let provider_text = "好的，这是你要的应用：\n```json\n{\"version\":1,\"window\":{\"title\":\"问候\"},\"controls\":[{\"id\":1,\"name\":\"姓名框\",\"kind\":\"TextField\",\"x\":40,\"y\":40,\"width\":200,\"height\":36,\"text\":\"世界\"}],\"handlers\":[]}\n```\n以上"
  match finish_real_generation(provider_text) {
    Ok(project) => {
      assert_true(project.window_title == "问候")
      assert_true(project.controls.length() == 1)
    }
    Err(errors) =>
      abort("散文包裹的提案应被提取：\{validation_summary(errors)}")
  }
  match finish_real_generation("抱歉，我无法生成") {
    Err(errors) => assert_true(errors[0] is InvalidJson)
    Ok(_) => abort("无 JSON 的回复应被拒绝")
  }
}

///|
test "系统提示词覆盖 schema 关键要素" {
  let prompt = proposal_system_prompt()
  assert_true(prompt.contains("version"))
  assert_true(prompt.contains("被单击"))
  assert_true(prompt.contains("取数值"))
  assert_true(prompt.contains("结束"))
}

///|
test "运行会话：信息框与实时文本" {
  let session = RunSession::start(sample_project())
  match
    session.run_source(
      "设置文本(\"姓名框\", \"小易\")\n信息框(\"你好，\" + 取文本(\"姓名框\"))",
    ) {
    Ok(next) => {
      assert_true(next.text_of("姓名框", "") == "小易")
      match next.message {
        Some(text) => assert_true(text == "你好，小易")
        None => abort("信息框应记录横幅")
      }
    }
    Err(error) => abort("运行会话脚本应成功：\{error.message()}")
  }
  // 原会话不被运行副作用污染（不可变值语义）
  assert_true(session.text_of("姓名框", "") == "")
  assert_true(session.text_of("问候按钮", "") == "打个招呼")
}
