///|
/// v4 IDE 中心工作区：可视化工作区（Live App 窗格 + 分隔条 + 积木窗格）/
/// 代码工作区（行号 + 高亮 + IR 行尺）/ 空舞台（新建入口）。
///
/// 与旧 center_panel 的分工：旧按 Mode 单一取视图；这里按 WorkSpace 编排
/// 多窗格，运行/帮助/预览三个全屏页仍走旧视图（它们是执行/只读场景）。
/// IR 是唯一事实来源——积木与代码都是投影，代码高亮只影响颜色。

// ============================================================================
// 可视化工作区
// ============================================================================

///|
/// Live App 窗格：设计舞台 / 运行舞台。宽度由 split_ratio 决定，
/// 舞台本身按帧等比缩放（与旧设计视图同一构造，外观零漂移）。
pub fn live_pane(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let head = pane_head(
    text(t, "app.pane.live"),
    if app_running(model) {
      text(t, "app.pane.live.running")
    } else {
      text(t, "app.pane.live.idle")
    },
    width,
    [
      // 「运行中 · N%」：设计稿 runBadge。百分比就是舞台的适应比例——
      // 它是「现在看到的是缩略还是原尺寸」的唯一读数（fit_scale 算得）。
      if app_running(model) {
        run_badge(model, t, width, height)
      } else {
        @views.text("", width=1.0, height=1.0)
      },
      icon_button(
        Focus,
        text(t, "app.pane.solo"),
        false,
        TogglePaneBlocks,
        24.0,
        22.0,
        13.0,
      ),
      // 设计稿每个窗格头都有「隐藏此窗格」（#btnHideLive / #btnHideBlocks）
      icon_button(
        Close,
        text(t, "app.pane.hide"),
        false,
        TogglePaneLive,
        24.0,
        22.0,
        13.0,
      ),
    ],
  )
  // 舞台：运行中显示运行态（解释轨），否则显示设计态。
  let stage = match current_track(model) {
    Interpret =>
      match model.run {
        Some(run) =>
          run_stage(
            model,
            run.state.texts,
            run.checks,
            run.state.rows,
            run.state.selections,
            width - 2.0,
            height - 62.0,
          )
        None => design_stage_view(model, t)
      }
    Compile =>
      match model.compiled_run {
        Some(run) =>
          run_stage(
            model,
            run.runtime.texts,
            run.checks,
            run.runtime.rows,
            run.runtime.selections,
            width - 2.0,
            height - 62.0,
          )
        None => design_stage_view(model, t)
      }
  }
  @views.container(
    // 列必须显式定尺：内容总高小于容器时容器盒会把整列**居中**，
    // 窗格头就会掉到中间（曾经的「标题浮在半空」现象）。
    @views.column(
      [
        head,
        @views.container(
          @views.center(stage, width=width - 2.0, height=height - 62.0),
          background=ide_editor_background(),
          height=height - 62.0,
          width~,
          padding=0.0,
        ),
        pane_foot(model, t, width),
      ],
      spacing=0.0,
    ).frame(width~, height~),
    background=ide_panel(),
    width~,
    height~,
    padding=0.0,
  )
}

///|
/// 设计舞台视图（可视化工作区的默认面）：缩放工具条 + 画布。
/// 与旧设计模式同源——只不过这里是窗格而非整列。
fn design_stage_view(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  let stage_widgets : Array[@moui.View[Msg]] = []
  let stage_rects : Array[@geometry.Rect] = []
  for control in model.program.controls {
    stage_widgets.push(
      form_widget(control, control.text, false, control.items, -1),
    )
    stage_rects.push(
      @geometry.Rect::new(
        x=control.x.to_double(),
        y=control.y.to_double(),
        width=control.width.to_double(),
        height=control.height.to_double(),
      ),
    )
  }
  design_stage(
    model.program,
    model.selected_control,
    match model.drag {
      Some(drag) => Some(drag.control)
      None => None
    },
    stage_widgets,
    stage_rects,
    text(t, "app.design.canvas"),
    text(t, "app.design.empty"),
  )
}

