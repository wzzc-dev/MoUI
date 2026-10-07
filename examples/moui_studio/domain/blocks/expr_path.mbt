///|
/// 表达式路径寻址：积木界面的**插槽**（reporter slot）。
///
/// # 为什么需要这一层
///
/// Scratch 的积木不是「一行文字」，而是**带洞的图**：`说 [你好]` 的圆角
/// 凹槽里可以再塞一块 `[2 + 3]`。此前 MoUI 的积木投影把表达式**预渲染成
/// 字符串**（`BlockItem.text = "x = 1 + 2"`），于是插槽在数据上根本不存在——
/// 用户只能改整行文本，不能把一块报告块拖进洞里。
///
/// 这一层补的是**寻址**：给一条语句、一条从语句根到某个子表达式的路径，
/// 就能读出/换掉那个子表达式。IR 仍是唯一真源——插槽操作是**表达式级
/// 手术**，与语句级手术（`stmt_at`/`replace_stmt_at`）同一纪律：克隆后
/// 手术、不改传入值。
///
/// # 路径语法
///
/// 每段是「从当前表达式进入第几个子表达式」，顺序与外层到内层一致：
///
/// - `[]` = 语句自己的**根表达式**（如 `Assign` 的右值、`If` 的条件）
/// - Assign("x", Binary(Add, IntLit 1, IntLit 2)) 的 `1` → `[1, 0]`
///   （先取根的右操作数，再取它的左操作数）
/// - `Call("set_text", [Var "a", StrLit "b"])` 的 `"b"` → `[1]`
///
/// 插槽编号（每段的「第几个」）按**规范书写顺序**，与
/// `canonical_expr` 的阅读顺序一致：二元运算是 [左, 右]，调用是实参顺序，
/// 索引是 [被索引, 下标]，列表字面量是元素顺序，一元是 [操作数]。
pub fn expr_slot_count(expr : Expr) -> Int {
  match expr {
    @ir.NumLit(_)
    | @ir.IntLit(_)
    | @ir.StrLit(_)
    | @ir.BoolLit(_)
    | @ir.Var(_)
    | @ir.EnumTag(_, _) => 0
    @ir.Not(_) | @ir.Neg(_) => 1
    @ir.Index(_, _) | @ir.Binary(_, _, _) => 2
    @ir.ListLit(items) => items.length()
    @ir.Call(_, args) => args.length()
    @ir.FieldAccess(_, _) => 1
  }
}

///|
/// 取第 `slot` 个子表达式。
pub fn expr_child(expr : Expr, slot : Int) -> Expr? {
  match expr {
    @ir.Not(inner) | @ir.Neg(inner) =>
      if slot == 0 {
        Some(inner)
      } else {
        None
      }
    @ir.Index(target, index) =>
      match slot {
        0 => Some(target)
        1 => Some(index)
        _ => None
      }
    @ir.Binary(_, left, right) =>
      match slot {
        0 => Some(left)
        1 => Some(right)
        _ => None
      }
    @ir.ListLit(items) =>
      if slot >= 0 && slot < items.length() {
        Some(items[slot])
      } else {
        None
      }
    @ir.Call(_, args) =>
      if slot >= 0 && slot < args.length() {
        Some(args[slot])
      } else {
        None
      }
    // 字段访问的唯一洞口是基底（`person.名字` 里可换的是 `person`）
    @ir.FieldAccess(base, _) => if slot == 0 { Some(base) } else { None }
    // 叶子（字面量/变量/枚举值）没有子表达式
    @ir.NumLit(_)
    | @ir.IntLit(_)
    | @ir.StrLit(_)
    | @ir.BoolLit(_)
    | @ir.Var(_)
    | @ir.EnumTag(_, _) => None
  }
}

