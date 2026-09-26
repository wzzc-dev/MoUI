///|
/// M0–M2 测试：画布命中/拖动、视口、绘制计划规模基线、
/// 提案解码与校验（≥15 类失败）、项目 codec 往返、编辑命令 undo/redo、
/// 执行状态机（重试/超时/取消/确定性无 UI 运行）、
/// M2 经 Msg 的编辑/属性表单/连接/提案预览与保存打开分支。

///|
fn step(model : @app.Model, msg : Msg) -> @app.Model {
  @app.update_pure(model, msg).0
}

///|
fn flow_edge(from : Int, to : Int) -> @app.BlockEdge {
  @app.BlockEdge::{ from, from_port: "flow", to, to_port: "trigger", }
}

///|
fn chain_graph(size : Int) -> @app.BlockGraph {
  let mut graph = @app.BlockGraph::empty()
  let mut i = 0
  while i < size {
    let x = 60.0 + (i % 5).to_double() * 190.0
    let y = 60.0 + (i / 5).to_double() * 110.0
    graph = graph.add_node("Sequence", "步骤 \{i + 1}", x, y)
    if i > 0 {
      graph = { ..graph, edges: [..graph.edges, flow_edge(i, i + 1)], }
    }
    i = i + 1
  }
  graph
}

///|
fn editor_with(graph : @app.BlockGraph) -> @app.GraphEditor {
  @app.GraphEditor::new(@app.block_catalog(), graph)
}

///|
fn model_with(graph : @app.BlockGraph) -> @app.Model {
  { ..@app.Model::new(), editor: editor_with(graph), }
}

///|
fn chatbot_graph() -> @app.BlockGraph raise {
  match
    @app.generate_from_prompt(
      "做一个能记住我、有人设的聊天应用",
      @app.block_catalog(),
    ) {
    Ok(graph) => graph
    Err(_) => fail("提案应通过校验")
  }
}

///|
test "画布命中测试返回最上层节点" {
  let mut graph = @app.BlockGraph::empty()
  graph = graph.add_node("Sequence", "A", 60.0, 60.0)
  graph = graph.add_node("Sequence", "B", 100.0, 80.0)
  match @app.hit_test(graph, 120.0, 100.0) {
    Some(node) => assert_eq(node.title, "B")
    None => fail("应命中节点 B")
  }
  match @app.hit_test(graph, 70.0, 65.0) {
    Some(node) => assert_eq(node.title, "A")
    None => fail("应命中节点 A")
  }
  assert_true(@app.hit_test(graph, 400.0, 400.0) is None)
}

///|
test "榫卯命中：凹槽挖空不命中、凸头内命中、凸头外不命中" {
  let mut graph = @app.BlockGraph::empty()
  graph = graph.add_node("Sequence", "A", 60.0, 60.0)
  // 节点 A：x 60..228, y 60..132；中心线 x=144，凹槽圆心 (144,60)、凸头圆心 (144,132)，半径 10
  assert_true(@app.hit_test(graph, 144.0, 65.0) is None)
  match @app.hit_test(graph, 144.0, 139.0) {
    Some(node) => assert_eq(node.title, "A")
    None => fail("凸头区域应命中")
  }
  assert_true(@app.hit_test(graph, 144.0, 148.0) is None)
  match @app.hit_test(graph, 100.0, 70.0) {
    Some(node) => assert_eq(node.title, "A")
    None => fail("主体非凹槽区域应命中")
  }
}

///|
test "画布按下选中并拖动，经 typed Msg 回到 reducer" {
  let mut graph = @app.BlockGraph::empty()
  graph = graph.add_node("Sequence", "A", 60.0, 60.0)
  let model = model_with(graph)
  let pressed = step(model, CanvasPress(70.0, 75.0))
  assert_eq(pressed.selection, Some(1))
  let dragged = step(pressed, CanvasDragTo(210.0, 215.0))
  match @app.GraphEditor::graph(dragged.editor).find_node(1) {
    Some(node) => {
      // 抓取点偏移 (60-70, 60-75)=(-10,-15)，拖动后左上角 = (200, 200)
      assert_eq(node.x, 200.0)
      assert_eq(node.y, 200.0)
    }
    None => fail("节点 1 应存在")
  }
  let released = step(dragged, CanvasRelease(210.0, 215.0))
  let moved = step(released, CanvasDragTo(500.0, 500.0))
  match @app.GraphEditor::graph(moved.editor).find_node(1) {
    Some(node) => assert_eq(node.x, 200.0)
    None => fail("节点 1 应存在")
  }
}

