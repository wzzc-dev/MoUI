///|
/// 语义节点的可见文本:label 优先,其次 value,最后 description。
pub fn node_text(node : @core.SemanticsNode) -> String {
  if node.label.length() > 0 {
    node.label
  } else if node.value.length() > 0 {
    node.value
  } else {
    node.description
  }
}

///|
fn clamp_cell(value : Int, limit : Int) -> Int {
  if value < 0 {
    0
  } else if value >= limit {
    limit - 1
  } else {
    value
  }
}

///|
/// 一维量化:只保留「格中心落在 [edge, edge+span) 内」的那些格。
///
/// 终端没有半格,而宿主发出的点击就是格中心那一个点
/// (`y = (row + 0.5) * cell`),所以一格算不算这一块的一部分,判据只能是它的
/// 中心在不在帧里。用外扩规则(顶边 `floor`、底边 `ceil`)时,帧顶边一落到格子的
/// 下半格,画出来的那一行中心其实在帧上方 —— 看得见却点不着,按钮标签会整体比
/// 命中区高一行。
fn quantize_span(
  edge : Double,
  span : Double,
  cell : Double,
  limit : Int,
) -> (Int, Int)? {
  let lo = (edge / cell - 0.5).ceil().to_int()
  let hi = ((edge + span) / cell - 0.5).ceil().to_int() - 1
  if hi < lo {
    None
  } else {
    Some((clamp_cell(lo, limit), clamp_cell(hi, limit)))
  }
}

///|
/// 量化成绘制区间。帧窄于半格时(分隔线就是这种)可能一个中心都不落在里面,
/// 那时退回帧起点那一格:宁可画出来少一行可点,也不能整块消失。
fn quantize_axis(
  edge : Double,
  span : Double,
  cell : Double,
  limit : Int,
) -> (Int, Int) {
  match quantize_span(edge, span, cell, limit) {
    Some(pair) => pair
    None => {
      let only = clamp_cell((edge / cell).floor().to_int(), limit)
      (only, only)
    }
  }
}

///|
/// 量化成绘制盒。子帧 ⊆ 父帧,所以按中心取格不会让分栏边界散架。
pub fn quantize(
  frame : @core.Rect,
  cell : CellBox,
  cols : Int,
  rows : Int,
) -> (Int, Int, Int, Int) {
  let (r0, r1) = quantize_axis(
    frame.origin.y,
    frame.size.height,
    cell.height,
    rows,
  )
  let (c0, c1) = quantize_axis(
    frame.origin.x,
    frame.size.width,
    cell.width,
    cols,
  )
  (r0, c0, r1, c1)
}

///|
/// 高亮带专用的量化:只用「中心确实落在矩形里」的那些格,没有残格兜底。
///
/// 残格兜底是为分隔线那种零高帧留的,让画不出字的窄帧至少占一格;但反白带
/// 铺在一格中心都不属于它的格子上,用户看到的就是一个没有内容的色块,
/// 而且那一格点不回这个条目(实测 100x30 末行只剩 4px 时整条底边框被反白盖住)。
fn quantize_box(
  frame : @core.Rect,
  cell : CellBox,
  cols : Int,
  rows : Int,
) -> (Int, Int, Int, Int)? {
  match quantize_span(frame.origin.y, frame.size.height, cell.height, rows) {
    None => None
    Some((r0, r1)) =>
      match quantize_span(frame.origin.x, frame.size.width, cell.width, cols) {
        None => None
        Some((c0, c1)) => Some((r0, c0, r1, c1))
      }
  }
}

