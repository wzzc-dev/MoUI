///|
/// kernel_ir：domain 下若干 .mbt 的逐字节副本。
/// 由 tools/sync_kernel 生成，勿手改；与源文件不一致时
/// `moon run examples/moui_studio/tools/sync_kernel --target native -- --check` 会报 DRIFT。

///|
pub fn kernel_ir_mbt() -> String {
  let source =
    #|///|
    #|/// MoUI Studio 程序 IR：唯一的程序事实来源。
    #|/// 设计视图 / 积木视图 / 双语代码视图与 AI 提案都读写这棵树；
    #|/// `.studio.json` 保存的是 IR 本身，不是任何一门前语言的源码。
    #|/// 零依赖纯 MoonBit：不引用 moui、json 或任何 UI 包。
    #|
    #|///|
    #|/// 控件种类（v1 表单应用域：6 类）。
    #|pub(all) enum ControlKind {
    #|  Button
    #|  Label
    #|  TextField
    #|  CheckBox
    #|  ListBox
    #|  Table
    #|}
    #|
    #|///|
    #|pub fn ControlKind::tag(self : ControlKind) -> String {
    #|  match self {
    #|    Button => "button"
    #|    Label => "label"
    #|    TextField => "text_field"
    #|    CheckBox => "check_box"
    #|    ListBox => "list_box"
    #|    Table => "table"
    #|  }
    #|}
    #|
    #|///|
    #|pub fn parse_control_kind(text : String) -> ControlKind? {
    #|  match text {
    #|    "button" => Some(Button)
    #|    "label" => Some(Label)
    #|    "text_field" => Some(TextField)
    #|    "check_box" => Some(CheckBox)
    #|    "list_box" => Some(ListBox)
    #|    "table" => Some(Table)
    #|    _ => None
    #|  }
    #|}
    #|
    #|///|
    #|/// 事件种类：点击类（按钮/列表框/表格）与内容改变类（输入框/选择框/列表框）。
    #|pub(all) enum EventKind {
    #|  OnClick
    #|  OnChange
    #|}
    #|
    #|///|
    #|pub fn EventKind::tag(self : EventKind) -> String {
    #|  match self {
    #|    OnClick => "on_click"
    #|    OnChange => "on_change"
    #|  }
    #|}
    #|
    #|///|
    #|pub fn parse_event_kind(text : String) -> EventKind? {
    #|  match text {
    #|    "on_click" => Some(OnClick)
    #|    "on_change" => Some(OnChange)
    #|    _ => None
    #|  }
    #|}
    #|
    #|///|
    #|pub fn ControlKind::supports_event(
    #|  self : ControlKind,
    #|  event : EventKind,
    #|) -> Bool {
    #|  match (self, event) {
    #|    (Button, OnClick) => true
    #|    (ListBox, OnClick) | (ListBox, OnChange) => true
    #|    (Table, OnClick) => true
    #|    (TextField, OnChange) | (CheckBox, OnChange) => true
    #|    _ => false
    #|  }
    #|}
    #|
    #|///|
    #|/// 设计空间：固定 640x480 画布（与前代一致，运行时按窗口缩放）。
    #|pub const DESIGN_WIDTH : Int = 640
    #|
    #|///|
    #|pub const DESIGN_HEIGHT : Int = 480
    #|
    #|///|
    #|/// 控件：表单上的一件实物。items 承载列表框选项/表格初始行。
    #|pub(all) struct Control {
    #|  id : Int
    #|  kind : ControlKind
    #|  name : String
    #|  text : String
    #|  x : Int
    #|  y : Int
    #|  width : Int
    #|  height : Int
    #|  items : Array[String]
    #|}
    #|
    #|///|
    #|/// 程序变量（DSL 动态类型）：init 是初始值文本，空串 = 空文本。
    #|pub(all) struct Variable {
    #|  name : String
    #|  init : String
    #|}
    #|
    #|///|
    #|/// 二元运算符（IR 是规范形态：源码符号只是渲染）。
    #|pub(all) enum BinOp {
    #|  Add // +（文本拼接或数值相加）
    #|  Sub
    #|  Mul
    #|  Div
    #|  Eq
    #|  Ne
    #|  Lt
    #|  Gt
    #|  Le
    #|  Ge
    #|  And
    #|  Or
    #|}
    #|
    #|///|
    #|pub fn BinOp::canonical(self : BinOp) -> String {
    #|  match self {
    #|    Add => "+"
    #|    Sub => "-"
    #|    Mul => "*"
    #|    Div => "/"
    #|    Eq => "="
    #|    Ne => "<>"
    #|    Lt => "<"
    #|    Gt => ">"
    #|    Le => "<="
    #|    Ge => ">="
    #|    And => "and"
    #|    Or => "or"
    #|  }
    #|}
    #|
    #|///|
    #|/// 表达式。
    #|pub(all) enum Expr {
    #|  NumLit(Double)
    #|  StrLit(String)
    #|  BoolLit(Bool)
    #|  Var(String)
    #|  Not(Expr)
    #|  Neg(Expr)
    #|  Binary(BinOp, Expr, Expr)
    #|  Call(String, Array[Expr]) // 内建命令/函数（规范名见 studio_lang 目录）
    #|}
    #|
    #|///|
    #|/// 语句（IR 是语句级，不是自由图；积木是其投影）。
    #|pub(all) enum Stmt {
    #|  Declare(String, Expr) // 变量 x = expr / let x = expr（首次引入）
    #|  Assign(String, Expr) // x = expr（必须已声明）
    #|  If(Expr, Array[Stmt], Array[(Expr, Array[Stmt])], Array[Stmt]) // cond, then, else-ifs, else
    #|  CountLoop(Expr, String?, Array[Stmt]) // times, loop var, body
    #|  WhileLoop(Expr, Array[Stmt])
    #|  Break
    #|  Call(String, Array[Expr]) // 内建命令
    #|}
    #|
    #|///|
    #|/// 事件子程序：一个（控件, 事件）对应一段程序体。
    #|/// note 是双语「意图说明」——AI 提案的必填项，可读性契约的载体。
    #|pub(all) struct Handler {
    #|  control_name : String
    #|  event : EventKind
    #|  note_zh : String
    #|  note_en : String
    #|  body : Array[Stmt]
    #|}
    #|
    #|///|
    #|pub(all) struct WindowSpec {
    #|  title : String
    #|  width : Int
    #|  height : Int
    #|}
    #|
    #|///|
    #|/// 程序：`.studio.json` 的根。
    #|pub(all) struct StudioProgram {
    #|  version : Int
    #|  window : WindowSpec
    #|  controls : Array[Control]
    #|  variables : Array[Variable]
    #|  handlers : Array[Handler]
    #|}
    #|
    #|///|
    #|pub fn default_window() -> WindowSpec {
    #|  { title: "MoUI Studio 程序", width: DESIGN_WIDTH, height: DESIGN_HEIGHT, }
    #|}
    #|
    #|///|
    #|pub fn empty_program() -> StudioProgram {
    #|  {
    #|    version: 1,
    #|    window: default_window(),
    #|    controls: [],
    #|    variables: [],
    #|    handlers: [],
    #|  }
    #|}
    #|
    #|///|
    #|pub fn find_control(program : StudioProgram, name : String) -> Control? {
    #|  for control in program.controls {
    #|    if control.name == name {
    #|      return Some(control)
    #|    }
    #|  }
    #|  None
    #|}
    #|
    #|///|
    #|pub fn find_variable(program : StudioProgram, name : String) -> Variable? {
    #|  for variable in program.variables {
    #|    if variable.name == name {
    #|      return Some(variable)
    #|    }
    #|  }
    #|  None
    #|}
    #|
    #|///|
    #|pub fn find_handler(
    #|  program : StudioProgram,
    #|  control_name : String,
    #|  event : EventKind,
    #|) -> Handler? {
    #|  for handler in program.handlers {
    #|    if handler.control_name == control_name &&
    #|      handler.event.tag() == event.tag() {
    #|      return Some(handler)
    #|    }
    #|  }
    #|  None
    #|}
    #|
    #|///|
    #|/// 下一个控件 id（比现有最大 id 大 1）。
    #|pub fn next_control_id(program : StudioProgram) -> Int {
    #|  let mut max_id = 0
    #|  for control in program.controls {
    #|    if control.id > max_id {
    #|      max_id = control.id
    #|    }
    #|  }
    #|  max_id + 1
    #|}
    #|
    #|///|
    #|/// 控件命名语法：ASCII 字母/下划线/中日韩汉字开头，后接字母数字汉字下划线。
    #|/// 保留字检查在 `studio_lang`（它拥有关键字表，IR 不依赖语言）。
    #|pub fn control_name_syntax_valid(name : String) -> Bool {
    #|  name_syntax_valid_inner(name, 32)
    #|}
    #|
    #|///|
    #|pub fn variable_name_syntax_valid(name : String) -> Bool {
    #|  name_syntax_valid_inner(name, 32)
    #|}
    #|
    #|///|
    #|fn name_syntax_valid_inner(name : String, max_length : Int) -> Bool {
    #|  if name.length() == 0 || name.length() > max_length {
    #|    return false
    #|  }
    #|  let mut first = true
    #|  for c in name {
    #|    let ok = if first { is_name_start(c) } else { is_name_part(c) }
    #|    if !ok {
    #|      return false
    #|    }
    #|    first = false
    #|  }
    #|  true
    #|}
    #|
    #|///|
    #|fn is_name_start(c : Char) -> Bool {
    #|  let code = c.to_int()
    #|  (code >= 0x41 && code <= 0x5A) ||
    #|  (code >= 0x61 && code <= 0x7A) ||
    #|  c == '_' ||
    #|  is_cjk(code)
    #|}
    #|
    #|///|
    #|fn is_name_part(c : Char) -> Bool {
    #|  let code = c.to_int()
    #|  is_name_start(c) || (code >= 0x30 && code <= 0x39)
    #|}
    #|
    #|///|
    #|/// CJK 统一表意文字主区（覆盖常用汉字；扩展区罕见不做）。
    #|fn is_cjk(code : Int) -> Bool {
    #|  code >= 0x4E00 && code <= 0x9FFF
    #|}
    #|
    #|///|
    #|/// 控件矩形分量（检查器属性编辑与画布拖拽共用）。
    #|pub(all) enum RectField {
    #|  RectX
    #|  RectY
    #|  RectWidth
    #|  RectHeight
    #|}
    #|
    #|///|
    #|/// 缩放角位（画布四角手柄拖拽缩放共用；对角在拖拽中保持不动）。
    #|pub(all) enum DragCorner {
    #|  CornerNW
    #|  CornerNE
    #|  CornerSW
    #|  CornerSE
    #|}
    #|
    #|///|
    #|fn clamp_int(value : Int, min : Int, max : Int) -> Int {
    #|  if value < min {
    #|    min
    #|  } else if value > max {
    #|    max
    #|  } else {
    #|    value
    #|  }
    #|}
    #|
    #|///|
    #|/// 控件最小边长（属性框误输入 0/负数的防线）。
    #|pub const MIN_CONTROL_SIZE : Int = 8
    #|
    #|///|
    #|/// 更新矩形分量并夹回设计画布：控件永远完整落在 640x480 内，
    #|/// 尺寸不小于 MIN_CONTROL_SIZE。拖拽与属性编辑共用同一夹取规则。
    #|pub fn Control::with_rect_field(
    #|  self : Control,
    #|  field : RectField,
    #|  value : Int,
    #|) -> Control {
    #|  match field {
    #|    RectWidth => {
    #|      let width = clamp_int(value, MIN_CONTROL_SIZE, DESIGN_WIDTH)
    #|      { ..self, width, x: clamp_int(self.x, 0, (DESIGN_WIDTH - width).max(0)), }
    #|    }
    #|    RectHeight => {
    #|      let height = clamp_int(value, MIN_CONTROL_SIZE, DESIGN_HEIGHT)
    #|      {
    #|        ..self,
    #|        height,
    #|        y: clamp_int(self.y, 0, (DESIGN_HEIGHT - height).max(0)),
    #|      }
    #|    }
    #|    RectX =>
    #|      { ..self, x: clamp_int(value, 0, (DESIGN_WIDTH - self.width).max(0)), }
    #|    RectY =>
    #|      { ..self, y: clamp_int(value, 0, (DESIGN_HEIGHT - self.height).max(0)), }
    #|  }
    #|}
    #|
    #|///|
    #|/// 从指定角拖拽缩放：对角固定，指针点作为该角的新位置。
    #|/// 与 with_rect_field 共用同一夹取纪律——控件永远完整落在 640x480 内，
    #|/// 边长不小于 MIN_CONTROL_SIZE。
    #|pub fn Control::resize_from_corner(
    #|  self : Control,
    #|  corner : DragCorner,
    #|  to_x : Int,
    #|  to_y : Int,
    #|) -> Control {
    #|  match corner {
    #|    CornerSE =>
    #|      // 左上角固定：宽高朝指针方向生长
    #|      {
    #|        ..self,
    #|        width: clamp_int(to_x - self.x, MIN_CONTROL_SIZE, DESIGN_WIDTH - self.x),
    #|        height: clamp_int(
    #|          to_y - self.y,
    #|          MIN_CONTROL_SIZE,
    #|          DESIGN_HEIGHT - self.y,
    #|        ),
    #|      }
    #|    CornerNW => {
    #|      // 右下角固定：移动左上角，宽高由对角反推
    #|      let right = self.x + self.width
    #|      let bottom = self.y + self.height
    #|      let new_x = clamp_int(to_x, 0, right - MIN_CONTROL_SIZE)
    #|      let new_y = clamp_int(to_y, 0, bottom - MIN_CONTROL_SIZE)
    #|      {
    #|        ..self,
    #|        x: new_x,
    #|        y: new_y,
    #|        width: right - new_x,
    #|        height: bottom - new_y,
    #|      }
    #|    }
    #|    CornerNE => {
    #|      // 左缘/下缘固定：右缘朝指针生长，上缘随指针移动
    #|      let bottom = self.y + self.height
    #|      let new_y = clamp_int(to_y, 0, bottom - MIN_CONTROL_SIZE)
    #|      {
    #|        ..self,
    #|        width: clamp_int(to_x - self.x, MIN_CONTROL_SIZE, DESIGN_WIDTH - self.x),
    #|        y: new_y,
    #|        height: bottom - new_y,
    #|      }
    #|    }
    #|    CornerSW => {
    #|      // 右缘/上缘固定：左缘随指针移动，下缘朝指针生长
    #|      let right = self.x + self.width
    #|      let new_x = clamp_int(to_x, 0, right - MIN_CONTROL_SIZE)
    #|      {
    #|        ..self,
    #|        x: new_x,
    #|        width: right - new_x,
    #|        height: clamp_int(
    #|          to_y - self.y,
    #|          MIN_CONTROL_SIZE,
    #|          DESIGN_HEIGHT - self.y,
    #|        ),
    #|      }
    #|    }
    #|  }
    #|}
    #|
  source
}