///|
test "空白处拖拽平移视口，节点拖拽只动节点（M2）" {
  let model = @app.Model::new()
  // 空白处按下 → 进入平移态（样例图占据左上部，右下为空白）
  let panning = step(model, CanvasPress(800.0, 600.0))
  match panning.drag {
    Panning(0.0, 0.0, 800.0, 600.0) => ()
    _ => fail("空白处按下应进入平移态")
  }
  let panned = step(panning, CanvasDragTo(860.0, 660.0))
  assert_eq(panned.viewport_x, -60.0)
  assert_eq(panned.viewport_y, -60.0)
  // 节点上按下 → 拖动节点，视口不变（节点 1 位于图坐标 60,60）
  match @app.GraphEditor::graph(model.editor).find_node(1) {
    Some(node) => {
      assert_eq(node.x, 60.0)
      let pressed = step(model, CanvasPress(70.0, 70.0))
      match pressed.drag {
        DraggingNode(1, _, _) => ()
        _ => fail("应进入节点拖动态")
      }
      let dragged = step(pressed, CanvasDragTo(100.0, 100.0))
      assert_eq(dragged.viewport_x, 0.0)
      match @app.GraphEditor::graph(dragged.editor).find_node(1) {
        Some(moved) => {
          assert_eq(moved.x, node.x + 30.0)
          assert_eq(moved.y, node.y + 30.0)
        }
        None => fail("节点 1 应存在")
      }
    }
    None => fail("节点 1 应存在")
  }
}

///|
test "缩放按钮有界钳制（M2）" {
  let mut model = @app.Model::new()
  let mut i = 0
  while i < 10 {
    model = step(model, ZoomIn)
    i = i + 1
  }
  assert_eq(model.viewport_zoom, 4.0)
  let mut j = 0
  while j < 20 {
    model = step(model, ZoomOut)
    j = j + 1
  }
  assert_eq(model.viewport_zoom, 0.25)
  assert_eq(step(model, ZoomReset).viewport_zoom, 1.0)
}

///|
test "画布拖动在放大视口下按缩放因子映射（M2）" {
  let base = { ..@app.Model::new(), viewport_zoom: 2.0, }
  match @app.GraphEditor::graph(base.editor).find_node(1) {
    Some(node) => {
      // zoom 2 下，节点 1（图坐标 60..228, 60..132）屏幕坐标为 120..456, 120..264
      let pressed = step(base, CanvasPress(200.0, 200.0))
      let dragged = step(pressed, CanvasDragTo(400.0, 400.0))
      match @app.GraphEditor::graph(dragged.editor).find_node(1) {
        Some(moved) => {
          // 屏幕移动 200px ÷ zoom 2 = 图坐标 100
          assert_eq(moved.x, node.x + 100.0)
          assert_eq(moved.y, node.y + 100.0)
        }
        None => fail("节点 1 应存在")
      }
    }
    None => fail("节点 1 应存在")
  }
}

///|
test "绘制计划规模随节点数线性增长（帧基线结构代理）" {
  let sizes = [20, 50, 100]
  let counts = sizes.map(fn(n) {
    @app.canvas_draw_plan(chain_graph(n), None, None).length()
  })
  // 每节点 FillBlock + NodeText 两条 op，链边 n-1 条 EdgeLine：3n-1
  assert_eq(counts[0], 59)
  assert_eq(counts[1], 149)
  assert_eq(counts[2], 299)
}

///|
test "fake model 提案 v2 解码、校验并自动布局" {
  let graph = chatbot_graph()
  assert_eq(graph.nodes.length(), 8)
  assert_eq(graph.edges.length(), 15)
  match graph.find_node(1) {
    Some(node) => {
      assert_eq(node.kind, "AppStart")
      assert_eq(node.x, 60.0)
    }
    None => fail("入口节点应存在")
  }
  match graph.find_node(7) {
    Some(node) => assert_true(node.config.any(fn(e) { e.0 == "temperature" }))
    None => fail("模型调用节点应存在")
  }
  assert_true(@app.validate_graph(graph, @app.block_catalog()).is_empty())
}

///|
test "未知积木 kind 与非法 JSON 提案被拒绝" {
  let source = "{\"version\":2,\"nodes\":[{\"id\":1,\"kind\":\"HackThePlanet\"}],\"edges\":[]}"
  match @app.decode_proposal(source, @app.block_catalog()) {
    Ok(_) => fail("未知 kind 必须被拒绝")
    Err(errors) =>
      assert_true(errors.any(fn(e) { e is UnknownKind("HackThePlanet") }))
  }
  match @app.decode_proposal("not json", @app.block_catalog()) {
    Ok(_) => fail("非法 JSON 必须被拒绝")
    Err(errors) => assert_true(errors.any(fn(e) { e is InvalidJson }))
  }
  match
    @app.decode_proposal(
      "{\"version\":1,\"nodes\":[],\"edges\":[]}",
      @app.block_catalog(),
    ) {
    Ok(_) => fail("旧版本提案必须被拒绝")
    Err(errors) => assert_true(errors.any(fn(e) { e is UnsupportedVersion }))
  }
}

///|
test "连线类型不匹配被检出" {
  let mut graph = @app.BlockGraph::empty()
  graph = graph.add_node("UserPrompt", "用户提问", 0.0, 0.0)
  graph = graph.add_node("UserConfirmation", "外发确认", 0.0, 120.0)
  graph = {
    ..graph,
    edges: [
      @app.BlockEdge::{
        from: 1,
        from_port: "prompt",
        to: 2,
        to_port: "action",
      },
    ],
  }
  let errors = @app.validate_graph(graph, @app.block_catalog())
  assert_true(
    errors.any(fn(e) { e is TypeMismatch(1, "prompt", 2, "action", Text, Json) }),
  )
}

