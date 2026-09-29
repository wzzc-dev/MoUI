///|
/// v4 IDE 壳装配：顶栏 40 / 图标栏 48 / 左栏 / 中心工作区 / 右栏 /
/// 底栏（审计 + Console）/ 状态栏 / AI 浮动层 / 对话框与 toast。
///
/// 布局纪律（三条硬约束，都是踩过的坑）：
/// 1. row 里的竖直分隔线必须显式 axis=Vertical——横线按可用宽度测量，
///    会盖住后面的兄弟（2026-09-27 面板消失事故）。
/// 2. 含分隔线的行必须钳高（.frame(height=…)）——竖直分隔线按可用高度
///    测量，不钳会把行撑到窗口高。
/// 3. 交互画布子树不用 .flexible()——加权子树的指针派发会在 tight 重排
///    下丢手势；用显式 .frame(height=…) 换空间。

// ============================================================================
// 顶栏（40pt 单行）
// ============================================================================

///|
/// 顶栏：品牌 + 面包屑 | 运行/单步/编译 | 语言 | 命令面板 | 设置。
/// 单行 40pt——设计稿口径；内容超出由窗口最小宽度承担（1280 起）。
pub fn ide_top_bar(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let running = app_running(model)
  let crumb = match model.workspace {
    WsVisual => text(t, "app.crumb.visual")
    WsCode => "\{text(t, "app.crumb.code")} › \{handler_crumb(model)}"
    WsEmpty => text(t, "app.crumb.empty")
  }
  let left = topbar_brand(text(t, "app.title"), model.dirty, crumb)
  let right : Array[@moui.View[Msg]] = [
    // 运行/停止：运行中变停止（同一键位的心智：它是「运行」的总闸）
    @views.button(
      if running {
        text(t, "app.run.stop")
      } else {
        text(t, "app.run.start")
      },
      on_click=if running { RunStop } else { RunStart },
      variant=if running { Outline } else { Primary },
      width=76.0,
      height=26.0,
    ),
    // 单步：仅在活运行（含闸门暂停）时可用——编译轨不支持单步，
    // 按钮仍显示但禁用（诚实反映「本轨没有单步」而不是藏起来）
    if running && current_track(model) is Interpret {
      @views.button(
        text(t, "app.run.step"),
        on_click=RunStep,
        variant=Outline,
        width=68.0,
        height=26.0,
      )
    } else {
      @views.button(
        text(t, "app.run.step"),
        variant=Outline,
        width=68.0,
        height=26.0,
      )
    },
    @views.button(
      text(t, "app.topbar.compile"),
      on_click=CompileRun,
      variant=Outline,
      width=104.0,
      height=26.0,
    ),
    pill(
      if model.language is ZhHans {
        "中"
      } else {
        "EN"
      },
      ide_text_muted(),
      34.0,
    ),
    icon_button(
      Search,
      text(t, "app.command.open"),
      false,
      CommandPaletteOpen,
      28.0,
      26.0,
      14.0,
    ),
    icon_button(
      Settings,
      text(t, "app.settings.title"),
      model.settings_open,
      ToggleSettings,
      28.0,
      26.0,
      14.0,
    ),
  ]
  // 内垫 10/10 → 内部行宽 = width − 20；行必须显式定宽，
  // 否则权重 spacer 拿不到 slack，顶栏内容会挤在中间（见 fill_row 注释）。
  @views.container(
    @views.padding_edges(
      fill_row(
        [
          left,
          @views.spacer(min_length=8.0, weight=1.0),
          @views.row(right, spacing=6.0, align=Center),
        ],
        (width - 20.0).max(120.0),
        8.0,
        Center,
      ),
      left=10.0,
      right=10.0,
    ),
    background=ide_panel(),
    width~,
    height=TOPBAR_HEIGHT,
    padding=0.0,
  )
}

///|
/// 面包屑尾段：当前子程序（控件.事件）。
fn handler_crumb(model : Model) -> String {
  match current_handler(model) {
    None => "—"
    Some(handler) => "\{handler.control_name}.\{handler.event.tag()}"
  }
}

// ============================================================================
// 图标栏（48pt）
// ============================================================================

