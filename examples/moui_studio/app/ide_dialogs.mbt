///|
/// v4 IDE 壳的对话框层：设置、AI 历史、toast、命令面。
/// 全部走同一个 overlay_host（顶层唯一宿主）——presentation 宿主只包一层，
/// 每个功能的显隐由各自的 presented 标志控制，关闭时不产生命中层。

// ============================================================================
// 设置对话框
// ============================================================================

///|
/// 设置：语言 / 双轨 / 编译可达性 / provider（端点·模型·密钥·假模型切换）
/// / 草稿自动保存说明 / 关于段。密钥只进会话内存——这里显式说明。
pub fn settings_dialog(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  let rows : Array[@moui.View[Msg]] = [
    @views.text(
      text(t, "app.settings.title"),
      theme=studio_theme(),
      role=Subtitle,
      width=392.0,
      height=26.0,
      align=TextStart,
    ).foreground(ide_text()),
    @views.divider(color=ide_border()),
    group_label(t, "app.settings.group.workspace"),
    @views.row(
      [
        @views.button(
          text(t, "app.ws.visual"),
          on_click=SetWorkSpace(WsVisual),
          variant=if model.workspace is WsVisual { Primary } else { Outline },
          width=124.0,
          height=28.0,
        ),
        @views.button(
          text(t, "app.ws.code"),
          on_click=SetWorkSpace(WsCode),
          variant=if model.workspace is WsCode { Primary } else { Outline },
          width=124.0,
          height=28.0,
        ),
        @views.button(
          text(t, "app.ws.empty"),
          on_click=SetWorkSpace(WsEmpty),
          variant=if model.workspace is WsEmpty { Primary } else { Outline },
          width=124.0,
          height=28.0,
        ),
      ],
      spacing=8.0,
    ),
    group_label(t, "app.settings.group.language"),
    @views.row(
      [
        @views.button(
          text(t, "app.lang.zh"),
          on_click=if model.language is ZhHans {
            Msg::Noop
          } else {
            SwitchLanguage
          },
          variant=if model.language is ZhHans { Primary } else { Outline },
          width=100.0,
          height=28.0,
        ),
        @views.button(
          text(t, "app.lang.en"),
          on_click=if model.language is En { Msg::Noop } else { SwitchLanguage },
          variant=if model.language is En { Primary } else { Outline },
          width=100.0,
          height=28.0,
        ),
      ],
      spacing=8.0,
    ),
    group_label(t, "app.settings.group.track"),
    @views.row(
      [
        @views.button(
          text(t, "app.track.interpret"),
          on_click=SetRunTrack(Interpret),
          variant=if current_track(model) is Interpret {
            Primary
          } else {
            Outline
          },
          width=124.0,
          height=28.0,
        ),
        @views.button(
          text(t, "app.track.compile"),
          on_click=SetRunTrack(Compile),
          variant=if current_track(model) is Compile {
            Primary
          } else {
            Outline
          },
          width=124.0,
          height=28.0,
        ),
      ],
      spacing=8.0,
    ),
    // 编译轨可达性说明：英文版 687/893pt，同样折行。
    hint_lines_view(
      if model.compile_track_available {
        text(t, "app.settings.compile.available")
      } else {
        text(t, "app.settings.compile.unavailable")
      },
      392.0,
      ide_text_faint(),
      3,
    ),
    group_label(t, "app.settings.group.provider"),
    @views.row(
      [
        @views.button(
          text(t, "app.ai.fake"),
          on_click=SetProviderMode(Fake),
          variant=if model.provider_mode is Fake { Primary } else { Outline },
          width=100.0,
          height=28.0,
        ),
        @views.button(
          text(t, "app.ai.real"),
          on_click=SetProviderMode(Real),
          variant=if model.provider_mode is Real { Primary } else { Outline },
          width=100.0,
          height=28.0,
        ),
      ],
      spacing=8.0,
    ),
    field_label(t, "app.ai.endpoint", 392.0),
    @views.text_field(
      model.provider_endpoint,
      on_input=value => SetProviderEndpoint(value),
      width=392.0,
      height=FIELD_HEIGHT,
    ),
    field_label(t, "app.ai.model", 392.0),
    @views.text_field(
      model.provider_model,
      on_input=value => SetProviderModel(value),
      width=392.0,
      height=FIELD_HEIGHT,
    ),
    field_label(t, "app.ai.key", 392.0),
    @views.row(
      [
        @views.text_field(
          if model.provider_key_revealed {
            model.provider_key
          } else {
            mask_key(model.provider_key)
          },
          on_input=value => SetProviderKey(value),
          width=320.0,
          height=FIELD_HEIGHT,
        ),
        action_chip(
          text(t, "app.ai.reveal"),
          ToggleProviderKeyReveal,
          Quiet,
          FIELD_HEIGHT,
        ),
      ],
      spacing=8.0,
    ),
    // 提示按可用宽折行——英文版这句话 766pt，392pt 的单行必然溢出。
    hint_lines_view(text(t, "app.ai.key_hint"), 392.0, ide_warning(), 3),
    @views.divider(color=ide_border()),
    hint_lines_view(
      text(t, "app.settings.draft_hint"),
      392.0,
      ide_text_faint(),
      2,
    ),
    fill_row(
      [
        @views.spacer(min_length=4.0, weight=1.0),
        action_chip(
          text(t, "app.settings.close"),
          ToggleSettings,
          Primary,
          28.0,
        ),
      ],
      392.0,
      8.0,
      Center,
    ),
  ]
  @views.container(
    @views.column(rows, spacing=6.0),
    width=432.0,
    background=ide_elevated(),
    corner_radius=8.0,
    border=Some(
      @graphics.BorderStyle::new(
        brush=@graphics.Brush::solid(ide_border()),
        width=1.0,
      ),
    ),
    padding=16.0,
  )
}