///|
test "单输入占用被检出" {
  let mut graph = @app.BlockGraph::empty()
  graph = graph.add_node("AppStart", "启动", 0.0, 0.0)
  graph = graph.add_node("UserPrompt", "提问 A", 0.0, 120.0)
  graph = graph.add_node("UserPrompt", "提问 B", 200.0, 120.0)
  graph = graph.add_node("UserConfirmation", "确认", 200.0, 240.0)
  graph = {
    ..graph,
    edges: [
      @app.BlockEdge::{
        from: 2,
        from_port: "prompt",
        to: 4,
        to_port: "action",
      },
      @app.BlockEdge::{
        from: 3,
        from_port: "prompt",
        to: 4,
        to_port: "action",
      },
    ],
  }
  let errors = @app.validate_graph(graph, @app.block_catalog())
  assert_true(errors.any(fn(e) { e is InputOccupied(4, "action") }))
}

///|
test "未知端口、未知配置键与坏配置值被检出" {
  let mut graph = @app.BlockGraph::empty()
  graph = graph.add_node("AppStart", "启动", 0.0, 0.0)
  graph = graph.add_node("UserPrompt", "提问", 0.0, 120.0)
  graph = {
    ..graph,
    edges: [
      @app.BlockEdge::{
        from: 1,
        from_port: "nonexistent",
        to: 2,
        to_port: "trigger",
      },
    ],
  }
  let errors = @app.validate_graph(graph, @app.block_catalog())
  assert_true(errors.any(fn(e) { e is UnknownPort(1, "nonexistent") }))
  let mut cfg_graph = @app.BlockGraph::empty()
  cfg_graph = cfg_graph.add_node("AppStart", "启动", 0.0, 0.0)
  cfg_graph = cfg_graph.add_node("ModelCall", "调用", 0.0, 120.0)
  cfg_graph = cfg_graph.add_node("UserConfirmation", "确认", 0.0, 240.0)
  cfg_graph = {
    nodes: cfg_graph.nodes.map(fn(node) {
      if node.kind == "ModelCall" {
        { ..node, config: [("typo_key", "x"), ("temperature", "hot")], }
      } else {
        node
      }
    }),
    edges: [
      @app.BlockEdge::{ from: 1, from_port: "flow", to: 3, to_port: "trigger", },
      @app.BlockEdge::{ from: 3, from_port: "flow", to: 2, to_port: "trigger", },
    ],
    next_id: cfg_graph.next_id,
  }
  let cfg_errors = @app.validate_graph(cfg_graph, @app.block_catalog())
  assert_true(cfg_errors.any(fn(e) { e is UnknownConfigKey(2, "typo_key") }))
  assert_true(cfg_errors.any(fn(e) { e is BadConfigValue(2, "temperature") }))
}

///|
test "预算超限被检出（节点数 / 遍历上限）" {
  let mut graph = @app.BlockGraph::empty()
  let mut i = 0
  while i < 65 {
    graph = graph.add_node("AppStart", "节点 \{i}", 0.0, 0.0)
    i = i + 1
  }
  let errors = @app.validate_graph(graph, @app.block_catalog())
  assert_true(errors.any(fn(e) { e is NodeBudgetExceeded(_) }))
  let mut loop_graph = @app.BlockGraph::empty()
  loop_graph = loop_graph.add_node("AppStart", "启动", 0.0, 0.0)
  loop_graph = loop_graph.add_node("ForEach", "遍历", 0.0, 120.0)
  loop_graph = {
    nodes: loop_graph.nodes.map(fn(node) {
      if node.kind == "ForEach" {
        { ..node, config: [("limit", "1000")], }
      } else {
        node
      }
    }),
    edges: [flow_edge(1, 2)],
    next_id: loop_graph.next_id,
  }
  let loop_errors = @app.validate_graph(loop_graph, @app.block_catalog())
  assert_true(loop_errors.any(fn(e) { e is IterationBudgetExceeded(2) }))
}

///|
test "校验失败类目覆盖至少 15 种" {
  let kinds = [
    @app.InvalidJson,
    @app.InvalidProposal,
    @app.FormatMismatch("other.format"),
    @app.UnsupportedVersion,
    @app.UnknownKind("Hack"),
    @app.DuplicateNodeId(99),
    @app.EdgeMissingEndpoint(1, 2),
    @app.UnknownPort(1, "ghost"),
    @app.UnknownConfigKey(1, "ghost_key"),
    @app.BadConfigValue(1, "temperature"),
    @app.TypeMismatch(1, "prompt", 2, "action", @app.Text, @app.Json),
    @app.InputOccupied(2, "action"),
    @app.MissingEntrypoint,
    @app.UnreachableNode(3),
    @app.CycleDetected,
    @app.NodeBudgetExceeded(65),
    @app.EdgeBudgetExceeded(97),
    @app.IterationBudgetExceeded(2),
    @app.MissingConfirmation(2),
  ]
  assert_true(kinds.length() >= 15)
  for kind in kinds {
    let label = @app.validation_error_label(kind)
    assert_true(!label.is_empty())
  }
}

///|
test "缺少人工确认的外发图被校验阻止并经 Msg 阻止运行" {
  let mut graph = @app.BlockGraph::empty()
  graph = graph.add_node("AppStart", "启动", 0.0, 0.0)
  graph = graph.add_node("ModelCall", "调用", 0.0, 120.0)
  graph = { ..graph, edges: [flow_edge(1, 2)], }
  let errors = @app.validate_graph(graph, @app.block_catalog())
  assert_true(errors.any(fn(e) { e is MissingConfirmation(2) }))
  let model = step(model_with(graph), RunExecution)
  assert_true(model.execution.status is Idle)
}