///|
/// 用 `value` 换掉 `expr` 的第 `slot` 个子表达式（克隆后手术）。
pub fn replace_expr_child(expr : Expr, slot : Int, value : Expr) -> Expr? {
  match expr {
    @ir.Not(_) => if slot == 0 { Some(@ir.Not(value)) } else { None }
    @ir.Neg(_) => if slot == 0 { Some(@ir.Neg(value)) } else { None }
    @ir.Index(target, index) =>
      match slot {
        0 => Some(@ir.Index(value, index))
        1 => Some(@ir.Index(target, value))
        _ => None
      }
    @ir.Binary(op, left, right) =>
      match slot {
        0 => Some(@ir.Binary(op, value, right))
        1 => Some(@ir.Binary(op, left, value))
        _ => None
      }
    @ir.ListLit(items) =>
      if slot >= 0 && slot < items.length() {
        let next : Array[Expr] = []
        let mut i = 0
        for item in items {
          next.push(if i == slot { value } else { item })
          i = i + 1
        }
        Some(@ir.ListLit(next))
      } else {
        None
      }
    @ir.Call(name, args) =>
      if slot >= 0 && slot < args.length() {
        let next : Array[Expr] = []
        let mut i = 0
        for item in args {
          next.push(if i == slot { value } else { item })
          i = i + 1
        }
        Some(@ir.Call(name, next))
      } else {
        None
      }
    // 字段访问：slot 0 换基底，字段名本身不可替换
    @ir.FieldAccess(_, field) =>
      if slot == 0 {
        Some(@ir.FieldAccess(value, field))
      } else {
        None
      }
    // 叶子（字面量/变量/枚举值）没有可替换的子表达式
    @ir.NumLit(_)
    | @ir.IntLit(_)
    | @ir.StrLit(_)
    | @ir.BoolLit(_)
    | @ir.Var(_)
    | @ir.EnumTag(_, _) => None
  }
}

///|
/// 按路径取子表达式。`path` 为空时返回**语句的根表达式**（若该语句有）。
///
/// 路径非法（越界 / 该语句没有根表达式 / 中途取不到子表达式）返回 `None`，
/// 调用方据此拒绝操作而不是猜一个位置。
pub fn expr_at(
  body : Array[Stmt],
  stmt_path : Array[Int],
  path : Array[Int],
) -> Expr? {
  let stmt = match stmt_at(body, stmt_path) {
    Some(stmt) => stmt
    None => return None
  }
  let root = match stmt_root_expr(stmt) {
    Some(expr) => expr
    None => return None
  }
  descend_expr(root, path)
}

///|
/// 按路径**替换**子表达式（克隆后手术，不改传入的 body）。
///
/// `path` 为空 = 换掉语句的根表达式。
pub fn replace_expr_at(
  body : Array[Stmt],
  stmt_path : Array[Int],
  path : Array[Int],
  value : Expr,
) -> Array[Stmt]? {
  let stmt = match stmt_at(body, stmt_path) {
    Some(stmt) => stmt
    None => return None
  }
  let working = clone_stmts(body)
  if path.length() == 0 {
    return replace_stmt_root_expr(working, stmt_path, value)
  }
  let root = match stmt_root_expr(stmt) {
    Some(expr) => expr
    None => return None
  }
  let updated = match graft_expr(root, path, value) {
    Some(expr) => expr
    None => return None
  }
  replace_stmt_root_expr(working, stmt_path, updated)
}

///|
/// 逐段下降。空路径返回根，中途失败返回 `None`。
fn descend_expr(expr : Expr, path : Array[Int]) -> Expr? {
  if path.length() == 0 {
    return Some(expr)
  }
  let child = match expr_child(expr, path[0]) {
    Some(child) => child
    None => return None
  }
  let rest : Array[Int] = []
  let mut i = 1
  while i < path.length() {
    rest.push(path[i])
    i = i + 1
  }
  descend_expr(child, rest)
}