///|
/// 密钥掩码：固定 12 个点（长度不泄露）。
fn mask_key(key : String) -> String {
  if key == "" {
    ""
  } else {
    "••••••••••••"
  }
}

///|
/// 分组小标题。
fn group_label(t : @i18n.Translator, key : String) -> @moui.View[Msg] {
  @views.text(
    text(t, key),
    theme=studio_theme(),
    width=392.0,
    height=20.0,
    align=TextStart,
  ).foreground(ide_accent())
}

// ============================================================================
// AI 历史
// ============================================================================

///|
/// AI 历史：会话内提案回放（采纳/拒绝 + 摘要 + diff 行）。
pub fn ai_history_dialog(
  model : Model,
  t : @i18n.Translator,
) -> @moui.View[Msg] {
  let rows : Array[@moui.View[Msg]] = [
    @views.text(
      text(t, "app.ai.history"),
      theme=studio_theme(),
      role=Subtitle,
      width=520.0,
      height=26.0,
      align=TextStart,
    ).foreground(ide_text()),
    @views.divider(color=ide_border()),
  ]
  if model.proposal_history.length() == 0 {
    rows.push(
      @views.text(
        text(t, "app.ai.history.empty"),
        theme=studio_theme(),
        width=520.0,
        height=24.0,
        align=TextStart,
      ).foreground(ide_text_faint()),
    )
  } else {
    // 新的在上（回放先看最近一次）
    let mut index = model.proposal_history.length() - 1
    while index >= 0 {
      let record = model.proposal_history[index]
      rows.push(
        @views.container(
          @views.column(
            [
              @views.row(
                [
                  count_badge(
                    "\{record.seq}",
                    if record.accepted {
                      1
                    } else {
                      3
                    },
                  ),
                  @views.text(
                    if record.accepted {
                      text(t, "app.ai.hist_accepted")
                    } else {
                      text(t, "app.ai.hist_rejected")
                    },
                    theme=studio_theme(),
                    width=72.0,
                    height=18.0,
                    align=TextStart,
                  ).foreground(
                    if record.accepted {
                      ide_success()
                    } else {
                      ide_danger()
                    },
                  ),
                  @views.text(
                    record.summary,
                    theme=studio_theme(),
                    width=380.0,
                    height=18.0,
                    align=TextStart,
                  ).foreground(ide_text()),
                ],
                spacing=6.0,
                align=Center,
              ),
              @views.column(diff_line_views(record.diff, 520.0), spacing=0.0),
            ],
            spacing=4.0,
          ),
          background=ide_panel(),
          corner_radius=4.0,
          width=552.0,
          padding=8.0,
        ),
      )
      index = index - 1
    }
  }
  rows.push(
    @views.row(
      [
        @views.spacer(min_length=4.0, weight=1.0),
        action_chip(
          text(t, "app.settings.close"),
          ToggleAiHistory,
          Primary,
          28.0,
        ),
      ],
      spacing=8.0,
    ),
  )
  @views.container(
    @views.column(rows, spacing=6.0),
    width=520.0,
    background=ide_elevated(),
    corner_radius=8.0,
    border=Some(
      @graphics.BorderStyle::new(
        brush=@graphics.Brush::solid(ide_border()),
        width=1.0,
      ),
    ),
    padding=12.0,
  )
}