///|
/// 闸门精度：确认节点挂在无关支路上（图可达但未接 approved）同样必须拒绝。
/// 「可达即放行」会让外发节点从未被用户批准的路径取到数据。
test "确认节点未接 approved 的外发图被拒绝（精确闸门）" {
  let mut graph = @app.BlockGraph::empty()
  graph = graph.add_node("AppStart", "启动", 0.0, 0.0)
  graph = graph.add_node("ModelCall", "调用", 0.0, 120.0)
  graph = graph.add_node("PromptTemplate", "模板", 0.0, 240.0)
  graph = graph.add_node("UserConfirmation", "确认", 240.0, 0.0)
  // 确认节点自成一条死支路：不向 ModelCall 的 approved 端口连线
  graph = {
    ..graph,
    edges: [
      flow_edge(1, 2),
      flow_edge(1, 4),
      flow_edge(1, 3),
      @app.BlockEdge::{
        from: 3,
        from_port: "rendered",
        to: 2,
        to_port: "prompt",
      },
    ],
  }
  let errors = @app.validate_graph(graph, @app.block_catalog())
  assert_true(errors.any(fn(e) { e is MissingConfirmation(2) }))
  // 接上 approved 连线后通过闸门检查
  let wired = {
    ..graph,
    edges: [
      ..graph.edges,
      @app.BlockEdge::{
        from: 4,
        from_port: "approved",
        to: 2,
        to_port: "approved",
      },
    ],
  }
  let wired_errors = @app.validate_graph(wired, @app.block_catalog())
  assert_true(wired_errors.any(fn(e) { e is MissingConfirmation(_) }) == false)
}

///|
test "环与不可达节点被检出" {
  let mut graph = @app.BlockGraph::empty()
  graph = graph.add_node("AppStart", "启动", 0.0, 0.0)
  graph = graph.add_node("Sequence", "A", 0.0, 120.0)
  graph = graph.add_node("Sequence", "B", 0.0, 240.0)
  graph = graph.add_node("Sequence", "孤岛", 400.0, 400.0)
  graph = {
    ..graph,
    edges: [flow_edge(1, 2), flow_edge(2, 3), flow_edge(3, 2)],
  }
  let errors = @app.validate_graph(graph, @app.block_catalog())
  assert_true(errors.any(fn(e) { e is CycleDetected }))
  assert_true(errors.any(fn(e) { e is UnreachableNode(4) }))
}

///|
test "项目 codec 往返稳定（.moblocks.json v1）" {
  let project = @app.Project::new("演示项目", chatbot_graph())
  let encoded = @app.encode_project(project)
  match @app.decode_project(encoded, @app.block_catalog()) {
    Ok(decoded) => {
      assert_eq(decoded.metadata.name, "演示项目")
      assert_eq(decoded.graph.nodes.length(), 8)
      assert_eq(decoded.graph.edges.length(), 15)
      assert_eq(decoded.graph.next_id, project.graph.next_id)
      assert_true(decoded.policy.require_confirmation == true)
      // 二次编码字节一致（稳定性）
      assert_eq(@app.encode_project(decoded), encoded)
      match (project.graph.find_node(7), decoded.graph.find_node(7)) {
        (Some(before), Some(after)) => {
          assert_eq(before.kind, after.kind)
          assert_eq(before.x, after.x)
          assert_eq(before.config.length(), after.config.length())
        }
        _ => fail("模型调用节点应存在")
      }
    }
    Err(_) => fail("合法项目应解码成功")
  }
}

///|
/// 提案形状的项目（节点不带坐标）解码后必须自动布局，否则所有节点叠在原点。
test "解码无坐标的提案形状项目时自动布局" {
  let proposal = @app.fake_model_completion("template").stringify()
  let project_json = "{\"format\":\"moblocks.project\",\"version\":1,\"metadata\":{\"id\":\"p\",\"name\":\"无坐标\"},\"graph\":\{proposal},\"policy\":{\"require_confirmation\":true,\"allow_external_submit\":false,\"allow_file_read\":true,\"allow_file_write\":false}}"
  match @app.decode_project(project_json, @app.block_catalog()) {
    Ok(project) => {
      let nodes = project.graph.nodes
      assert_eq(nodes.length(), 8)
      // 不再全部位于原点：至少两个不同的 x 与两个不同的 y
      let xs = nodes.map(fn(node) { node.x })
      let ys = nodes.map(fn(node) { node.y })
      assert_true(xs.any(fn(x) { x != xs[0] }))
      assert_true(ys.any(fn(y) { y != ys[0] }))
      // 带坐标解码不应改变坐标：二次编码字节一致
      let encoded = @app.encode_project(project)
      match @app.decode_project(encoded, @app.block_catalog()) {
        Ok(again) => assert_eq(@app.encode_project(again), encoded)
        Err(_) => fail("带坐标项目应解码成功")
      }
    }
    Err(_) => fail("无坐标项目应解码成功并自动布局")
  }
}

