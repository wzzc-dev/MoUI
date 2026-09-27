///|
/// MoMao 程序 IR：唯一的程序事实来源。
/// 设计视图 / 积木视图 / 双语代码视图与 AI 提案都读写这棵树；
/// `.momao.json` 保存的是 IR 本身，不是任何一门前语言的源码。
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
    _ => None
  }
}

///|
/// 事件种类：点击类（按钮/列表框/表格）与内容改变类（输入框/选择框/列表框）。
pub(all) enum EventKind {
  OnClick
  OnChange
}

///|
pub fn EventKind::tag(self : EventKind) -> String {
  match self {
    OnClick => "on_click"
    OnChange => "on_change"
  }
}

///|
pub fn parse_event_kind(text : String) -> EventKind? {
  match text {
    "on_click" => Some(OnClick)
    "on_change" => Some(OnChange)
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
    _ => false
  }
}

///|
/// 设计空间：固定 640x480 画布（与前代一致，运行时按窗口缩放）。
pub const DESIGN_WIDTH : Int = 640

///|
pub const DESIGN_HEIGHT : Int = 480

///|
/// 控件：表单上的一件实物。items 承载列表框选项/表格初始行。
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
  StrLit(String)
  BoolLit(Bool)
  Var(String)
  Not(Expr)
  Neg(Expr)
  Binary(BinOp, Expr, Expr)
  Call(String, Array[Expr]) // 内建命令/函数（规范名见 momao_lang 目录）
}

///|
/// 语句（IR 是语句级，不是自由图；积木是其投影）。
pub(all) enum Stmt {
  Declare(String, Expr) // 变量 x = expr / let x = expr（首次引入）
  Assign(String, Expr) // x = expr（必须已声明）
  If(
    Expr,
    Array[Stmt],
    Array[(Expr, Array[Stmt])],
    Array[Stmt],
  ) // cond, then, else-ifs, else
  CountLoop(Expr, String?, Array[Stmt]) // times, loop var, body
  WhileLoop(Expr, Array[Stmt])
  Break
  Call(String, Array[Expr]) // 内建命令
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
}

///|
/// 程序：`.momao.json` 的根。
pub(all) struct MomaoProgram {
  version : Int
  window : WindowSpec
  controls : Array[Control]
  variables : Array[Variable]
  handlers : Array[Handler]
}

///|
pub fn default_window() -> WindowSpec {
  { title: "MoMao 程序", width: DESIGN_WIDTH, height: DESIGN_HEIGHT, }
}

///|
pub fn empty_program() -> MomaoProgram {
  {
    version: 1,
    window: default_window(),
    controls: [],
    variables: [],
    handlers: [],
  }
}

///|
pub fn find_control(program : MomaoProgram, name : String) -> Control? {
  for control in program.controls {
    if control.name == name {
      return Some(control)
    }
  }
  None
}

///|
pub fn find_variable(program : MomaoProgram, name : String) -> Variable? {
  for variable in program.variables {
    if variable.name == name {
      return Some(variable)
    }
  }
  None
}

///|
pub fn find_handler(
  program : MomaoProgram,
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
pub fn next_control_id(program : MomaoProgram) -> Int {
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
/// 保留字检查在 `momao_lang`（它拥有关键字表，IR 不依赖语言）。
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
    let ok = if first {
      is_name_start(c)
    } else {
      is_name_part(c)
    }
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
