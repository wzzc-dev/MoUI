///|
/// v4 IDE 壳的纯数据推导：结构树、本地数据、代码高亮与行映射、分类条、
/// 运行时监视、工具条计数。
///
/// 本模块只做「模型 → 视图数据」，不发消息、不改模型——所有条目都是
/// 程序事实的派生（IR 仍是唯一事实来源），因此可独立测试。

///|
/// 结构树节点种类：分组标题 / 窗体 / 控件 / 变量 / 子程序 / 数据文件。
pub(all) enum TreeNodeKind {
  TnGroup
  TnWindow
  TnControl
  TnVariable
  TnHandler
  TnDataFile
  /// 自定义积木（Scratch 的「我的积木」）。
  TnFunction
}

///|
/// 结构树节点：展示名 + 右侧元信息 + 所属分组键 + 缩进层级。
/// sel 表示该节点是当前选中对象（控件名或子程序键）。
pub(all) struct TreeNode {
  kind : TreeNodeKind
  label : String
  meta : String
  group : String
  depth : Int
  locked : Bool
  // 选中定位键：控件节点 = 控件名；子程序节点 = handler_key；
  // 其余为空串（不可选中）
  select_key : String
  // 点击后发出的消息标识（视图层映射回 typed Msg）：空串 = 不可点
  action : String
}

///|
/// 结构树分组键（展开折叠状态用；i18n 键在渲染层解析）。
pub fn tree_group_window() -> String {
  "window"
}

///|
pub fn tree_group_controls() -> String {
  "controls"
}

///|
pub fn tree_group_variables() -> String {
  "variables"
}

///|
pub fn tree_group_functions() -> String {
  "functions"
}

///|
pub fn tree_group_handlers() -> String {
  "handlers"
}

///|
pub fn tree_group_data() -> String {
  "data"
}

///|
/// 分组 i18n 键。
pub fn tree_group_label_key(group : String) -> String {
  "app.tree.group.\{group}"
}

///|
/// 控件种类 i18n 键（与 views 的 control.<kind> 同源）。
pub fn control_kind_key(kind : @ir.ControlKind) -> String {
  match kind {
    @ir.Button => "control.button"
    @ir.Label => "control.label"
    @ir.TextField => "control.text_field"
    @ir.CheckBox => "control.check_box"
    @ir.ListBox => "control.list_box"
    @ir.Table => "control.table"
    @ir.Dropdown => "control.dropdown"
    @ir.ProgressBar => "control.progress_bar"
    @ir.Image => "control.image"
  }
}