///|
/// 假模型关键词路由：默认描述 → 对话机器人提案；csv/表格 → CSV 助手；
/// 文档/论文 → 本地文档分析助手。
test "假模型按提示词关键词路由到不同模板" {
  let specs = @app.block_catalog()
  let chatbot = match
    @app.fake_generate_from_prompt(default_prompt_text(), specs) {
    Ok(graph) => graph
    Err(_) => fail("默认描述应路由到对话机器人")
  }
  assert_eq(chatbot.nodes.length(), 8)
  assert_eq(chatbot.edges.length(), 15)
  let csv = match
    @app.fake_generate_from_prompt(
      "帮我看看这份 csv 表格的数据", specs,
    ) {
    Ok(graph) => graph
    Err(_) => fail("csv 描述应路由到 CSV 助手模板")
  }
  assert_eq(csv.nodes.length(), 8)
  assert_eq(csv.edges.length(), 10)
  assert_true(csv.nodes.any(fn(node) { node.kind == "ForEach" }))
  let doc = match
    @app.fake_generate_from_prompt("总结一下这篇文档的内容", specs) {
    Ok(graph) => graph
    Err(_) => fail("文档描述应路由到文档助手模板")
  }
  assert_true(doc.nodes.any(fn(node) { node.kind == "FileSelected" }))
  assert_true(doc.nodes.any(fn(node) { node.kind == "ShowTable" }))
}

///|
fn default_prompt_text() -> String {
  @app.default_prompt()
}

///|
test "项目 codec 拒绝错误格式与版本" {
  match
    @app.decode_project(
      "{\"format\":\"other.format\",\"version\":1}",
      @app.block_catalog(),
    ) {
    Ok(_) => fail("错误格式必须被拒绝")
    Err(errors) =>
      assert_true(errors.any(fn(e) { e is FormatMismatch("other.format") }))
  }
  let wrong_version = "{\"format\":\"moblocks.project\",\"version\":2,\"metadata\":{\"id\":\"p\",\"name\":\"n\"},\"graph\":{\"nodes\":[],\"edges\":[]}}"
  match @app.decode_project(wrong_version, @app.block_catalog()) {
    Ok(_) => fail("错误版本必须被拒绝")
    Err(errors) => assert_true(errors.any(fn(e) { e is UnsupportedVersion }))
  }
  match
    @app.decode_project(
      "{\"format\":\"moblocks.project\",\"version\":1}",
      @app.block_catalog(),
    ) {
    Ok(_) => fail("缺 metadata/graph 必须被拒绝")
    Err(errors) => assert_true(errors.any(fn(e) { e is InvalidProject }))
  }
}

///|
fn try_edit(
  editor : @app.GraphEditor,
  edit : GraphEdit,
) -> (@app.GraphEditor, Bool) {
  match @app.GraphEditor::apply(editor, edit) {
    Some(next) => (next, true)
    None => (editor, false)
  }
}

///|
test "编辑命令 + 25 步 undo/redo" {
  let editor = editor_with(chatbot_graph())
  let baseline = @app.GraphEditor::graph(editor)
  let mut current = editor
  let mut ok_count = 0
  let mut i = 0
  while i < 25 {
    let (next, applied) = if i % 5 == 0 {
      try_edit(current, AddNode("FileSelected", 40.0, 40.0))
    } else if i % 5 == 1 {
      try_edit(current, MoveNode(2, 100.0 + i.to_double(), 50.0))
    } else if i % 5 == 2 {
      try_edit(current, SetConfig(7, "temperature", "0.4"))
    } else if i % 5 == 3 {
      try_edit(current, SetNodeTitle(8, "自定义标题"))
    } else {
      try_edit(current, AddEdge(1, "flow", 8, "trigger"))
    }
    current = next
    if applied {
      ok_count = ok_count + 1
    }
    i = i + 1
  }
  assert_true(ok_count >= 20)
  assert_true(@app.GraphEditor::undo_depth(current) >= 20)
  let mut ticks = 0
  while @app.GraphEditor::can_undo(current) && ticks < 25 {
    current = @app.GraphEditor::undo(current)
    ticks = ticks + 1
  }
  assert_true(!@app.GraphEditor::can_undo(current))
  let restored = @app.GraphEditor::graph(current)
  assert_eq(restored.nodes.length(), baseline.nodes.length())
  assert_eq(restored.edges.length(), baseline.edges.length())
  let mut redo_steps = 0
  while @app.GraphEditor::can_redo(current) {
    current = @app.GraphEditor::redo(current)
    redo_steps = redo_steps + 1
  }
  assert_true(redo_steps >= 20)
}

///|
test "编辑命令拒绝结构性非法操作" {
  let editor = editor_with(chatbot_graph())
  let (after_kind, kind_ok) = try_edit(
    editor,
    AddNode("HackThePlanet", 0.0, 0.0),
  )
  assert_eq(kind_ok, false)
  let (_, missing_node) = try_edit(
    after_kind,
    AddEdge(1, "flow", 999, "trigger"),
  )
  assert_eq(missing_node, false)
  let (_, bad_port) = try_edit(after_kind, AddEdge(1, "ghost", 2, "trigger"))
  assert_eq(bad_port, false)
  let (_, bad_cfg) = try_edit(after_kind, SetConfig(7, "not_in_schema", "x"))
  assert_eq(bad_cfg, false)
  let (_, bad_delete) = try_edit(after_kind, DeleteNode(9999))
  assert_eq(bad_delete, false)
  assert_eq(@app.GraphEditor::graph(after_kind).nodes.length(), 8)
  assert_true(!@app.GraphEditor::can_undo(after_kind))
}