///|
/// 图标栏：可视化 / 代码 | 树 / 数据 | AI | 设置。
/// 点当前项 = 收起（工作区进空舞台、左栏收起），与设计稿 setLeft/setWS 同语义。
pub fn ide_icon_bar(
  model : Model,
  t : @i18n.Translator,
  height : Double,
) -> @moui.View[Msg] {
  let items : Array[@moui.View[Msg]] = [
    icon_button(
      Eye,
      text(t, "app.ws.visual"),
      model.workspace is WsVisual,
      SetWorkSpace(WsVisual),
      40.0,
      36.0,
      17.0,
    ),
    icon_button(
      CodeInline,
      text(t, "app.ws.code"),
      model.workspace is WsCode,
      SetWorkSpace(WsCode),
      40.0,
      36.0,
      17.0,
    ),
    // 分隔线在 column 里必须是横线：竖线按「可用高度」测量，放进列里会
    // 量到整列高并盖住后面的兄弟（与 row 里必须用竖线是同一条约定）。
    @views.divider(thickness=1.0, color=ide_border(), inset=8.0),
    icon_button(
      Sidebar,
      text(t, "app.left.tree"),
      model.left_view is LeftTree,
      SetLeftView(LeftTree),
      40.0,
      36.0,
      17.0,
    ),
    icon_button(
      Table,
      text(t, "app.left.data"),
      model.left_view is LeftData,
      SetLeftView(LeftData),
      40.0,
      36.0,
      17.0,
    ),
    icon_button(
      Focus,
      text(t, "app.ai.title"),
      model.ai_anchor is AiDocked && !model.ai_pill,
      CycleAiAnchor,
      40.0,
      36.0,
      17.0,
    ),
    @views.spacer(min_length=4.0, weight=1.0),
    @views.divider(thickness=1.0, color=ide_border(), inset=8.0),
    icon_button(
      Settings,
      text(t, "app.settings.title"),
      model.settings_open,
      ToggleSettings,
      40.0,
      36.0,
      17.0,
    ),
  ]
  @views.container(
    // 列必须显式定宽高：权重 spacer 只有在确定了主轴尺寸后才拿得到 slack。
    @views.column(items, spacing=4.0, align=Center).frame(
      width=ICONBAR_WIDTH,
      height~,
    ),
    background=ide_panel(),
    width=ICONBAR_WIDTH,
    height~,
    padding=0.0,
  )
}

// ============================================================================
// 左栏
// ============================================================================

///|
/// 左栏：搜索 + 结构树（或本地数据）+ 底部（最近修改 + 快速插入）。
pub fn ide_left_panel(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let head = panel_head(
    if model.left_view is LeftData {
      text(t, "app.left.data")
    } else {
      text(t, "app.left.tree")
    },
    "",
    [
      icon_button(
        Close,
        text(t, "app.left.hide"),
        false,
        SetLeftView(LeftHidden),
        22.0,
        20.0,
        11.0,
      ),
    ],
    width,
  )
  let search = @views.container(
    @views.padding_xy(
      @views.text_field(
        model.tree_query,
        on_input=query => SetTreeQuery(query),
        placeholder=text(t, "app.left.search"),
        variant=Outline,
        width=(width - 16.0).max(80.0),
        height=FIELD_HEIGHT,
      ),
      horizontal=8.0,
      vertical=4.0,
    ),
    background=ide_panel(),
    width~,
    padding=0.0,
  )
  // 高度预算：头 + 搜索 + 底部条（高度由内容算，见 bottom_strip_height），
  // 其余全给结构树。底部块必须显式定高——不定高的子树会按内容一路长高，
  // 把结构树挤没。
  let strip_height = bottom_strip_height(model)
  let body_height = (height - PANEL_HEAD_HEIGHT - 34.0 - strip_height).max(
    120.0,
  )
  let body = if model.left_view is LeftData {
    data_view(model, t, width, body_height)
  } else {
    tree_view_ide(model, t, width, body_height)
  }
  @views.container(
    @views.column(
      [
        head,
        search,
        body,
        @views.container(
          bottom_strip(model, t, width),
          width~,
          height=strip_height,
          padding=0.0,
        ),
      ],
      spacing=0.0,
    ),
    background=ide_panel(),
    width~,
    height~,
    padding=0.0,
  )
}