///|
/// diff 行渲染：+ 绿 / − 红 / 上下文灰（最多 8 行——历史是回放不是全量）。
fn diff_line_views(
  diff : Array[@proposals.DiffEntry],
  width : Double,
) -> Array[@moui.View[Msg]] {
  let views : Array[@moui.View[Msg]] = []
  let mut shown = 0
  for entry in diff {
    if shown >= 8 {
      break
    }
    let (marker, label) = match entry.op {
      @proposals.Added => ("+", entry.new_text)
      @proposals.Removed => ("-", entry.old_text)
      @proposals.Changed => ("-", entry.old_text)
    }
    views.push(diff_row(marker, label, width))
    shown = shown + 1
  }
  views
}

// ============================================================================
// toast
// ============================================================================

///|
/// toast 层：底部居中的堆叠条（最新在上）。warning 用暖色左边条。
pub fn toast_host(base : @moui.View[Msg], model : Model) -> @moui.View[Msg] {
  let specs : Array[@views.PresentationSpec[Msg]] = []
  let toasts = recent_toasts(model.toasts)
  let mut index = 0
  for toast in toasts {
    let label = toast.text
    let warning = toast.warning
    specs.push(
      @views.PresentationSpec::new(
        id="studio-toast-\{index}",
        kind=@views.PresentationKind::Toast,
        content=toast_view(label, warning),
        placement=Some(
          @views.PresentationPlacement::new(
            candidates=[@views.PresentationPlacementCandidate::BelowCenter],
            viewport_insets=@core.Insets::all(16.0 + index.to_double() * 36.0),
          ),
        ),
        dismiss=@views.PresentationDismissPolicy::new(
          outside_tap=true,
          message=Some(DismissToast(index)),
        ),
        presented=true,
      ),
    )
    index = index + 1
  }
  @views.overlay_host(base, specs)
}

///|
/// 最近的 toast（最多 TOAST_LIMIT 条，新的在前——视觉上最新在最上）。
fn recent_toasts(toasts : Array[ToastEntry]) -> Array[ToastEntry] {
  let out : Array[ToastEntry] = []
  let mut index = toasts.length() - 1
  while index >= 0 && out.length() < TOAST_LIMIT {
    out.push(toasts[index])
    index = index - 1
  }
  out
}

///|
/// 单条 toast：左色条 + 文案。
fn toast_view(label : String, warning : Bool) -> @moui.View[Msg] {
  @views.container(
    @views.row(
      [
        @views.container(
          @views.text("", width=3.0, height=1.0),
          background=if warning { ide_warning() } else { ide_success() },
          width=3.0,
          padding=0.0,
        ),
        @views.padding_xy(
          @views.text(
            label,
            theme=studio_theme(),
            width=300.0,
            height=20.0,
            align=TextStart,
          ).foreground(ide_text()),
          horizontal=10.0,
          vertical=0.0,
        ),
      ],
      spacing=0.0,
      align=Center,
    ),
    background=ide_elevated(),
    corner_radius=4.0,
    border=Some(
      @graphics.BorderStyle::new(
        brush=@graphics.Brush::solid(ide_border()),
        width=1.0,
      ),
    ),
    height=32.0,
    padding=0.0,
  )
}

// ============================================================================
// 状态栏
// ============================================================================