///|
/// 结构树：窗体 / 控件 / 变量 / 事件子程序 / 本地数据 五个分组。
/// 搜索查询按「展示名 + 元信息」做子串匹配（大小写不敏感）；
/// 命中的节点所在分组强制展开（collapsed 只作用于空查询态）。
pub fn program_tree(model : Model) -> Array[TreeNode] {
  let nodes : Array[TreeNode] = []
  let query = model.tree_query.trim().to_owned()
  fn matches(query : String, label : String, meta : String) -> Bool {
    if query == "" {
      true
    } else {
      lower_ascii(label).contains(lower_ascii(query)) ||
      lower_ascii(meta).contains(lower_ascii(query))
    }
  }
  // 窗体分组
  let window_label = model.program.window.title
  let window_meta = "\{model.program.window.width}×\{model.program.window.height}"
  nodes.push(TreeNode::{
    kind: TnGroup,
    label: "",
    meta: "",
    group: tree_group_window(),
    depth: 0,
    locked: false,
    select_key: "",
    action: "",
  })
  if matches(query, window_label, window_meta) {
    nodes.push(TreeNode::{
      kind: TnWindow,
      label: window_label,
      meta: window_meta,
      group: tree_group_window(),
      depth: 1,
      locked: false,
      select_key: "",
      action: "",
    })
  }
  // 控件分组
  nodes.push(TreeNode::{
    kind: TnGroup,
    label: "",
    meta: "\{model.program.controls.length()}",
    group: tree_group_controls(),
    depth: 0,
    locked: false,
    select_key: "",
    action: "",
  })
  for control in model.program.controls {
    let meta = match control.kind {
      @ir.Button => "button"
      @ir.Label => "label"
      @ir.TextField => "text_field"
      @ir.CheckBox => "check_box"
      @ir.ListBox => "list_box"
      @ir.Table => "table"
      @ir.Dropdown => "dropdown"
      @ir.ProgressBar => "progress"
      @ir.Image => "image"
    }
    if matches(query, control.name, meta) {
      nodes.push(TreeNode::{
        kind: TnControl,
        label: control.name,
        meta,
        group: tree_group_controls(),
        depth: 1,
        locked: false,
        select_key: control.name,
        action: "control",
      })
    }
  }
  // 变量分组：程序声明的变量 + handler 里出现但未声明的（运行时才出现）
  nodes.push(TreeNode::{
    kind: TnGroup,
    label: "",
    meta: "\{model.program.variables.length()}",
    group: tree_group_variables(),
    depth: 0,
    locked: false,
    select_key: "",
    action: "",
  })
  for variable in model.program.variables {
    if matches(query, variable.name, variable.init) {
      nodes.push(TreeNode::{
        kind: TnVariable,
        label: variable.name,
        meta: variable.init,
        group: tree_group_variables(),
        depth: 1,
        locked: false,
        // 变量行必须携带名字：点击要按名字选中（`SelectSide(SideVariable(name))`），
        // 留空会让整棵树所有变量行都指向同一个空目标。
        select_key: variable.name,
        action: "variable",
      })
    }
  }
  // 子程序分组：每个 handler 一行，meta = 语句条数
  nodes.push(TreeNode::{
    kind: TnGroup,
    label: "",
    meta: "\{model.program.handlers.length()}",
    group: tree_group_handlers(),
    depth: 0,
    locked: false,
    select_key: "",
    action: "",
  })
  for handler in model.program.handlers {
    let label = "\{handler.control_name}.\{handler.event.tag()}"
    let meta = "×\{handler.body.length()}"
    if matches(query, label, meta) {
      nodes.push(TreeNode::{
        kind: TnHandler,
        label,
        meta,
        group: tree_group_handlers(),
        depth: 1,
        locked: false,
        select_key: handler_key(handler.control_name, handler.event.tag()),
        action: "handler",
      })
    }
  }
  // **自定义积木分组**（Scratch 的「我的积木」）。
  //
  // 为什么必须有这一组：`FuncDef` 语言层一直支持，但树上没有位置、界面上
  // 也没有创建入口——于是「自己定义一个积木」在积木界面里完全做不到
  // （只能从 JSON 手写）。有了这一组，用户看得见、点得到、能改名。
  nodes.push(TreeNode::{
    kind: TnGroup,
    label: "",
    meta: "\{model.program.functions.length()}",
    group: tree_group_functions(),
    depth: 0,
    locked: false,
    select_key: "",
    action: "",
  })
  for func in model.program.functions {
    let label = func.name
    let meta = "×\{func.body.length()}"
    if matches(query, label, meta) {
      nodes.push(TreeNode::{
        kind: TnFunction,
        label,
        meta,
        group: tree_group_functions(),
        depth: 1,
        locked: false,
        select_key: func.name,
        action: "function",
      })
    }
  }
  // 本地数据分组
  let files = data_file_entries(model)
  nodes.push(TreeNode::{
    kind: TnGroup,
    label: "",
    meta: "\{files.length()}",
    group: tree_group_data(),
    depth: 0,
    locked: false,
    select_key: "",
    action: "",
  })
  for file in files {
    if matches(query, file.name, file.meta) {
      nodes.push(TreeNode::{
        kind: TnDataFile,
        label: file.name,
        meta: file.meta,
        group: tree_group_data(),
        depth: 1,
        locked: file.locked,
        // 同上：数据条目按名字选中（条目是从程序派生的，名字是唯一键）。
        select_key: file.name,
        action: "data",
      })
    }
  }
  nodes
}

