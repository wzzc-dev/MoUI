///|
/// 语句插入面板：让**没有 AI、没有模板**的用户也能从零写出程序逻辑。
///
/// 为什么需要它：积木画布原有的三条写回路径（`commit_block` 替换、
/// `duplicate_block` 克隆、`delete_block` 删除）都**要求语句已存在**
/// ——`commit_block` 遇到空 path 直接 return。于是从零开始的用户只有
/// 「让 AI 生成」「手打代码草稿」「打开模板」三条路，积木视图本身**加不出
/// 一行逻辑**。分类轨虽然可点，但只改一个高亮标志位。
///
/// 本模块把分类轨点击变成真正的入口：点分类 → 列出该分类可插入的语句骨架
/// → 点骨架 → 插入到选中块之后（无选中则末尾）。
///
/// **零新语义**：骨架是 DSL 文本，插入路径复用 `parse_handler_body` 校验
/// 与 `@blocks.insert_stmt_at` 手术，与既有编辑链完全同一条。
///
/// 模板只提供**最常用的最小骨架**（带占位名），不是完整语法树——
/// 参数编辑仍走右栏的语句编辑卡（选中块 → 改写）。这样面板不需要理解
/// 表达式，只负责「开个头」。

///|
/// 一条可插入的语句骨架。
pub(all) struct StatementTemplate {
  /// 该骨架所属分类（与分类轨一一对应）。
  category : @blocks.BlockCategory
  /// i18n 键：面板里显示的名字（说明这条语句是干什么的）。
  label_key : String
  /// 插入用的 DSL 骨架，**两种语言各一份**：关键字表是按语言互斥的
  /// （`keywords_for(ZhHans)` 只有「变量/如果/结束」，`keywords_for(En)`
  /// 只有 `let/if/end`），同一段文本不可能在两边都解析。
  /// 内建命令名（`set_text` 等）反而是语言中立的——`find_builtin` 同时认
  /// `spec.zh`、`spec.en` 与 `spec.id`，所以骨架里统一写规范 id。
  skeleton_zh : String
  skeleton_en : String
}

///|
/// 按当前界面语言取骨架文本。
pub fn StatementTemplate::skeleton(
  self : StatementTemplate,
  language : @studio_lang.Language,
) -> String {
  match language {
    @studio_lang.ZhHans => self.skeleton_zh
    @studio_lang.En => self.skeleton_en
  }
}

