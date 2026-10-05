///|
/// v4 IDE 代码工作区：行号槽 + 真编辑面 + IR 行尺 + 脚注，
/// 以及空舞台。
///
/// 从 `workspace.mbt` 拆出（原文件 1162 行，逼近 1200 硬上限）。分工：
/// `workspace.mbt` 管窗格外壳与宽度分配（窗格头、分隔条、可视化工作区），
/// 本文件管**代码视图与空舞台**这两块内容渲染。
///
/// IR 是唯一事实来源——高亮与编辑都发生在 `model.code_draft`（IR 的
/// 渲染投影）上，提交时经 `parse_handler_body` 写回 IR，不产生第二份结构。
/// 编辑面是 `moui_richtext` 的受控富文本编辑器（光标/选区/撤销/剪贴板
/// 全部框架侧），DSL 着色通过 `format=` 的 token run 注入。

// ============================================================================
// 代码工作区
// ============================================================================

///|
/// 代码工作区：行号槽 + 受控编辑面 + IR 行尺 + 脚注。
/// 三列共用一份滚动状态（`model.code_scroll`）：编辑面是滚动的事实来源，
/// 行号槽与竖尺是跟随者，行号 ↔ 色块的对应才不会错位。
pub fn code_workspace(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  // 标题副行取当前子程序的控件名（match 作实参时逗号会被当成臂分隔，
  // 先落成局部量）。
  let handler_subtitle = match current_handler(model) {
    None => text(t, "app.handler.none")
    Some(handler) => handler.control_name
  }
  // 外观胶囊（M5-5e）：MoonBit（默认显示）⇄ DSL，点按循环。
  let head = pane_head(text(t, "app.pane.code"), handler_subtitle, width, [])
  let spans = ir_line_spans(model)
  // 高度预算：头 30 + 说明条 30 + 脚注 36 + 补全占位 1 + **底栏页签带 26**
  //（中心列的下缘与收起底栏的页签头相接——实测这 26pt 会被底栏盖住，
  // 脚注整行「消失」，切换芯片也随之不可见）,错误条可见时再 +24。
  let error_reserve = if model.code_error == "" { 0.0 } else { 24.0 }
  let chrome = 123.0 + error_reserve
  let code_height = (height - chrome).max(120.0)
  let editor_width = (width - 2.0 - CODE_GUTTER_WIDTH - IR_RAIL_WIDTH).max(80.0)
  @views.container(
    @views.column(
      [
        head,
        code_error_bar(model, t, width),
        // 行号槽 | 编辑面 | IR 竖尺 并排：三者同高，滚动同步由
        // `EditorScrolled` 单向汇聚到 model 再各自回填 offset。
        @views.row(
          [
            code_gutter(model, CODE_GUTTER_WIDTH, code_height),
            code_editor_surface(model, t, editor_width, code_height),
            ir_ruler(model, spans, code_height),
          ],
          spacing=0.0,
          align=Start,
        ).frame(width=width - 2.0, height=code_height),
        completion_popup(model, width),
        code_hint_bar(t, width),
        code_foot(model, t, width),
      ],
      spacing=0.0,
    ).frame(width~, height~),
    background=ide_editor_background(),
    width~,
    height~,
    padding=0.0,
  )
}

///|
/// 行号槽宽度：4 位数行号 + 错误标记位（切片 B 启用）。
const CODE_GUTTER_WIDTH : Double = 44.0

///|
/// 语法错误条：`code_error` 非空时单行提示（提交失败时由 commit_code 写入）。
fn code_error_bar(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  if model.code_error == "" {
    @views.text("", width=1.0, height=1.0)
  } else {
    @views.container(
      @views.text(
        text(t, "app.code.error") + "：" + model.code_error,
        theme=studio_theme(),
        width=(width - 20.0).max(80.0),
        height=20.0,
        align=TextStart,
      ).foreground(ide_danger()),
      background=ide_panel(),
      height=24.0,
      width=width - 2.0,
      padding=0.0,
    )
  }
}

