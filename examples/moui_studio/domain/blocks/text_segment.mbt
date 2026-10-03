///|
/// 积木文本的**分段投影**：把一行的规范文本切成「字面段」与「插槽段」。
///
/// # 为什么需要分段
///
/// Scratch 的积木是**带洞的图**：`说 [你好]` 的圆角凹槽里可以再塞一块
/// `[2 + 3]`。要把洞画出来，必须知道洞在**行内的 x 范围**——而一行文本的
/// 每段宽度不同（`"下标["` 与 `"2 + 3"` 宽度不同），所以不能靠整行字符串。
///
/// 这一层只产出**结构**（段序列 + 每段对应的表达式路径），不涉及像素：
/// 像素宽度由绘制层用注入的度量函数填（见 `blocks_canvas.mbt`）。这样
/// 分段逻辑是可单测的纯数据，且绘制与命中能共用同一份段表——避免
/// 「画在一处、点在另一处」。
///
/// # 与 IR 的关系
///
/// 段里的 `expr_path` 就是 `expr_path.mbt` 的路径语法，于是「点中某段 →
/// 换掉那个子表达式」是同一条寻址链路，不新造坐标系统。
/// 无洞的文本段 `expr_path` 为 `None`。
pub(all) struct TextSegment {
  text : String
  /// 该段对应的表达式路径；`None` = 纯字面文本（不是洞）
  expr_path : Array[Int]?
  /// 该段是否画成**插槽**（圆角凹槽背景）。文本段为 `false`。
  is_slot : Bool
  /// 该段是**关键字**时对应的 i18n 键（否则 `None`）。
  ///
  /// 为什么关键字不能烘进 `text`：`如果` / `重复` / `当` 是**界面语言**的
  /// 一部分（`blocks.if` 等键），而这一层在 `domain` 里、拿不到翻译器。
  /// 把中文写死会让英文界面出现中文关键字；把键交给宿主翻译则两边一致。
  /// 表达式段永远是 `None`（表达式按语言无关的规范写法渲染）。
  label_key : String?
}

///|
/// 一条语句的**行内分段**（按该语句在积木上显示的形态切）。
///
/// 各形态与 `emit_chain` 的 `text` 一一对应——**同一份切法**，否则洞的位置
/// 与实际文本对不上。返回空数组表示该语句没有可编辑洞口。
pub fn stmt_text_segments(stmt : Stmt) -> Array[TextSegment] {
  let segments : Array[TextSegment] = []
  match stmt {
    @ir.Declare(name, expr) => {
      push_literal(segments, "\{name} = ")
      push_slot(segments, expr, [])
    }
    @ir.Assign(name, expr) => {
      push_literal(segments, "\{name} = ")
      push_slot(segments, expr, [])
    }
    @ir.SetIndex(name, index, value) => {
      push_literal(segments, "\{name}[")
      push_slot(segments, index, [0])
      push_literal(segments, "] = ")
      push_slot(segments, value, [1])
    }
    // 控制流行在界面上是「<分类标签>  <item.text>」——**分类标签已经说明了
    // 这是哪一块**（`计次循环` / `如果`），所以这里只负责 `item.text` 那一段，
    // 与 `emit_chain` 写的 `text` 逐字对应。把关键字也切进来会让行内多出一份
    // 重复的标签。
    @ir.If(cond, _, _, _) => push_slot(segments, cond, [])
    @ir.CountLoop(times, loop_var, _) => {
      // `emit_chain` 的写法是 `"<次数> / <循环变量>"`（变量可空）——
      // 分段必须逐字对应，否则洞的位置与实际文本错位。
      push_slot(segments, times, [])
      push_literal(segments, " / ")
      let name = match loop_var {
        Some(name) => name
        None => ""
      }
      push_literal(segments, name)
    }
    @ir.WhileLoop(cond, _) => push_slot(segments, cond, [])
    @ir.Return(Some(expr)) => push_slot(segments, expr, [])
    @ir.Call(name, args) => {
      push_literal(segments, "\{name}(")
      let mut index = 0
      for arg in args {
        if index > 0 {
          push_literal(segments, ", ")
        }
        push_slot(segments, arg, [index])
        index = index + 1
      }
      push_literal(segments, ")")
    }
    _ => ()
  }
  segments
}

///|
/// 追加一个**结构字面**段（标点、`=`、逗号等语言无关的记号）。
fn push_literal(segments : Array[TextSegment], text : String) -> Unit {
  if text.length() > 0 {
    segments.push(TextSegment::{
      text,
      expr_path: None,
      is_slot: false,
      label_key: None,
    })
  }
}

///|
/// 追加一个插槽段。文本用规范写法（与 `canonical_expr` 同源）。
///
/// **叶子的插槽不是洞**：字面量（数字/字符串/布尔）在 Scratch 里是**可点击
/// 编辑的值**，不是可以再塞块的洞。区分开是为了让绘制层给它们不同的视觉
/// （洞 = 圆角凹槽等一块积木；值 = 可点选编辑的胶囊），也让命中层知道
/// 「点这里是改值，不是插块」。
pub fn push_slot(
  segments : Array[TextSegment],
  expr : Expr,
  path : Array[Int],
) -> Unit {
  // **值是叶子，其余都是洞**：字面量与变量名是可直接读取的值（点它们是
  // 改值/看值），而运算、调用、索引是**能再塞一块积木**的凹槽。
  // 判据取「叶子 vs 复合」而不是「字面量 vs 非字面量」——变量虽不是字面量，
  // 但它是叶子（没有子表达式可以替换），当成洞会让它显示为一个空的凹槽。
  let is_leaf = match expr {
    @ir.NumLit(_) | @ir.IntLit(_) | @ir.StrLit(_) | @ir.BoolLit(_) |
    @ir.Var(_) => true
    _ => false
  }
  segments.push(TextSegment::{
    text: @studio_lang.canonical_expr(expr),
    expr_path: Some(path),
    is_slot: !is_leaf,
    label_key: None,
  })
}

///|
/// 一段的**像素宽度**由其文本与字体决定，绘制层用注入的度量函数算。
/// 这里给出纯结构的**总段数**与**插槽数**，供测试与命中层快速判定。
pub fn segments_slot_count(segments : Array[TextSegment]) -> Int {
  let mut count = 0
  for segment in segments {
    if segment.is_slot {
      count = count + 1
    }
  }
  count
}