///|
/// 状态栏：工作区 / 文件 + 脏标 / 位置 / 编码+语言 / 警告·错误计数 /
/// 构建读数 / 运行态。
pub fn ide_status_bar(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let workspace = match model.workspace {
    WsVisual => text(t, "app.ws.visual")
    WsCode => text(t, "app.ws.code")
    WsEmpty => text(t, "app.ws.empty")
  }
  let file = match current_handler(model) {
    None => text(t, "app.statusbar.nofile")
    Some(handler) => "\{handler.control_name}.\{handler.event.tag()}"
  }
  let pending = pending_side_effects(model)
  let errors = audit_error_count(model)
  let cells : Array[(String, Int)] = [
    ("MoUI Studio", 4),
    (workspace, 0),
    (
      file + (if model.dirty { " ●" } else { "" }),
      if model.dirty {
        2
      } else {
        0
      },
    ),
    (status_position(model), 0),
    ("UTF-8 · MoonBit", 0),
    ("warn \{pending}", if pending > 0 { 2 } else { 0 }),
    ("err \{errors}", if errors > 0 { 3 } else { 0 }),
  ]
  let build = status_build_label(model)
  let cells_final = if build == "" {
    cells
  } else {
    let extended = cells
    extended.push(
      (text(t, build), if build == "app.statusbar.build_ok" { 1 } else { 3 }),
    )
    extended
  }
  let run_cell = if app_running(model) {
    (text(t, "app.statusbar.running"), 1)
  } else {
    (text(t, "app.statusbar.idle"), 0)
  }
  let all = cells_final
  all.push(run_cell)
  // 悬停提示优先占位：图标悬停时状态栏左端显示该图标的说明，离开即还原。
  // 放在最前而不是最后：状态栏尾格在窄窗被裁，提示不能被裁掉。
  let cells_with_hint = if model.hover_hint == "" {
    all
  } else {
    let hinted : Array[(String, Int)] = [(model.hover_hint, 0)]
    for cell in all {
      hinted.push(cell)
    }
    hinted
  }
  // VS Code 状态栏口径：**左组**（应用/工作区/文件标识）+ **右组**
  // （行号/编码/警告错误/运行状态），中间 weight spacer 撑开。
  let split = cells_with_hint.length().clamp(min=3, max=99).min(4)
  let left_cells : Array[(String, Int)] = []
  let right_cells : Array[(String, Int)] = []
  let mut cursor = 0
  for cell in cells_with_hint {
    if cursor < split {
      left_cells.push(cell)
    } else {
      right_cells.push(cell)
    }
    cursor = cursor + 1
  }
  let left_width = (width * 0.45).max(300.0)
  let right_width = (width - left_width).max(200.0)
  @views.container(
    @views.row(
      [
        status_cells(left_cells, left_width, false),
        @views.spacer(min_length=8.0, weight=1.0),
        status_cells(right_cells, right_width, true),
      ],
      spacing=0.0,
      align=Center,
    ).frame(width~),
    background=ide_panel_alt(),
    height=STATUSBAR_HEIGHT,
    padding=0.0,
  )
}

// ============================================================================
// 命令面（Studio 自有命令表）
// ============================================================================