///|
/// 窗格头：标题 + 状态副标题 + 右侧动作（30pt 高）。
pub fn pane_head(
  title : String,
  subtitle : String,
  width : Double,
  trailing : Array[@moui.View[Msg]],
) -> @moui.View[Msg] {
  let cells : Array[@moui.View[Msg]] = [
    @views.text(
      title,
      theme=studio_theme(),
      width=90.0,
      height=18.0,
      align=TextStart,
    ).foreground(ide_text()),
    @views.text(
      subtitle,
      theme=studio_theme(),
      width=120.0,
      height=16.0,
      align=TextStart,
    ).foreground(ide_text_faint()),
    @views.spacer(min_length=4.0, weight=1.0),
  ]
  for item in trailing {
    cells.push(item)
  }
  @views.container(
    @views.padding_xy(
      fill_row(cells, (width - 16.0).max(80.0), 6.0, Center),
      horizontal=8.0,
      vertical=0.0,
    ),
    background=ide_panel_alt(),
    height=PANEL_HEAD_HEIGHT,
    width~,
    padding=0.0,
  )
}

///|
/// 「运行中 · N%」徽标（设计稿 `#runBadge`）：绿点 + 单行读数。
/// 百分比是舞台当前的适应比例——`fit_scale` 同一个来源，不另算一份。
fn run_badge(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let live_width = (width * model.split_ratio).max(200.0)
  let percent = (fit_scale(
    live_width - 2.0,
    height - 62.0,
    @ir.DESIGN_WIDTH.to_double(),
    @ir.DESIGN_HEIGHT.to_double(),
  ) *
  100.0).round()
  @views.container(
    @views.padding_xy(
      @views.row(
        [
          @views.container(
            @views.text("", width=1.0, height=1.0),
            background=ide_success(),
            corner_radius=3.0,
            width=6.0,
            height=6.0,
            padding=0.0,
          ),
          @views.text(
            text_with(t, "app.pane.live.badge", [
              ("percent", percent.to_int().to_string()),
            ]),
            theme=studio_theme(),
            role=Mono,
            width=84.0,
            height=16.0,
            align=TextStart,
          ).foreground(ide_success()),
        ],
        spacing=5.0,
        align=Center,
      ),
      horizontal=8.0,
      vertical=0.0,
    ),
    background=ide_success_soft(),
    corner_radius=9.0,
    height=18.0,
    padding=0.0,
  )
}

///|
/// 可视化工作区脚注：当前子程序 + 事件标签（设计稿的 foot 行）。
pub fn pane_foot(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let label = match current_handler(model) {
    None => text(t, "app.handler.none")
    Some(handler) =>
      "\{handler.control_name} . \{text(t, "event.\{handler.event.tag()}")}"
  }
  // 右侧计数按**文字实测宽**给：写死 90 会把「2 个控件」截掉（实测需要 102）。
  let count_label = text_with(t, "app.pane.foot_controls", [
    ("count", model.program.controls.length().to_string()),
  ])
  let count_w = text_estimate_width(count_label) + 6.0
  @views.container(
    @views.padding_xy(
      fill_row(
        [
          @views.text(
            label,
            theme=studio_theme(),
            width=(width - count_w - 30.0).max(60.0),
            height=16.0,
            align=TextStart,
          ).foreground(ide_text_faint()),
          @views.spacer(min_length=4.0, weight=1.0),
          @views.text(
            count_label,
            theme=studio_theme(),
            role=Mono,
            width=count_w,
            height=16.0,
            align=TextEnd,
          ).foreground(ide_text_faint()),
        ],
        (width - 16.0).max(80.0),
        6.0,
        Center,
      ),
      horizontal=8.0,
      vertical=0.0,
    ),
    background=ide_panel(),
    height=24.0,
    width~,
    padding=0.0,
  )
}

///|
/// 单窗格恢复带高度（设计稿 `.addbtn` 所在那一行）。
pub const RESTORE_STRIP_HEIGHT : Double = 28.0

///|
/// 单窗格布局 + 顶部「+ 另一个窗格」恢复带。
///
/// 判据：`pane` 占满剩余高度；恢复带贴顶。带内只有一个按钮，文案是
/// **被隐藏的那个窗格**的名字（点它就把那个窗格加回来）。
fn single_pane_with_restore(
  pane : @moui.View[Msg],
  label : String,
  on_click : Msg,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let label_width = (text_estimate_width(label) * 1.05 + 20.0).min(
    (width - 40.0).max(60.0),
  )
  let restore = @views.container(
    fill_row(
      [
        @views.container(
          @views.center(
            @views.text(
              label,
              theme=studio_theme(),
              width=(label_width - 16.0).max(40.0),
              height=18.0,
              align=TextCenter,
            ).foreground(ide_text_muted()),
            width=label_width,
            height=22.0,
          ),
          background=ide_panel_alt(),
          corner_radius=4.0,
          width=label_width,
          height=22.0,
          padding=0.0,
        ).on_tap(on_click),
      ],
      (width - 16.0).max(60.0),
      6.0,
      Start,
    ),
    background=ide_panel(),
    height=RESTORE_STRIP_HEIGHT,
    width~,
    padding=0.0,
  )
  @views.column([restore, pane], spacing=0.0).frame(width~, height~)
}

