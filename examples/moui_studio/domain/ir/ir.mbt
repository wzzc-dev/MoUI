///|
/// MoUI Studio 程序 IR：唯一的程序事实来源。
/// 设计视图 / 积木视图 / 双语代码视图与 AI 提案都读写这棵树；
/// `.studio.json` 保存的是 IR 本身，不是任何一门前语言的源码。
/// 零依赖纯 MoonBit：不引用 moui、json 或任何 UI 包。

///|
/// 控件种类（v1 表单应用域：6 类）。
pub(all) enum ControlKind {
  Button
  Label
  TextField
  CheckBox
  ListBox
  Table
  Dropdown
  ProgressBar
  Image
}

///|
pub fn ControlKind::tag(self : ControlKind) -> String {
  match self {
    Button => "button"
    Label => "label"
    TextField => "text_field"
    CheckBox => "check_box"
    ListBox => "list_box"
    Table => "table"
    Dropdown => "dropdown"
    ProgressBar => "progress_bar"
    Image => "image"
  }
}

///|
pub fn parse_control_kind(text : String) -> ControlKind? {
  match text {
    "button" => Some(Button)
    "label" => Some(Label)
    "text_field" => Some(TextField)
    "check_box" => Some(CheckBox)
    "list_box" => Some(ListBox)
    "table" => Some(Table)
    "dropdown" => Some(Dropdown)
    "progress_bar" => Some(ProgressBar)
    "image" => Some(Image)
    _ => None
  }
}

///|
/// 事件种类：点击类（按钮/列表框/表格）与内容改变类（输入框/选择框/列表框）。
pub(all) enum EventKind {
  OnClick
  OnChange
  OnInputDone
  OnTimer
  OnBroadcast
  /// 程序启动（G7.1）：窗体级（control_name = ""），运行装填后立即执行
  OnStart
}

///|
pub fn EventKind::tag(self : EventKind) -> String {
  match self {
    OnClick => "on_click"
    OnChange => "on_change"
    OnInputDone => "on_input_done"
    OnTimer => "on_timer"
    OnBroadcast => "on_broadcast"
    OnStart => "on_start"
  }
}

///|
pub fn parse_event_kind(text : String) -> EventKind? {
  match text {
    "on_click" => Some(OnClick)
    "on_change" => Some(OnChange)
    "on_input_done" => Some(OnInputDone)
    "on_timer" => Some(OnTimer)
    "on_broadcast" => Some(OnBroadcast)
    "on_start" => Some(OnStart)
    _ => None
  }
}

///|
pub fn ControlKind::supports_event(
  self : ControlKind,
  event : EventKind,
) -> Bool {
  match (self, event) {
    (Button, OnClick) => true
    (ListBox, OnClick) | (ListBox, OnChange) => true
    (Table, OnClick) => true
    (TextField, OnChange) | (CheckBox, OnChange) => true
    // 切片 G 新控件
    (Dropdown, OnChange) | (Dropdown, OnInputDone) => true
    (ProgressBar, OnChange) => true
    (Image, OnClick) => true
    (TextField, OnInputDone) => true
    _ => false
  }
}

///|
/// 设计空间：固定 640x480 画布（与前代一致，运行时按窗口缩放）。
pub const DESIGN_WIDTH : Int = 640

///|
pub const DESIGN_HEIGHT : Int = 480

///|
/// 控件：表单上的一件实物。items 按种类承载不同载荷（属性 schema 的
/// 数据面）：列表框/下拉框=选项、表格=初始行、进度条=[绑定变量名]、
/// 图片=[资源路径]。
pub(all) struct Control {
  id : Int
  kind : ControlKind
  name : String
  text : String
  x : Int
  y : Int
  width : Int
  height : Int
  items : Array[String]
}

///|
/// 程序变量（DSL 动态类型）：init 是初始值文本，空串 = 空文本。
pub(all) struct Variable {
  name : String
  init : String
}

///|
/// 二元运算符（IR 是规范形态：源码符号只是渲染）。
pub(all) enum BinOp {
  Add // +（文本拼接或数值相加）
  Sub
  Mul
  Div
  Eq
  Ne
  Lt
  Gt
  Le
  Ge
  And
  Or
}

///|
pub fn BinOp::canonical(self : BinOp) -> String {
  match self {
    Add => "+"
    Sub => "-"
    Mul => "*"
    Div => "/"
    Eq => "="
    Ne => "<>"
    Lt => "<"
    Gt => ">"
    Le => "<="
    Ge => ">="
    And => "and"
    Or => "or"
  }
}

///|
/// 表达式。
pub(all) enum Expr {
  NumLit(Double)
  IntLit(Int)
  StrLit(String)
  ListLit(Array[Expr])
  BoolLit(Bool)
  Var(String)
  Not(Expr)
  Neg(Expr)
  Index(Expr, Expr)
  Binary(BinOp, Expr, Expr)
  Call(String, Array[Expr]) // 内建命令/函数（规范名见 studio_lang 目录）
  FieldAccess(Expr, String) // base.field_name（M5-5c）
  EnumTag(String, String) // 枚举值字面量：枚举名::情况名（M5-5d）
}