///|
/// 行号槽：跟随编辑面滚动（共享 `code_scroll`），当前行点亮。
fn code_gutter(
  model : Model,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let active_line = @code_editor.code_editor_caret_position(
      model.code_draft,
      model.code_caret,
    ).line
  let diagnostic_lines = @code_editor.code_editor_diagnostic_lines(
    model.code_draft,
    model.code_diagnostics,
  )
  let rows : Array[@moui.View[Msg]] = []
  for line in @code_editor.code_editor_source_lines(model.code_draft) {
    let is_active = line.number == active_line
    let has_diagnostic = diagnostic_lines.contains(line.number)
    // 行号槽 = 8pt 标记位 + 行号：诊断行画红点并把行号染红——
    // 「哪一行有问题」在滚动时也要一眼可辨。
    let marker = @views.container(
      @views.text("", width=1.0, height=1.0),
      background=if has_diagnostic {
        ide_danger()
      } else {
        ide_editor_background()
      },
      corner_radius=2.0,
      width=5.0,
      height=5.0,
      padding=0.0,
    )
    rows.push(
      @views.container(
        @views.row(
          [
            @views.container(
              @views.center(marker, width=8.0, height=CODE_LINE_HEIGHT),
              width=8.0,
              height=CODE_LINE_HEIGHT,
              padding=0.0,
            ),
            @views.text(
              "\{line.number}",
              theme=studio_theme(),
              role=Mono,
              width=(width - 16.0).max(20.0),
              height=CODE_LINE_HEIGHT,
              align=TextEnd,
            ).foreground(
              if has_diagnostic {
                ide_danger()
              } else if is_active {
                ide_text()
              } else {
                ide_text_faint()
              },
            ),
          ],
          spacing=2.0,
          align=Center,
        ).frame(width~, height=CODE_LINE_HEIGHT),
        background=if is_active {
          ide_panel_alt()
        } else {
          ide_editor_background()
        },
        width~,
        height=CODE_LINE_HEIGHT,
        padding=0.0,
      ),
    )
  }
  @views.scroll_view(
    @views.column(rows, spacing=0.0),
    offset=model.code_scroll,
    width~,
    height~,
    on_scroll=Some(offset => EditorScrolled(offset.y)),
    shows_indicator=false,
  )
}

///|
/// 代码行高：行号槽 / 编辑面块高 / IR 竖尺三方对齐的基准。
const CODE_LINE_HEIGHT : Double = 20.0

///|
/// 编辑面：`moui_richtext` 受控富文本编辑器。
/// DSL 着色走 `format=`（token run + source_range），换行自动缩进走
/// `input_transform=`，滚动上报走 `on_scroll=`（行号槽与竖尺跟随）。
fn code_editor_surface(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let font = @text.FontSpec::new(
    families=@text.FontFamilyStack::monospace(),
    size=13.0,
  )
  @moui_richtext.controlled_rich_text_editor(
    value=model.code_draft,
    on_input=source => EditCode(source),
    placeholder=text(t, "app.code.cheatsheet"),
    size=@geometry.Size::new(width~, height~),
    format=source => code_document(model, source, font),
    font~,
    foreground=code_plain_color(),
    placeholder_color=ide_text_faint(),
    background=@graphics.Brush::solid(ide_editor_background()),
    cursor_color=ide_accent(),
    corner_radius=0.0,
    on_selection_change=Some((caret, selection) => {
      EditorCaretMoved(caret, selection)
    }),
    input_transform=Some((source, caret, _selection, inserted) => {
      if inserted == "\n" {
        code_newline_transform(model, source, caret)
      } else {
        None
      }
    }),
    accepts_tab_input=false,
    visible_scroll_y=model.code_scroll.y,
    on_scroll=Some(y => EditorScrolled(y)),
    visible_viewport_height=height,
    visible_overscan=160.0,
    selection_caret=model.code_caret,
    selection_range=model.code_selection,
    kind="StudioCodeEditor",
    key=Some("studio-code-editor"),
  )
}