///|
/// Studio 命令表：比文本命令协议的 10 个 intent 更宽——壳操作（工作区/
/// 面板/审计/AI 层/设置）与运行/文件操作都在这里，全部收敛回既有 Msg。
pub fn studio_commands(t : @i18n.Translator) -> Array[StudioCommand] {
  let group_ws = text(t, "app.command.group.workspace")
  let group_pane = text(t, "app.command.group.pane")
  let group_ai = text(t, "app.command.group.ai")
  let group_run = text(t, "app.command.group.run")
  let group_file = text(t, "app.command.group.file")
  let group_view = text(t, "app.command.group.mode")
  let group_template = text(t, "app.templates")
  [
    StudioCommand::{
      id: "studio.workspace.visual",
      label: text(t, "app.command.ws.visual"),
      group: group_ws,
      hint: "",
    },
    StudioCommand::{
      id: "studio.workspace.code",
      label: text(t, "app.command.ws.code"),
      group: group_ws,
      hint: "",
    },
    StudioCommand::{
      id: "studio.workspace.empty",
      label: text(t, "app.command.ws.empty"),
      group: group_ws,
      hint: "",
    },
    StudioCommand::{
      id: "studio.pane.live",
      label: text(t, "app.command.pane.live"),
      group: group_pane,
      hint: "",
    },
    StudioCommand::{
      id: "studio.pane.blocks",
      label: text(t, "app.command.pane.blocks"),
      group: group_pane,
      hint: "",
    },
    StudioCommand::{
      id: "studio.pane.split",
      label: text(t, "app.command.pane.split"),
      group: group_pane,
      hint: "",
    },
    StudioCommand::{
      id: "studio.left.tree",
      label: text(t, "app.command.left.tree"),
      group: group_pane,
      hint: "",
    },
    StudioCommand::{
      id: "studio.left.data",
      label: text(t, "app.command.left.data"),
      group: group_pane,
      hint: "",
    },
    StudioCommand::{
      id: "studio.right.toggle",
      label: text(t, "app.command.right.toggle"),
      group: group_pane,
      hint: "",
    },
    StudioCommand::{
      id: "studio.ctx.runtime",
      label: text(t, "app.command.ctx.runtime"),
      group: group_pane,
      hint: "",
    },
    StudioCommand::{
      id: "studio.code.complete",
      label: text(t, "app.command.code.complete"),
      group: group_pane,
      hint: "",
    },
    StudioCommand::{
      id: "studio.code.jump",
      label: text(t, "app.command.code.jump"),
      group: group_pane,
      hint: "",
    },
    StudioCommand::{
      id: "studio.bottom.toggle",
      label: text(t, "app.command.bottom.toggle"),
      group: group_pane,
      hint: "",
    },
    StudioCommand::{
      id: "studio.bottom.audit",
      label: text(t, "app.command.bottom.audit"),
      group: group_pane,
      hint: "",
    },
    StudioCommand::{
      id: "studio.bottom.console",
      label: text(t, "app.command.bottom.console"),
      group: group_pane,
      hint: "",
    },
    StudioCommand::{
      id: "studio.bottom.problems",
      label: text(t, "app.command.bottom.problems"),
      group: group_pane,
      hint: "",
    },
    StudioCommand::{
      id: "studio.audit.settle_all",
      label: text(t, "app.command.audit.settle_all"),
      group: group_pane,
      hint: "",
    },
    StudioCommand::{
      id: "studio.ai.anchor",
      label: text(t, "app.command.ai.anchor"),
      group: group_ai,
      hint: "",
    },
    StudioCommand::{
      id: "studio.ai.dock",
      label: text(t, "app.command.ai.dock"),
      group: group_ai,
      hint: "",
    },
    StudioCommand::{
      id: "studio.ai.pill",
      label: text(t, "app.command.ai.pill"),
      group: group_ai,
      hint: "",
    },
    StudioCommand::{
      id: "studio.ai.history",
      label: text(t, "app.command.ai.history"),
      group: group_ai,
      hint: "",
    },
    StudioCommand::{
      id: "studio.run.start",
      label: text(t, "app.command.run.start"),
      group: group_run,
      hint: "",
    },
    StudioCommand::{
      id: "studio.run.stop",
      label: text(t, "app.command.run.stop"),
      group: group_run,
      hint: "",
    },
    StudioCommand::{
      id: "studio.compile.run",
      label: text(t, "app.command.compile.run"),
      group: group_run,
      hint: "",
    },
    // 模板四件套必须进表：run_studio_command 早有处理器，但表里没有——
    // 「口算训练营 / 班级小卖部」（提交数据闸门的核心教案）此前没有任何
    // UI 入口，是死命令。表与处理器必须成对出现。
    StudioCommand::{
      id: "studio.template.hello",
      label: text(t, "app.templates.hello"),
      group: group_template,
      hint: "",
    },
    StudioCommand::{
      id: "studio.template.roll_call",
      label: text(t, "app.templates.roll_call"),
      group: group_template,
      hint: "",
    },
    StudioCommand::{
      id: "studio.template.drill",
      label: text(t, "app.templates.drill"),
      group: group_template,
      hint: "",
    },
    StudioCommand::{
      id: "studio.template.store",
      label: text(t, "app.templates.store"),
      group: group_template,
      hint: "",
    },
    StudioCommand::{
      id: "studio.file.new",
      label: text(t, "app.command.file.new"),
      group: group_file,
      hint: "",
    },
    StudioCommand::{
      id: "studio.file.save",
      label: text(t, "app.command.file.save"),
      group: group_file,
      hint: "",
    },
    StudioCommand::{
      id: "studio.file.open",
      label: text(t, "app.command.file.open"),
      group: group_file,
      hint: "",
    },
    StudioCommand::{
      id: "studio.file.export",
      label: text(t, "app.command.file.export"),
      group: group_file,
      hint: "",
    },
    StudioCommand::{
      id: "studio.preview",
      label: text(t, "app.preview.title"),
      group: group_view,
      hint: "",
    },
    StudioCommand::{
      id: "studio.help",
      label: text(t, "app.help.title"),
      group: group_view,
      hint: "",
    },
    StudioCommand::{
      id: "studio.settings",
      label: text(t, "app.command.settings"),
      group: group_file,
      hint: "",
    },
    StudioCommand::{
      id: "studio.lang.switch",
      label: text(t, "app.command.lang.switch"),
      group: group_file,
      hint: "",
    },
  ]
}

///|
/// Studio 命令过滤：查询为空时全部；否则按标签/分组子串匹配（大小写不敏感）。
pub fn filter_studio_commands(
  commands : Array[StudioCommand],
  query : String,
) -> Array[StudioCommand] {
  let trimmed = query.trim().to_owned()
  if trimmed == "" {
    return commands
  }
  let needle = lowercase(trimmed)
  let matched : Array[StudioCommand] = []
  for command in commands {
    if lowercase(command.label).contains(needle) ||
      lowercase(command.group).contains(needle) {
      matched.push(command)
    }
  }
  matched
}

///|
fn lowercase(text : String) -> String {
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