///|
/// 语句骨架表：每个分类给出最常用的 2–3 条。
///
/// 变量名一律用**自解释**的名字（`得分` / `score`）而不是 `a1`/`tmp`——
/// 可读性是本产品的一等目标（计划 §7.1），插入的骨架也不该例外。
pub fn statement_templates() -> Array[StatementTemplate] {
  [
    // 事件分类没有可插入项（事件头由控件决定），保留分类但不给骨架。
    // 变量
    StatementTemplate::{
      category: @blocks.CatVariable,
      label_key: "app.stmt.tpl.declare",
      skeleton_zh: "变量 计数 = 0",
      skeleton_en: "let count = 0",
    },
    StatementTemplate::{
      category: @blocks.CatVariable,
      label_key: "app.stmt.tpl.assign",
      skeleton_zh: "计数 = 1",
      skeleton_en: "count = 1",
    },
    StatementTemplate::{
      category: @blocks.CatVariable,
      label_key: "app.stmt.tpl.set_index",
      skeleton_zh: "名单[1] = \"张三\"",
      skeleton_en: "roster[1] = \"alice\"",
    },
    // 流程
    StatementTemplate::{
      category: @blocks.CatFlow,
      label_key: "app.stmt.tpl.if",
      skeleton_zh: "如果 计数 > 0 则\n  set_text(标签, \"\") \n结束",
      skeleton_en: "if count > 0 then\n  set_text(label, \"\") \nend",
    },
    StatementTemplate::{
      category: @blocks.CatFlow,
      label_key: "app.stmt.tpl.if_else",
      skeleton_zh: "如果 计数 > 0 则\n  set_text(标签, \"正\") \n否则\n  set_text(标签, \"负\") \n结束",
      skeleton_en: "if count > 0 then\n  set_text(label, \"pos\") \nelse\n  set_text(label, \"neg\") \nend",
    },
    // **如果…否则…结束**：语言层与积木链一直支持（`Stmt::If` 的第四个
    // 字段就是 else 体，`block_chain` 会展开成 `else` 装饰块），但面板里
    // 只有「如果…结束」——用户想要 else 分支只能先插 if 再手写代码。
    // 这是 Scratch 最基本的控制流之一，缺入口等于缺能力。
    StatementTemplate::{
      category: @blocks.CatFlow,
      label_key: "app.stmt.tpl.repeat",
      skeleton_zh: "计次循环 3 次\n  set_text(标签, \"\") \n结束",
      skeleton_en: "repeat 3 times\n  set_text(label, \"\") \nend",
    },
    StatementTemplate::{
      category: @blocks.CatFlow,
      label_key: "app.stmt.tpl.for_each",
      skeleton_zh: "遍历 名单 中的每个 元素\n  set_text(标签, 元素) \n结束",
      skeleton_en: "foreach roster as item\n  set_text(label, item) \nend",
    },
    StatementTemplate::{
      category: @blocks.CatFlow,
      label_key: "app.stmt.tpl.while",
      skeleton_zh: "当 计数 < 10 循环\n  计数 = 计数 + 1\n结束",
      skeleton_en: "while count < 10 do\n  count = count + 1\nend",
    },
    StatementTemplate::{
      category: @blocks.CatFlow,
      label_key: "app.stmt.tpl.forever",
      skeleton_zh: "当 真 循环\n  message_box(\"一直做\")\n结束",
      skeleton_en: "while true do\n  message_box(\"keep going\")\nend",
    },
    // **重复执行（永远）**：Scratch 的 `forever`。IR 里等价于
    // 「当 真 循环」——同样是**零成本对齐**（不动执行语义）。
    //
    // 安全性：不会真的卡死——解释器有 `DEFAULT_MAX_STEPS`（10 万步）预算，
    // 编译轨有同一预算，超了报 `StepBudget`。所以「永远」是相对用户语义
    // 的，运行时仍有硬上限（教学场景里比挂死浏览器好得多）。
    StatementTemplate::{
      category: @blocks.CatFlow,
      label_key: "app.stmt.tpl.repeat_until",
      skeleton_zh: "当 非(计数 > 10) 循环\n  计数 = 计数 + 1\n结束",
      skeleton_en: "while not count > 10 do\n  count = count + 1\nend",
    },
    // **重复直到…**：Scratch 的 `repeat until`。本仓的 IR 里它等价于
    // 「当 非(条件) 循环」——所以**不新增执行语义**，只给一条让用户
    // 不必自己写 `非` 的骨架（negation 由骨架承担）。
    //
    // 为什么不加 IR 变体：那会牵动 parser/printer/interp/codegen/
    // compiled_runtime/kernel 六处，而语义完全等价——用骨架表达是
    // 「零成本对齐」。
    StatementTemplate::{
      category: @blocks.CatFlow,
      label_key: "app.stmt.tpl.break",
      skeleton_zh: "跳出循环",
      skeleton_en: "break",
    },
    // 命令（内建名语言中立，写规范 id）
    StatementTemplate::{
      category: @blocks.CatCommand,
      label_key: "app.stmt.tpl.message",
      skeleton_zh: "message_box(\"你好\")",
      skeleton_en: "message_box(\"hello\")",
    },
    StatementTemplate::{
      category: @blocks.CatCommand,
      label_key: "app.stmt.tpl.set_text",
      skeleton_zh: "set_text(标签, \"你好\")",
      skeleton_en: "set_text(label, \"hello\")",
    },
    StatementTemplate::{
      category: @blocks.CatCommand,
      label_key: "app.stmt.tpl.append_row",
      skeleton_zh: "append_row(表格, \"\")",
      skeleton_en: "append_row(table, \"\")",
    },
    StatementTemplate::{
      category: @blocks.CatCommand,
      label_key: "app.stmt.tpl.submit",
      skeleton_zh: "submit_data(计数, \"演示目标\")",
      skeleton_en: "submit_data(count, \"demo\")",
    },
    // 下面两条此前只能手打：解释器早就实现了，但面板里没有入口，
    // 于是「广播消息」与「往列表里加一项」在积木界面里**够不着**——
    // 这正是「积木界面覆盖 Scratch 能力」的缺口：能力在、入口不在。
    StatementTemplate::{
      category: @blocks.CatCommand,
      label_key: "app.stmt.tpl.wait",
      skeleton_zh: "wait(1)",
      skeleton_en: "wait(1)",
    },
    // `等待 N 秒`：执行到那里挂起若干帧再继续（Scratch 的「等待」）。
    StatementTemplate::{
      category: @blocks.CatCommand,
      label_key: "app.stmt.tpl.ask",
      skeleton_zh: "ask(\"你叫什么名字？\")",
      skeleton_en: "ask(\"What is your name?\")",
    },
    // `ask`（询问并等待）是**闸门**：执行到这里会停下等人回答，
    // 与 `submit_data` 同一条 Gate 通道。它此前已实现却没有面板入口，
    // 于是「问一句再按回答分支」这种基本交互在积木界面里做不到。
    StatementTemplate::{
      category: @blocks.CatCommand,
      label_key: "app.stmt.tpl.stop_all",
      skeleton_zh: "stop_all()",
      skeleton_en: "stop_all()",
    },
    StatementTemplate::{
      category: @blocks.CatCommand,
      label_key: "app.stmt.tpl.broadcast",
      skeleton_zh: "broadcast(\"开始\")",
      skeleton_en: "broadcast(\"start\")",
    },
    StatementTemplate::{
      category: @blocks.CatCommand,
      label_key: "app.stmt.tpl.append_list",
      skeleton_zh: "append_list(列表, \"\")",
      skeleton_en: "append_list(items, \"\")",
    },
    // 运算：单独一条运算语句没有意义（运算只作为表达式嵌在别的语句里），
    // 所以给一条「赋值 + 运算」的可用骨架，让分类不是空的。
    StatementTemplate::{
      category: @blocks.CatExpression,
      label_key: "app.stmt.tpl.assign_expr",
      skeleton_zh: "计数 = 计数 + 1",
      skeleton_en: "count = count + 1",
    },
  ]
}