///|
/// DSL 源码 → 富文本文档：每行一个块，token run 带 `source_range` +
/// 语义配色。行高固定 `CODE_LINE_HEIGHT`，行号槽与竖尺才能逐行对齐。
fn code_document(
  model : Model,
  source : String,
  font : @text.FontSpec,
) -> @moui_richtext.RichTextDocument {
  let keywords = @studio_lang.keywords_for(model.language.dsl_language())
  let builtins = builtin_words(model.language.dsl_language())
  let diagnostics = model.code_diagnostics
  let blocks : Array[@moui_richtext.RichTextBlock] = []
  let chars = source.to_array()
  let mut line_start = 0
  let mut index = 0
  while index < chars.length() {
    if chars[index] == '\n' {
      blocks.push(
        code_line_block(
          String::from_array(chars[line_start:index]),
          line_start~,
          content_end=index,
          source_end=index + 1,
          keywords~,
          builtins~,
          diagnostics~,
          font~,
        ),
      )
      line_start = index + 1
    }
    index = index + 1
  }
  blocks.push(
    code_line_block(
      String::from_array(chars[line_start:chars.length()]),
      line_start~,
      content_end=chars.length(),
      source_end=chars.length(),
      keywords~,
      builtins~,
      diagnostics~,
      font~,
    ),
  )
  @moui_richtext.RichTextDocument::new(blocks~)
}

///|
/// 单行 → 富文本块：ranged token 直接映射 run（颜色取渲染层调色板）。
fn code_line_block(
  line : String,
  line_start~ : Int,
  content_end~ : Int,
  source_end~ : Int,
  keywords~ : @studio_lang.Keywords,
  builtins~ : Array[String],
  diagnostics~ : Array[@code_editor.CodeDiagnostic],
  font~ : @text.FontSpec,
) -> @moui_richtext.RichTextBlock {
  let runs : Array[@moui_richtext.RichTextRun] = []
  for token in highlight_line_ranged(line, line_start, keywords, builtins) {
    let start = token.start
    let end = start + token.text.length()
    // 行内标记：与诊断区间相交的 run 加淡红底——richtext 的装饰
    // 只有删除线，底色是「这一段有问题」的最低限度行内提示。
    let flagged = diagnostics
      .iter()
      .any(diagnostic => {
        diagnostic.range.start < end && start < diagnostic.range.end
      })
    runs.push(
      @moui_richtext.RichTextRun::new(
        text=token.text,
        font=Some(font),
        color=Some(code_token_color(token.kind)),
        background=if flagged {
          Some(@graphics.Brush::solid(code_error_line_tint()))
        } else {
          None
        },
        source_range=Some({ start, end, }),
      ),
    )
  }
  if runs.is_empty() {
    runs.push(
      @moui_richtext.RichTextRun::new(
        text="",
        font=Some(font),
        source_range=Some({ start: line_start, end: line_start, }),
      ),
    )
  }
  @moui_richtext.RichTextBlock::new(
    runs~,
    font=Some(font),
    source_range=Some({ start: line_start, end: source_end, }),
    content_range=Some({ start: line_start, end: content_end, }),
    line_height=Some(CODE_LINE_HEIGHT),
  )
}

///|
/// 换行输入变换：`\n` → `\n` + 缩进。缩进 = 当前行前导空白，
/// 当前行以块首关键字（如果/计次循环/当…）开头时多进一层；
/// 块尾关键字（结束/跳出循环）回退一层。分类器复用 DSL 解析器的
/// 关键字表，双语同一条路径。
fn code_newline_transform(
  model : Model,
  source : String,
  caret : Int,
) -> @moui_richtext.RichTextInputTransform? {
  let indent = dsl_indent_for_newline(model, source, caret)
  let (text, cursors) = @code_editor.code_insert_text(
    source,
    [@code_editor.CodeCursor::new(position=caret)],
    "\n" + indent,
  )
  let next_caret = match cursors {
    [cursor, ..] => cursor.position
    [] => caret
  }
  Some(
    @moui_richtext.RichTextInputTransform::new(
      text~,
      caret=next_caret,
      selection=None,
    ),
  )
}