///|
test "编辑：删除节点级联删除其连线" {
  let editor = editor_with(chatbot_graph())
  let before = @app.GraphEditor::graph(editor)
  match @app.GraphEditor::apply(editor, DeleteNode(6)) {
    Some(after) => {
      // 节点 6（UserConfirmation）涉及 4 条边：2 入 2 出
      assert_eq(
        @app.GraphEditor::graph(after).edges.length(),
        before.edges.length() - 4,
      )
      let restored = @app.GraphEditor::undo(after)
      assert_eq(
        @app.GraphEditor::graph(restored).edges.length(),
        before.edges.length(),
      )
    }
    None => fail("删除已存在节点应成功")
  }
}

///|
test "M2：经 Msg 的增删改、撤销重做与拒绝提示" {
  let model = model_with(chatbot_graph())
  let added = step(model, AddBlock("FileSelected"))
  assert_eq(@app.GraphEditor::graph(added.editor).nodes.length(), 9)
  assert_eq(added.selection, Some(9))
  assert_true(added.dirty)
  let undone = step(added, UndoEdit)
  assert_eq(@app.GraphEditor::graph(undone.editor).nodes.length(), 8)
  let redone = step(undone, RedoEdit)
  assert_eq(@app.GraphEditor::graph(redone.editor).nodes.length(), 9)
  // 非法编辑被拒绝并写 notice，图不变
  let rejected = step(redone, ApplyEdit(AddNode("HackThePlanet", 0.0, 0.0)))
  assert_true(rejected.notice.contains("编辑被拒绝"))
  assert_eq(@app.GraphEditor::graph(rejected.editor).nodes.length(), 9)
  // 删除选中
  let deleted = step(rejected, DeleteSelected)
  assert_eq(@app.GraphEditor::graph(deleted.editor).nodes.length(), 8)
}

///|
test "M2：属性表单 Msg 改名与改配置" {
  let model = model_with(chatbot_graph())
  let renamed = step(model, TitleInput(8, "我的渲染器"))
  match @app.GraphEditor::graph(renamed.editor).find_node(8) {
    Some(node) => assert_eq(node.title, "我的渲染器")
    None => fail("节点 8 应存在")
  }
  let configured = step(model, ConfigInput(7, "temperature", "0.9"))
  match @app.GraphEditor::graph(configured.editor).find_node(7) {
    Some(node) =>
      assert_true(
        node.config.any(fn(e) { e.0 == "temperature" && e.1 == "0.9" }),
      )
    None => fail("节点 7 应存在")
  }
  // 非法配置值：编辑层放行（schema 内），校验器报错
  let bad = step(model, ConfigInput(7, "temperature", "hot"))
  let bad_node = match @app.GraphEditor::graph(bad.editor).find_node(7) {
    Some(node) => node
    None => fail("节点 7 应存在")
  }
  let model_spec = match @app.find_spec(@app.block_catalog(), "ModelCall") {
    Some(spec) => spec
    None => fail("ModelCall spec 应存在")
  }
  assert_true(
    @app.validate_node_config(bad_node, model_spec).any(fn(e) {
      e is BadConfigValue(7, "temperature")
    }),
  )
}

///|
test "M2：L0 按钮式连接与断开，重复输入被拒" {
  let model = model_with(chatbot_graph())
  // 选中 AppStart（输出 flow/Unit），连到 UserConfirmation 的空 trigger
  match @app.GraphEditor::graph(model.editor).find_node(6) {
    Some(node) => assert_eq(node.kind, "UserConfirmation")
    None => fail("节点 6 应存在")
  }
  // UserConfirmation 的 trigger 已被占用（5→6）；先断开再连
  let dropped = step(model, DropEdge(5, "flow", 6, "trigger"))
  assert_eq(@app.GraphEditor::graph(dropped.editor).edges.length(), 14)
  let connected = step(dropped, ConnectTo(1, "flow", 6, "trigger"))
  assert_eq(@app.GraphEditor::graph(connected.editor).edges.length(), 15)
  // 重复占用同一输入 → 拒绝
  let again = step(connected, ConnectTo(3, "flow", 6, "trigger"))
  assert_true(again.notice.contains("编辑被拒绝"))
  assert_eq(@app.GraphEditor::graph(again.editor).edges.length(), 15)
}

///|
test "M2：AI 提案预览 → 接受/取消" {
  let model = model_with(chain_graph(3))
  let pending = step(model, GenerateFromPrompt)
  match pending.pending_proposal {
    Some(proposal) => {
      assert_eq(proposal.nodes, 8)
      assert_eq(proposal.edges, 15)
    }
    None => fail("应进入提案预览态")
  }
  // 图尚未替换
  assert_eq(@app.GraphEditor::graph(pending.editor).nodes.length(), 3)
  let cancelled = step(pending, CancelProposal)
  match cancelled.pending_proposal {
    Some(_) => fail("取消后不应有 pending 提案")
    None => ()
  }
  assert_eq(@app.GraphEditor::graph(cancelled.editor).nodes.length(), 3)
  let accepted = step(pending, AcceptProposal)
  assert_eq(@app.GraphEditor::graph(accepted.editor).nodes.length(), 8)
  match accepted.pending_proposal {
    Some(_) => fail("接受后 pending 应清空")
    None => ()
  }
}

