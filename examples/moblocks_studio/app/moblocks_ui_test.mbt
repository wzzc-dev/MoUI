///|
/// M2 UI 输入测试：以 AppRuntime 真实运行程序，按文本定位按钮并派发点击。
/// 复现/回归 row 内按钮与扁平列内按钮的指针命中差异。
/// 依赖（runtime/geometry/backend-common）仅在测试目标导入。

///|
fn runtime_program() -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(
    program=@app.program(),
    width=1280.0,
    height=800.0,
  )
}

///|
fn draw_commands(runtime : @runtime.AppRuntime) -> Array[@core.DrawCommand] {
  runtime.draw_commands()
}

///|
fn text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @geometry.Rect? {
  for command in commands {
    match command {
      DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}

///|
fn click_text(runtime : @runtime.AppRuntime, text : String) -> Unit raise {
  guard text_frame(draw_commands(runtime), text) is Some(frame) else {
    fail("expected text frame for \{text}")
  }
  let point = @geometry.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  runtime.dispatch_event(
    Pointer(@core.PointerEvent::new(position=point, phase=Down)),
  )
  runtime.dispatch_event(
    Pointer(@core.PointerEvent::new(position=point, phase=Up)),
  )
}

///|
test "M2：扁平列按钮可经指针事件驱动（自动运行）" {
  let runtime = runtime_program()
  assert_true(
    text_frame(draw_commands(runtime), "自动运行到阻塞点") is Some,
  )
  click_text(runtime, "自动运行到阻塞点")
  // 样例链的自动运行停在第一个外发积木等待确认
  assert_true(
    text_frame(
      draw_commands(runtime),
      "已自动运行到阻塞点：等待人工确认",
    )
    is Some,
  )
}

///|
test "M2：检查器 AI 生成按钮可经指针事件驱动" {
  let runtime = runtime_program()
  click_text(runtime, "生成")
  assert_true(
    text_frame(
      draw_commands(runtime),
      "AI 提案就绪（8 积木 / 15 连线），等待接受",
    )
    is Some,
  )
}

///|
/// 自然语言输入面：提示词输入框经 typed Msg 改 draft，假模型按关键词路由到
/// 不同内置模板（默认描述 → 对话机器人；csv/表格 → CSV 助手）。
test "M2：提示词输入驱动假模型关键词路由" {
  let model = @app.Model::new()
  let drafted = @app.update_pure(
      model,
      @app.PromptInput("帮我分析上传的 csv 表格数据"),
    ).0
  assert_eq(drafted.prompt_draft, "帮我分析上传的 csv 表格数据")
  let generated = @app.update_pure(drafted, @app.GenerateFromPrompt).0
  match generated.pending_proposal {
    Some(proposal) => {
      // CSV 分析助手模板：8 积木 / 10 连线（与对话机器人 8/15 不同）
      assert_eq(proposal.nodes, 8)
      assert_eq(proposal.edges, 10)
      assert_true(
        generated.notice.contains("AI 提案就绪（8 积木 / 10 连线）"),
      )
    }
    None => fail("应进入提案预览态")
  }
  // 默认描述仍走对话机器人提案
  let default_run = @app.update_pure(model, @app.GenerateFromPrompt).0
  assert_true(
    default_run.notice.contains("AI 提案就绪（8 积木 / 15 连线）"),
  )
}

///|
/// 画布 draw 命令里的文本帧是**画布局部坐标**（画布 draw 回调里的 transform 不进
/// 命令记录），而指针事件是屏幕坐标。画布位于 notice（32px 高）之下、根 column 的
/// 默认间距 10px 处，故画布屏幕原点为 (0, 42)；把局部帧换算成屏幕点需加上该偏移。
let canvas_top_offset = 42.0

///|
fn canvas_screen_point(rect : @geometry.Rect) -> @geometry.Point {
  @geometry.Point::new(
    x=rect.origin.x + rect.size.width / 2.0,
    y=rect.origin.y + rect.size.height / 2.0 + canvas_top_offset,
  )
}

///|
/// 在画布积木上按下并拖到 (dx,dy)。
/// 拖拽手势的 `Started` 发生在第一次越过阈值（3px）的 Move 上，因此先发一个越过
/// 阈值的小步进触发 CanvasPress（抓取积木），再发完整位移触发 CanvasDragTo。
fn canvas_drag_label(
  runtime : @runtime.AppRuntime,
  label : String,
  dx : Double,
  dy : Double,
) -> Unit raise {
  let frame = match text_frame(draw_commands(runtime), label) {
    Some(rect) => rect
    None => fail("expected canvas text frame for \{label}")
  }
  let start = canvas_screen_point(frame)
  runtime.dispatch_event(
    Pointer(@core.PointerEvent::new(position=start, phase=Down)),
  )
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(x=start.x + 6.0, y=start.y + 3.0),
        phase=Move,
      ),
    ),
  )
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(x=start.x + dx, y=start.y + dy),
        phase=Move,
      ),
    ),
  )
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(x=start.x + dx, y=start.y + dy),
        phase=Up,
      ),
    ),
  )
}

///|
/// L1 画布交互回归：`on_drag_with_frame` 的框架可用性由
/// `moui/runtime/row_child_pointer_input_test.mbt` 固定；这里验证 Studio 画布
/// 积木拖拽链路（CanvasPress → hit_test → DraggingNode → CanvasDragTo →
/// MoveNode）经 AppRuntime 指针事件端到端生效。
test "M2：画布积木可经拖拽移动" {
  let runtime = runtime_program()
  let before = match text_frame(draw_commands(runtime), "应用启动") {
    Some(rect) => rect.origin
    None => fail("expected node title frame")
  }
  canvas_drag_label(runtime, "应用启动", 64.0, 28.0)
  let after = match text_frame(draw_commands(runtime), "应用启动") {
    Some(rect) => rect.origin
    None => fail("expected node title frame after drag")
  }
  // 位移扣除触发 Started 的 6px/3px 小步进
  assert_true(after.x > before.x + 52.0)
  assert_true(after.y > before.y + 20.0)
}