///|
fn index_of(
  nodes : Array[@core.SemanticsNode],
  id : @core.SemanticsNodeId,
) -> Int? {
  let mut i = 0
  while i < nodes.length() {
    if nodes[i].node_id == id {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// 一个节点能被画到的最大范围。根节点用它起步,
/// 深层节点只会继承更窄的范围。
pub fn viewport(cell : CellBox, cols : Int, rows : Int) -> @core.Rect {
  @core.Rect::new(
    x=0.0,
    y=0.0,
    width=cell.width * cols.to_double(),
    height=cell.height * rows.to_double(),
  )
}

///|
/// 继承范围要分两条,因为终端的「线」是一整格,而布局的边框只有几像素。
///
/// - `chrome`:区域画边框可用的范围。`List`/`Tree` 的帧和它所属的
///   `ScrollView` 重合,两道框必须还能落在同一圈格子上,否则会套出第二道框。
/// - `content`:字形与高亮带可用的范围,也就是那一圈边框的**内侧**。
///   边框量化要吃掉一整格,内容却按像素贴着框的内沿起排,两者共用一格时
///   列表行就写在框线上(实测 100x30:树行首格压在顶边框,末行残格压在底边框)。
pub struct Clip {
  chrome : @core.Rect
  content : @core.Rect
}

///|
/// 框线内侧的像素范围。框小到没有内侧时退回整栏:
/// 一栏放不下任何行也要先把行画出来,不能只剩一个空框。
fn inside_ring(
  ring : @core.Rect,
  cell : CellBox,
  cols : Int,
  rows : Int,
) -> @core.Rect {
  let (r0, c0, r1, c1) = quantize(ring, cell, cols, rows)
  let (top, left) = (r0 + 1, c0 + 1)
  let (bottom, right) = (r1 - 1, c1 - 1)
  if bottom < top || right < left {
    ring
  } else {
    @core.Rect::new(
      x=cell.width * left.to_double(),
      y=cell.height * top.to_double(),
      width=cell.width * (right - left + 1).to_double(),
      height=cell.height * (bottom - top + 1).to_double(),
    )
  }
}

///|
/// 子树的可见范围:只有 `ScrollView` 会收窄范围,
/// 其它容器(分组、行、面板边框)不裁剪,否则一个普通 `Group`
/// 就能把兄弟节点的格子擦掉。
fn child_clip(
  node : @core.SemanticsNode,
  inherited : Clip,
  cell : CellBox,
  cols : Int,
  rows : Int,
) -> Clip {
  if node.role != @core.ScrollView {
    inherited
  } else {
    match visible_box(node.frame, inherited.chrome) {
      None =>
        // 滚动面板本身已完全离屏:给它一个空范围,子节点全部按离屏处理。
        {
          chrome: @core.Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
          content: @core.Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
        }
      Some(ring) =>
        { chrome: ring, content: inside_ring(ring, cell, cols, rows), }
    }
  }
}

///|
/// 继承范围按广度优先序逐层收窄,与 `paint_order` 同一条通路。
/// 树里指不到或来自环之外的节点拿可视区,和「补在尾部」的规则一致。
pub fn clips_in_tree(
  nodes : Array[@core.SemanticsNode],
  root : @core.SemanticsNodeId?,
  cell : CellBox,
  cols : Int,
  rows : Int,
) -> Array[Clip] {
  let view = viewport(cell, cols, rows)
  let start = { chrome: view, content: view, }
  let clips = Array::make(nodes.length(), start)
  let visited = Array::make(nodes.length(), false)
  let queue : Array[Int] = []
  let queue_clips : Array[Clip] = []
  match root {
    Some(id) =>
      match index_of(nodes, id) {
        Some(i) => {
          queue.push(i)
          queue_clips.push(start)
        }
        None => ()
      }
    None => ()
  }
  let mut head = 0
  while head < queue.length() {
    let i = queue[head]
    let clip = queue_clips[head]
    head = head + 1
    if visited[i] {
      continue
    }
    visited[i] = true
    clips[i] = clip
    let child = child_clip(nodes[i], clip, cell, cols, rows)
    for child_id in nodes[i].children {
      match index_of(nodes, child_id) {
        Some(j) =>
          if !visited[j] {
            queue.push(j)
            queue_clips.push(child)
          }
        None => ()
      }
    }
  }
  clips
}

///|
/// 节点的绘制盒与它的可视范围求交。
///
/// 退化盒(高或宽为 0,例如分隔线)与范围的交集按定义为空,
/// 但它可能正好落在范围里,所以用左上角判归属,而不是当成离屏丢掉。
fn visible_box(frame : @core.Rect, clip : @core.Rect) -> @core.Rect? {
  match frame.intersection(clip) {
    Some(r) => Some(r)
    None =>
      if frame.is_empty() && clip.contains(frame.origin) {
        Some(frame)
      } else {
        None
      }
  }
}

///|
/// 从根开始的广度优先序:浅层先画,深层后可以抢占浅层的格子。
/// 这就是 S0 定下的 z-order 策略。游离于根之外的节点补在尾部,
/// 保证不会因为树不完整而整个丢掉。
pub fn paint_order(
  nodes : Array[@core.SemanticsNode],
  root : @core.SemanticsNodeId?,
) -> Array[Int] {
  let order : Array[Int] = []
  let visited = Array::make(nodes.length(), false)
  let queue : Array[Int] = []
  match root {
    Some(id) =>
      match index_of(nodes, id) {
        Some(i) => queue.push(i)
        None => ()
      }
    None => ()
  }
  let mut head = 0
  while head < queue.length() {
    let i = queue[head]
    head = head + 1
    if visited[i] {
      continue
    }
    visited[i] = true
    order.push(i)
    for child_id in nodes[i].children {
      match index_of(nodes, child_id) {
        Some(j) => if !visited[j] { queue.push(j) }
        None => ()
      }
    }
  }
  let mut i = 0
  while i < nodes.length() {
    if !visited[i] {
      order.push(i)
    }
    i = i + 1
  }
  order
}

///|
fn check_mark(checked : @core.SemanticsCheckedState?) -> String {
  match checked {
    Some(@core.Checked) => "(x) "
    Some(@core.Mixed) => "(-) "
    Some(@core.Unchecked) | None => "( ) "
  }
}

///|
/// 有内容的节点怎么写字。`region`/`item` 不进这里:前者只画框,
/// 后者把自己整行的字都交给了子节点。
fn paint_content(
  canvas : Canvas,
  log : DegradeLog,
  node : @core.SemanticsNode,
  role : String,
  text : String,
  attrs : @tui.CellAttrs,
  box : (Int, Int, Int, Int),
  seq : Int,
) -> Unit {
  let (r0, c0, r1, c1) = box
  if role == "Button" {
    // 没名字的按钮不硬凑 `[]`:那是包装层,内容在子节点里,
    // 空括号只会盖住容器的角。
    if text.length() > 0 {
      canvas.write_boxed(r0, c0, r1, c1, "[" + text + "]", attrs, seq)
    }
  } else if role == "Image" || role == "WebView" {
    let source = if role == "Image" { "role-image" } else { "role-web-view" }
    let marker = if role == "Image" { "[image]" } else { "[web-view]" }
    log.note(
      source,
      "\{role} 语义节点只能占位,像素内容不可投影",
    )
    canvas.write_boxed(r0, c0, r1, c1, marker, attrs, seq)
  } else if role == "Checkbox" || role == "Switch" || role == "Radio" {
    canvas.write_boxed(
      r0,
      c0,
      r1,
      c1,
      check_mark(node.state.checked) + text,
      attrs,
      seq,
    )
  } else if role == "TextField" || role == "ComboBox" {
    canvas.write_boxed(r0, c0, r1, c1, text + "|", attrs, seq)
  } else if role == "Slider" || role == "Progress" {
    let mut c = c0
    while c <= c1 && c < canvas.cols {
      ignore(canvas.put(r0, c, "═", attrs, seq))
      c = c + 1
    }
    ignore(canvas.put(r0, c0 + 1, ">", attrs, seq))
  } else if text.length() > 0 {
    canvas.write_boxed(r0, c0, r1, c1, text, attrs, seq)
  } else if node.children.length() == 0 && role_kind(node.role) == Content {
    log.note(
      "unlabeled-leaf",
      "无名叶子 \{role} 落在格 \{r0},\{c0}:只在不抢已有笔画的前提下写一个 `?`",
    )
    // 占位符是标记不是内容,所以用最低优先级:它只填还没人占的格子。
    ignore(canvas.put(r0, c0, "?", attrs, canvas.new_seq(0)))
  }
}

///|
/// 绘制一个语义节点,返回它的绘制范围(完全落在可用范围之外时返回 `None`)。
///
/// 求交对象按角色分两条:区域的边框用 `chrome`,其余写字的节点用 `content`
/// 那一圈框的内侧。滚出面板的行因此被丢掉而不是叠到面板外的兄弟行上,
/// 这正是 S4 双栏 demo 暴露出的缺口。
/// 返回的范围同时是帧末高亮带的作用范围,所以这里只求交一次。
fn paint_node(
  canvas : Canvas,
  node : @core.SemanticsNode,
  cell : CellBox,
  clip : Clip,
  log : DegradeLog,
  palette : TuiPalette,
) -> @core.Rect? {
  let role = role_tag(node.role)
  let kind = role_kind(node.role)
  let bounds = if kind == Region { clip.chrome } else { clip.content }
  match visible_box(node.frame, bounds) {
    None => None
    Some(visible) => {
      let box = quantize(visible, cell, canvas.cols, canvas.rows)
      let seq = canvas.new_seq(role_priority(kind))
      if kind == Region {
        let (r0, c0, r1, c1) = box
        canvas.draw_box(
          r0,
          c0,
          r1,
          c1,
          palette.attrs_for(node.role, node.state),
          seq,
        )
      } else if kind != Item {
        // 条目行自己不写字:它的名字是子节点文本的聚合,
        // 再写一遍只会把子节点打断成残字。焦点/选中由帧末高亮带表达。
        paint_content(
          canvas,
          log,
          node,
          role,
          node_text(node),
          palette.attrs_for(node.role, node.state),
          box,
          seq,
        )
      }
      Some(visible)
    }
  }
}

///|
/// 投影一帧语义负载,返回被丢弃的离屏节点数。
///
/// 两遍:先按广度优先序落字形,再刷焦点/选中的样式带。
/// 顺序不能反,也不能合成一遍 —— 高亮带换的是 attrs 不是字符,
/// 但归属判定只认 seq,把它塞进第一遍会让某个条目为了"显眼"
/// 而吃掉兄弟的文字。
fn project_payload(
  canvas : Canvas,
  payload : @core.SemanticsFramePayload,
  cell : CellBox,
  log : DegradeLog,
  palette : TuiPalette,
) -> Int {
  let nodes = payload.nodes()
  let clips = clips_in_tree(
    nodes,
    payload.root(),
    cell,
    canvas.cols,
    canvas.rows,
  )
  let painted : Array[(Int, @core.Rect)] = []
  let mut offscreen = 0
  for i in paint_order(nodes, payload.root()) {
    match paint_node(canvas, nodes[i], cell, clips[i], log, palette) {
      Some(box) => painted.push((i, box))
      None => offscreen = offscreen + 1
    }
  }
  // 样式带再分两小遍:**焦点带先刷、选中带后刷**。带覆盖是整体覆写 attrs,
  // 点击选中的条目恰恰同时收进一个带焦点的内嵌按钮(左栏的 ghost 按钮
  // 与行同框,右栏的标签按钮盒子从缩进+折叠钮之后才开始):按旧的
  // 单遍绘制序,按钮带会吃掉行带 —— 左栏被点行整行无带、旧选中行在焦点
  // 让位的那一帧闪现反白;右栏行带只剩按钮盒没盖住的前几格,看起来就是
  // 「被点选项前面亮一块」。焦点态浅、选中态是选中的唯一表示(S4 定的),
  // 所以选中带必须压轴。焦点与选中同挂在一个节点上时,attrs_for 本来就
  // 会把两个状态合成一组 attrs,两遍只是重刷同一组,视觉不变。
  for (i, box) in painted {
    let state = nodes[i].state
    if !state.focused {
      continue
    }
    match quantize_box(box, cell, canvas.cols, canvas.rows) {
      None => ()
      Some((r0, c0, r1, c1)) =>
        canvas.style_range(
          r0,
          c0,
          r1,
          c1,
          palette.attrs_for(nodes[i].role, state),
        )
    }
  }
  for (i, box) in painted {
    let state = nodes[i].state
    if !state.selected {
      continue
    }
    match quantize_box(box, cell, canvas.cols, canvas.rows) {
      None => ()
      Some((r0, c0, r1, c1)) =>
        canvas.style_range(
          r0,
          c0,
          r1,
          c1,
          palette.attrs_for(nodes[i].role, state),
        )
    }
  }
  offscreen
}