///|
/// 程序结构树：分组头 + 行。搜索非空时全部展开。
fn tree_view_ide(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let nodes = program_tree(model)
  let groups = visible_groups(nodes)
  let rows : Array[@moui.View[Msg]] = []
  for group in groups {
    let children = group_children(nodes, group)
    let expanded = tree_group_expanded(model, group)
    rows.push(
      tree_row(
        text(t, tree_group_label_key(group)),
        children.length().to_string(),
        0,
        false,
        children.length() > 0,
        expanded,
        None,
        Some(ToggleTreeGroup(group)),
        width,
      ),
    )
    if expanded {
      for child in children {
        rows.push(tree_node_row(model, child, width))
      }
    }
  }
  if rows.length() == 0 {
    return empty_hint(text(t, "app.left.no_match"), height)
  }
  // 结构树按内容自适应高度，超出交给滚动容器（避免行被压扁）
  @views.scroll_view(
    @views.column(rows, spacing=0.0),
    width~,
    height~,
    shows_indicator=true,
  )
}

///|
/// 单个树节点行 → 消息映射（视图层把 kind 收成 typed Msg）。
fn tree_node_row(
  model : Model,
  node : TreeNode,
  width : Double,
) -> @moui.View[Msg] {
  let selected = match node.kind {
    TnControl => model.selected_control == node.select_key
    TnHandler => model.selected_handler == node.select_key
    _ => false
  }
  let on_click = match node.kind {
    TnControl => Some(SelectControl(node.select_key))
    TnHandler => Some(SelectHandler(node.select_key))
    _ => None
  }
  ignore(model)
  tree_row(
    node.label,
    node.meta,
    node.depth,
    selected,
    false,
    false,
    on_click,
    None,
    width,
  )
}

///|
/// 本地数据视图：文件列表 + 选中预览（只读）。
/// 条目来自程序里的列表/表格控件与变量——不是假文件系统。
fn data_view(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let files = data_file_entries(model)
  if files.length() == 0 {
    return empty_hint(text(t, "app.data.none"), height)
  }
  let rows : Array[@moui.View[Msg]] = []
  for file in files {
    rows.push(
      @views.container(
        @views.padding_edges(
          @views.column(
            [
              @views.row(
                [
                  @views.text(
                    file.name,
                    theme=studio_theme(),
                    width=(width - 100.0).max(60.0),
                    height=18.0,
                    align=TextStart,
                  ).foreground(ide_text()),
                  @views.text(
                    if file.locked {
                      text(t, "app.data.readonly")
                    } else {
                      text(t, "app.data.live")
                    },
                    theme=studio_theme(),
                    width=56.0,
                    height=16.0,
                    align=TextEnd,
                  ).foreground(
                    if file.locked {
                      ide_warning()
                    } else {
                      ide_success()
                    },
                  ),
                ],
                spacing=4.0,
                align=Center,
              ),
              @views.text(
                file.meta,
                theme=studio_theme(),
                role=Mono,
                width=(width - 24.0).max(60.0),
                height=16.0,
                align=TextStart,
              ).foreground(ide_text_faint()),
              @views.text(
                if file.preview == "app.data.empty" {
                  text(t, "app.data.empty")
                } else {
                  file.preview
                },
                theme=studio_theme(),
                role=Mono,
                width=(width - 24.0).max(60.0),
                height=(preview_height(file.preview).to_double() * 16.0).max(
                  16.0,
                ),
                align=TextStart,
              ).foreground(code_plain_color()),
            ],
            spacing=2.0,
          ),
          left=8.0,
          right=8.0,
          top=6.0,
          bottom=6.0,
        ),
        background=ide_panel(),
        width~,
        padding=0.0,
      ),
    )
  }
  @views.scroll_view(
    @views.column(rows, spacing=0.0),
    width~,
    height~,
    shows_indicator=true,
  )
}

///|
/// 预览行数：按换行数估算（限制 8 行以内，避免一块数据吃掉整个左栏）。
fn preview_height(preview : String) -> Int {
  let mut lines = 1
  for c in preview {
    if c == '\n' {
      lines = lines + 1
    }
  }
  lines.min(8)
}

///|
/// 左栏底部：最近修改列表 + 快速插入按钮组。

///|
/// 底部条的高度是**内容决定**的：最近修改行数可变，写死高度不是裁掉
/// 最后一行就是把面板撑破。左右两条（最近修改 + 快速插入）都定高。
pub fn bottom_strip_height(model : Model) -> Double {
  let rows = recent_tail(model.recent_changes, RECENT_STRIP_ROWS).length()
  let row_count = if rows == 0 { 1 } else { rows }
  PANEL_HEAD_HEIGHT +
  row_count.to_double() * TREE_ROW_HEIGHT +
  PANEL_HEAD_HEIGHT +
  2.0 * 26.0 +
  4.0 +
  8.0
}