///|
/// DSL 换行缩进：当前行前导空白为基，块首关键字 +2，块尾关键字 -2。
fn dsl_indent_for_newline(
  model : Model,
  source : String,
  caret : Int,
) -> String {
  let chars = source.to_array()
  let pos = caret.clamp(min=0, max=chars.length())
  let mut line_start = pos
  while line_start > 0 && chars[line_start - 1] != '\n' {
    line_start = line_start - 1
  }
  let indent : Array[Char] = []
  let mut index = line_start
  while index < pos && (chars[index] == ' ' || chars[index] == '\t') {
    indent.push(chars[index])
    index = index + 1
  }
  // 行内容（去前导空白后）的第一个词
  let mut end = pos
  while end < chars.length() && chars[end] != '\n' {
    end = end + 1
  }
  let trimmed = String::from_array(chars[index:end])
  let word = StringBuilder()
  for c in trimmed {
    if ({
        let code = c.to_int()
        code >= 0x80 ||
        (code >= 0x30 && code <= 0x39) ||
        (code >= 0x41 && code <= 0x5A) ||
        (code >= 0x61 && code <= 0x7A) ||
        code == 0x5F
      }) {
      word.write_char(c)
    } else {
      break
    }
  }
  let keywords = @studio_lang.keywords_for(model.language.dsl_language())
  let deeper = match
    @studio_lang.classify_stmt_keyword(word.to_string(), keywords) {
    KwIf | KwCountLoop | KwWhile => 2
    _ => 0
  }
  // 块尾关键字回退：结束/跳出循环（双语）
  let closes = trimmed == keywords.end_kw || trimmed == keywords.break_kw
  let width = indent.length() + deeper * 2 - (if closes { 2 } else { 0 })
  let spaces = StringBuilder()
  for _ in 0..<width.max(0) {
    spaces.write_char(' ')
  }
  spaces.to_string()
}

///|
/// token 配色：模型只带语义分类，取色在渲染层。
fn code_token_color(kind : CodeTokenKind) -> @graphics.Color {
  match kind {
    TokKeyword => code_keyword_color()
    TokString => code_string_color()
    TokNumber => code_number_color()
    TokBuiltin => code_function_color()
    TokComment => code_comment_color()
    TokPlain => code_plain_color()
  }
}

