///|
/// 测试夹具:`@core.SemanticsNode` 没有 `new`,20 个字段的记录字面量
/// 在每个用例里重写在断言里读不到意图,所以收敛到这里。
/// 仓库里的其它语义测试(`moui/core/semantics_test.mbt`)也是用字面量构造的。
fn nid(v : UInt64) -> @core.SemanticsNodeId {
  @core.SemanticsNodeId::new(v)
}

///|
fn rect(x : Double, y : Double, width : Double, height : Double) -> @core.Rect {
  @core.Rect::new(x~, y~, width~, height~)
}

///|
fn node(
  id : UInt64,
  role~ : @core.SemanticsRole,
  frame~ : @core.Rect,
  label? : String = "",
  value? : String = "",
  state? : @core.SemanticsState = @core.SemanticsState::default(),
  children? : Array[@core.SemanticsNodeId] = [],
) -> @core.SemanticsNode {
  {
    node_id: @core.SemanticsNodeId::new(id),
    semantic_id: None,
    role,
    level: None,
    url: "",
    label,
    value,
    description: "",
    state,
    numeric: None,
    text: None,
    collection: None,
    relations: @core.SemanticsRelations::empty(),
    live: Off,
    live_atomic: false,
    actions: [],
    focus_order: None,
    frame,
    children,
  }
}

///|
fn container(
  id : UInt64,
  frame~ : @core.Rect,
  title~ : String,
  children~ : Array[@core.SemanticsNodeId],
) -> @core.SemanticsNode {
  node(id, role=@core.List, frame~, label=title, children~)
}

///|
fn semantics_frame(
  nodes~ : Array[@core.SemanticsNode],
  root~ : @core.SemanticsNode,
  commands? : Array[@core.DrawCommand] = [],
  platform_views? : Array[@core.PlatformViewPlacement] = [],
) -> @core.DrawFrame {
  @core.DrawFrame::new(
    commands~,
    platform_views~,
    damage=@core.DamageRegion::empty(),
    semantics=Some(
      @core.SemanticsFramePayload::new(
        generation=@core.SemanticsGeneration::new(1UL),
        nodes~,
        root=Some(root.node_id),
      ),
    ),
  )
}

///|
/// 不带语义负载的帧:用来验证降级诊断而不是崩溃。
fn empty_frame(
  commands? : Array[@core.DrawCommand] = [],
  platform_views? : Array[@core.PlatformViewPlacement] = [],
) -> @core.DrawFrame {
  @core.DrawFrame::new(
    commands~,
    platform_views~,
    damage=@core.DamageRegion::empty(),
    semantics=None,
  )
}

///|
/// 用例只要关心"哪一个状态变了",所以差异收敛在这里,
/// 而不是每个断言前重写 13 个字段的记录字面量。
fn state(
  focused? : Bool = false,
  selected? : Bool = false,
  pressed? : Bool = false,
) -> @core.SemanticsState {
  let base = @core.SemanticsState::default()
  {
    focused,
    disabled: base.disabled,
    selected,
    pressed,
    checked: base.checked,
    expanded: base.expanded,
    invalid: base.invalid,
    required: base.required,
    read_only: base.read_only,
    busy: base.busy,
    multiline: base.multiline,
    password: base.password,
    modal: base.modal,
  }
}

///|
/// 只换文本、保留 identity 与几何的节点副本:动态组件树的
/// "同一位置内容变了"就是这种帧。
fn relabeled(
  node : @core.SemanticsNode,
  label~ : String,
) -> @core.SemanticsNode {
  {
    node_id: node.node_id,
    semantic_id: node.semantic_id,
    role: node.role,
    level: node.level,
    url: node.url,
    label,
    value: node.value,
    description: node.description,
    state: node.state,
    numeric: node.numeric,
    text: node.text,
    collection: node.collection,
    relations: node.relations,
    live: node.live,
    live_atomic: node.live_atomic,
    actions: node.actions,
    focus_order: node.focus_order,
    frame: node.frame,
    children: node.children,
  }
}

///|
fn metrics(width : Double, height : Double) -> @core.SurfaceMetrics {
  @core.SurfaceMetrics::from_logical(size=@core.Size::new(width~, height~))
}

///|
struct Capture {
  chunks : Array[String]
}

///|
fn capture() -> (@moui_tui_renderer.TuiSink, Capture) {
  let box = { chunks: [], }
  let sink = @moui_tui_renderer.TuiSink::new(description="capture", write=bytes => {
    box.chunks.push(bytes)
  })
  (sink, box)
}

///|
fn Capture::text(self : Capture) -> String {
  let mut all = ""
  for chunk in self.chunks {
    all = all + chunk
  }
  all
}

///|
fn Capture::total(self : Capture) -> Int {
  self.text().length()
}

///|
fn submission(frame : @core.DrawFrame) -> @render.RenderFrameSubmission {
  @render.RenderFrameSubmission::new(
    token=@render.FrameToken::new(surface_generation=0, sequence=0),
    frame~,
  )
}

///|
fn line_chars(text : String) -> Array[Char] {
  let out : Array[Char] = []
  for ch in text {
    out.push(ch)
  }
  out
}

///|
/// 把投影结果按 cell 列读回来:`line_text` 会裁掉尾部空格,
/// 所以越界的列按空白算。宽字符占两格但只出一个字符,
/// 列号必须按格累加,不能按字符下标取。
fn cell_at(
  renderer : @moui_tui_renderer.TuiRenderer,
  row : Int,
  col : Int,
) -> Char {
  let mut x = 0
  for ch in renderer.line_text(row) {
    let width = @tui.unicode_width(ch.to_string())
    if col < x + width {
      return ch
    }
    x = x + width
  }
  ' '
}

///|
fn grid(lines : Array[String]) -> String {
  let mut out = ""
  for line in lines {
    out = out + line + "\n"
  }
  out
}

///|
/// ANSI 增量断言要数出现次数,而 `String` 只有 `contains`。
fn count_occurrences(haystack : String, needle : String) -> Int {
  let hay = line_chars(haystack)
  let pat = line_chars(needle)
  if pat.length() == 0 || hay.length() < pat.length() {
    return 0
  }
  let mut hits = 0
  let mut i = 0
  while i + pat.length() <= hay.length() {
    let mut j = 0
    let mut same = true
    while j < pat.length() {
      if hay[i + j] != pat[j] {
        same = false
      }
      j = j + 1
    }
    if same {
      hits = hits + 1
    }
    i = i + 1
  }
  hits
}

///|
/// 能力表必须"每个特性恰好一条",重名会让聚合报告说谎。
fn has_duplicates(items : Array[String]) -> Bool {
  let mut i = 0
  while i < items.length() {
    let mut j = i + 1
    while j < items.length() {
      if items[i] == items[j] {
        return true
      }
      j = j + 1
    }
    i = i + 1
  }
  false
}

///|
fn sources(log : @moui_tui_renderer.DegradeLog) -> Array[String] {
  let out : Array[String] = []
  for record in log.records() {
    out.push(record.source)
  }
  out
}

///|
fn has_source(log : @moui_tui_renderer.DegradeLog, source : String) -> Bool {
  log.find(source) != None
}
