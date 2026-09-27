///|
test "示例项目自校验通过" {
  let errors = validate_project(sample_project())
  assert_true(errors.is_empty())
}

///|
test "编解码往返保真" {
  let project = sample_project()
  let decoded = match decode_project(encode_project(project)) {
    Ok(project) => project
    Err(errors) => abort("往返解码失败：\{validation_summary(errors)}")
  }
  assert_true(decoded.name == project.name)
  assert_true(decoded.window_title == project.window_title)
  assert_true(decoded.controls.length() == project.controls.length())
  assert_true(decoded.handlers.length() == project.handlers.length())
  assert_true(
    decoded.handler_of("问候按钮", "被单击") ==
    project.handler_of("问候按钮", "被单击"),
  )
  let first = decoded.controls[0]
  assert_true(first.name == "标题")
  assert_true(first.kind is Label)
  assert_true(first.x == 40.0)
}

///|
test "格式门卫与版本拒绝" {
  match decode_project("{\"format\":\"other\",\"version\":1}") {
    Err(errors) => assert_true(errors[0] is BadFormat)
    Ok(_) => abort("format 错误应被拒绝")
  }
  let body = encode_project(sample_project())
  let mutated = body.replace(old="\"version\":1", new="\"version\":99")
  match decode_project(mutated) {
    Err(errors) => assert_true(errors[0] is UnsupportedVersion)
    Ok(_) => abort("版本错误应被拒绝")
  }
  match decode_project("不是 JSON") {
    Err(errors) => assert_true(errors[0] is InvalidJson)
    Ok(_) => abort("非法 JSON 应被拒绝")
  }
}

///|
test "未知类型与重名与坏语法被拒绝" {
  let project : FormProject = {
    name: "坏项目",
    window_title: "窗口",
    controls: [
      {
        id: 1,
        name: "按钮1",
        kind: Button,
        x: 0.0,
        y: 0.0,
        width: 100.0,
        height: 40.0,
        text: "好",
      },
      {
        id: 2,
        name: "按钮1",
        kind: Label,
        x: 0.0,
        y: 60.0,
        width: 100.0,
        height: 30.0,
        text: "重名",
      },
      {
        id: 3,
        name: "坏框",
        kind: TextField,
        x: 0.0,
        y: 120.0,
        width: 0.0,
        height: 30.0,
        text: "",
      },
    ],
    handlers: [
      { control: "不存在", event: "被单击", source: "", },
      { control: "按钮1", event: "被单击", source: "如果 真 则", },
      { control: "按钮1", event: "被滚动", source: "", },
    ],
    next_id: 4,
  }
  let errors = validate_project(project)
  assert_true(errors.any(fn(error) { error is DuplicateName(_) }))
  assert_true(errors.any(fn(error) { error is BadSize(_) }))
  assert_true(errors.any(fn(error) { error is UnknownHandlerControl(_) }))
  assert_true(errors.any(fn(error) { error is BadSyntax(_, _, _) }))
  assert_true(errors.any(fn(error) { error is UnknownHandlerEvent(_, _) }))
}

///|
test "控件事件表" {
  match parse_control_kind("Button") {
    Some(kind) => {
      assert_true(kind.events() == ["被单击"])
      assert_true(kind.label() == "按钮")
    }
    None => abort("Button 应可解析")
  }
  match parse_control_kind("标签") {
    Some(kind) => {
      assert_true(kind.events().is_empty())
      assert_true(kind.label() == "标签")
    }
    None => abort("标签 应可解析")
  }
  match parse_control_kind("TextField") {
    Some(kind) => assert_true(kind.events() == ["内容改变"])
    None => abort("TextField 应可解析")
  }
  assert_true(parse_control_kind("神秘") is None)
  let button = parse_control_kind("Button").unwrap()
  assert_true(kind_supports_event(button, "被单击"))
  assert_true(!kind_supports_event(button, "内容改变"))
}

///|
test "名称合法性" {
  assert_true(control_name_valid("按钮1"))
  assert_true(!control_name_valid(""))
  assert_true(!control_name_valid("按 钮"))
  assert_true(!control_name_valid("按\n钮"))
}
