///|
/// 终端拖选节点:捕获 Pointer Down/Move/Up,将坐标换算为屏幕单元格,
/// 转为选择消息。拖动状态由 app Model 维护(节点实例每次重建,
/// 不保存可变状态)。
pub struct TerminalSelectionNode {
  cell_width : Double
  cell_height : Double
  scroll_offset : Int
  total_lines : Int
  rows : Int
  cols : Int
}

///|
pub fn TerminalSelectionNode::new(
  cell_width~ : Double,
  cell_height~ : Double,
  scroll_offset~ : Int,
  total_lines~ : Int,
  rows~ : Int,
  cols~ : Int,
) -> TerminalSelectionNode {
  { cell_width, cell_height, scroll_offset, total_lines, rows, cols }
}

///|
impl @core.ViewNode for TerminalSelectionNode with fn identity(_self) {
  @core.ViewIdentity::new(kind="TerminalSelection")
}

///|
impl @core.ViewNode for TerminalSelectionNode with fn layout(_self, ctx) {
  let child_size = if ctx.child_sizes.length() > 0 {
    ctx.child_sizes[0]
  } else {
    @core.Size::new(width=0.0, height=0.0)
  }
  @core.ViewLayoutResult::new(size=child_size, child_frames=[
    @core.Rect::new(
      x=0.0,
      y=0.0,
      width=child_size.width,
      height=child_size.height,
    ),
  ])
}

///|
impl @core.ViewNode for TerminalSelectionNode with fn focusable(_self) {
  false
}

///|
/// 事件坐标 → 屏幕单元格(全局行 + 列),越界收敛。
pub fn TerminalSelectionNode::cell_at(
  self : TerminalSelectionNode,
  position : @core.Point,
  frame : @core.Rect,
) -> (Int, Int) {
  let dx = position.x - frame.origin.x
  let dy = position.y - frame.origin.y
  let col = if self.cell_width > 0.0 {
    (dx / self.cell_width).floor().to_int()
  } else {
    0
  }
  let row_on_screen = if self.cell_height > 0.0 {
    (dy / self.cell_height).floor().to_int()
  } else {
    0
  }
  // 可视区第一行对应的全局行
  let first_visible = self.total_lines - self.rows - self.scroll_offset
  let row = first_visible + row_on_screen
  let row_clamped = row.clamp(min=0, max=(self.total_lines - 1).max(0))
  let col_clamped = col.clamp(min=0, max=(self.cols - 1).max(0))
  (row_clamped, col_clamped)
}

///|
/// 拖选包装:子节点照常渲染,本节点把指针拖选转为消息。
pub fn[Msg] terminal_selection_input(
  content : @moui.View[Msg],
  on_begin : (Int, Int) -> Msg?,
  on_move : (Int, Int) -> Msg?,
  on_end : () -> Msg?,
  cell_width~ : Double,
  cell_height~ : Double,
  scroll_offset~ : Int,
  total_lines~ : Int,
  rows~ : Int,
  cols~ : Int,
) -> @moui.View[Msg] {
  let node = TerminalSelectionNode::new(
    cell_width~,
    cell_height~,
    scroll_offset~,
    total_lines~,
    rows~,
    cols~,
  )
  @core.View::from_node(node, children=_node => [content], event=(_node, ctx) => {
    match ctx.event {
      @core.AppEvent::Pointer(pointer) =>
        match pointer.phase {
          @core.PointerPhase::Down =>
            if pointer.button == 0 {
              let (row, col) = node.cell_at(pointer.position, ctx.frame)
              match on_begin(row, col) {
                Some(msg) => @core.ViewEventResult::message(msg)
                None => @core.ViewEventResult::ignored()
              }
            } else {
              @core.ViewEventResult::ignored()
            }
          @core.PointerPhase::Move => {
            let (row, col) = node.cell_at(pointer.position, ctx.frame)
            match on_move(row, col) {
              Some(msg) => @core.ViewEventResult::message(msg)
              None => @core.ViewEventResult::ignored()
            }
          }
          @core.PointerPhase::Up =>
            if pointer.button == 0 {
              match on_end() {
                Some(msg) => @core.ViewEventResult::message(msg)
                None => @core.ViewEventResult::ignored()
              }
            } else {
              @core.ViewEventResult::ignored()
            }
          _ => @core.ViewEventResult::ignored()
        }
      _ => @core.ViewEventResult::ignored()
    }
  })
}