///|
/// **报告块骨架**（reporter）：只作为**表达式**嵌进别的积木的洞里，
/// 不能单独成为一条语句。与 `statement_templates` 分开两张表——
/// 混在一起会让「点击插入一条语句」把 `1 + 1` 当成语句插进列表，
/// 而那在语言里非法。
pub(all) struct ExpressionTemplate {
  label_key : String
  skeleton_zh : String
  skeleton_en : String
}

///|
pub fn ExpressionTemplate::skeleton(
  self : ExpressionTemplate,
  language : @studio_lang.Language,
) -> String {
  match language {
    @studio_lang.ZhHans => self.skeleton_zh
    @studio_lang.En => self.skeleton_en
  }
}

///|
/// 报告块清单（Scratch 的「运算」分类内容）。
///
/// 每一项都是**完整可解析的表达式**——拖进洞后过 `parse_expression_text`
/// 与手打表达式同一条校验链，解析失败就什么都不做（绝不把非法表达式塞进 IR）。
pub fn expression_templates() -> Array[ExpressionTemplate] {
  [
    ExpressionTemplate::{
      label_key: "app.expr.tpl.add",
      skeleton_zh: "1 + 1",
      skeleton_en: "1 + 1",
    },
    ExpressionTemplate::{
      label_key: "app.expr.tpl.random",
      skeleton_zh: "random(10)",
      skeleton_en: "random(10)",
    },
    ExpressionTemplate::{
      label_key: "app.expr.tpl.to_text",
      skeleton_zh: "to_text(1)",
      skeleton_en: "to_text(1)",
    },
    ExpressionTemplate::{
      label_key: "app.expr.tpl.length",
      skeleton_zh: "text_length(\"\")",
      skeleton_en: "text_length(\"\")",
    },
    ExpressionTemplate::{
      label_key: "app.expr.tpl.compare",
      skeleton_zh: "1 > 0",
      skeleton_en: "1 > 0",
    },
    ExpressionTemplate::{
      label_key: "app.expr.tpl.and",
      // 布尔**关键字随语言变**（中文 `真`/`假`，英文 `true`/`false`）——
      // 两语言共用一份骨架会在某种语言下解析失败。
      skeleton_zh: "真 且 假",
      skeleton_en: "true and false",
    },
    // 下面这些**同样是早就实现却够不着**的：`get_text` / `get_number` /
    // `row_count` / `row_at` / `selected_row` / `list_length` / `contains`
    // 在解释器里都有完整分支，但报告块面板里没有入口——用户看得到积木
    // 却拖不出来。补齐后由不变式用例守住（见 `blocks_slot_test.mbt`）。
    ExpressionTemplate::{
      label_key: "app.expr.tpl.get_text",
      skeleton_zh: "get_text(\"\")",
      skeleton_en: "get_text(\"\")",
    },
    ExpressionTemplate::{
      label_key: "app.expr.tpl.get_number",
      skeleton_zh: "get_number(\"0\")",
      skeleton_en: "get_number(\"0\")",
    },
    ExpressionTemplate::{
      label_key: "app.expr.tpl.row_count",
      skeleton_zh: "row_count(表格)",
      skeleton_en: "row_count(table)",
    },
    ExpressionTemplate::{
      label_key: "app.expr.tpl.row_at",
      skeleton_zh: "row_at(表格, 1)",
      skeleton_en: "row_at(table, 1)",
    },
    ExpressionTemplate::{
      label_key: "app.expr.tpl.selected_row",
      skeleton_zh: "selected_row(表格)",
      skeleton_en: "selected_row(table)",
    },
    ExpressionTemplate::{
      label_key: "app.expr.tpl.list_length",
      skeleton_zh: "list_length(列表)",
      skeleton_en: "list_length(items)",
    },
    ExpressionTemplate::{
      label_key: "app.expr.tpl.mod",
      // `mod` 是**函数**（目录里的内建），不是 `%` 运算符——词法器没有 `%`，
      // 写成中缀会解析失败。两语言共用一份（内建名语言中立）。
      skeleton_zh: "mod(7, 3)",
      skeleton_en: "mod(7, 3)",
    },
    ExpressionTemplate::{
      label_key: "app.expr.tpl.round",
      skeleton_zh: "round(1)",
      skeleton_en: "round(1)",
    },
    // Scratch 运算分类里的其余数学函数（内建名语言中立，两语言共用）
    ExpressionTemplate::{
      label_key: "app.expr.tpl.answer",
      // `回答`：`询问` 的返回值（Scratch 的「回答」报告块）。
      skeleton_zh: "answer()",
      skeleton_en: "answer()",
    },
    ExpressionTemplate::{
      label_key: "app.expr.tpl.abs",
      skeleton_zh: "abs(0 - 1)",
      skeleton_en: "abs(0 - 1)",
    },
    ExpressionTemplate::{
      label_key: "app.expr.tpl.floor",
      skeleton_zh: "floor(1)",
      skeleton_en: "floor(1)",
    },
    ExpressionTemplate::{
      label_key: "app.expr.tpl.ceiling",
      skeleton_zh: "ceiling(1)",
      skeleton_en: "ceiling(1)",
    },
    ExpressionTemplate::{
      label_key: "app.expr.tpl.sqrt",
      skeleton_zh: "sqrt(9)",
      skeleton_en: "sqrt(9)",
    },
    ExpressionTemplate::{
      label_key: "app.expr.tpl.letter_of",
      // **第 N 个字符**：字符串下标（Scratch 的 `letter N of`）。
      // 本仓的写法与列表下标同构：`"abc"[1]`。
      skeleton_zh: "\"abc\"[1]",
      skeleton_en: "\"abc\"[1]",
    },
    ExpressionTemplate::{
      label_key: "app.expr.tpl.contains",
      skeleton_zh: "contains(\"a\", \"abc\")",
      skeleton_en: "contains(\"a\", \"abc\")",
    },
  ]
}