///|
/// 匹配分派臂（M5-5d）：case_name 必须是某已声明枚举的情况。
pub(all) struct MatchArm {
  case_name : String
  body : Array[Stmt]
}

///|
/// 语句（IR 是语句级，不是自由图；积木是其投影）。
pub(all) enum Stmt {
  Declare(String, Expr) // 变量 x = expr / let x = expr（首次引入）
  Assign(String, Expr) // x = expr（必须已声明）
  If(Expr, Array[Stmt], Array[(Expr, Array[Stmt])], Array[Stmt]) // cond, then, else-ifs, else
  CountLoop(Expr, String?, Array[Stmt]) // times, loop var, body
  ForEach(Expr, String, Array[Stmt]) // 遍历列表表达式, 元素变量, 体（G7.1）
  WhileLoop(Expr, Array[Stmt])
  Break
  Call(String, Array[Expr]) // 内建命令
  SetIndex(String, Expr, Expr) // 名单[i] = 值
  Return(Expr?) // 返回 expr（仅函数体内合法）
  Match(Expr, Array[MatchArm], Array[Stmt]) // subject, arms, else（M5-5d；else 可为空但必在）
}

///|
/// 事件子程序：一个（控件, 事件）对应一段程序体。
/// note 是双语「意图说明」——AI 提案的必填项，可读性契约的载体。
pub(all) struct Handler {
  control_name : String
  event : EventKind
  note_zh : String
  note_en : String
  body : Array[Stmt]
}

///|
pub(all) struct WindowSpec {
  title : String
  width : Int
  height : Int
  // 定时器间隔（秒；0 = 关闭）——OnTimer 虚拟时钟只在运行期间步进
  timer_interval : Int
}

///|
/// 用户自定义函数：带参子程序（切片 F 语言层）。
/// 返回值经 `Return` 语句给出；无 Return 的函数返回 VUnit。
/// note 延续 Handler 的双语「意图说明」可读性契约。
pub(all) struct FuncDef {
  name : String
  params : Array[String]
  body : Array[Stmt]
  note_zh : String
  note_en : String
}

///|
/// 程序：`.studio.json` 的根。
pub(all) struct StudioProgram {
  version : Int
  window : WindowSpec
  controls : Array[Control]
  variables : Array[Variable]
  handlers : Array[Handler]
  functions : Array[FuncDef]
  structs : Array[StructDecl]
  enums : Array[EnumDecl]
}

///|
/// struct 字段(M5-5c)。
pub(all) struct StructField {
  field_name : String
  field_type : String
}

///|
/// struct 声明(M5-5c)。
pub(all) struct StructDecl {
  name : String
  fields : Array[StructField]
}

///|
/// 枚举声明(M5-5d)：标签集合，v1 无载荷。
pub(all) struct EnumDecl {
  name : String
  cases : Array[String]
}

///|
pub fn default_window() -> WindowSpec {
  {
    title: "MoUI Studio 程序",
    width: DESIGN_WIDTH,
    height: DESIGN_HEIGHT,
    timer_interval: 0,
  }
}

///|
pub fn empty_program() -> StudioProgram {
  {
    version: 1,
    window: default_window(),
    controls: [],
    variables: [],
    handlers: [],
    functions: [],
    structs: [],
    enums: [],
  }
}

///|
/// 按名找用户函数（调用解析：先内建、后自定义）。
pub fn find_function(program : StudioProgram, name : String) -> FuncDef? {
  for func in program.functions {
    if func.name == name {
      return Some(func)
    }
  }
  None
}

///|
pub fn find_control(program : StudioProgram, name : String) -> Control? {
  for control in program.controls {
    if control.name == name {
      return Some(control)
    }
  }
  None
}

///|
pub fn find_variable(program : StudioProgram, name : String) -> Variable? {
  for variable in program.variables {
    if variable.name == name {
      return Some(variable)
    }
  }
  None
}

///|
pub fn find_handler(
  program : StudioProgram,
  control_name : String,
  event : EventKind,
) -> Handler? {
  for handler in program.handlers {
    if handler.control_name == control_name &&
      handler.event.tag() == event.tag() {
      return Some(handler)
    }
  }
  None
}

///|
/// 下一个控件 id（比现有最大 id 大 1）。
pub fn next_control_id(program : StudioProgram) -> Int {
  let mut max_id = 0
  for control in program.controls {
    if control.id > max_id {
      max_id = control.id
    }
  }
  max_id + 1
}

///|
/// 控件命名语法：ASCII 字母/下划线/中日韩汉字开头，后接字母数字汉字下划线。
/// 保留字检查在 `studio_lang`（它拥有关键字表，IR 不依赖语言）。
pub fn control_name_syntax_valid(name : String) -> Bool {
  name_syntax_valid_inner(name, 32)
}

