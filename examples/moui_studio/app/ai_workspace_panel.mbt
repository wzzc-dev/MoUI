///|
/// AI 工作区面板（RvWorkspace,VS Code 智能体模式右栏口径）：
/// 双页签「更改 N（提案历史）/ 文件（工程树）」。
///
/// 「更改」= 提案历史时间线（采纳✓/拒绝✗ + 摘要 + 改动文件 chips）,
/// 待采纳提案置顶并内嵌采纳/拒绝操作（复用既有通道,不新增执行路径）；
/// 「文件」= 复用工程探索器（空态自带「还没有导入的工程」提示）。
/// 页签头 = 双页签 + 计数徽章（提案数）。

///|
/// 面板头高（与左栏面板头同节奏）。
pub const AI_WS_HEAD_HEIGHT : Double = 34.0

///|
/// 单条提案历史行高（摘要行 + 文件 chips 行）。
pub const AI_WS_ENTRY_HEIGHT : Double = 44.0

///|
/// 从提案 diff 的 IR 路径推导改动的**落盘文件**：control/window →
/// form.mbt（布局）;handler/variable/function/struct → handlers.mbt（逻辑）。
/// 去重、form 在前——与代码真源的两文件布局一致。
fn ai_ws_changed_files(diff : Array[@proposals.DiffEntry]) -> Array[String] {
  let mut form = false
  let mut handlers = false
  for entry in diff {
    let p = entry.path
    let is_form = p.has_prefix("control.") || p == "window"
    let is_logic = p.has_prefix("handler.") ||
      p.has_prefix("variable.") ||
      p.has_prefix("function.") ||
      p.has_prefix("struct.")
    if is_form {
      form = true
    } else if is_logic {
      handlers = true
    }
  }
  let files : Array[String] = []
  if form {
    files.push("form.mbt")
  }
  if handlers {
    files.push("handlers.mbt")
  }
  files
}

///|
/// 工作区面板（RvWorkspace 装配入口,ide_root 右栏分支调用）。
pub fn ai_workspace_panel(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let inner = (width - 8.0).max(80.0)
  let body = match model.right_panel_tab {
    RpChanges => {
      let tab_h = (height - AI_WS_HEAD_HEIGHT).max(80.0)
      ai_ws_changes_tab(model, t, inner, tab_h)
    }
    RpFiles => {
      let tab_h = (height - AI_WS_HEAD_HEIGHT).max(80.0)
      @views.container(
        project_explorer(model, t, inner, tab_h),
        width~,
        padding=0.0,
      )
    }
  }
  @views.column([ai_ws_tab_header(model, t, inner), body], spacing=0.0).frame(
    width~,
    height~,
  )
}

///|
/// 页签头：「更改 N」（徽章 = 已落账提案数）+「文件」，活动态强调色。
fn ai_ws_tab_header(
  model : Model,
  t : @i18n.Translator,
  width : Double,
) -> @moui.View[Msg] {
  let changes_w = (text_estimate_width(text(t, "app.ai.ws.changes")) * 1.05 +
  30.0).max(56.0)
  let files_w = (text_estimate_width(text(t, "app.ai.ws.files")) * 1.05 + 16.0).max(
    48.0,
  )
  let changes_active = model.right_panel_tab is RpChanges
  let files_active = model.right_panel_tab is RpFiles
  let count = model.ai_sessions.current().proposal_history.length()
  @views.container(
    @views.padding_edges(
      @views.row(
        [
          @views.container(
            @views.center(
              @views.row(
                [
                  @views.text(
                    text(t, "app.ai.ws.changes"),
                    theme=studio_theme(),
                    width=changes_w - 30.0,
                    height=16.0,
                  ).foreground(
                    if changes_active {
                      ide_text()
                    } else {
                      ide_text_muted()
                    },
                  ),
                  count_badge(count.to_string(), if count > 0 { 1 } else { 0 }),
                ],
                spacing=4.0,
                align=Center,
              ).frame(width=changes_w - 8.0),
              width=changes_w,
              height=22.0,
            ),
            background=if changes_active {
              ide_selection()
            } else {
              ide_panel()
            },
            corner_radius=4.0,
            width=changes_w,
            height=22.0,
            padding=0.0,
          ).on_tap(SetRightPanelTab(RpChanges)),
          @views.container(
            @views.center(
              @views.text(
                text(t, "app.ai.ws.files"),
                theme=studio_theme(),
                width=files_w - 8.0,
                height=16.0,
              ).foreground(
                if files_active {
                  ide_text()
                } else {
                  ide_text_muted()
                },
              ),
              width=files_w,
              height=22.0,
            ),
            background=if files_active { ide_selection() } else { ide_panel() },
            corner_radius=4.0,
            width=files_w,
            height=22.0,
            padding=0.0,
          ).on_tap(SetRightPanelTab(RpFiles)),
          @views.spacer(min_length=6.0, weight=1.0),
        ],
        spacing=6.0,
        align=Center,
      ),
      left=8.0,
      right=8.0,
    ),
    background=ide_panel(),
    width~,
    height=AI_WS_HEAD_HEIGHT,
    padding=0.0,
  )
}