///|
/// IR 映射竖条（设计稿 `#irRuler`）：30pt 宽的竖条，与右侧代码**逐行对齐**，
/// 每条语句按其行号区间画成一个色块。
///
/// 实现方式：**逐行一个 20pt 单元**的列，而不是一块 canvas。原因是交互：
/// canvas 是纯绘制节点，拿不到「悬停/点击了哪一条」；要按指针 y 反查就得
/// 自己在 `on_tap_with_frame` 里算，而 `on_hover` 只给 Bool、拿不到位置，
/// 悬停方向就永远做不出来。逐行单元让每行各自持有 `on_hover`/`on_tap`，
/// 命中判断交给框架，同时**对齐是天然的**（两列同为 20pt 行高）。
///
/// 连续块的观感靠圆角区分：区间首行圆上角、末行圆下角、中间行不圆角，
/// 相邻行贴在一起就还原了设计稿里一根长条的样子。
///
/// 交互（这是本窗格脚注「悬停代码行或右缘色块试试」的兑现）：
/// 悬停 → `HoverIrPath`（瞬态预览，离开还原）；点击 → `HighlightIrPath`
/// （驻留高亮，再点一次取消）。
pub fn ir_ruler(
  model : Model,
  spans : Array[IrLineSpan],
  height : Double,
) -> @moui.View[Msg] {
  // 全部行都画（编辑面是滚动事实来源，竖尺作为跟随者滚动同步）。
  let line_count = split_line_texts(model.code_draft).length().max(1)
  let highlight = model.ir_highlight
  let cells : Array[@moui.View[Msg]] = []
  for line in 1..<=line_count {
    let span = ir_span_for_line(spans, line)
    let cell = match span {
      None =>
        // 无映射的行：留空白单元占位，保证与代码行不错位
        @views.container(
          @views.text("", width=1.0, height=1.0),
          background=ide_panel(),
          width=IR_RAIL_WIDTH,
          height=IR_RAIL_LINE_HEIGHT,
          padding=0.0,
        )
      Some(span) => {
        let hovered_bar = match model.hover_path {
          Some(hover) => same_path(span.path, hover)
          None => false
        }
        // 驻留高亮（点击）与悬停（瞬态预览）是**不同**的视觉：
        // 驻留全亮暖黄，悬停半透明——竖尺是映射交互的唯一载体，
        // 两者同色就分不清「我看的是它」和「我选了它」。
        let pinned = same_path(span.path, highlight)
        let is_first = line == span.first_line
        let is_last = line == span.last_line
        // 首/末行圆角，中间行方角 —— 相邻贴合成一根长条
        let radius = if is_first && is_last {
          3.0
        } else if is_first {
          3.0
        } else if is_last {
          3.0
        } else {
          0.0
        }
        // 中间行向上/下各溢出 1pt，盖住单元间隙，避免长条出现横向接缝
        let bar_height = if is_first && is_last {
          14.0
        } else if is_first || is_last {
          17.0
        } else {
          IR_RAIL_LINE_HEIGHT
        }
        let bar = @views.container(
          @views.text("", width=1.0, height=1.0),
          background=if pinned {
            ide_ir_highlight()
          } else if hovered_bar {
            ide_ir_hover()
          } else {
            block_category_fill(block_category(span.kind))
          },
          corner_radius=radius,
          width=14.0,
          height=bar_height,
          padding=0.0,
        )
        @views.container(
          @views.row(
            [
              @views.spacer(min_length=5.0, weight=0.0),
              bar,
              @views.spacer(min_length=0.0, weight=1.0),
            ],
            spacing=0.0,
            align=Center,
          ).frame(width=IR_RAIL_WIDTH, height=IR_RAIL_LINE_HEIGHT),
          background=ide_panel(),
          width=IR_RAIL_WIDTH,
          height=IR_RAIL_LINE_HEIGHT,
          padding=0.0,
        )
        .on_hover(active => {
          HoverIrPath(if active { Some(span.path) } else { None })
        })
        .on_tap(HighlightIrPath(span.path))
      }
    }
    cells.push(cell)
  }
  // 竖尺是滚动的**跟随者**：offset 由编辑面（或竖尺自身）经
  // `EditorScrolled` 汇入 model，再回填到这里。
  @views.scroll_view(
    @views.column(cells, spacing=0.0),
    offset=model.code_scroll,
    width=IR_RAIL_WIDTH,
    height~,
    on_scroll=Some(offset => EditorScrolled(offset.y)),
    shows_indicator=false,
  )
}

///|
/// IR 竖条宽度（设计稿 #irRuler 30pt）。
pub const IR_RAIL_WIDTH : Double = 30.0

///|
/// 竖条行高：与代码行高一致，色块才能和行对齐。
const IR_RAIL_LINE_HEIGHT : Double = 20.0

///|
/// 代码脚注：光标行列读数 + 恢复渲染 + 编译轨入口。
/// 编辑已上移到主区（受控编辑面），脚注只留状态与动作。
fn code_foot(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  @views.container(
    @views.padding_xy(
      code_foot_row(model, t, (width - 16.0).max(120.0)),
      horizontal=8.0,
      vertical=6.0,
    ),
    background=ide_panel(),
    width~,
    padding=0.0,
  )
}

