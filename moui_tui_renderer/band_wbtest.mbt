// R-B1 的单元级证据:两个样式带 pass 的顺序(焦点先落、选中压轴)此前只有
// PTY 用例("S7 a clicked row keeps the selection band on itself")兜底 ——
// 那要真终端、要串行、要秒级,而且无法把断言精确钉在两个带的重叠格上。
// 这里用白盒直接调 project_payload,把"谁压住谁"钉成一次可复跑的几何事实。

///|
fn payload_of(
  nodes~ : Array[@core.SemanticsNode],
  root~ : @core.SemanticsNode,
) -> @core.SemanticsFramePayload {
  @core.SemanticsFramePayload::new(
    generation=@core.SemanticsGeneration::new(1UL),
    nodes~,
    root=Some(root.node_id),
  )
}

///|
/// 白盒包看不到黑盒 `fixture_test.mbt` 的助手,这里自带最小构造:
/// `SemanticsNode` 是 `pub(all)` 记录,`SemanticsState::default()` 是 pub。
fn mk_node(
  v~ : UInt64,
  role~ : @core.SemanticsRole,
  y0~ : Double,
  h~ : Double,
  x0~ : Double,
  w~ : Double,
  label~ : String,
  state~ : @core.SemanticsState,
  children~ : Array[@core.SemanticsNodeId],
) -> @core.SemanticsNode {
  {
    node_id: @core.SemanticsNodeId::new(v),
    semantic_id: None,
    role,
    level: None,
    url: "",
    label,
    value: "",
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
    frame: @core.Rect::new(x=x0, y=y0, width=w, height=h),
    children,
  }
}

///|
fn nid(v : UInt64) -> @core.SemanticsNodeId {
  @core.SemanticsNodeId::new(v)
}

///|
/// 本工具链版本没有 `{ ... }` 记录更新,全字段字面量照 `SemanticsState::default()`
/// 展开;测试只关心 focused/selected 两维,其余一律取默认值。
fn mk_state(
  focused? : Bool = false,
  selected? : Bool = false,
) -> @core.SemanticsState {
  let base = @core.SemanticsState::default()
  {
    focused,
    disabled: base.disabled,
    selected,
    pressed: base.pressed,
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
/// 布局:整屏 Group 画框;第 1 行是一条选中的 ListItem(它自己不写字,
/// 带跨整行 0..19);行内嵌一个带焦点的 Button(盒跨 1..3 行的 4..11 列,
/// `[Go]` 字形落在第 1 行)。按钮带先刷、行带后刷,重叠列 4..11 的最终
/// attrs 就是顺序的指纹:选中压轴 → 反白在、下划线不在;若顺序反过来,
/// 焦点带会在压轴时把重叠格刷回无下划线的青底 —— 反白消失。
test "the selected band wins every cell it shares with the focused band" {
  let canvas = Canvas::new(20, 5)
  let row_state = mk_state(selected=true)
  let button_state = mk_state(focused=true)
  let root = mk_node(
    v=1UL,
    role=@core.Group,
    y0=0.0,
    h=80.0,
    x0=0.0,
    w=160.0,
    label="",
    state=@core.SemanticsState::default(),
    children=[nid(2UL), nid(3UL)],
  )
  let row = mk_node(
    v=2UL,
    role=@core.ListItem,
    y0=16.0,
    h=16.0,
    x0=0.0,
    w=160.0,
    label="",
    state=row_state,
    children=[nid(3UL)],
  )
  let button = mk_node(
    v=3UL,
    role=@core.Button,
    y0=16.0,
    h=48.0,
    x0=32.0,
    w=64.0,
    label="Go",
    state=button_state,
    children=[],
  )
  ignore(
    project_payload(
      canvas,
      payload_of(nodes=[root, row, button], root~),
      CellBox::default(),
      DegradeLog::new(),
      TuiPalette::default(),
    ),
  )
  // 重叠且无字形:选中的反白必须活着(顺序反了这里就没有 reverse)。
  assert_true(cell_at(canvas, 1, 9).attrs.reverse)
  // 重叠且有字形:行带仍然压过按钮焦点带 —— 整行是选中的唯一表示。
  assert_true(cell_at(canvas, 1, 4).attrs.reverse)
  // 焦点带自己盒子里、行带之外的格:没有反白可继承,只剩色不带装饰。
  assert_false(cell_at(canvas, 2, 6).attrs.reverse)
  assert_false(cell_at(canvas, 2, 6).attrs.underline)
}