///|
test "M2：保存打开的结果分支（不依赖真实文件系统）" {
  let services = @services.AppServices::unavailable()
  let model = model_with(chatbot_graph())
  // 不可用服务：请求保存/打开只产生 effect，纯状态不坏
  let (saving, save_effect) = @app.update_with_services(
    model,
    SaveRequested,
    services,
  )
  assert_eq(saving.notice, model.notice)
  ignore(save_effect)
  // 打开结果成功：应用项目
  let opened = @app.update_with_services(
    model,
    OpenReadCompleted(
      Success(
        @app.encode_project(@app.Project::new("载入项目", chain_graph(4))),
      ),
    ),
    services,
  )
  assert_eq(opened.0.project_name, "载入项目")
  assert_eq(@app.GraphEditor::graph(opened.0.editor).nodes.length(), 4)
  // 打开结果失败：拒绝并保留原图
  let broken = @app.update_with_services(
    model,
    OpenReadCompleted(Success("{\"format\":\"wrong\",\"version\":1}")),
    services,
  )
  assert_true(broken.0.notice.contains("项目被拒绝"))
  assert_eq(@app.GraphEditor::graph(broken.0.editor).nodes.length(), 8)
  // 取消分支
  let cancelled = @app.update_with_services(
    model,
    OpenPathPicked(Cancelled),
    services,
  )
  assert_true(cancelled.0.notice.contains("已取消打开"))
}

///|
test "M2：绿旗时刻聚光灯为运行中/等待确认节点追加高亮" {
  let graph = chain_graph(6)
  let plain = @app.canvas_draw_plan(graph, None, None)
  let lit = @app.canvas_draw_plan(graph, None, Some(3))
  // 选中与聚光灯各追加一条 StrokeBlock
  assert_eq(lit.length(), plain.length() + 1)
}

///|
test "M2：provider 面板切换与字段输入" {
  // 默认入口（无 async worker）拒绝进入真实模式，避免 Web 提交后静默挂起
  let web = @app.Model::new()
  assert_true(web.real_provider_available is false)
  let refused = step(web, ToggleProviderMode)
  assert_true(refused.fake_provider)
  assert_true(refused.notice.contains("不支持真实 provider"))
  // 具备 worker 的入口（macOS）可切换：真实 ↔ 假模型
  let native = { ..@app.Model::new(), real_provider_available: true, }
  let model = step(native, ToggleProviderMode)
  assert_true(!model.fake_provider)
  assert_true(model.notice.contains("真实 provider"))
  let back = step(model, ToggleProviderMode)
  assert_true(back.fake_provider)
  assert_true(back.notice.contains("假模型"))
  let endpoint = step(back, ProviderEndpointInput("http://localhost:9999/v1"))
  assert_eq(endpoint.provider_endpoint, "http://localhost:9999/v1")
  let keyed = step(endpoint, ProviderKeyInput("sk-test"))
  assert_eq(keyed.provider_key, "sk-test")
}

///|
test "M2：项目保存不含 provider key（凭据脱敏）" {
  let model = step(@app.Model::new(), ProviderKeyInput("sk-secret"))
  let project = @app.Project::new(
    "脱敏项目",
    @app.GraphEditor::graph(model.editor),
  )
  let encoded = @app.encode_project(project)
  assert_true(!encoded.contains("sk-secret"))
}

///|
test "M3：finish_real_generation 容忍围栏与散文" {
  let proposal = fixtures_chatbot_json()
  // 裸 JSON
  match @app.finish_real_generation(proposal, @app.block_catalog()) {
    Ok(graph) => assert_eq(graph.nodes.length(), 8)
    Err(_) => fail("裸 JSON 提案应通过")
  }
  // 带 ```json 围栏与前言散文
  let wrapped = "好的，以下是工作流：\n```json\n\{proposal}\n```\n希望对你有帮助"
  match @app.finish_real_generation(wrapped, @app.block_catalog()) {
    Ok(graph) => assert_eq(graph.nodes.length(), 8)
    Err(_) => fail("围栏包裹的提案应通过")
  }
  // 非法内容拒绝
  match @app.finish_real_generation("完全不是 JSON", @app.block_catalog()) {
    Ok(_) => fail("非法内容必须被拒绝")
    Err(errors) => assert_true(errors.any(fn(e) { e is InvalidJson }))
  }
}

///|
fn fixtures_chatbot_json() -> String {
  @app.fake_model_completion("fixture").stringify()
}