///|
fn bottom_strip(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let header = panel_head(text(t, "app.recent.title"), "", [], width)
  let rows : Array[@moui.View[Msg]] = []
  let recent = recent_tail(model.recent_changes, RECENT_STRIP_ROWS)
  if recent.length() == 0 {
    rows.push(
      @views.container(
        @views.padding_edges(
          @views.text(
            text(t, "app.recent.empty"),
            theme=studio_theme(),
            width=(width - 20.0).max(60.0),
            height=18.0,
            align=TextStart,
          ).foreground(ide_text_faint()),
          left=8.0,
          right=8.0,
        ),
        height=TREE_ROW_HEIGHT,
        width~,
        padding=0.0,
      ),
    )
  } else {
    for change in recent {
      rows.push(
        @views.container(
          @views.padding_edges(
            @views.row(
              [
                @views.text(
                  change.target,
                  theme=studio_theme(),
                  width=64.0,
                  height=18.0,
                  align=TextStart,
                ).foreground(ide_text()),
                @views.text(
                  actor_label(t, change.by_agent),
                  theme=studio_theme(),
                  width=38.0,
                  height=18.0,
                  align=TextStart,
                ).foreground(
                  if change.by_agent {
                    ide_accent()
                  } else {
                    ide_text_faint()
                  },
                ),
                @views.text(
                  text(t, change.action),
                  theme=studio_theme(),
                  width=(width - 128.0).max(40.0),
                  height=18.0,
                  align=TextStart,
                ).foreground(ide_text_muted()),
              ],
              spacing=4.0,
              align=Center,
            ),
            left=8.0,
            right=8.0,
          ),
          height=TREE_ROW_HEIGHT,
          width~,
          padding=0.0,
        ),
      )
    }
  }
  // 快速插入：选中控件为空时这四个按钮是唯一的「从零开始」通道，
  // 所以恒显示（不做选中态判断），点击即 AddControl（落到默认槽位）。
  let insert_head = panel_head(text(t, "app.insert.title"), "", [], width)
  let inserts : Array[@moui.View[Msg]] = [
    quick_insert(t, @ir.Button, "control.button", width),
    quick_insert(t, @ir.Label, "control.label", width),
    quick_insert(t, @ir.ListBox, "control.list_box", width),
    quick_insert(t, @ir.TextField, "control.text_field", width),
  ]
  let strip_height = bottom_strip_height(model)
  @views.container(
    @views.column(
      [
        header,
        @views.column(rows, spacing=0.0),
        insert_head,
        @views.padding_xy(
          @views.grid(inserts, columns=2, row_spacing=4.0, column_spacing=4.0),
          horizontal=8.0,
          vertical=4.0,
        ),
      ],
      spacing=0.0,
    ).frame(width~, height=strip_height),
    background=ide_panel(),
    width~,
    height=strip_height,
    padding=0.0,
  )
}

///|
fn actor_label(t : @i18n.Translator, by_agent : Bool) -> String {
  if by_agent {
    text(t, "app.recent.agent")
  } else {
    text(t, "app.recent.you")
  }
}

///|
/// 最近修改尾部 N 条（新的在下——设计稿是最近在最上，取尾部后反转）。
fn recent_tail(
  changes : Array[RecentChange],
  count : Int,
) -> Array[RecentChange] {
  let tail : Array[RecentChange] = []
  let mut index = changes.length() - 1
  while index >= 0 && tail.length() < count {
    tail.push(changes[index])
    index = index - 1
  }
  tail
}

///|
fn quick_insert(
  t : @i18n.Translator,
  kind : @ir.ControlKind,
  key : String,
  width : Double,
) -> @moui.View[Msg] {
  // 手搓而不用 @views.button：button 的 `height` 进的是 `min_size`，
  // 真实高度 = max(min_size.height, 文本高 + spacing_scale.sm × 2)，
  // 所以 height=26 会渲染成 36，把底部的「快速插入」两行挤出面板下缘
  // （与右栏「快速操作」同一个坑，那里也是手搓的）。
  let cell_width = (width - 22.0) / 2.0
  // 「+ 按钮」而不是「按钮」：这排按钮的语义是**插入动作**，不是分类标签
  // （设计稿 #qaRow 的 .qabtn 同样带前缀）。前缀走 i18n，不写死 '+ '。
  let label = text_with(t, "app.insert.chip", [("name", text(t, key))])
  @views.container(
    @views.center(
      @views.text(
        label,
        theme=studio_theme(),
        width=(cell_width - 10.0).max(20.0),
        height=16.0,
      ).foreground(ide_accent()),
      width=cell_width,
      height=26.0,
    ),
    background=ide_panel_alt(),
    corner_radius=4.0,
    width=cell_width,
    height=26.0,
    padding=0.0,
  ).on_tap(AddControl(kind))
}