///|
/// 代码视图的说明条（设计稿 `#codeFoot`）：一句话讲清「行号 ↔ 积木块」
/// 是双向的，并提示怎么试。它替代不了竖条本身，但用户第一次看到右侧
/// 色块时需要一个「那是什么」的答案。
fn code_hint_bar(t : @i18n.Translator, width : Double) -> @moui.View[Msg] {
  @views.container(
    @views.padding_xy(
      fill_row(
        [
          @views.icon(Info, size=12.0, color=ide_text_faint()),
          @views.text(
            fit_label(text(t, "app.code.foot_hint"), (width - 44.0).max(80.0)),
            theme=studio_theme(),
            width=(width - 40.0).max(80.0),
            height=16.0,
            align=TextStart,
          ).foreground(ide_text_faint()),
        ],
        (width - 20.0).max(80.0),
        8.0,
        Center,
      ),
      horizontal=10.0,
      vertical=0.0,
    ),
    background=ide_panel(),
    height=30.0,
    width~,
    padding=0.0,
  )
}

///|
/// 代码页脚的动作行：光标行列 + 恢复 + 编译。宽度按可用宽分配，
/// 按钮用定宽胶囊（`@views.button` 的 width 是最小值，会把行撑破）。
fn code_foot_row(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  // 按钮宽**按标签实测宽**给（+左右各 10 内垫）：写死 62/68 会把
  // 「按 IR 重渲染」「编译 MoonBit」截成「按 IR 重渲」「编译 MoonB」。
  // 内垫取 34：`text_estimate_width` 是估算，中文 + 拉丁混排的真实字形
  // 比估算宽 5-8px，取值要把这段差额也盖住（实测 26 仍差 2.7px）。
  let restore_w = text_estimate_width(text(t, "app.code.restore")) + 34.0
  let compile_w = text_estimate_width(text(t, "app.code.compile")) + 34.0
  let gap = 6.0
  let caret = @code_editor.code_editor_caret_position(
    model.code_draft,
    model.code_caret,
  )
  let caret_label = text_with(t, "app.code.caret", [
    ("line", "\{caret.line}"),
    ("col", "\{caret.column}"),
  ])
  let appearance_w = match model.code_appearance {
    AppMoonBit => {
      let label = text(t, "app.code.switch_dsl")
      text_estimate_width(label) * 1.05 + 28.0
    }
    AppDsl => {
      let label = text(t, "app.code.switch_moonbit")
      text_estimate_width(label) * 1.05 + 28.0
    }
  }
  let hint_w = (width - appearance_w - restore_w - compile_w - gap * 3.0).max(40.0)
  // 外观切换芯片（实测反馈两轮：用户找不到入口）——脚注行右侧，
  // 文案写明**目标**（「切到中文 DSL」/「切到 MoonBit」），不存在歧义。
  let appearance_chip = match model.code_appearance {
    AppMoonBit => {
      let label = text(t, "app.code.switch_dsl")
      foot_chip(
        label,
        text_estimate_width(label) * 1.05 + 28.0,
        false,
        SetCodeAppearance(AppDsl),
      )
    }
    AppDsl => {
      let label = text(t, "app.code.switch_moonbit")
      foot_chip(
        label,
        text_estimate_width(label) * 1.05 + 28.0,
        false,
        SetCodeAppearance(AppMoonBit),
      )
    }
  }
  fill_row(
    [
      @views.text(
        caret_label,
        theme=studio_theme(),
        role=Mono,
        width=hint_w,
        height=16.0,
        align=TextStart,
      ).foreground(ide_text_faint()),
      appearance_chip,
      foot_chip(text(t, "app.code.restore"), restore_w, false, RestoreCodeDraft),
      foot_chip(text(t, "app.code.compile"), compile_w, true, CompileRun),
    ],
    width,
    gap,
    Center,
  )
}