///|
/// 分组是否有可见子节点（分组头徽标：0 时灰显）。
pub fn tree_group_has_children(nodes : Array[TreeNode], group : String) -> Bool {
  for node in nodes {
    if node.group == group && !(node.kind is TnGroup) {
      return true
    }
  }
  false
}

///|
/// 分组展开态：搜索非空时全部展开（否则命中结果被折叠藏起来）。
pub fn tree_group_expanded(model : Model, group : String) -> Bool {
  if model.tree_query.trim().to_owned() != "" {
    true
  } else {
    !model.tree_collapsed.contains(group)
  }
}

///|
/// ASCII 小写化：结构树搜索用（不做完整 Unicode case folding，
/// 中文标识符本身无大小写）。
fn lower_ascii(text : String) -> String {
  let buf = StringBuilder()
  for c in text {
    let code = c.to_int()
    if code >= 0x41 && code <= 0x5A {
      buf.write_char((code + 0x20).unsafe_to_char())
    } else {
      buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
/// 本地数据文件：由程序的列表/表格控件与变量推导的只读数据面投影。
/// 设计稿的「本地数据」是程序外挂的 json/csv；当前 IR 没有文件系统，
/// 所以条目如实来自控件 items（列表/表格）与变量初值——预览就是那几行，
/// 不假装有 IO。
pub fn data_file_entries(model : Model) -> Array[DataFileEntry] {
  let entries : Array[DataFileEntry] = []
  for control in model.program.controls {
    match control.kind {
      @ir.ListBox | @ir.Table => {
        let rows = control.items.length()
        let preview = if rows == 0 {
          "app.data.empty"
        } else {
          let buf = StringBuilder()
          let mut index = 0
          for item in control.items {
            if index >= 6 {
              break
            }
            if index > 0 {
              buf.write_string("\n")
            }
            buf.write_string(item)
            index = index + 1
          }
          if rows > 6 {
            buf.write_string("\n… +\{rows - 6}")
          }
          buf.to_string()
        }
        entries.push(DataFileEntry::{
          name: control.name,
          meta: "\{rows} · \{control_kind_key(control.kind)}",
          locked: true,
          preview,
        })
      }
      _ => ()
    }
  }
  if model.program.variables.length() > 0 {
    let buf = StringBuilder()
    let mut index = 0
    for variable in model.program.variables {
      if index > 0 {
        buf.write_string("\n")
      }
      buf.write_string("\{variable.name} = \{variable.init}")
      index = index + 1
    }
    entries.push(DataFileEntry::{
      name: "variables",
      meta: "\{model.program.variables.length()} · vars",
      locked: false,
      preview: buf.to_string(),
    })
  }
  entries
}

// ============================================================================
// 代码渲染与高亮
// ============================================================================

///|
/// 代码行渲染：按当前语言渲染草稿，并逐行切分高亮 token。
/// 高亮是**渲染层**事实——它读关键字表与内建表做词形分类，失败只是
/// 退化成纯文本，绝不改变语义（IR 仍是唯一事实来源）。
pub fn code_lines(model : Model) -> Array[CodeLine] {
  let lines : Array[CodeLine] = []
  let keywords = @studio_lang.keywords_for(model.language.dsl_language())
  let builtins = builtin_words(model.language.dsl_language())
  let texts = split_line_texts(model.code_draft)
  let mut number = 1
  for text in texts {
    lines.push(CodeLine::{
      number,
      tokens: highlight_line(text, keywords, builtins),
    })
    number = number + 1
  }
  if lines.length() == 0 {
    lines.push(CodeLine::{ number: 1, tokens: [], })
  }
  lines
}

///|
/// 内建命令名集合（当前语言）：高亮用（分类只影响颜色）。
/// 从 builtin_catalog 取一遍名字，避免在词法扫描里反复查目录。
pub fn builtin_words(language : @studio_lang.Language) -> Array[String] {
  let words : Array[String] = []
  for entry in @studio_lang.builtin_catalog() {
    words.push(
      match language {
        @studio_lang.ZhHans => entry.zh
        @studio_lang.En => entry.en
      },
    )
  }
  words
}

///|
/// 按换行切分（保留空行——行号必须与真实行一一对应，
/// 否则 IR 行映射与光标位置会错位）。
pub fn split_line_texts(source : String) -> Array[String] {
  let lines : Array[String] = []
  let buf = StringBuilder()
  for c in source {
    if c == '\n' {
      lines.push(buf.to_string())
      buf.reset()
    } else if c != '\r' {
      buf.write_char(c)
    }
  }
  lines.push(buf.to_string())
  if lines.length() == 1 && lines[0] == "" {
    []
  } else {
    lines
  }
}

///|
/// 单行高亮：扫描 token 序列并分类。
/// 顺序敏感——字符串先吃掉引号内内容（注释符在字符串里不算注释），
/// 注释吃掉行尾。
fn highlight_line(
  text : String,
  keywords : @studio_lang.Keywords,
  builtins : Array[String],
) -> Array[CodeToken] {
  let tokens : Array[CodeToken] = []
  for token in highlight_line_ranged(text, 0, keywords, builtins) {
    tokens.push(CodeToken::{ kind: token.kind, text: token.text, })
  }
  tokens
}

///|
/// 单行高亮（带源内偏移）：编辑器着色需要每个 token 的 `source_range`，
/// 扫描逻辑与 `highlight_line` 同一份；`line_start` 是本行在完整源码里的
/// 起始偏移，产出的 start/end 是**全文绝对偏移**。
fn highlight_line_ranged(
  text : String,
  line_start : Int,
  keywords : @studio_lang.Keywords,
  builtins : Array[String],
) -> Array[RangedToken] {
  let tokens : Array[RangedToken] = []
  let chars : Array[Char] = []
  for c in text {
    chars.push(c)
  }
  let mut index = 0
  // 已产出 token 覆盖的字符数：每个 token 的起点 = line_start + consumed
  let mut consumed = 0
  let length = chars.length()
  let buf = StringBuilder()
  let flush = fn(buf : StringBuilder, kind : CodeTokenKind) {
    let value = buf.to_string()
    if value != "" {
      tokens.push(RangedToken::{ start: line_start + consumed, text: value, kind, })
      consumed = consumed + value.length()
    }
    buf.reset()
  }
  while index < length {
    let c = chars[index]
    // 注释：// 到行尾（归属前一段普通文本要先冲出去）
    if c == '/' && index + 1 < length && chars[index + 1] == '/' {
      flush(buf, TokPlain)
      let tail = StringBuilder()
      while index < length {
        tail.write_char(chars[index])
        index = index + 1
      }
      flush(tail, TokComment)
      break
    }
    // 字符串：双引号成对（不处理转义——DSL 字符串内不设转义符）
    if c == '"' {
      flush(buf, TokPlain)
      let literal = StringBuilder()
      literal.write_char(c)
      index = index + 1
      while index < length {
        literal.write_char(chars[index])
        if chars[index] == '"' {
          index = index + 1
          break
        }
        index = index + 1
      }
      flush(literal, TokString)
      continue
    }
    // 数字
    if is_digit_char(c) {
      flush(buf, TokPlain)
      let number = StringBuilder()
      while index < length && is_number_char(chars[index]) {
        number.write_char(chars[index])
        index = index + 1
      }
      flush(number, TokNumber)
      continue
    }
    // 标识符 / 关键字 / 内建
    if is_word_char(c) {
      flush(buf, TokPlain)
      let word = StringBuilder()
      while index < length && is_word_char(chars[index]) {
        word.write_char(chars[index])
        index = index + 1
      }
      let value = word.to_string()
      let kind = if keyword_set_contains(keywords, value) {
        TokKeyword
      } else if builtins.contains(value) {
        TokBuiltin
      } else {
        TokPlain
      }
      flush(word, kind)
      continue
    }
    // 其余（运算符/标点/空白）留在普通缓冲里
    buf.write_char(c)
    index = index + 1
  }
  flush(buf, TokPlain)
  tokens
}

///|
fn is_digit_char(c : Char) -> Bool {
  let code = c.to_int()
  code >= 0x30 && code <= 0x39
}

///|
fn is_number_char(c : Char) -> Bool {
  is_digit_char(c) || c == '.'
}

///|
/// 标识符字符：ASCII 字母数字下划线 + 非 ASCII（中文标识符）。
/// 与 DSL 词法同口径——中文关键字也是标识符 token，由关键字表分派。
fn is_word_char(c : Char) -> Bool {
  let code = c.to_int()
  if code >= 0x80 {
    true
  } else {
    (code >= 0x30 && code <= 0x39) ||
    (code >= 0x41 && code <= 0x5A) ||
    (code >= 0x61 && code <= 0x7A) ||
    code == 0x5F
  }
}

///|
/// 关键字表包含判定：正确拼写的 Keywords 字段逐项比对。
/// 分类只影响颜色，漏判只是不高亮，不影响任何语义。
fn keyword_set_contains(
  keywords : @studio_lang.Keywords,
  word : String,
) -> Bool {
  let groups : Array[String] = [
    keywords.declare_kw,
    keywords.if_kw,
    keywords.then_kw,
    keywords.else_if_kw,
    keywords.else_kw,
    keywords.end_kw,
    keywords.count_kw,
    keywords.times_kw,
    keywords.as_kw,
    keywords.while_kw,
    keywords.do_kw,
    keywords.break_kw,
    keywords.true_kw,
    keywords.false_kw,
    keywords.and_kw,
    keywords.or_kw,
    keywords.not_kw,
  ]
  groups.contains(word)
}

///|
/// IR 语句 → 代码行映射区段。
/// 口径：把当前子程序的每条顶层语句**逐条渲染**，数出行数即区间——
/// 渲染函数是确定性的（同一 IR 逐字节稳定），所以行号可复现；
/// 行号不进 IR，映射是渲染的副产品。
/// 只映射顶层语句（嵌套语句的行号随父语句起算，展开会与父块重叠）。
pub fn ir_line_spans(model : Model) -> Array[IrLineSpan] {
  let spans : Array[IrLineSpan] = []
  match current_handler(model) {
    None => ()
    Some(handler) => {
      let language = model.language.dsl_language()
      // 头部注释行数（handler note 渲染在前）——用「整段渲染」与
      // 「逐条渲染」的差值定位每条语句的起点。
      let mut cursor = 1
      let rendered_all = @studio_lang.render_handler(handler, language)
      let total_lines = split_line_texts(rendered_all).length()
      let body_lines = split_line_texts(
        @studio_lang.render_stmts(handler.body, language),
      ).length()
      // 语句体之前的头部行数（note 注释 + 子程序头）
      cursor = total_lines - body_lines + 1
      let mut index = 0
      for stmt in handler.body {
        let one = @studio_lang.render_stmts([stmt], language)
        let lines = split_line_texts(one).length()
        let first = cursor
        let last = if lines > 0 { cursor + lines - 1 } else { cursor }
        spans.push(IrLineSpan::{
          path: [index],
          kind: @blocks.stmt_block_kind(stmt),
          depth: 0,
          first_line: first,
          last_line: last,
        })
        cursor = last + 1
        index = index + 1
      }
    }
  }
  spans
}

///|
/// 按语句路径查行区间（路径为空或无匹配时 None）。
pub fn ir_span_at(spans : Array[IrLineSpan], path : Array[Int]) -> IrLineSpan? {
  if path.length() == 0 {
    return None
  }
  for span in spans {
    if span.path == path {
      return Some(span)
    }
  }
  None
}

///|
/// 行号落在哪个区间（IR 行 → 积木块的反向映射）。
pub fn ir_span_for_line(spans : Array[IrLineSpan], line : Int) -> IrLineSpan? {
  for span in spans {
    if line >= span.first_line && line <= span.last_line {
      return Some(span)
    }
  }
  None
}

///|
/// 积木分类条：按 IR 的 5 个语义族列出「该分类在当前子程序的第一个块下标」。
/// 分类是固定枚举顺序（事件/变量/控制/命令/表达式），-1 表示本子程序
/// 没有该分类的块（分类条灰显）。
pub fn block_category_entries(model : Model) -> Array[BlockCategoryEntry] {
  let blocks = match current_handler(model) {
    None => ([] : Array[@blocks.BlockItem])
    Some(handler) => @blocks.block_chain(handler.body)
  }
  let categories : Array[@blocks.BlockCategory] = [
    @blocks.CatEvent,
    @blocks.CatVariable,
    @blocks.CatFlow,
    @blocks.CatCommand,
    @blocks.CatExpression,
  ]
  let entries : Array[BlockCategoryEntry] = []
  for category in categories {
    let mut first = -1
    let mut index = 0
    for item in blocks {
      if first == -1 && same_category(block_category(item.kind), category) {
        first = index
      }
      index = index + 1
    }
    entries.push(BlockCategoryEntry::{ category, first_index: first, })
  }
  entries
}

///|
/// 分类同一性：BlockCategory 没有 Eq 派生（domain 保持最小派生面），
/// 用色键做同一定义（色键与枚举一一对应，见 domain 的 category_color_key）。
pub fn same_category(
  a : @blocks.BlockCategory,
  b : @blocks.BlockCategory,
) -> Bool {
  @blocks.category_color_key(a) == @blocks.category_color_key(b)
}

///|
/// 积木分类条同一行的定位下标：分类条点「流程」时滚动到该分类首块。
pub fn block_category_first(
  entries : Array[BlockCategoryEntry],
  index : Int,
) -> Int {
  if index < 0 || index >= entries.length() {
    -1
  } else {
    entries[index].first_index
  }
}

///|
/// 积木分类条 i18n 键：与 domain 的 category_color_key 同源后缀，
/// 渲染层解析成中文分类名。
pub fn block_category_label_key(category : @blocks.BlockCategory) -> String {
  "app.blocks.cat.\{@blocks.category_color_key(category)}"
}

///|
/// 积木种类 → 语义分类（分类条与取色共用）。
/// 这条映射在 app 层：domain 的 spec 表只对「内建命令」给出分类，
/// 而控制流/声明这些由 IR 语句结构决定的块没有 spec 条目。
pub fn block_category(kind : @blocks.BlockKind) -> @blocks.BlockCategory {
  match kind {
    @blocks.BkDeclare | @blocks.BkAssign | @blocks.BkSetIndex =>
      @blocks.CatVariable
    @blocks.BkReturn => @blocks.CatFlow
    @blocks.BkIf | @blocks.BkElseIf | @blocks.BkElse | @blocks.BkEnd =>
      @blocks.CatFlow
    @blocks.BkCountLoop | @blocks.BkWhile => @blocks.CatFlow
    @blocks.BkBreak => @blocks.CatFlow
    @blocks.BkCall => @blocks.CatCommand
  }
}

// ============================================================================
// 运行时监视与工具条计数
// ============================================================================

///|
/// 运行时监视行：当前轨的变量表（未运行时空——面板显示「未运行」提示）。
/// 解释轨读 RunState.vars，编译轨读 Runtime.vars；两轨口径一致
/// （按键名稳定排序），与运行视图的变量表同源。
pub fn watch_rows(model : Model) -> Array[WatchRow] {
  let rows : Array[WatchRow] = []
  match current_track(model) {
    Interpret =>
      match model.run {
        None => ()
        Some(run) => {
          let names : Array[String] = []
          for name in run.state.vars.keys() {
            names.push(name)
          }
          names.sort()
          for name in names {
            match run.state.vars.get(name) {
              Some(value) =>
                rows.push(WatchRow::{
                  name,
                  value: @studio_lang.value_to_text(value),
                  type_label: value_type_label(value),
                })
              None => ()
            }
          }
        }
      }
    Compile =>
      match model.compiled_run {
        None => ()
        Some(run) => {
          let names : Array[String] = []
          for name in run.runtime.vars.keys() {
            names.push(name)
          }
          names.sort()
          for name in names {
            match run.runtime.vars.get(name) {
              Some(value) =>
                rows.push(WatchRow::{
                  name,
                  value: @compiled_runtime.value_to_text(value),
                  type_label: compiled_value_type_label(value),
                })
              None => ()
            }
          }
        }
      }
  }
  rows
}

///|
fn value_type_label(value : @studio_lang.Value) -> String {
  match value {
    @studio_lang.VStr(_) => "text"
    @studio_lang.VNum(_) | @studio_lang.VInt(_) => "number"
    @studio_lang.VArr(_) => "list"
    @studio_lang.VBool(_) => "bool"
    @studio_lang.VUnit => "unit"
  }
}

///|
fn compiled_value_type_label(value : @compiled_runtime.Value) -> String {
  match value {
    @compiled_runtime.VStr(_) => "text"
    @compiled_runtime.VNum(_) | @compiled_runtime.VInt(_) => "number"
    @compiled_runtime.VArr(_) => "list"
    @compiled_runtime.VBool(_) => "bool"
    @compiled_runtime.VUnit => "unit"
  }
}

///|
/// 是否正在运行（任一轨）——工具条/状态栏/监视面板共用。
pub fn app_running(model : Model) -> Bool {
  match current_track(model) {
    Interpret => model.run is Some(_)
    Compile => model.compiled_run is Some(_)
  }
}

///|
/// 当前轨是否停在闸门（待确认外发）。
pub fn gate_pending(model : Model) -> Bool {
  match current_track(model) {
    Interpret =>
      match model.run {
        Some(run) => run.state.gate is Some(_)
        None => false
      }
    Compile =>
      match model.compiled_run {
        Some(run) => run.runtime.gate is Some(_)
        None => false
      }
  }
}

///|
/// 待处理副作用数（审计 warn 未 settled）：状态栏计数 + 药丸徽标共用。
pub fn pending_side_effects(model : Model) -> Int {
  let mut count = 0
  for entry in model.audit_entries {
    if entry.kind is AuditWarn && !entry.settled {
      count = count + 1
    }
  }
  count
}

///|
/// 运行错误数（审计 error 未 settled）。
pub fn audit_error_count(model : Model) -> Int {
  let mut count = 0
  for entry in model.audit_entries {
    if entry.kind is AuditError && !entry.settled {
      count = count + 1
    }
  }
  count
}

///|
/// 待审计的 AI 卡数（未 settled 的 diff/副作用卡）：药丸徽标 + 折叠条共用。
pub fn pending_ai_cards(model : Model) -> Int {
  let mut count = 0
  for card in model.ai_cards {
    if !card.settled && (card.kind is CardDiff || card.kind is CardSideEffect) {
      count = count + 1
    }
  }
  count
}

///|
/// 状态栏位置读数：当前子程序的首个映射行（"4:7" 形态的位置提示）。
/// 没有映射时显示 1:1（空程序也成立，不让状态栏空着）。
pub fn status_position(model : Model) -> String {
  let spans = ir_line_spans(model)
  if spans.length() == 0 {
    "1:1"
  } else {
    let target = match model.ir_highlight.length() {
      0 => spans[0]
      _ =>
        match ir_span_at(spans, model.ir_highlight) {
          Some(span) => span
          None => spans[0]
        }
    }
    let column = if model.ir_highlight.length() > 0 { 7 } else { 1 }
    "\{target.first_line}:\{column}"
  }
}

///|
/// 状态栏构建读数：编译报告存在时显示耗时，否则显示「未构建」。
pub fn status_build_label(model : Model) -> String {
  match model.compile_report {
    None => ""
    Some(report) =>
      if report.ok {
        "app.statusbar.build_ok"
      } else {
        "app.statusbar.build_failed"
      }
  }
}

///|
/// 结构树按可见分组过滤后的分组序列（渲染层用：分组头 + 其子节点）。
pub fn visible_groups(nodes : Array[TreeNode]) -> Array[String] {
  let groups : Array[String] = []
  for node in nodes {
    if node.kind is TnGroup && !groups.contains(node.group) {
      groups.push(node.group)
    }
  }
  groups
}

///|
/// 分组下的子节点（不含分组头本身）。
pub fn group_children(
  nodes : Array[TreeNode],
  group : String,
) -> Array[TreeNode] {
  let children : Array[TreeNode] = []
  for node in nodes {
    if node.group == group && !(node.kind is TnGroup) {
      children.push(node)
    }
  }
  children
}
