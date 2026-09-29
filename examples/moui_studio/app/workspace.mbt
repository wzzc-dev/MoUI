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
      icon_button(
        Focus,
        text(t, "app.pane.solo"),
        false,
        TogglePaneBlocks,
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
  @views.container(
    @views.padding_xy(
      fill_row(
        [
          @views.text(
            label,
            theme=studio_theme(),
            width=(width - 120.0).max(60.0),
            height=16.0,
            align=TextStart,
          ).foreground(ide_text_faint()),
          @views.spacer(min_length=4.0, weight=1.0),
          @views.text(
            text_with(t, "app.pane.foot_controls", [
              ("count", model.program.controls.length().to_string()),
            ]),
            theme=studio_theme(),
            role=Mono,
            width=90.0,
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
/// 积木窗格：分类条 + 积木画布 + 语句编辑条。
/// 分类条点分类滚动到该类首块（选中分类记忆在 model.selected_category）。
pub fn blocks_pane(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let handler_label = match current_handler(model) {
    None => text(t, "app.handler.none")
    Some(handler) =>
      "\{handler.control_name} . \{text(t, "event.\{handler.event.tag()}")}"
  }
  let head = pane_head(text(t, "app.pane.blocks"), handler_label, width, [
    icon_button(
      Columns,
      if model.pane_live {
        text(t, "app.pane.hide_live")
      } else {
        text(t, "app.pane.show_live")
      },
      model.pane_live,
      TogglePaneLive,
      24.0,
      22.0,
      13.0,
    ),
  ])
  let catbar = category_bar(model, t, width)
  let body = match current_handler(model) {
    None => empty_hint(text(t, "app.handler.none"), (height - 100.0).max(80.0))
    Some(handler) => {
      let blocks = @blocks.block_chain(handler.body)
      let display_texts : Array[String] = []
      for item in blocks {
        let label = text(t, @blocks.block_label_key(item.kind))
        display_texts.push(
          if item.text == "" {
            label
          } else {
            "\{label}  \{item.text}"
          },
        )
      }
      let rects = blocks_item_rects(blocks)
      let canvas_height = (rects.length().to_double() * BLOCK_ROW_HEIGHT + 24.0).max(
        120.0,
      )
      let spotlight = current_spotlight(model)
      @views.scroll_view(
        blocks_canvas(
          blocks,
          display_texts,
          model.selected_block,
          spotlight,
          model.block_drag,
          width - 2.0,
          canvas_height,
          text(t, "app.blocks.canvas"),
        ),
        width=width - 2.0,
        height=(height - 130.0).max(80.0),
        shows_indicator=true,
      )
    }
  }
  @views.container(
    @views.column(
      [head, catbar, body, block_editor_bar(model, t, width)],
      spacing=0.0,
    ).frame(width~, height~),
    background=ide_editor_background(),
    width~,
    height~,
    padding=0.0,
  )
}

///|
/// 积木分类条：5 个语义分类 + 「全部」。命中分类给出该分类首块下标，
/// 视图层只做高亮（滚动定位需要 viewport 反馈，当前 core 没有
/// 「滚到某偏移」的消息回环，所以这里诚实地只做选中态）。
pub fn category_bar(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let entries = block_category_entries(model)
  let chips : Array[@moui.View[Msg]] = [
    text_chip(
      text(t, "app.blocks.cat.all"),
      SelectBlockCategory(-1),
      52.0,
      model.selected_category < 0,
    ),
  ]
  let mut index = 0
  for entry in entries {
    let has_blocks = entry.first_index >= 0
    let label = text(t, block_category_label_key(entry.category))
    let selected = model.selected_category == index
    let chip = if has_blocks {
      text_chip(label, SelectBlockCategory(index), 62.0, selected)
    } else {
      // 无块分类：灰显不可点（诚实反映「本子程序没有这类块」）
      text_chip(label, SelectBlockCategory(index), 62.0, false)
    }
    chips.push(chip)
    index = index + 1
  }
  chips.push(@views.spacer(min_length=4.0, weight=1.0))
  @views.container(
    @views.padding_xy(
      fill_row(chips, (width - 16.0).max(80.0), 4.0, Center),
      horizontal=8.0,
      vertical=0.0,
    ),
    background=ide_panel(),
    height=30.0,
    width~,
    padding=0.0,
  )
}

///|
/// 积木编辑条：选中块的语句草稿 + 应用/删除（旧 blocks_panel 的编辑区，
/// 移入窗格脚注以把纵向空间还给画布）。
fn block_editor_bar(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let blocks = match current_handler(model) {
    None => ([] : Array[@blocks.BlockItem])
    Some(handler) => @blocks.block_chain(handler.body)
  }
  if model.selected_block < 0 || model.selected_block >= blocks.length() {
    return @views.container(
      @views.text(
        text(t, "app.blocks.reorder_hint"),
        theme=studio_theme(),
        width=(width - 20.0).max(60.0),
        height=26.0,
        align=TextStart,
      ).foreground(ide_text_faint()),
      background=ide_panel(),
      height=30.0,
      width~,
      padding=0.0,
    )
  }
  @views.container(
    @views.padding_xy(
      @views.row(
        [
          @views.text_area(
            model.block_draft,
            on_input=source => EditBlock(source),
            lines=1,
            width=(width - 190.0).max(80.0),
            line_height=24.0,
          ),
          @views.button(
            text(t, "app.block.apply"),
            on_click=CommitBlock,
            variant=Primary,
            width=64.0,
            height=26.0,
          ),
          @views.button(
            text(t, "app.block.delete"),
            on_click=DeleteBlock,
            variant=Outline,
            width=64.0,
            height=26.0,
          ),
        ],
        spacing=6.0,
        align=Center,
      ),
      horizontal=8.0,
      vertical=0.0,
    ),
    background=ide_panel(),
    height=34.0,
    width~,
    padding=0.0,
  )
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
  if !model.pane_blocks {
    return live_pane(model, t, width, height)
  }
  if !model.pane_live {
    return blocks_pane(model, t, width, height)
  }
  let live_width = (width * model.split_ratio).max(200.0)
  let rest = (width - live_width - 5.0).max(160.0)
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
  let ruler = ir_ruler(model, t, spans, width - 2.0)
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
        @views.scroll_view(
          @views.column(rows, spacing=0.0),
          width=width - 2.0,
          height=(height - 150.0).max(100.0),
          shows_indicator=true,
        ),
        ruler,
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
  let highlighted = ir_span_for_line(spans, line.number) is Some(span) &&
    same_path(span.path, model.ir_highlight)
  let cells : Array[@moui.View[Msg]] = [
    @views.text(
      line.number.to_string(),
      theme=studio_theme(),
      role=Mono,
      width=32.0,
      height=20.0,
      align=TextEnd,
    ).foreground(
      if highlighted {
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
  @views.container(
    @views.padding_edges(
      @views.row(cells, spacing=6.0, align=Center),
      left=8.0,
      right=8.0,
    ),
    background=if highlighted {
      ide_selection()
    } else {
      ide_editor_background()
    },
    height=20.0,
    width~,
    padding=0.0,
  )
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
/// IR 行尺：30pt 高的暖色条带，按映射区段画出每条语句占的行区间。
/// 点条带发 HighlightIrPath —— 「代码 → IR」方向；点击积木块发同一条消息
/// 即得反向高亮（两向共用 ir_highlight 一个状态）。
pub fn ir_ruler(
  model : Model,
  t : @i18n.Translator,
  spans : Array[IrLineSpan],
  width : Double,
) -> @moui.View[Msg] {
  let segments : Array[@moui.View[Msg]] = []
  if spans.length() == 0 {
    segments.push(
      @views.text(
        text(t, "app.code.ruler.empty"),
        theme=studio_theme(),
        width=(width - 20.0).max(80.0),
        height=18.0,
        align=TextStart,
      ).foreground(ide_text_faint()),
    )
  } else {
    for span in spans {
      let active = same_path(span.path, model.ir_highlight)
      let label = "\{span.first_line}–\{span.last_line}"
      let segment = @views.container(
        @views.center(
          @views.text(
            label,
            theme=studio_theme(),
            role=Mono,
            width=42.0,
            height=16.0,
          ).foreground(
            if active {
              ide_editor_background()
            } else {
              ide_ir_highlight()
            },
          ),
          width=50.0,
          height=20.0,
        ),
        background=if active { ide_ir_highlight() } else { ide_panel_alt() },
        corner_radius=3.0,
        width=50.0,
        height=20.0,
        padding=0.0,
      )
      segments.push(segment.on_tap(HighlightIrPath(clone_path(span.path))))
    }
  }
  @views.container(
    @views.padding_xy(
      @views.row(segments, spacing=4.0, align=Center),
      horizontal=8.0,
      vertical=0.0,
    ),
    background=ide_panel(),
    height=30.0,
    width~,
    padding=0.0,
  )
}

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
          @views.row(
            [
              @views.text(
                text(t, "app.code.draft_hint"),
                theme=studio_theme(),
                width=(width - 240.0).max(60.0),
                height=16.0,
                align=TextStart,
              ).foreground(ide_text_faint()),
              @views.button(
                text(t, "app.code.restore"),
                on_click=RestoreCodeDraft,
                variant=Outline,
                width=84.0,
                height=26.0,
              ),
              @views.button(
                text(t, "app.code.compile"),
                on_click=CompileRun,
                variant=Tonal,
                width=96.0,
                height=26.0,
              ),
            ],
            spacing=6.0,
            align=Center,
          ),
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
