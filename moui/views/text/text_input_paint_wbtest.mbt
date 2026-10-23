///|
/// 文本框的编辑覆盖层在没有逐字插入点可依据时也不能崩。
///
/// 真终端里点一下文本框整个应用就没掉了,走的就是这条:等宽 cell 文本系统只保证
/// 盒尺寸,原先报的是 `caret_positions: []`,而覆盖层先把下标 `clamp` 到
/// `max_int(0, len - 1)`(空数组得到 0)再按下标取 —— 看着像防越界,其实是把
/// 空数组的越界藏进了一个合法下标里。
test "the text field editing overlay survives a caret-less text system" {
  let control : @core.TextControlStateContext = {
    caret: 1,
    selection: None,
    text_selection_anchor: None,
    goal_column: None,
    reveal: None,
    text_selection_origin: None,
    composition: None,
    composition_cursor: None,
    undo_stack: [],
    redo_stack: [],
  }
  let frame = @core.Rect::new(x=10.0, y=4.0, width=120.0, height=24.0)
  let layout : @core.TextLayoutResult = {
    size: @core.Size::new(width=0.0, height=0.0),
    baseline: 0.0,
    caret_positions: [],
  }
  let commands : Array[@core.DrawCommand] = []
  append_text_field_editing_overlay(
    commands,
    text="ab",
    display_text="ab",
    text_frame=frame,
    layout~,
    control~,
    cursor_color=@style.default_theme().palette.primary,
    theme=@style.default_theme(),
  )
  // 没有几何可依据时插入点退回盒起点,但裁剪必须照样成对开合:
  // 少了那一次 PopClip,后续所有绘制都会一直裁在这个框里。
  assert_eq(commands.length(), 3)
  match commands[0] {
    PushClip(rect) => assert_true(rect.origin.x == frame.origin.x)
    _ => fail("expected the overlay to open with its clip")
  }
  match commands[1] {
    FillRect(rect, _) => assert_true(rect.origin.x == frame.origin.x)
    _ => fail("expected the caret rectangle")
  }
  match commands[2] {
    PopClip => ()
    _ => fail("expected the overlay to close its clip")
  }
}

///|
/// 选中底色要的是两个插入点之间的区间:没有插入点就没有区间,
/// 但也不能因此越界(这条在带选区的文本框上同样会走到)。
test "text field selection geometry needs no caret positions" {
  let layout : @core.TextLayoutResult = {
    size: @core.Size::new(width=0.0, height=0.0),
    baseline: 0.0,
    caret_positions: [],
  }
  let commands : Array[@core.DrawCommand] = []
  append_text_field_selection_commands(
    commands,
    "ab",
    @core.Rect::new(x=10.0, y=4.0, width=120.0, height=24.0),
    layout,
    Some(@core.TextRange::new(start=0, end=2)),
    @style.default_theme(),
  )
  assert_true(commands.is_empty())
}
