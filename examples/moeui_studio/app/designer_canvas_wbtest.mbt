///|
test "命中测试：后画的控件在上" {
  let controls : Array[FormControl] = [
    {
      id: 1,
      name: "下层",
      kind: Label,
      x: 0.0,
      y: 0.0,
      width: 200.0,
      height: 100.0,
      text: "下",
    },
    {
      id: 2,
      name: "上层",
      kind: Button,
      x: 50.0,
      y: 30.0,
      width: 80.0,
      height: 40.0,
      text: "上",
    },
  ]
  match hit_test_control(controls, 60.0, 40.0) {
    Some(control) => assert_true(control.name == "上层")
    None => abort("重叠区应命中上层")
  }
  match hit_test_control(controls, 10.0, 10.0) {
    Some(control) => assert_true(control.name == "下层")
    None => abort("外围应命中下层")
  }
  assert_true(hit_test_control(controls, 300.0, 300.0) is None)
}

///|
test "绘制计划：窗口底板 + 每控件三笔 + 选中描边" {
  let project = sample_project()
  // 3 控件：底板 1 + 每控件（填充/名字条/文本）3 笔 = 10
  let plan = design_draw_plan(project, None)
  assert_true(plan.length() == 1 + project.controls.length() * 3)
  // 选中追加 1 笔描边
  let plan2 = design_draw_plan(project, Some(2))
  assert_true(plan2.length() == plan.length() + 1)
}

///|
test "设计坐标夹取" {
  assert_true(clamp_design_x(-10.0, 120.0) == 0.0)
  assert_true(clamp_design_x(700.0, 120.0) == design_width - 120.0)
  assert_true(clamp_design_y(50.0, 40.0) == 50.0)
}
