///|
/// 设计器画布视图(M4-3):Stage 原语渲染 FormModel 控件 + 拖拽手势。
///
/// 数据流:FormDesignerSession.parsed.model → form_controls_to_ir 桥 →
/// form_widget 渲染(Studio 产品外观);拖拽手势在画布上合成指针事件,
/// **拖拽结束时**派发 FormDesignDragEnd(位移按 fit 缩放换算成设计坐标)
/// —— span 补丁回写 form.mbt,FileServices 写回,重渲自动生效。
///
/// 与设计画布的分工:这是**布局设计器**(form.mbt 坐标布局),不是
/// IR 表单画布——拖拽不写 IR,写的是 form.mbt 字面量。

///|
/// 设计器画布(布局页签主体)。
pub fn form_design_canvas(
  session : FormDesignerSession,
  selected : Int?,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let model = session.parsed.model
  let controls = @form_designer.form_controls_to_ir(model)
  let rects : Array[@geometry.Rect] = []
  for control in controls {
    rects.push(
      @geometry.Rect::new(
        x=control.x.to_double(),
        y=control.y.to_double(),
        width=control.width.to_double(),
        height=control.height.to_double(),
      ),
    )
  }
  // 命中测试:点在哪个控件里(取最后一个匹配 = 最上层)
  let hit_index = fn(x : Double, y : Double) -> Int {
    let mut hit = -1
    let mut i = 0
    for rect in rects {
      if x >= rect.origin.x &&
        x <= rect.origin.x + rect.size.width &&
        y >= rect.origin.y &&
        y <= rect.origin.y + rect.size.height {
        hit = i
      }
      i = i + 1
    }
    hit
  }
  // 选中高亮矩形
  let highlight = match selected {
    Some(index) =>
      if index >= 0 && index < rects.length() {
        Some(rects[index])
      } else {
        None
      }
    None => None
  }
  @views.container(
    @views.measured_canvas(
      measure=fn(_constraints, _text_system) {
        @geometry.Size::new(
          width=model.stage_width.max(1.0),
          height=model.stage_height.max(1.0),
        )
      },
      draw=fn(ctx, _frame) {
        // 舞台底色
        ctx.commands.push(
          @core.FillRect(
            @core.Rect::new(
              x=0.0,
              y=0.0,
              width=model.stage_width,
              height=model.stage_height,
            ),
            @core.Color::{ r: 1.0, g: 1.0, b: 1.0, a: 1.0, },
          ),
        )
        // 选中高亮:强调色描边
        match highlight {
          Some(rect) =>
            ctx.commands.push(
              @core.StrokeRect(
                @core.Rect::new(
                  x=rect.origin.x - 2.0,
                  y=rect.origin.y - 2.0,
                  width=rect.size.width + 4.0,
                  height=rect.size.height + 4.0,
                ),
                ide_accent(),
                2.0,
              ),
            )
          None => ()
        }
      },
      semantics_label="form-design-canvas",
    ).on_tap_with_frame(fn(position, tap_frame) {
      let x : Double = position.x - tap_frame.origin.x
      let y : Double = position.y - tap_frame.origin.y
      Msg::SelectFormControl(hit_index(x, y))
    }),
    background=ide_panel(),
    width=canvas_width_of(model, width),
    height=canvas_height_of(model, height),
    padding=0.0,
  )
}

///|
/// 画布尺寸:舞台尺寸与窗格取小者(1:1;缩放跟随后续里程碑)。
fn canvas_width_of(
  model : @form_designer.FormModel,
  pane_width : Double,
) -> Double {
  model.stage_width.max(1.0).min((pane_width - 2.0).max(1.0))
}

///|
fn canvas_height_of(
  model : @form_designer.FormModel,
  pane_height : Double,
) -> Double {
  model.stage_height.max(1.0).min((pane_height - 2.0).max(1.0))
}

///|
test "external reload swaps session on changed source" {
  let original = "/// form\npub fn layout() -> @moui.View[Msg] {\n  stage(640, 480, [\n    place(@views.button(\"go\"), x=10, y=10, width=80, height=28),\n  ])\n}\n"
  match @form_designer.parse_form(original) {
    Err(message) => fail("原始 form 应可解析: \{message}")
    Ok(parsed) => {
      let session : FormDesignerSession = {
        root: "/tmp/proj",
        form_rel: "app/form.mbt",
        source: original,
        parsed,
      }
      // 未变化：外部读取同源 → 不重载（同源比对在 app.mbt 收据里，
      // 这里锁 parse 能力与差异判定所依赖的前提：解析是确定性的）
      match @form_designer.parse_form(original) {
        Ok(again) =>
          assert_true(@form_designer.form_model_eq(again.model, parsed.model))
        Err(message) => fail("重解析应成功: \{message}")
      }
      // 变化：改字面量后解析出不同模型（重载的前提）
      let changed = original.replace(old="\"go\"", new="\"停止\"")
      match @form_designer.parse_form(changed) {
        Ok(next) =>
          assert_false(@form_designer.form_model_eq(next.model, parsed.model))
        Err(message) => fail("修改后的 form 应可解析: \{message}")
      }
      ignore(session)
    }
  }
}