///|
/// 逐段下降并**替换**叶子（克隆后重建，不改传入的表达式）。
fn graft_expr(expr : Expr, path : Array[Int], value : Expr) -> Expr? {
  if path.length() == 0 {
    return Some(value)
  }
  let child = match expr_child(expr, path[0]) {
    Some(child) => child
    None => return None
  }
  let rest : Array[Int] = []
  let mut i = 1
  while i < path.length() {
    rest.push(path[i])
    i = i + 1
  }
  let updated = match graft_expr(child, rest, value) {
    Some(updated) => updated
    None => return None
  }
  replace_expr_child(expr, path[0], updated)
}

///|
/// 语句的**根表达式**（积木上的可编辑洞口；没有则 `None`）。
///
/// 只列真正对用户可见、可放报告块的洞口。刻意**不含** `If` 的 else-if 链
/// 与 `Return` 的 `None`：那些没有稳定的单一路径语义，先把主路径做对。
pub fn stmt_root_expr(stmt : Stmt) -> Expr? {
  match stmt {
    @ir.Declare(_, expr) | @ir.Assign(_, expr) => Some(expr)
    @ir.If(cond, _, _, _) => Some(cond)
    @ir.CountLoop(times, _, _) => Some(times)
    @ir.ForEach(list_expr, _, _) => Some(list_expr)
    @ir.WhileLoop(cond, _) => Some(cond)
    @ir.Return(Some(expr)) => Some(expr)
    @ir.SetIndex(_, index, _) => Some(index)
    // **调用语句的根是整条调用**，不是第一个实参：分段的插槽路径
    // （`text_segment.mbt`）按「第几个实参」编号，若根取 `args[0]`，
    // 路径 `[1]` 会指向第一个实参的子表达式——洞与内容错位一格。
    // 根取整条调用后，`[k]` 恰好是第 k 个实参，两处编号一致。
    @ir.Stmt::Call(name, args) => Some(@ir.Expr::Call(name, args))
    _ => None
  }
}

///|
/// 换掉语句的根表达式（克隆后手术）。返回 `None` 表示该语句没有根表达式、
/// 或路径非法。
fn replace_stmt_root_expr(
  body : Array[Stmt],
  stmt_path : Array[Int],
  value : Expr,
) -> Array[Stmt]? {
  let stmt = match stmt_at(body, stmt_path) {
    Some(stmt) => stmt
    None => return None
  }
  let updated = match stmt {
    @ir.Declare(name, _) => @ir.Declare(name, value)
    @ir.Assign(name, _) => @ir.Assign(name, value)
    @ir.If(_, then_body, arms, else_body) =>
      @ir.If(value, then_body, arms, else_body)
    @ir.CountLoop(_, loop_var, loop_body) =>
      @ir.CountLoop(value, loop_var, loop_body)
    @ir.ForEach(_, loop_var, loop_body) =>
      @ir.ForEach(value, loop_var, loop_body)
    @ir.WhileLoop(_, loop_body) => @ir.WhileLoop(value, loop_body)
    @ir.Return(_) => @ir.Return(Some(value))
    @ir.SetIndex(name, _, v) => @ir.SetIndex(name, value, v)
    // 调用语句：**整个根被替换**时也只可能是调用本身（调用不能换成别的
    // 表达式——语句的类型由语法决定），所以这里只在 `value` 也是调用且
    // 实参个数相同时接受，其余情况返回 `None` 让调用方拒绝。
    @ir.Call(name, args) =>
      match value {
        @ir.Call(next_name, next_args) =>
          if next_name == name && next_args.length() == args.length() {
            @ir.Call(next_name, next_args)
          } else {
            return None
          }
        _ => return None
      }
    _ => return None
  }
  Some(replace_stmt_at(body, stmt_path, updated))
}