///|
/// 页脚小胶囊：手搓定宽（button 的 width 是最小值，撑不出精确宽度）。
fn foot_chip(
  label : String,
  width : Double,
  primary : Bool,
  on_click : Msg,
) -> @moui.View[Msg] {
  @views.container(
    @views.center(
      // 文字宽 = 胶囊宽 − 左右内垫（各 4）。原来减 8 但内垫是 4+4，
      // 再叠上字形比估算宽，长标签会被截。
      @views.text(
        label,
        theme=studio_theme(),
        width=(width - 6.0).max(20.0),
        height=16.0,
      ).foreground(if primary { ide_accent() } else { ide_text_muted() }),
      width~,
      height=24.0,
    ),
    background=if primary { ide_accent_soft() } else { ide_panel_alt() },
    corner_radius=4.0,
    width~,
    height=24.0,
    padding=0.0,
  )
  .accessibility_label(label)
  .on_tap(on_click)
}

// ============================================================================
// 空舞台
// ============================================================================

///|
/// 空舞台：三工作区都收起时的引导面（设计稿 wsEmpty）。
/// 四个入口 = 起手式：新建空程序 / 载入样例 / 打开文件 / 生成提案。

///|
/// 空舞台的动作按钮：**按内容宽度**，不写死 150。
///
/// 写死 150 会让整行随按钮数量越出中心列：模板 3 颗 + 恢复入口最多 2 颗，
/// 5×150 + 4×10 = 790 > 1280 窗口下的中心列 724，最右那颗被面板裁掉
/// （实测 `+ 积木窗格` 只露出左半）。`@views.button` 的 `width` 又只是最小
/// 宽，所以宽度必须自己算准（`button_label_width`），并夹在窗格内。
const EMPTY_BUTTON_MIN_WIDTH : Double = 96.0

///|
/// 空舞台按钮行：一行放得下就一行，放不下就折成两行。
///
/// 折行而不是压缩：把 5 颗按钮压到 ~140 会让「新建问候程序」这种 6 字标签
/// 贴边（`@views.button` 内垫 32，6 全角字要 96+32=128）。两行更宽松，也
/// 不至于在窄窗口下把按钮挤出窗格。
fn empty_stage_button_rows(
  buttons : Array[@moui.View[Msg]],
  widths : Array[Double],
  width : Double,
) -> Array[@moui.View[Msg]] {
  let avail = (width - 24.0).max(120.0)
  let gap = 10.0
  let rows : Array[@moui.View[Msg]] = []
  let mut current : Array[@moui.View[Msg]] = []
  let mut used = 0.0
  let mut index = 0
  for button in buttons {
    let w = if index < widths.length() { widths[index] } else { 120.0 }
    let needed = if current.length() == 0 { w } else { used + gap + w }
    if current.length() > 0 && needed > avail {
      rows.push(@views.row(current, spacing=gap, align=Center))
      current = []
      used = 0.0
    }
    current.push(button)
    used = if used == 0.0 { w } else { used + gap + w }
    index = index + 1
  }
  if current.length() > 0 {
    rows.push(@views.row(current, spacing=gap, align=Center))
  }
  rows
}