// ============================================================================
// 底栏（审计 + Console）
// ============================================================================

///|
/// 底栏：拖动条 + 页签头 + 面板体。收起时只剩 26pt 页签头。
pub fn ide_bottom_bar(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let pending = pending_side_effects(model)
  let errors = audit_error_count(model)
  let head_cells : Array[@moui.View[Msg]] = [
    tab_button(
      text(t, "app.bottom.audit"),
      model.bottom_audit,
      SetBottomTab(true),
      pending,
    ),
    tab_button(
      text(t, "app.bottom.console"),
      !model.bottom_audit,
      SetBottomTab(false),
      model.log_lines.length(),
    ),
    @views.spacer(min_length=6.0, weight=1.0),
  ]
  if model.bottom_audit && pending > 0 {
    head_cells.push(
      @views.button(
        text(t, "app.audit.confirm_all"),
        on_click=AuditSettleAll("app.audit.confirmed"),
        variant=Tonal,
        width=110.0,
        height=22.0,
      ),
    )
  }
  if !model.bottom_audit {
    head_cells.push(
      @views.button(
        text(t, "app.console.clear"),
        on_click=ClearConsole,
        variant=Ghost,
        width=64.0,
        height=22.0,
      ),
    )
  }
  head_cells.push(
    pill(
      if errors > 0 {
        "\{errors}"
      } else {
        "0"
      },
      if errors > 0 {
        ide_danger()
      } else {
        ide_success()
      },
      30.0,
    ),
  )
  head_cells.push(
    icon_button(
      if model.bottom_open {
        ChevronDown
      } else {
        ChevronRight
      },
      if model.bottom_open {
        text(t, "app.bottom.collapse")
      } else {
        text(t, "app.bottom.expand")
      },
      model.bottom_open,
      ToggleBottom,
      22.0,
      22.0,
      12.0,
    ),
  )
  let head = @views.container(
    @views.padding_xy(
      fill_row(head_cells, (width - 16.0).max(120.0), 6.0, Center),
      horizontal=8.0,
      vertical=0.0,
    ),
    background=ide_panel_alt(),
    height=PANEL_HEAD_HEIGHT,
    width~,
    padding=0.0,
  )
  if !model.bottom_open {
    return @views.container(
      @views.column([hairline(), head], spacing=0.0),
      background=ide_panel(),
      width~,
      padding=0.0,
    )
  }
  let body = if model.bottom_audit {
    audit_pane(model, t, width, model.bottom_height - 30.0)
  } else {
    console_pane(model, t, width, model.bottom_height - 30.0)
  }
  @views.container(
    @views.column([hairline(), head, body], spacing=0.0),
    background=ide_panel(),
    width~,
    padding=0.0,
  )
}

///|
/// 页签按钮：选中态用强调色下边框式的高亮（这里用底色 + 亮文字表达）。
fn tab_button(
  label : String,
  selected : Bool,
  on_click : Msg,
  count : Int,
) -> @moui.View[Msg] {
  let cells : Array[@moui.View[Msg]] = [
    @views.text(
      label,
      theme=studio_theme(),
      width=88.0,
      height=18.0,
      align=TextStart,
    ).foreground(if selected { ide_text() } else { ide_text_faint() }),
  ]
  if count > 0 {
    cells.push(count_badge(count.to_string(), if selected { 4 } else { 0 }))
  }
  @views.container(
    @views.padding_xy(
      @views.row(cells, spacing=6.0, align=Center),
      horizontal=8.0,
      vertical=0.0,
    ),
    background=if selected { ide_selection() } else { ide_panel_alt() },
    corner_radius=4.0,
    height=22.0,
    padding=0.0,
  ).on_tap(on_click)
}

