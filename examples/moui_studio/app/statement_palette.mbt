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
      label_key: "app.stmt.tpl.repeat",
      skeleton_zh: "计次循环 3 次\n  set_text(标签, \"\") \n结束",
      skeleton_en: "repeat 3 times\n  set_text(label, \"\") \nend",
    },
    StatementTemplate::{
      category: @blocks.CatFlow,
      label_key: "app.stmt.tpl.while",
      skeleton_zh: "当 计数 < 10 循环\n  计数 = 计数 + 1\n结束",
      skeleton_en: "while count < 10 do\n  count = count + 1\nend",
    },
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
