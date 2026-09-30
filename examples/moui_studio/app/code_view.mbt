///|
/// v4 IDE 代码工作区：行号 + 高亮 token + 行内联错误 + IR 行尺 + 脚注，
/// 以及空舞台。
///
/// 从 `workspace.mbt` 拆出（原文件 1162 行，逼近 1200 硬上限）。分工：
/// `workspace.mbt` 管窗格外壳与宽度分配（窗格头、分隔条、可视化工作区），
/// 本文件管**代码视图与空舞台**这两块内容渲染。
///
/// IR 是唯一事实来源——代码高亮只影响颜色，不产生第二份结构。

// ============================================================================
// 代码工作区
// ============================================================================

///|
/// 代码工作区：行号 + 高亮 token 行 + 行内联错误 + IR 行尺 + 脚注。
/// 只读渲染 + 下方纯文本编辑区：高亮是「读」的投影，编辑仍走 text_area
/// （避免自绘文本光标——core 没有文本命中/光标 API）。
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
  let head = pane_head(text(t, "app.pane.code"), handler_subtitle, width, [
    pill(
      if model.language is ZhHans {
        "MoonBit"
      } else {
        "MoonBit"
      },
      ide_text_faint(),
      66.0,
    ),
  ])
  let lines = code_lines(model)
  let spans = ir_line_spans(model)
  let rows : Array[@moui.View[Msg]] = []
  for line in lines {
    rows.push(code_line_row(model, line, spans, width - 2.0))
  }
  // 高度预算：头 30 + 错误条 + 代码区 + 说明条 30 + 脚注
  let code_height = (height - 180.0).max(100.0)
  let ruler = ir_ruler(model, t, spans, IR_RAIL_WIDTH, code_height)
  let error_bar = if model.code_error == "" {
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
  @views.container(
    @views.column(
      [
        head,
        error_bar,
        // 代码区与 IR 竖条**并排**（设计稿：竖条贴右缘、色块对齐代码行），
        // 不是上下堆叠。两者同高，行号→色块的对应关系才是空间上的。
        @views.row(
          [
            @views.scroll_view(
              @views.column(rows, spacing=0.0),
              width=(width - 2.0 - IR_RAIL_WIDTH).max(80.0),
              height=code_height,
              shows_indicator=true,
            ),
            ruler,
          ],
          spacing=0.0,
          align=Start,
        ).frame(width=width - 2.0, height=code_height),
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
/// 单行代码：行号槽（32pt）+ token 序列。
/// 命中 IR 高亮的行整行加暖色底——这是「IR → 代码」方向的可视提示。
fn code_line_row(
  model : Model,
  line : CodeLine,
  spans : Array[IrLineSpan],
  width : Double,
) -> @moui.View[Msg] {
  let span = ir_span_for_line(spans, line.number)
  let highlighted = span is Some(span) &&
    same_path(span.path, model.ir_highlight)
  // 悬停高亮：与点击高亮**取并集**，但用更轻的底色——点击是驻留选择，
  // 悬停是瞬态预览，两者视觉上要能区分开（设计稿 irHl 也是加一层 tl 边）。
  let hovered = match (span, model.hover_path) {
    (Some(span), Some(path)) => same_path(span.path, path)
    _ => false
  }
  let cells : Array[@moui.View[Msg]] = [
    @views.text(
      line.number.to_string(),
      theme=studio_theme(),
      role=Mono,
      width=32.0,
      height=20.0,
      align=TextEnd,
    ).foreground(
      // 行号是「这一行和某条 IR 语句有关系」最直接的指示器：点击与悬停
      // 都要点亮它，否则悬停整行只有底色变化、左缘的行号还是灰的，
      // 看上去像没反应（实测就是漏了 `hovered` 这一支）。
      if highlighted || hovered {
        ide_ir_highlight()
      } else {
        ide_text_faint()
      },
    ),
  ]
  if line.tokens.length() == 0 {
    // 空行保留行高（否则行号与内容错位）
    cells.push(@views.text("", width=(width - 44.0).max(20.0), height=20.0))
  } else {
    let token_views : Array[@moui.View[Msg]] = []
    for token in line.tokens {
      token_views.push(
        @views.text(
          token.text,
          theme=studio_theme(),
          role=Mono,
          width=token_width(token),
          height=20.0,
          align=TextStart,
        ).foreground(code_token_color(token.kind)),
      )
    }
    cells.push(@views.row(token_views, spacing=0.0, align=Center))
  }
  // 行必须显式钉宽：`row` 只量到子节点之和，容器（ContainerBox）会把
  // 「比容器窄」的子节点**居中**——表现是行号贴左、代码却飘在中间
  // （实测行号 x=205、代码 x=460）。这是本仓最常复发的布局陷阱。
  @views.container(
    @views.padding_edges(
      @views.row(cells, spacing=6.0, align=Center).frame(
        width=(width - 16.0).max(20.0),
      ),
      left=8.0,
      right=8.0,
    ),
    background=if highlighted {
      ide_selection()
    } else if hovered {
      ide_panel_alt()
    } else {
      ide_editor_background()
    },
    height=20.0,
    width~,
    padding=0.0,
  ).on_hover(active => {
    HoverIrPath(if active { span.map(span => span.path) } else { None })
  })
}

///|
/// token 宽度估算：等宽 13pt 的 ASCII 约 7.8px/字符，非 ASCII（中文）
/// 约 13px/字符。按字符类别分别计数——比统一乘系数更贴近实际，
/// 且不依赖字体度量（core 没有文本测量 API）。
fn token_width(token : CodeToken) -> Double {
  let mut ascii = 0
  let mut wide = 0
  for c in token.text {
    if c.to_int() < 0x80 {
      ascii = ascii + 1
    } else {
      wide = wide + 1
    }
  }
  let estimate = ascii.to_double() * 7.9 + wide.to_double() * 13.0
  estimate.max(6.0)
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
  t : @i18n.Translator,
  spans : Array[IrLineSpan],
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let line_count = code_lines(model).length()
  // 只画放得下的行：竖条不滚动，超出的部分本来也看不见。
  let visible = (height / IR_RAIL_LINE_HEIGHT).floor().to_int().min(line_count)
  let highlight = model.ir_highlight
  let cells : Array[@moui.View[Msg]] = []
  for line in 1..<=visible {
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
        let active = same_path(span.path, highlight) || hovered_bar
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
          background=if active {
            ide_ir_highlight()
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
  @views.container(
    @views.column(cells, spacing=0.0).frame(width=IR_RAIL_WIDTH, height~),
    background=ide_panel(),
    width=IR_RAIL_WIDTH,
    height~,
    padding=0.0,
  )
}

///|
/// IR 竖条宽度（设计稿 #irRuler 30pt）。
pub const IR_RAIL_WIDTH : Double = 30.0

///|
/// 竖条行高：与代码行高一致，色块才能和行对齐。
const IR_RAIL_LINE_HEIGHT : Double = 20.0

///|
/// 代码脚注：草稿编辑入口 + 恢复渲染 + 编译轨入口。
/// 编辑区放在脚注（可折起）而不是主区：高亮区是主体，
/// 编辑是低频动作，但必须可达（不能只读——那就成了预览不是编辑器）。
fn code_foot(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  @views.container(
    @views.padding_xy(
      @views.column(
        [
          @views.text_area(
            model.code_draft,
            on_input=source => EditCode(source),
            placeholder=text(t, "app.code.cheatsheet"),
            lines=3,
            width=(width - 20.0).max(80.0),
            line_height=20.0,
          ),
          code_foot_row(model, t, (width - 16.0).max(120.0)),
        ],
        spacing=6.0,
      ),
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
/// 代码页脚的动作行：草稿提示 + 恢复 + 编译。宽度按可用宽分配，
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
  let hint_w = (width - restore_w - compile_w - gap * 2.0).max(40.0)
  fill_row(
    [
      @views.text(
        text(t, "app.code.draft_hint"),
        theme=studio_theme(),
        width=hint_w,
        height=16.0,
        align=TextStart,
      ).foreground(ide_text_faint()),
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
  ).on_tap(on_click)
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
  // hero 时引导语**上移**：AI 输入框这时升到上方当主角，两者都居中会
  // 撞在一起（设计稿里 hero 卡直接盖住装饰性的「空 舞 台」字样，但本实现
  // 的引导语是**可点的入口**——三个模板按钮——被盖住就等于点了没反应）。
  // 用定长前导 spacer 顶到上沿，而不是按权重分配余量：权重份数随窗口
  // 高度变化，窄窗口会把引导语又推回卡片底下。
  let body = if ai_hero(model) {
    @views.container(
      @views.column(
        [
          @views.spacer(min_length=28.0, weight=0.0),
          words,
          @views.spacer(min_length=0.0, weight=1.0),
        ],
        spacing=0.0,
        align=Center,
      ).frame(width~, height~),
      background=ide_editor_background(),
      width~,
      height~,
      padding=0.0,
    )
  } else {
    @views.container(
      @views.center(words, width~, height~),
      background=ide_editor_background(),
      width~,
      height~,
      padding=0.0,
    )
  }
  body
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