///|
test "M3：RealGenerationFinished 成功进入提案预览，失败写入 notice" {
  let specs = @app.block_catalog()
  let proposal = @app.fake_model_completion("fixture").stringify()
  // 成功：合法提案 → pending
  let ok_model = step(@app.Model::new(), RealGenerationFinished(Ok(proposal)))
  match ok_model.pending_proposal {
    Some(proposal_summary) => assert_eq(proposal_summary.nodes, 8)
    None => fail("合法提案应进入预览态")
  }
  // 成功但提案非法 → 拒绝
  let bad_model = step(
    { ..@app.Model::new(), fake_provider: false, },
    RealGenerationFinished(
      Ok(
        "{{\"version\":2,\"nodes\":[{\"id\":1,\"kind\":\"Hack\"}],\"edges\":[]}",
      ),
    ),
  )
  assert_true(bad_model.notice.contains("提案被拒绝"))
  // 网络失败 → notice 记录原因
  let err_model = step(
    { ..@app.Model::new(), fake_provider: false, },
    RealGenerationFinished(Err("provider 返回 HTTP 429")),
  )
  assert_true(err_model.notice.contains("429"))
}

///|
test "M3：proposal_system_prompt 覆盖 schema 与安全规则" {
  let prompt = @app.proposal_system_prompt()
  assert_true(prompt.contains("version"))
  assert_true(prompt.contains("UserConfirmation"))
  assert_true(prompt.contains("ModelCall"))
  assert_true(prompt.contains("只输出一个 JSON 对象"))
}

///|
test "M3：三个内置模板均可加载并通过校验" {
  let specs = @app.block_catalog()
  let base = @app.Model::new()
  let chatbot = step(base, LoadTemplate("chatbot"))
  assert_true(chatbot.notice.contains("对话机器人"))
  assert_true(
    @app.validate_graph(@app.GraphEditor::graph(chatbot.editor), specs).is_empty(),
  )
  let doc = step(base, LoadTemplate("doc"))
  assert_true(doc.notice.contains("本地文档分析助手"))
  assert_true(
    @app.validate_graph(@app.GraphEditor::graph(doc.editor), specs).is_empty(),
  )
  let csv = step(base, LoadTemplate("csv"))
  assert_true(csv.notice.contains("CSV 分析助手"))
  assert_true(
    @app.validate_graph(@app.GraphEditor::graph(csv.editor), specs).is_empty(),
  )
  // 未知模板名安全拒绝
  let bad = step(base, LoadTemplate("nope"))
  assert_true(bad.notice.contains("模板加载失败"))
}

///|
test "M3：新建空项目只含入口积木" {
  let fresh = step(@app.Model::new(), NewProject)
  assert_eq(@app.GraphEditor::graph(fresh.editor).nodes.length(), 1)
  assert_eq(fresh.project_name, "未命名项目")
}

///|
test "M3：模板项目可导出再导回（fixtures 镜像闭环）" {
  let loaded = step(@app.Model::new(), LoadTemplate("doc"))
  let project = @app.Project::new(
    "本地文档分析助手",
    @app.GraphEditor::graph(loaded.editor),
  )
  let encoded = @app.encode_project(project)
  match @app.decode_project(encoded, @app.block_catalog()) {
    Ok(round) => assert_eq(round.graph.edges.length(), 15)
    Err(_) => fail("模板导出后再导入应成功")
  }
}

///|
test "M4：join_path 与导出路径拼接" {
  assert_eq(@app.join_path("/tmp/out", "x/moon.mod"), "/tmp/out/x/moon.mod")
  assert_eq(@app.join_path("/tmp/out/", "x/moon.mod"), "/tmp/out/x/moon.mod")
}

///|
test "step_policy：预算只来自真正上游的 Retry/Timeout 配置" {
  let node = fn(
    id : Int,
    kind : String,
    config : Array[(String, String)],
  ) -> @app.BlockNode {
    { id, kind, title: kind, x: 0.0, y: 0.0, config, }
  }
  let graph : @app.BlockGraph = {
    nodes: [
      node(1, "AppStart", []),
      node(2, "Retry", [("attempts", "2")]),
      node(3, "Sequence", []),
      node(4, "Timeout", [("budget_ms", "500")]),
      node(5, "ParseJson", []),
      node(6, "Timeout", [("budget_ms", "100")]),
      node(7, "Retry", [("attempts", "9")]),
    ],
    edges: [
      flow_edge(1, 2),
      flow_edge(2, 3),
      flow_edge(1, 4),
      flow_edge(4, 5),
      flow_edge(5, 7),
    ],
    next_id: 8,
  }
  // 入口自身：无任何策略
  let (entry_attempts, entry_budget) = @app.step_policy(graph, 1)
  assert_eq(entry_attempts, 1)
  assert_eq(entry_budget, 0)
  // Retry 下游：attempts=2 → 总尝试 3；无上游 Timeout → 预算 0
  let (retried, no_budget) = @app.step_policy(graph, 3)
  assert_eq(retried, 3)
  assert_eq(no_budget, 0)
  // Retry 约束自身步骤
  let (self_attempts, _) = @app.step_policy(graph, 2)
  assert_eq(self_attempts, 3)
  // Timeout 下游：预算 500 生效；Retry 不在其上游 → 总尝试 1
  let (no_retry, budget) = @app.step_policy(graph, 5)
  assert_eq(no_retry, 1)
  assert_eq(budget, 500)
  // 无关的 Timeout(100) 不影响任何步骤（旧实现取全图最小值）
  let (_, unrelated) = @app.step_policy(graph, 3)
  assert_eq(unrelated, 0)
  // attempts 超限被钳制到 3：总尝试上限 4
  let (clamped, _) = @app.step_policy(graph, 7)
  assert_eq(clamped, 4)
}
