///|
/// update 的便捷包装:丢弃 Effect,只取 Model。
fn next(model : Model, msg : Msg) -> Model {
  update(model, msg).0
}

///|
test "render default page produces draw commands" {
  // 默认地址是网络 URL,LoadAddress 进入加载页(loading)
  let rendered = next(Model::new(proxy=None), Msg::LoadAddress)
  inspect(rendered.commands.length() > 0, content="true")
  inspect(rendered.renders, content="1")
  inspect(rendered.status.has_prefix("loading"), content="true")
  inspect(rendered.loading, content="true")
}

///|
test "full program frame contains translated commands" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(initial_url="data:text/html,<h1>hi</h1>", proxy=None),
    width=1000.0,
    height=760.0,
  )
  let commands = runtime.draw_commands()
  // 背景 + 标题 + 内容,命令数应远大于 0
  inspect(commands.length() > 10, content="true")
}

///|
test "load address renders custom html" {
  let model = Model::new(proxy=None)
  let next_model = next(model, Msg::AddressChanged("<h1>hello</h1>"))
  let rendered = next(next_model, Msg::LoadAddress)
  inspect(rendered.renders, content="1")
  inspect(rendered.commands.length() > 0, content="true")
  inspect(rendered.status.has_prefix("rendered"), content="true")
}

///|
test "clicking a data-url link navigates" {
  let model = next(
    Model::new(proxy=None),
    Msg::AddressChanged(
      "<a href='data:text/html,<h1>nav</h1>' style='display:block;width:100px;height:20px'>go</a>",
    ),
  )
  let rendered = next(model, Msg::LoadAddress)
  inspect(rendered.links.length(), content="1")
  inspect(rendered.links[0].href, content="data:text/html,<h1>nav</h1>")
  let clicked = next(
    rendered,
    Msg::CanvasDrag({
      phase: @core.DragGesturePhase::Ended,
      start: { x: 20.0, y: 15.0 },
      position: { x: 20.0, y: 15.0 },
      delta: { x: 0.0, y: 0.0 },
      translation: { x: 0.0, y: 0.0 },
    }),
  )
  inspect(clicked.status.has_prefix("rendered"), content="true")
  inspect(clicked.renders, content="2")
}

///|
test "clicking a non-data link starts network loading" {
  let model = next(
    Model::new(proxy=None),
    Msg::AddressChanged(
      "<a href='https://example.com' style='display:block;width:100px;height:20px'>go</a>",
    ),
  )
  let rendered = next(model, Msg::LoadAddress)
  let clicked = next(
    rendered,
    Msg::CanvasDrag({
      phase: @core.DragGesturePhase::Ended,
      start: { x: 20.0, y: 15.0 },
      position: { x: 20.0, y: 15.0 },
      delta: { x: 0.0, y: 0.0 },
      translation: { x: 0.0, y: 0.0 },
    }),
  )
  inspect(clicked.status.has_prefix("loading"), content="true")
  inspect(clicked.loading, content="true")
  inspect(clicked.pending_url, content="https://example.com")
}

///|
test "navigated data-url page runs its scripts" {
  let href = "data:text/html,<script>console.log(%27nav%27)</script><h1>n</h1>"
  let model = next(
    Model::new(proxy=None),
    Msg::AddressChanged(
      "<a href='" + href + "' style='display:block;width:100px;height:20px'>go</a>",
    ),
  )
  let rendered = next(model, Msg::LoadAddress)
  inspect(rendered.links.length(), content="1")
  let clicked = next(
    rendered,
    Msg::CanvasDrag({
      phase: @core.DragGesturePhase::Ended,
      start: { x: 20.0, y: 15.0 },
      position: { x: 20.0, y: 15.0 },
      delta: { x: 0.0, y: 0.0 },
      translation: { x: 0.0, y: 0.0 },
    }),
  )
  inspect(clicked.status.has_prefix("rendered"), content="true")
  inspect(clicked.console_logs.length(), content="1")
  inspect(clicked.console_logs[0], content="nav")
}

///|
test "page scripts run on load and logs land in model" {
  let model = next(
    Model::new(proxy=None),
    Msg::AddressChanged(
      "<script>console.log('hello js')</script><h1>t</h1>",
    ),
  )
  let rendered = next(model, Msg::LoadAddress)
  inspect(rendered.script_errors, content="0")
  inspect(rendered.console_logs.length(), content="1")
  inspect(rendered.console_logs[0], content="hello js")
  inspect(rendered.status.contains("ran 1 scripts"), content="true")
}

///|
test "script errors are reported in status" {
  let model = next(
    Model::new(proxy=None),
    Msg::AddressChanged(
      "<script>throw new Error('x')</script><h1>t</h1>",
    ),
  )
  let rendered = next(model, Msg::LoadAddress)
  inspect(rendered.script_errors, content="1")
  inspect(rendered.status.contains("1 script errors"), content="true")
}

///| init 即渲染加载页:首帧必须含内容区绘制(body 背景矩形),而非仅 UI 文字
test "program init renders the loading page into the first frame" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(
      initial_url="data:text/html,<body style='background:#f2f4f7'><h1>t</h1></body>",
      proxy=None,
    ),
    width=1000.0,
    height=760.0,
  )
  let commands = runtime.draw_commands()
  let fills = commands.filter_map(fn(c) {
    match c {
      @core.DrawCommand::FillRect(rect, color) => Some((rect, color))
      _ => None
    }
  })
  // data: 页面内容区渲染,应含较宽矩形
  let has_body = fills.iter().any(fn(f) { f.0.size.width >= 800.0 })
  inspect(has_body, content="true")
  inspect(commands.length() > 5, content="true")
}

///|
test "page script builds DOM via document API and renders it" {
  let model = next(
    Model::new(proxy=None),
    Msg::AddressChanged(
      "<script>" +
      "var box = document.createElement('div');" +
      "box.setAttribute('style','background:#ffeeaa;width:200px;height:60px');" +
      "var t = document.createTextNode('built by js');" +
      "box.appendChild(t);" +
      "document.body.appendChild(box);" +
      "</script>",
    ),
  )
  let rendered = next(model, Msg::LoadAddress)
  inspect(rendered.script_errors, content="0")
  // JS 生成的 div 应出现在绘制命令里(带背景填充)
  let has_js_box = rendered.commands.iter().any(fn(c) {
    match c {
      @core.DrawCommand::FillRect(rect, _) => rect.size.width > 150.0 && rect.size.height > 40.0
      _ => false
    }
  })
  inspect(has_js_box, content="true")
  inspect(rendered.status.contains("ran 1 scripts"), content="true")
}