///|
pub fn kernel_ir_invariants_mbt() -> String {
  let source =
    #|///|
    #|/// IR 结构不变量与预算：decode / 编辑 / AI 提案 / 导出四处共用同一套。
    #|/// 本包只管「结构对不对」；内置命令名、关键字、可读性政策在
    #|/// `studio_lang` 与 `proposals`（它们不依赖本包，避免反向依赖）。
    #|
    #|///|
    #|pub const MAX_CONTROLS : Int = 128
    #|
    #|///|
    #|pub const MAX_VARIABLES : Int = 64
    #|
    #|///|
    #|pub const MAX_HANDLERS : Int = 64
    #|
    #|///|
    #|pub const MAX_STMTS_PER_HANDLER : Int = 512
    #|
    #|///|
    #|pub const MAX_TOTAL_STMTS : Int = 4096
    #|
    #|///|
    #|pub const MAX_LOOP_DEPTH : Int = 64
    #|
    #|///|
    #|pub const MAX_EXPR_DEPTH : Int = 32
    #|
    #|///|
    #|/// 结构错误（可读文案由界面层经 i18n catalog 本地化）。
    #|pub(all) enum IrError {
    #|  DuplicateControlName(String)
    #|  InvalidControlName(String)
    #|  InvalidVariableName(String)
    #|  DuplicateVariableName(String)
    #|  InvalidControlRect(String)
    #|  DuplicateHandler(String)
    #|  UnknownControlInHandler(String)
    #|  UnsupportedEvent(String, String)
    #|  TooManyControls
    #|  TooManyVariables
    #|  TooManyHandlers
    #|  TooManyStatements(Int)
    #|  LoopTooDeep(Int)
    #|  ExprTooDeep(Int)
    #|}
    #|
    #|///|
    #|/// 收集全部结构问题（不短路：一次报全，教学场景更友好）。
    #|pub fn validate_program(program : StudioProgram) -> Array[IrError] {
    #|  let errors : Array[IrError] = []
    #|  if program.controls.length() > MAX_CONTROLS {
    #|    errors.push(TooManyControls)
    #|  }
    #|  if program.variables.length() > MAX_VARIABLES {
    #|    errors.push(TooManyVariables)
    #|  }
    #|  if program.handlers.length() > MAX_HANDLERS {
    #|    errors.push(TooManyHandlers)
    #|  }
    #|  let mut total_stmts = 0
    #|  let names : Array[String] = []
    #|  for control in program.controls {
    #|    if !control_name_syntax_valid(control.name) {
    #|      errors.push(InvalidControlName(control.name))
    #|    }
    #|    if names.contains(control.name) {
    #|      errors.push(DuplicateControlName(control.name))
    #|    } else {
    #|      names.push(control.name)
    #|    }
    #|    if control.x < 0 ||
    #|      control.y < 0 ||
    #|      control.width < MIN_CONTROL_SIZE ||
    #|      control.height < MIN_CONTROL_SIZE ||
    #|      control.x + control.width > DESIGN_WIDTH ||
    #|      control.y + control.height > DESIGN_HEIGHT {
    #|      errors.push(InvalidControlRect(control.name))
    #|    }
    #|  }
    #|  let var_names : Array[String] = []
    #|  for variable in program.variables {
    #|    if !variable_name_syntax_valid(variable.name) {
    #|      errors.push(InvalidVariableName(variable.name))
    #|    }
    #|    if var_names.contains(variable.name) {
    #|      errors.push(DuplicateVariableName(variable.name))
    #|    } else {
    #|      var_names.push(variable.name)
    #|    }
    #|  }
    #|  // (控件, 事件) 对唯一（计划 §3 不变量）；重复对使 find_handler 语义不确定
    #|  let handler_pairs : Array[String] = []
    #|  for handler in program.handlers {
    #|    let pair = "\{handler.control_name}@\{handler.event.tag()}"
    #|    if handler_pairs.contains(pair) {
    #|      errors.push(DuplicateHandler(handler.control_name))
    #|    } else {
    #|      handler_pairs.push(pair)
    #|    }
    #|  }
    #|  for handler in program.handlers {
    #|    let handler_stmts = count_stmts(handler.body)
    #|    total_stmts = total_stmts + handler_stmts
    #|    if handler_stmts > MAX_STMTS_PER_HANDLER {
    #|      errors.push(TooManyStatements(handler_stmts))
    #|    }
    #|    if stmt_loop_depth(handler.body) > MAX_LOOP_DEPTH {
    #|      errors.push(LoopTooDeep(stmt_loop_depth(handler.body)))
    #|    }
    #|    if body_expr_depth(handler.body) > MAX_EXPR_DEPTH {
    #|      errors.push(ExprTooDeep(body_expr_depth(handler.body)))
    #|    }
    #|    match find_control(program, handler.control_name) {
    #|      Some(control) =>
    #|        if !control.kind.supports_event(handler.event) {
    #|          errors.push(
    #|            UnsupportedEvent(handler.control_name, handler.event.tag()),
    #|          )
    #|        }
    #|      None => errors.push(UnknownControlInHandler(handler.control_name))
    #|    }
    #|  }
    #|  if total_stmts > MAX_TOTAL_STMTS {
    #|    errors.push(TooManyStatements(total_stmts))
    #|  }
    #|  errors
    #|}
    #|
    #|///|
    #|/// 语句总数（循环体按静态出现一次计，不展开）。
    #|pub fn count_stmts(body : Array[Stmt]) -> Int {
    #|  let mut total = 0
    #|  for stmt in body {
    #|    total = total + count_stmt(stmt)
    #|  }
    #|  total
    #|}
    #|
    #|///|
    #|fn count_stmt(stmt : Stmt) -> Int {
    #|  match stmt {
    #|    Declare(_, _) | Assign(_, _) | Call(_, _) | Break => 1
    #|    If(_, then_body, else_ifs, else_body) =>
    #|      1 +
    #|      count_stmts(then_body) +
    #|      count_stmts(else_body) +
    #|      count_if_chain(else_ifs)
    #|    CountLoop(_, _, body) | WhileLoop(_, body) => 1 + count_stmts(body)
    #|  }
    #|}
    #|
    #|///|
    #|fn count_if_chain(arms : Array[(Expr, Array[Stmt])]) -> Int {
    #|  let mut total = 0
    #|  for arm in arms {
    #|    total = total + 1 + count_stmts(arm.1)
    #|  }
    #|  total
    #|}
    #|
    #|///|
    #|/// 循环嵌套深度（If 不计入；循环内嵌循环才计）。
    #|pub fn stmt_loop_depth(body : Array[Stmt]) -> Int {
    #|  body_loop_depth(body, 0)
    #|}
    #|
    #|///|
    #|fn body_loop_depth(body : Array[Stmt], current : Int) -> Int {
    #|  let mut deepest = current
    #|  for stmt in body {
    #|    let depth = match stmt {
    #|      Declare(_, _) | Assign(_, _) | Call(_, _) | Break => current
    #|      If(_, then_body, else_ifs, else_body) => {
    #|        let then_depth = body_loop_depth(then_body, current)
    #|        let else_depth = body_loop_depth(else_body, current)
    #|        let mut arms = if then_depth > else_depth {
    #|          then_depth
    #|        } else {
    #|          else_depth
    #|        }
    #|        for arm in else_ifs {
    #|          let inner3 = body_loop_depth(arm.1, current)
    #|          if inner3 > arms {
    #|            arms = inner3
    #|          }
    #|        }
    #|        arms
    #|      }
    #|      CountLoop(_, _, loop_body) | WhileLoop(_, loop_body) =>
    #|        body_loop_depth(loop_body, current + 1)
    #|    }
    #|    if depth > deepest {
    #|      deepest = depth
    #|    }
    #|  }
    #|  deepest
    #|}
    #|
    #|///|
    #|/// 表达式最大深度（防栈爆与不可读的巨型单行）。
    #|pub fn expr_depth(expr : Expr) -> Int {
    #|  match expr {
    #|    NumLit(_) | StrLit(_) | BoolLit(_) | Var(_) => 1
    #|    Not(inner) | Neg(inner) => 1 + expr_depth(inner)
    #|    Binary(_, left, right) => {
    #|      let l = expr_depth(left)
    #|      let r = expr_depth(right)
    #|      (if l > r { l } else { r }) + 1
    #|    }
    #|    Call(_, args) => {
    #|      let mut deepest = 0
    #|      for arg in args {
    #|        let d = expr_depth(arg)
    #|        if d > deepest {
    #|          deepest = d
    #|        }
    #|      }
    #|      deepest + 1
    #|    }
    #|  }
    #|}
    #|
    #|///|
    #|fn body_expr_depth(body : Array[Stmt]) -> Int {
    #|  let mut deepest = 0
    #|  for stmt in body {
    #|    let d = stmt_expr_depth(stmt)
    #|    if d > deepest {
    #|      deepest = d
    #|    }
    #|  }
    #|  deepest
    #|}
    #|
    #|///|
    #|fn stmt_expr_depth(stmt : Stmt) -> Int {
    #|  match stmt {
    #|    Declare(_, expr) | Assign(_, expr) => expr_depth(expr)
    #|    Call(_, args) => {
    #|      let mut deepest = 0
    #|      for arg in args {
    #|        let d = expr_depth(arg)
    #|        if d > deepest {
    #|          deepest = d
    #|        }
    #|      }
    #|      deepest
    #|    }
    #|    Break => 0
    #|    If(cond, then_body, else_ifs, else_body) => {
    #|      let mut deepest = expr_depth(cond)
    #|      let then_depth = body_expr_depth(then_body)
    #|      let else_depth = body_expr_depth(else_body)
    #|      if then_depth > deepest {
    #|        deepest = then_depth
    #|      }
    #|      if else_depth > deepest {
    #|        deepest = else_depth
    #|      }
    #|      for arm in else_ifs {
    #|        let arm_depth = expr_depth(arm.0)
    #|        if arm_depth > deepest {
    #|          deepest = arm_depth
    #|        }
    #|        let arm_body = body_expr_depth(arm.1)
    #|        if arm_body > deepest {
    #|          deepest = arm_body
    #|        }
    #|      }
    #|      deepest
    #|    }
    #|    CountLoop(times, _, body) => {
    #|      let count_depth = expr_depth(times)
    #|      let body_depth = body_expr_depth(body)
    #|      if count_depth > body_depth {
    #|        count_depth
    #|      } else {
    #|        body_depth
    #|      }
    #|    }
    #|    WhileLoop(cond, body) => {
    #|      let cond_depth = expr_depth(cond)
    #|      let body_depth = body_expr_depth(body)
    #|      if cond_depth > body_depth {
    #|        cond_depth
    #|      } else {
    #|        body_depth
    #|      }
    #|    }
    #|  }
    #|}
    #|
  source
}

