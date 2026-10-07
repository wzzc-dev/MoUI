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
      props: @ir.ControlProps::default(),
      },
      {
        kind: FkText,
        text: "标题:计数器",
        handler: None,
        x: 40.0,
        y: 20.0,
        width: 200.0,
        height: 24.0,
      props: @ir.ControlProps::default(),
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
      props: @ir.ControlProps::default(),
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
              props: @ir.ControlProps::default(),
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
      props: @ir.ControlProps::default(),
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

///|
/// G7.2 P3:属性进 form.mbt 子集——非默认属性命名参数往返字段级一致;
/// 默认属性渲染整体省略(旧文件形态零变化)。
test "props roundtrip:styled control survives parse(render(m))" {
  let model : FormModel = {
    stage_width: 640.0,
    stage_height: 480.0,
    controls: [
      {
        kind: FkText,
        text: "标题",
        handler: None,
        x: 40.0,
        y: 20.0,
        width: 200.0,
        height: 32.0,
        props: @ir.ControlProps::{
          font_size: 20,
          bold: true,
          text_color: "#FF8800",
          back_color: "",
          align: "center",
          visible: true,
          disabled: false,
          multiline: false,
          placeholder: "",
          password: false,
        },
      },
      {
        kind: FkTextField,
        text: "",
        handler: None,
        x: 40.0,
        y: 80.0,
        width: 220.0,
        height: 28.0,
        props: @ir.ControlProps::{
          font_size: 0,
          bold: false,
          text_color: "",
          back_color: "",
          align: "",
          visible: true,
          disabled: true,
          multiline: false,
          placeholder: "请输入昵称",
          password: true,
        },
      },
    ],
  }
  let rendered = render_form(model)
  // 默认属性省略:非默认才渲染(第一控件 align=center 应出现;
  // 第二控件无 font_size,默认 visible 不渲染)
  assert_true(rendered.contains("align=\"center\""), msg="非默认对齐应渲染")
  assert_false(rendered.contains("visible="), msg="默认 visible 不应渲染")
  assert_false(rendered.contains("font_size=0"), msg="默认字号不应渲染")
  assert_true(rendered.contains("font_size=20"), msg="非默认字号应渲染")
  assert_true(rendered.contains("placeholder=\"请输入昵称\""), msg="占位符应渲染")
  match parse_form(rendered) {
    Err(msg) => fail("带属性渲染文本应可解析:\{msg}")
    Ok(parsed) => assert_true(form_model_eq(model, parsed.model), msg="属性往返门失败")
  }
  // 未知键结构化报错(规范形态纪律)
  assert_true(
    match parse_form(
      rendered.replace(old="font_size=20", new="rotation=45"),
    ) {
      Err(msg) => msg.contains("未知属性键")
      Ok(_) => false
    },
    msg="未知属性键应结构化报错",
  )
}