///|
/// 按 i18n 键在某个分类里找骨架的下标（`None` = 该分类没有这一条）。
///
/// 为什么需要它：测试与命令绑定若按**位置下标**引用骨架，那么每次在表里
/// 插入一条新骨架，后面所有下标都会平移——用例会突然开始测另一条骨架，
/// 而且**失败信息完全指不到原因**（例如「拖拽测试失败」其实是因为
/// `InsertStatement(2, 1)` 从「计次循环」变成了「如果…否则」）。
/// 按稳定的键查找，插入不影响既有引用。
pub fn template_index_of(category_index : Int, label_key : String) -> Int? {
  let category = match category_at(category_index) {
    None => return None
    Some(category) => category
  }
  let templates = templates_for_category(category)
  let mut index = 0
  for template in templates {
    if template.label_key == label_key {
      return Some(index)
    }
    index = index + 1
  }
  None
}

///|
/// 某个分类下的骨架（保持表内顺序）。
pub fn templates_for_category(
  category : @blocks.BlockCategory,
) -> Array[StatementTemplate] {
  let matched : Array[StatementTemplate] = []
  for template in statement_templates() {
    if @blocks.category_color_key(template.category) ==
      @blocks.category_color_key(category) {
      matched.push(template)
    }
  }
  matched
}

///|
/// 分类轨的固定顺序（下标 → 分类）。分类轨视图与插入面板共用同一顺序，
/// 两处各写一份就会「点第三个分类出现第二个分类的模板」。
pub fn category_at(index : Int) -> @blocks.BlockCategory? {
  match index {
    0 => Some(@blocks.CatEvent)
    1 => Some(@blocks.CatVariable)
    2 => Some(@blocks.CatFlow)
    3 => Some(@blocks.CatCommand)
    4 => Some(@blocks.CatExpression)
    _ => None
  }
}

///|
/// 面板标题（分类名 + 用途），走 i18n。
pub fn statement_palette_title(t : @i18n.Translator) -> String {
  text(t, "app.stmt.palette.title")
}