///|
/// 可视化工作区：Live App 窗格 + 5pt 分隔条 + 积木窗格。
/// 分隔条用 on_drag_with_frame 换算成比例（0.2–0.8，update 侧钳制）。
pub fn visual_workspace(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  if !model.pane_live && !model.pane_blocks {
    return empty_stage(model, t, width, height)
  }
  // 单窗格：占满中心列，**并在顶部给一条恢复入口**。
  //
  // 设计稿的 `#btnAddLive`/`#btnAddBlocks` 就是干这个的：隐藏窗格之后必须
  // 还能把它加回来，否则「隐藏」等于永久丢失（只能去设置里找，或者重开）。
  // 这条恢复带只在**恰好剩一个窗格**时出现——两个都在时它没有意义。
  if !model.pane_blocks {
    return single_pane_with_restore(
      live_pane(model, t, width, (height - RESTORE_STRIP_HEIGHT).max(80.0)),
      text(t, "app.pane.show_blocks"),
      TogglePaneBlocks,
      t,
      width,
      height,
    )
  }
  if !model.pane_live {
    return single_pane_with_restore(
      blocks_pane(model, t, width, (height - RESTORE_STRIP_HEIGHT).max(80.0)),
      text(t, "app.pane.show_live"),
      TogglePaneLive,
      t,
      width,
      height,
    )
  }
  // 双窗格有最小可用宽度：640 设计宽按 fit_scale 的 0.5 下限缩放后仍需
  // ~320pt 才放得下，积木画布同理。中心列窄到放不下两个窗格时**只显示
  // Live App**——把积木窗格压到 160pt 只会让里面的积木文字被裁掉
  // （实测 w=900 时积木窗格 160pt、块内文字 410pt 宽被切）。
  let live_min = 320.0
  let blocks_min = 240.0
  let gap = 5.0
  if width < live_min + blocks_min + gap {
    return live_pane(model, t, width, height)
  }
  // 占比也要钳：拖拽后任一侧都不得小于各自下限。
  let max_live = width - blocks_min - gap
  let live_width = (width * model.split_ratio).max(live_min).min(max_live)
  let rest = (width - live_width - gap).max(blocks_min)
  @views.row(
    [
      live_pane(model, t, live_width, height),
      splitter(live_width, width),
      blocks_pane(model, t, rest, height),
    ],
    spacing=0.0,
    align=Start,
  ).frame(width~, height~)
}

///|
/// 分隔条：5pt 竖条，拖拽改 Live App 窗格占比。
/// 拖拽起点用 history 无关的绝对换算——on_drag_with_frame 给全局坐标，
/// 减去行原点即得窗格内 x；除以总宽得比例。
pub fn splitter(live_width : Double, total_width : Double) -> @moui.View[Msg] {
  let base = @views.container(
    @views.center(
      @views.text("", width=1.0, height=24.0),
      width=5.0,
      height=24.0,
    ),
    background=ide_panel(),
    width=5.0,
    height=600.0,
    padding=0.0,
  )
  let _ = live_width
  base.on_drag_with_frame(fn(event, frame) {
    let _ = event
    // 拖到哪算哪：全局 x − 帧原点 = 该点在行内的 x
    SetSplitRatio((event.position.x - frame.origin.x) / total_width)
  })
}

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
            text(t, "app.code.foot_hint"),
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
pub fn empty_stage(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let buttons : Array[@moui.View[Msg]] = [
    @views.button(
      text(t, "app.empty.hello"),
      on_click=SelectTemplate(0),
      variant=Primary,
      width=150.0,
      height=34.0,
    ),
    @views.button(
      text(t, "app.empty.roll_call"),
      on_click=SelectTemplate(1),
      variant=Tonal,
      width=150.0,
      height=34.0,
    ),
    @views.button(
      text(t, "app.empty.open"),
      on_click=OpenRequested,
      variant=Outline,
      width=150.0,
      height=34.0,
    ),
  ]
  let words = @views.column(
    [
      @views.text(
        text(t, "app.empty.title"),
        theme=studio_theme(),
        width=420.0,
        height=30.0,
      ).foreground(ide_text()),
      @views.text(
        text(t, "app.empty.body"),
        theme=studio_theme(),
        width=460.0,
        height=22.0,
      ).foreground(ide_text_faint()),
      @views.row(buttons, spacing=10.0, align=Center),
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