///|
/// 一个**叶子值**的文本（可直接在积木上编辑的那种）。
///
/// 只有字面量与变量名是叶子值：它们在 Scratch 里是**可点击就地修改**的，
/// 而不是能再塞一块积木的凹槽。返回 `None` 表示该表达式不是叶子（是洞），
/// 调用方据此决定「点了是改值还是插块」。
pub fn expr_leaf_text(expr : Expr) -> String? {
  match expr {
    @ir.NumLit(value) => Some(@studio_lang.number_to_text(value))
    @ir.IntLit(value) => Some(value.to_string())
    @ir.StrLit(text) => Some(text)
    @ir.BoolLit(flag) => Some(if flag { "true" } else { "false" })
    @ir.Var(name) => Some(name)
    @ir.EnumTag(enum_name, case_name) => Some("\{enum_name}::\{case_name}")
    _ => None
  }
}

///|
/// 把叶子值的新文本解析成表达式。
///
/// 与手打表达式**同一条解析链**（`parse_expression_text`），但多一层
/// 「裸词是字符串还是变量」的判定——这是 Scratch 值编辑的核心语义：
/// 用户在数字格子里打 `abc` 想要的是**文本 `abc`**，而在文本格子里打
/// `abc` 想要的也是文本；只有明确写成变量名才当变量。
///
/// 规则（按序）：
/// 1. 能整段解析为**字面量**（数字/字符串/布尔）→ 用解析结果；
/// 2. 否则若能解析为表达式且是**单个标识符**（变量）→ 用变量；
/// 3. 否则一律当**字符串字面量**（用户输入的原样文本）。
///
/// 第 3 条是关键的宽容：值编辑格子里打什么都应该能存下去，而不是报
/// 「解析失败」——那会让用户觉得「改了没反应」。
pub fn parse_leaf_value(
  source : String,
  language : @studio_lang.Language,
) -> Expr {
  let trimmed = source.trim().to_owned()
  if trimmed.length() == 0 {
    return @ir.StrLit("")
  }
  match @studio_lang.parse_expression_text(trimmed, language) {
    Ok(expr) =>
      match expr {
        @ir.NumLit(_) | @ir.IntLit(_) | @ir.StrLit(_) => expr
        @ir.BoolLit(_) => expr
        // 变量名要**真的像变量名**才当变量。词法器对标识符极宽松
        // （任何非空白非运算符的连续字符都算 Ident），于是「你好」也会被
        // 解析成变量——但用户在值格子里打中文想要的是**文本**。
        // 这里加一道形状检查：标识符必须由字母/数字/下划线/中文**标识符**
        // 组成且不以数字开头，否则回落成字符串。
        @ir.Var(name) =>
          if leaf_is_identifier_shaped(name) {
            expr
          } else {
            @ir.StrLit(source)
          }
        _ => @ir.StrLit(source)
      }
    Err(_) => @ir.StrLit(source)
  }
}

///|
/// `name` 是否像一个**变量名**（而不是用户随手打的文本）。
///
/// 判据：非空、首字符不是数字、且只含 ASCII 字母/数字/下划线。中文变量名
/// 在本仓是允许的（模板里就有 `计数`），所以中文按「全是 CJK 表意字符」
/// 单独放行——但「你好，世界」这种带标点的不会通过（逗号不在允许集里）。
fn leaf_is_identifier_shaped(name : String) -> Bool {
  if name.length() == 0 {
    return false
  }
  let mut index = 0
  let mut first = true
  for c in name {
    let code = c.to_int()
    let is_ascii_letter = (code >= 0x41 && code <= 0x5A) ||
      (code >= 0x61 && code <= 0x7A)
    let is_digit = code >= 0x30 && code <= 0x39
    let is_underscore = code == 0x5F
    // CJK 统一表意文字（含扩展 A）——模板里的中文变量名靠这一段放行
    let is_cjk = (code >= 0x4E00 && code <= 0x9FFF) ||
      (code >= 0x3400 && code <= 0x4DBF)
    if first {
      if is_digit {
        return false
      }
      if !(is_ascii_letter || is_underscore || is_cjk) {
        return false
      }
    } else if !(is_ascii_letter || is_digit || is_underscore || is_cjk) {
      return false
    }
    first = false
    index = index + 1
  }
  true
}