///|
/// 空舞台：模板入口 + 窗格恢复入口。
pub fn empty_stage(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  // 标签与其真实宽度成对收集，宽度供折行计算
  let specs : Array[(String, Msg, @style.ButtonVariant)] = [
    (text(t, "app.empty.hello"), SelectTemplate(0), Primary),
    (text(t, "app.empty.roll_call"), SelectTemplate(1), Tonal),
    // 从真正的空白开始：empty_program 此前没有任何 UI 入口——「无 AI
    // 也能从零写程序」缺的就是这个原点（配合语句插入面板）。
    (text(t, "app.empty.blank"), NewBlankProgram, Tonal),
    (text(t, "app.empty.open"), OpenRequested, Outline),
  ]
  // 窗格都被关掉时，空舞台就是**唯一的恢复入口**（设计稿 `#btnAddLive` /
  // `#btnAddBlocks`）。只在真的有窗格被关掉时才加——否则「+ 实时应用」
  // 在一个已经显示着实时的界面上是个说不通的按钮。
  if !model.pane_live {
    specs.push((text(t, "app.pane.show_live"), ShowPaneLive, Outline))
  }
  if !blocks_pane_wanted(model) {
    specs.push((text(t, "app.pane.show_blocks"), ShowPaneBlocks, Outline))
  }
  let buttons : Array[@moui.View[Msg]] = []
  let widths : Array[Double] = []
  for spec in specs {
    let (label, msg, variant) = spec
    let w = (button_label_width(label) + 16.0).max(EMPTY_BUTTON_MIN_WIDTH)
    widths.push(w)
    buttons.push(
      @views.button(label, on_click=msg, variant~, width=w, height=34.0),
    )
  }
  let button_rows = empty_stage_button_rows(buttons, widths, width)
  let words = @views.column(
    [
      @views.text(
        text(t, "app.empty.title"),
        theme=studio_theme(),
        width=(text_estimate_width(text(t, "app.empty.title")) * 1.02 + 8.0).min(
          460.0,
        ),
        height=30.0,
      ).foreground(ide_text()),
      // 长引导句按宽折行（英文版 766pt，460pt 单行必溢出）。
      hint_lines_view(text(t, "app.empty.body"), 460.0, ide_text_faint(), 2),
      @views.column(button_rows, spacing=8.0, align=Center),
    ],
    spacing=12.0,
    align=Center,
  )
  // 引导语**居中**：空舞台不再有「hero 输入框升到上方」这回事——AI 输入条
  // 已改由底栏页签/右栏停靠承载，不再浮在中心列上，所以引导语不需要让位。
  // （历史：hero 态曾把引导语用定长前导 spacer 顶到上沿，避免与浮起的
  // 输入卡撞在一起。输入卡离开中心列后这段分支失去意义。）
  @views.container(
    @views.center(words, width~, height~),
    background=ide_editor_background(),
    width~,
    height~,
    padding=0.0,
  )
}

// ============================================================================
// 小工具
// ============================================================================

///|
/// 路径同一性：Array[Int] 没有结构相等（MoonBit 数组按引用比较），
/// 逐元素比对。
pub fn same_path(a : Array[Int], b : Array[Int]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let mut index = 0
  while index < a.length() {
    if a[index] != b[index] {
      return false
    }
    index = index + 1
  }
  true
}

///|
/// 路径副本：路径要进模型（消息载荷），必须拷贝——避免与
/// blocks 内部的临时数组共享可变引用。
pub fn clone_path(path : Array[Int]) -> Array[Int] {
  let copy : Array[Int] = []
  for value in path {
    copy.push(value)
  }
  copy
}

///|
/// 补全弹层（切片 H）：候选词胶囊行——点击插入并关闭。
/// 放在编辑面与说明条之间（不遮正文，不用弹层）。
fn completion_popup(model : Model, width : Double) -> @moui.View[Msg] {
  if !model.completion_open {
    return @views.text("", width=1.0, height=1.0)
  }
  let chips : Array[@moui.View[Msg]] = []
  for word in model.completions {
    let chip_width = (text_estimate_width(word) + 12.0).max(28.0)
    chips.push(
      @views.container(
        @views.center(
          @views.text(
            word,
            theme=studio_theme(),
            role=Mono,
            width=(chip_width - 4.0).max(20.0),
            height=16.0,
          ).foreground(ide_text()),
          width=chip_width,
          height=20.0,
        ),
        background=ide_accent_soft(),
        corner_radius=4.0,
        width=chip_width,
        height=22.0,
        padding=0.0,
      )
      .accessibility_label(word)
      .on_tap(ApplyCompletion(word)),
    )
  }
  @views.container(
    @views.padding_xy(
      @views.scroll_view(
        @views.row(chips, spacing=4.0, align=Center),
        width=(width - 16.0).max(80.0),
        height=26.0,
        shows_indicator=false,
      ),
      horizontal=8.0,
      vertical=3.0,
    ),
    background=ide_panel_alt(),
    width~,
    padding=0.0,
  )
}