///|
/// 审计时间线：逐条卡片（时间点 + 文字），副作用卡带确认按钮，
/// 错误卡带调用栈。
pub fn audit_pane(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  if model.audit_entries.length() == 0 {
    return empty_hint(text(t, "app.audit.empty"), height)
  }
  let cards : Array[@moui.View[Msg]] = []
  let mut index = 0
  for entry in model.audit_entries {
    cards.push(audit_card(model, t, entry, index, width - 20.0))
    index = index + 1
  }
  @views.container(
    @views.scroll_view(
      @views.column(cards, spacing=6.0),
      width~,
      height~,
      shows_indicator=true,
    ),
    background=ide_editor_background(),
    width~,
    height~,
    padding=0.0,
  )
}

///|
/// 单条审计卡：左侧语义色条 + 文本 + （副作用）确认按钮 + （错误）调用栈。
/// 点击卡片跳转到对应积木（AuditOpen）。
fn audit_card(
  model : Model,
  t : @i18n.Translator,
  entry : AuditEntry,
  index : Int,
  width : Double,
) -> @moui.View[Msg] {
  ignore(model)
  let accent = match entry.kind {
    AuditOk => ide_success()
    AuditRun => ide_accent()
    AuditWarn => ide_warning()
    AuditError => ide_danger()
  }
  let body : Array[@moui.View[Msg]] = [
    @views.text(
      text(t, entry.text),
      theme=studio_theme(),
      width=(width - 40.0).max(80.0),
      height=18.0,
      align=TextStart,
    ).foreground(ide_text()),
  ]
  if entry.detail != "" {
    body.push(
      @views.text(
        entry.detail,
        theme=studio_theme(),
        role=Mono,
        width=(width - 40.0).max(80.0),
        height=16.0,
        align=TextStart,
      ).foreground(ide_text_muted()),
    )
  }
  if entry.stack != "" {
    body.push(
      @views.text(
        entry.stack,
        theme=studio_theme(),
        role=Mono,
        width=(width - 40.0).max(80.0),
        height=16.0,
        align=TextStart,
      ).foreground(code_comment_color()),
    )
  }
  if entry.kind is AuditWarn && !entry.settled {
    body.push(
      @views.row(
        [
          @views.button(
            text(t, "app.audit.confirm"),
            on_click=AuditSettle(index, "app.audit.confirmed"),
            variant=Tonal,
            width=72.0,
            height=22.0,
          ),
          @views.button(
            text(t, "app.audit.reject"),
            on_click=AuditSettle(index, "app.audit.rejected"),
            variant=Outline,
            width=72.0,
            height=22.0,
          ),
          @views.text(
            text(t, "app.audit.gate_hint"),
            theme=studio_theme(),
            width=(width - 200.0).max(60.0),
            height=16.0,
            align=TextStart,
          ).foreground(ide_text_faint()),
        ],
        spacing=6.0,
        align=Center,
      ),
    )
  } else if entry.settled {
    body.push(
      @views.text(
        entry.settled_note,
        theme=studio_theme(),
        width=(width - 40.0).max(80.0),
        height=16.0,
        align=TextStart,
      ).foreground(ide_success()),
    )
  }
  inline_card(accent, @views.column(body, spacing=4.0), width, entry.settled).on_tap(
    AuditOpen(index),
  )
}

///|
/// Console：等宽日志行，级别着色。
pub fn console_pane(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  if model.log_lines.length() == 0 {
    return empty_hint("", height)
  }
  let rows : Array[@moui.View[Msg]] = []
  for line in model.log_lines {
    let (tag, color) = match line.level {
      LogInfo => ("INFO ", ide_text_muted())
      LogWarn => ("WARN ", ide_warning())
      LogError => ("ERROR", ide_danger())
    }
    rows.push(
      @views.row(
        [
          @views.text(
            tag,
            theme=studio_theme(),
            role=Mono,
            width=44.0,
            height=16.0,
          ).foreground(color),
          @views.text(
            text(t, line.text),
            theme=studio_theme(),
            role=Mono,
            width=(width - 70.0).max(80.0),
            height=16.0,
            align=TextStart,
          ).foreground(code_plain_color()),
        ],
        spacing=6.0,
        align=Center,
      ),
    )
  }
  @views.container(
    @views.scroll_view(
      @views.column(rows, spacing=0.0),
      width~,
      height~,
      shows_indicator=true,
    ),
    background=ide_editor_background(),
    width~,
    height~,
    padding=0.0,
  )
}