///|
/// 「更改」页签：待采纳提案置顶（内嵌采纳/拒绝）+ 提案历史时间线;
/// 空态提示。滚动接管超长历史。
fn ai_ws_changes_tab(
  model : Model,
  t : @i18n.Translator,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let rows : Array[@moui.View[Msg]] = []
  // 待采纳提案置顶:摘要 + 改动文件 + 采纳/拒绝（复用既有通道）
  match model.pending {
    Some(pending) =>
      rows.push(
        ai_ws_pending_card(model, t, pending.summary, pending.diff, width),
      )
    None => ()
  }
  // 提案历史（最新在前）
  let history = model.ai_sessions.current().proposal_history
  let mut index = history.length()
  while index > 0 {
    index = index - 1
    let record = history[index]
    let files = ai_ws_changed_files(record.diff)
    let state_label = if record.accepted {
      text(t, "app.ai.hist_accepted")
    } else {
      text(t, "app.ai.hist_rejected")
    }
    rows.push(
      @views.container(
        @views.column(
          [
            fill_row(
              [
                @views.text(
                  fit_label(record.summary, (width - 70.0).max(40.0)),
                  theme=studio_theme(),
                  width=(width - 74.0).max(40.0),
                  height=15.0,
                  align=TextStart,
                ).foreground(ide_text()),
                @views.spacer(min_length=4.0, weight=1.0),
                @views.text(
                  state_label,
                  theme=studio_theme(),
                  width=40.0,
                  height=14.0,
                ).foreground(
                  if record.accepted {
                    ide_success()
                  } else {
                    ide_text_faint()
                  },
                ),
              ],
              width,
              4.0,
              Center,
            ),
            file_chips_row(files, width),
          ],
          spacing=3.0,
        ),
        background=if index % 2 == 1 { ide_panel() } else { ide_panel_alt() },
        width~,
        height=AI_WS_ENTRY_HEIGHT,
        padding=0.0,
      ),
    )
  }
  if rows.length() == 0 {
    rows.push(
      @views.container(
        @views.center(
          @views.text(
            text(t, "app.ai.ws.empty"),
            theme=studio_theme(),
            width=(width - 40.0).max(40.0),
            height=15.0,
          ).foreground(ide_text_faint()),
          width~,
          height=60.0,
        ),
        width~,
        padding=0.0,
      ),
    )
  }
  @views.scroll_view(
    @views.column(rows, spacing=2.0).frame(width=(width - 8.0).max(80.0)),
    width~,
    height=height.max(80.0),
    shows_indicator=true,
  )
}

///|
/// 待采纳提案卡：摘要 + 改动文件 chips + 采纳/拒绝（既有 Accept/Reject 通道）。
fn ai_ws_pending_card(
  model : Model,
  t : @i18n.Translator,
  summary : String,
  diff : Array[@proposals.DiffEntry],
  width : Double,
) -> @moui.View[Msg] {
  ignore(model)
  let files = ai_ws_changed_files(diff)
  let rows : Array[@moui.View[Msg]] = [
    @views.text(
      fit_label(summary, (width - 32.0).max(40.0)),
      theme=studio_theme(),
      width=(width - 32.0).max(40.0),
      height=15.0,
      align=TextStart,
    ).foreground(ide_accent()),
    file_chips_row(files, width),
    @views.row(
      [
        action_chip(text(t, "app.ai.accept"), AcceptProposal, Primary, 22.0),
        action_chip(text(t, "app.ai.reject"), RejectProposal, Quiet, 22.0),
      ],
      spacing=6.0,
      align=Center,
    ),
  ]
  @views.container(
    @views.padding_edges(
      @views.column(rows, spacing=4.0),
      left=8.0,
      right=8.0,
      top=6.0,
      bottom=6.0,
    ),
    background=ide_panel_alt(),
    corner_radius=6.0,
    width~,
    padding=0.0,
  )
}

///|
/// 改动文件 chips 行：每个落盘文件一枚 Mono 小芯片（无文件时 0 高）。
fn file_chips_row(files : Array[String], width : Double) -> @moui.View[Msg] {
  if files.length() == 0 {
    return @views.container(
      @views.text("", width=1.0, height=0.0),
      width~,
      height=0.0,
      padding=0.0,
    )
  }
  let cells : Array[@moui.View[Msg]] = []
  for file in files {
    let chip_w = (text_estimate_width(file) * 1.05 + 14.0).max(36.0)
    cells.push(
      @views.container(
        @views.center(
          @views.text(
            file,
            theme=studio_theme(),
            role=Mono,
            width=chip_w - 10.0,
            height=14.0,
          ).foreground(ide_text_muted()),
          width=chip_w,
          height=18.0,
        ),
        background=ide_panel(),
        corner_radius=4.0,
        width=chip_w,
        height=18.0,
        padding=0.0,
      ),
    )
  }
  @views.row(cells, spacing=4.0, align=Center)
}