///|
pub fn kernel_ir_signature_mbt() -> String {
  let source =
    #|///|
    #|/// 规范签名：语言中立的确定性文本倾倒。
    #|/// 没有 derive(Eq) 的 toolchain 现实下，签名是测试与 diff 的相等性判据：
    #|/// 往返解析、代码↔IR 同步、导出 bundle 快照，全部比对签名。
    #|
    #|///|
    #|pub fn program_signature(program : StudioProgram) -> String {
    #|  let buf = StringBuilder()
    #|  buf.write_string("program v\{program.version}\n")
    #|  buf.write_string(
    #|    "window «\{program.window.title}» \{program.window.width} \{program.window.height}\n",
    #|  )
    #|  for control in program.controls {
    #|    buf.write_string(
    #|      "control \{control.id} \{control.kind.tag()} «\{control.name}» «\{control.text}» \{control.x} \{control.y} \{control.width} \{control.height}",
    #|    )
    #|    if control.items.length() > 0 {
    #|      buf.write_string(" items[")
    #|      for item in control.items {
    #|        buf.write_string("«\{item}» ")
    #|      }
    #|      buf.write_string("]")
    #|    }
    #|    buf.write_string("\n")
    #|  }
    #|  for variable in program.variables {
    #|    buf.write_string("variable «\{variable.name}» = «\{variable.init}»\n")
    #|  }
    #|  for handler in program.handlers {
    #|    buf.write_string(
    #|      "handler «\{handler.control_name}» \{handler.event.tag()} note(«\{handler.note_zh}»|«\{handler.note_en}»)\n",
    #|    )
    #|    buf.write_string(handler_signature(handler))
    #|  }
    #|  buf.to_string()
    #|}
    #|
    #|///|
    #|pub fn handler_signature(handler : Handler) -> String {
    #|  stmts_signature(handler.body)
    #|}
    #|
    #|///|
    #|pub fn stmts_signature(body : Array[Stmt]) -> String {
    #|  let buf = StringBuilder()
    #|  write_stmts(buf, body, 0)
    #|  buf.to_string()
    #|}
    #|
    #|///|
    #|fn write_stmts(buf : StringBuilder, body : Array[Stmt], indent : Int) -> Unit {
    #|  for stmt in body {
    #|    write_indent(buf, indent)
    #|    write_stmt(buf, stmt, indent)
    #|  }
    #|}
    #|
    #|///|
    #|fn write_indent(buf : StringBuilder, indent : Int) -> Unit {
    #|  buf.write_string("\n")
    #|  for _ in 0..<indent {
    #|    buf.write_string("  ")
    #|  }
    #|}
    #|
    #|///|
    #|fn write_stmt(buf : StringBuilder, stmt : Stmt, indent : Int) -> Unit {
    #|  match stmt {
    #|    Declare(name, expr) => {
    #|      buf.write_string("declare \{name} = ")
    #|      write_expr(buf, expr)
    #|    }
    #|    Assign(name, expr) => {
    #|      buf.write_string("assign \{name} = ")
    #|      write_expr(buf, expr)
    #|    }
    #|    If(cond, then_body, else_ifs, else_body) => {
    #|      buf.write_string("if ")
    #|      write_expr(buf, cond)
    #|      write_stmts(buf, then_body, indent + 1)
    #|      for arm in else_ifs {
    #|        write_indent(buf, indent)
    #|        buf.write_string("elseif ")
    #|        write_expr(buf, arm.0)
    #|        write_stmts(buf, arm.1, indent + 1)
    #|      }
    #|      if else_body.length() > 0 {
    #|        write_indent(buf, indent)
    #|        buf.write_string("else")
    #|        write_stmts(buf, else_body, indent + 1)
    #|      }
    #|    }
    #|    CountLoop(times, loop_var, body) => {
    #|      buf.write_string("count ")
    #|      write_expr(buf, times)
    #|      buf.write_string(" as \{loop_var.unwrap_or("-")}")
    #|      write_stmts(buf, body, indent + 1)
    #|    }
    #|    WhileLoop(cond, body) => {
    #|      buf.write_string("while ")
    #|      write_expr(buf, cond)
    #|      write_stmts(buf, body, indent + 1)
    #|    }
    #|    Break => buf.write_string("break")
    #|    Call(name, args) => {
    #|      buf.write_string("call \{name}")
    #|      for arg in args {
    #|        buf.write_string(" ")
    #|        write_expr(buf, arg)
    #|      }
    #|    }
    #|  }
    #|}
    #|
    #|///|
    #|fn write_expr(buf : StringBuilder, expr : Expr) -> Unit {
    #|  match expr {
    #|    NumLit(n) => buf.write_string("num(\{n})")
    #|    StrLit(text) => buf.write_string("str(«\{text}»)")
    #|    BoolLit(flag) =>
    #|      buf.write_string(if flag { "bool(true)" } else { "bool(false)" })
    #|    Var(name) => buf.write_string("var(\{name})")
    #|    Not(inner) => {
    #|      buf.write_string("not ")
    #|      write_expr(buf, inner)
    #|    }
    #|    Neg(inner) => {
    #|      buf.write_string("neg ")
    #|      write_expr(buf, inner)
    #|    }
    #|    Binary(op, left, right) => {
    #|      buf.write_string("(")
    #|      write_expr(buf, left)
    #|      buf.write_string(" \{op.canonical()} ")
    #|      write_expr(buf, right)
    #|      buf.write_string(")")
    #|    }
    #|    Call(name, args) => {
    #|      buf.write_string("fn(\{name}")
    #|      for arg in args {
    #|        buf.write_string(" ")
    #|        write_expr(buf, arg)
    #|      }
    #|      buf.write_string(")")
    #|    }
    #|  }
    #|}
    #|
  source
}
