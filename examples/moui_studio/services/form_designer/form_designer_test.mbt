///|
/// 往返门(硬):parse(render(m)) == m,字段级一致。
test "form 往返门:render → parse 字段级一致" {
  let model : FormModel = {
    stage_width: 640.0,
    stage_height: 480.0,
    controls: [
      {
        kind: FkButton,
        text: "确定",
        handler: Some("do_submit"),
        x: 280.0,
        y: 180.0,
        width: 80.0,
        height: 36.0,
      },
      {
        kind: FkText,
        text: "标题:计数器",
        handler: None,
        x: 40.0,
        y: 20.0,
        width: 200.0,
        height: 24.0,
      },
    ],
  }
  let rendered = render_form(model)
  match parse_form(rendered) {
    Err(msg) => fail("渲染文本应可解析:\{msg}")
    Ok(parsed) =>
      assert_true(form_model_eq(model, parsed.model), msg="往返门失败")
  }
}

///|
/// span 补丁:拖拽改 x → 源码只有 x 字面量变化,其他字段零破坏。
test "span 补丁:改 x 不破坏其他字段,往返仍闭合" {
  let model : FormModel = {
    stage_width: 640.0,
    stage_height: 480.0,
    controls: [
      {
        kind: FkButton,
        text: "确定",
        handler: None,
        x: 280.0,
        y: 180.0,
        width: 80.0,
        height: 36.0,
      },
    ],
  }
  let source = render_form(model)
  match parse_form(source) {
    Err(msg) => fail("基线应可解析:\{msg}")
    Ok(parsed) => {
      let spans = parsed.spans[0]
      // 拖拽:x 280 → 88
      let patched = apply_control_patch(source, spans, 88.0, 180.0, 80.0, 36.0)
      match parse_form(patched) {
        Err(msg) => fail("补丁后应可解析:\{msg}")
        Ok(parsed2) => {
          assert_eq(parsed2.model.controls[0].x, 88.0)
          assert_eq(parsed2.model.controls[0].y, 180.0)
          assert_eq(parsed2.model.controls[0].width, 80.0)
          // 重建基线模型(新坐标)→ 往返门再闭合
          let updated : FormModel = {
            stage_width: parsed2.model.stage_width,
            stage_height: parsed2.model.stage_height,
            controls: [
              {
                kind: FkButton,
                text: "确定",
                handler: None,
                x: 88.0,
                y: 180.0,
                width: 80.0,
                height: 36.0,
              },
            ],
          }
          assert_true(form_model_eq(updated, parsed2.model))
        }
      }
    }
  }
}

///|
/// 文本补丁:改字符串字面量(点标题改文本的同一机制)。
test "文本补丁:点标题改文本" {
  let model : FormModel = {
    stage_width: 640.0,
    stage_height: 480.0,
    controls: [
      {
        kind: FkText,
        text: "MoUI Counter",
        handler: None,
        x: 44.0,
        y: 10.0,
        width: 200.0,
        height: 20.0,
      },
    ],
  }
  let source = render_form(model)
  match parse_form(source) {
    Err(msg) => fail("基线应可解析:\{msg}")
    Ok(parsed) => {
      let span = parsed.spans[0]
      let patched = apply_text_patch(source, span.text, 14, "我的计数器")
      match parse_form(patched) {
        Err(msg) => fail("补丁后应可解析:\{msg}")
        Ok(parsed2) =>
          assert_eq(parsed2.model.controls[0].text, "我的计数器")
      }
    }
  }
}

///|
/// 解析错误:漂出子集的结构化报错。
test "非子集文本结构化报错" {
  match parse_form("fn unrelated() { 1 }") {
    Err(msg) => assert_true(msg.contains("stage"), msg~)
    Ok(_) => fail("非子集文本应失败")
  }
}