///|
pub fn variable_name_syntax_valid(name : String) -> Bool {
  name_syntax_valid_inner(name, 32)
}

///|
fn name_syntax_valid_inner(name : String, max_length : Int) -> Bool {
  if name.length() == 0 || name.length() > max_length {
    return false
  }
  let mut first = true
  for c in name {
    let ok = if first { is_name_start(c) } else { is_name_part(c) }
    if !ok {
      return false
    }
    first = false
  }
  true
}

///|
fn is_name_start(c : Char) -> Bool {
  let code = c.to_int()
  (code >= 0x41 && code <= 0x5A) ||
  (code >= 0x61 && code <= 0x7A) ||
  c == '_' ||
  is_cjk(code)
}

///|
fn is_name_part(c : Char) -> Bool {
  let code = c.to_int()
  is_name_start(c) || (code >= 0x30 && code <= 0x39)
}

///|
/// CJK 统一表意文字主区（覆盖常用汉字；扩展区罕见不做）。
fn is_cjk(code : Int) -> Bool {
  code >= 0x4E00 && code <= 0x9FFF
}

///|
/// 控件矩形分量（检查器属性编辑与画布拖拽共用）。
pub(all) enum RectField {
  RectX
  RectY
  RectWidth
  RectHeight
}

///|
/// 缩放角位（画布四角手柄拖拽缩放共用；对角在拖拽中保持不动）。
pub(all) enum DragCorner {
  CornerNW
  CornerNE
  CornerSW
  CornerSE
}

///|
fn clamp_int(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
/// 控件最小边长（属性框误输入 0/负数的防线）。
pub const MIN_CONTROL_SIZE : Int = 8

///|
/// 更新矩形分量并夹回设计画布：控件永远完整落在 640x480 内，
/// 尺寸不小于 MIN_CONTROL_SIZE。拖拽与属性编辑共用同一夹取规则。
pub fn Control::with_rect_field(
  self : Control,
  field : RectField,
  value : Int,
) -> Control {
  match field {
    RectWidth => {
      let width = clamp_int(value, MIN_CONTROL_SIZE, DESIGN_WIDTH)
      { ..self, width, x: clamp_int(self.x, 0, (DESIGN_WIDTH - width).max(0)), }
    }
    RectHeight => {
      let height = clamp_int(value, MIN_CONTROL_SIZE, DESIGN_HEIGHT)
      {
        ..self,
        height,
        y: clamp_int(self.y, 0, (DESIGN_HEIGHT - height).max(0)),
      }
    }
    RectX =>
      { ..self, x: clamp_int(value, 0, (DESIGN_WIDTH - self.width).max(0)), }
    RectY =>
      { ..self, y: clamp_int(value, 0, (DESIGN_HEIGHT - self.height).max(0)), }
  }
}

///|
/// 从指定角拖拽缩放：对角固定，指针点作为该角的新位置。
/// 与 with_rect_field 共用同一夹取纪律——控件永远完整落在 640x480 内，
/// 边长不小于 MIN_CONTROL_SIZE。
pub fn Control::resize_from_corner(
  self : Control,
  corner : DragCorner,
  to_x : Int,
  to_y : Int,
) -> Control {
  match corner {
    CornerSE =>
      // 左上角固定：宽高朝指针方向生长
      {
        ..self,
        width: clamp_int(to_x - self.x, MIN_CONTROL_SIZE, DESIGN_WIDTH - self.x),
        height: clamp_int(
          to_y - self.y,
          MIN_CONTROL_SIZE,
          DESIGN_HEIGHT - self.y,
        ),
      }
    CornerNW => {
      // 右下角固定：移动左上角，宽高由对角反推
      let right = self.x + self.width
      let bottom = self.y + self.height
      let new_x = clamp_int(to_x, 0, right - MIN_CONTROL_SIZE)
      let new_y = clamp_int(to_y, 0, bottom - MIN_CONTROL_SIZE)
      {
        ..self,
        x: new_x,
        y: new_y,
        width: right - new_x,
        height: bottom - new_y,
      }
    }
    CornerNE => {
      // 左缘/下缘固定：右缘朝指针生长，上缘随指针移动
      let bottom = self.y + self.height
      let new_y = clamp_int(to_y, 0, bottom - MIN_CONTROL_SIZE)
      {
        ..self,
        width: clamp_int(to_x - self.x, MIN_CONTROL_SIZE, DESIGN_WIDTH - self.x),
        y: new_y,
        height: bottom - new_y,
      }
    }
    CornerSW => {
      // 右缘/上缘固定：左缘随指针移动，下缘朝指针生长
      let right = self.x + self.width
      let new_x = clamp_int(to_x, 0, right - MIN_CONTROL_SIZE)
      {
        ..self,
        x: new_x,
        width: right - new_x,
        height: clamp_int(
          to_y - self.y,
          MIN_CONTROL_SIZE,
          DESIGN_HEIGHT - self.y,
        ),
      }
    }
  }
}
