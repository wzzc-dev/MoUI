///|
priv struct WorkbenchInspectorTab {
  id : String
  label : String
}

///|
fn workbench_inspector_tabs() -> Array[WorkbenchInspectorTab] {
  [
    { id: "context", label: "上下文" },
    { id: "runs", label: "运行" },
    { id: "diagnostics", label: "诊断" },
  ]
}

///|
fn WorkbenchModel::workspace_inspector(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let rows : Array[@core.View[WorkbenchMsg]] = [
    self.workspace_inspector_header(layout, theme),
    self.workspace_inspector_tabs(layout, theme),
    self.workspace_inspector_content(layout, theme),
  ]
  surface(
    column(rows, spacing=8.0, align=Stretch),
    width=layout.inspector_width,
    height=layout.workspace_body_height,
    background=@core.Color::white(),
    corner_radius=10.0,
    theme~,
    padding=12.0,
  ).border(workbench_hairline_border())
}

///|
fn WorkbenchModel::workspace_inspector_header(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      text(
        self.workspace_inspector_title(),
        role=Control,
        theme~,
        width=78.0,
        height=28.0,
      ),
      text(
        self.workspace_inspector_summary_label(),
        role=Caption,
        theme~,
        width=workbench_max_double(1.0, layout.inspector_body_width - 86.0),
        height=28.0,
      ),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn WorkbenchModel::workspace_inspector_title(self : WorkbenchModel) -> String {
  if self.has_turn_evidence_card_content() ||
    self.active_agent_runtime_signal().active_tool_name != "" ||
    !self.plan.is_empty() {
    "当前证据"
  } else {
    "工作台"
  }
}

///|
fn WorkbenchModel::workspace_inspector_summary_label(
  self : WorkbenchModel,
) -> String {
  let parts : Array[String] = []
  if self.pending_transport_count() > 0 {
    parts.push(self.pending_transport_count().to_string() + " 排队")
  }
  if !self.commands.is_empty() {
    parts.push(self.commands.length().to_string() + " 运行")
  }
  let diagnostic_count = self.visible_workspace_diagnostic_count()
  if diagnostic_count > 0 {
    parts.push(diagnostic_count.to_string() + " 诊断")
  }
  if !self.files.is_empty() {
    parts.push(self.files.length().to_string() + " 文件")
  }
  if parts.is_empty() {
    "上下文就绪"
  } else {
    parts.join(" · ")
  }
}

///|
fn WorkbenchModel::workspace_inspector_tabs(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let tabs = workbench_inspector_tabs()
  let tab_width = workbench_max_double(
    1.0,
    (layout.inspector_body_width - (tabs.length() - 1).to_double() * 6.0) /
    tabs.length().to_double(),
  )
  let active = self.active_inspector_panel_id()
  let controls : Array[@core.View[WorkbenchMsg]] = []
  for tab in tabs {
    controls.push(
      button(
        tab.label,
        on_click=SelectPanel(tab.id),
        variant=if active == tab.id { Outline } else { Ghost },
        theme~,
        width=tab_width,
        height=34.0,
      ),
    )
  }
  row(controls, spacing=6.0, align=Center)
}

///|
fn WorkbenchModel::active_inspector_panel_id(self : WorkbenchModel) -> String {
  match self.selected_panel {
    "runs" | "activity" | "commands" => "runs"
    "diagnostics" | "diagnostic" | "diag" => "diagnostics"
    "context" | "agent" | "workspace" | "files" =>
      self.default_inspector_panel_id()
    _ => self.default_inspector_panel_id()
  }
}

///|
fn WorkbenchModel::default_inspector_panel_id(self : WorkbenchModel) -> String {
  if self.visible_workspace_diagnostic_count() > 0 ||
    self.transport_failure_message() is Some(_) {
    "diagnostics"
  } else if !self.commands.is_empty() ||
    self.active_agent_runtime_signal().active_tool_name != "" ||
    self.should_show_focused_check_presets() {
    "runs"
  } else if self.has_workspace_digest_content() {
    "context"
  } else if self.latest_visible_activity_event() is Some(_) {
    "runs"
  } else {
    "context"
  }
}

///|
fn WorkbenchModel::workspace_inspector_content(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  match self.active_inspector_panel_id() {
    "runs" => self.workspace_runs_panel(layout, theme)
    "diagnostics" => self.workspace_diagnostics_panel(layout, theme)
    _ => self.workspace_context_panel(layout, theme)
  }
}

///|
fn WorkbenchLayout::inspector_content_height(self : WorkbenchLayout) -> Double {
  workbench_max_double(1.0, self.workspace_body_height - 102.0)
}

///|
fn WorkbenchModel::workspace_context_panel(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let active = self.active_session()
  let rows : Array[@core.View[WorkbenchMsg]] = [
    inspector_section_title("会话", active.title, layout, theme),
    inspector_key_value_row(
      "项目",
      project_display_label(active.project_path),
      layout,
      theme,
    ),
    inspector_key_value_row("分支", active.branch, layout, theme),
    self.inspector_context_scope_row(layout, theme),
    inspector_section_title(
      "文件",
      self.workspace_summary_label(),
      layout,
      theme,
    ),
  ]
  if self.diff.has_context() {
    rows.push(self.inspector_diff_card(layout, theme))
    if self.workspace_details_expanded {
      rows.push(self.inspector_workspace_detail_card(layout, theme))
    }
  }
  if self.files.is_empty() && !self.diff.has_context() {
    rows.push(
      inspector_empty_state(
        "暂无文件上下文", "文件、diff 和代码证据会显示在这里。",
        layout, theme,
      ),
    )
  } else {
    let start = workbench_max_int(0, self.files.length() - 3)
    for index in start..<self.files.length() {
      rows.push(inspector_file_card(self.files[index], layout, theme))
    }
  }
  surface(
    column(rows, spacing=7.0, align=Stretch),
    width=layout.inspector_body_width,
    height=layout.inspector_content_height(),
    background=ui_color(0.988, 0.989, 0.985),
    corner_radius=8.0,
    theme~,
    padding=10.0,
  ).border(workbench_hairline_border())
}

///|
fn WorkbenchModel::inspector_context_scope_row(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let chip_width = workbench_max_double(
    1.0,
    (layout.inspector_body_width - 20.0 - 18.0) / 4.0,
  )
  row(
    [
      self.context_chip("仓库", "repo", theme, width=chip_width),
      self.context_chip("示例", "examples", theme, width=chip_width),
      self.context_chip("证据", "evidence", theme, width=chip_width),
      self.context_chip("会话", "session", theme, width=chip_width),
    ],
    spacing=6.0,
    align=Center,
  )
}

///|
fn WorkbenchModel::inspector_diff_card(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let detail_width = workbench_max_double(
    1.0,
    layout.inspector_body_width - 20.0,
  )
  surface(
    column(
      [
        row(
          [
            badge("Diff", tone=Accent, theme~, width=58.0),
            text(
              diff_next_action_detail(self.diff),
              role=Caption,
              theme~,
              width=workbench_max_double(1.0, detail_width - 66.0),
              height=24.0,
            ),
          ],
          spacing=8.0,
          align=Center,
        ),
        row(
          [
            button(
              if self.workspace_details_expanded {
                "收起"
              } else {
                "展开"
              },
              on_click=ToggleWorkspaceDetails,
              variant=Ghost,
              theme~,
              width=54.0,
              height=30.0,
            ),
            button(
              if self.current_plan_action_step() is Some(_) {
                "查看变更"
              } else {
                "审核当前变更"
              },
              on_click=ReviewDiff,
              variant=Outline,
              theme~,
              width=118.0,
              height=30.0,
            ),
          ],
          spacing=6.0,
          align=Center,
        ),
      ],
      spacing=6.0,
      align=Start,
    ),
    width=layout.inspector_body_width,
    height=74.0,
    background=@core.Color::white(),
    corner_radius=8.0,
    theme~,
    padding=10.0,
  ).border(workbench_hairline_border())
}

///|
fn WorkbenchModel::inspector_workspace_detail_card(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let width = workbench_max_double(1.0, layout.inspector_body_width - 20.0)
  let lines : Array[@core.View[WorkbenchMsg]] = []
  for
    line in self.workspace_detail_lines(
      readable_line_char_limit(width),
      max_lines=4,
    ) {
    lines.push(text(line, role=Caption, theme~, width~, height=20.0))
  }
  surface(
    column(lines, spacing=2.0, align=Start),
    width=layout.inspector_body_width,
    height=inspector_workspace_detail_card_height(self),
    background=@core.Color::white(),
    corner_radius=8.0,
    theme~,
    padding=10.0,
  ).border(workbench_hairline_border())
}

///|
fn inspector_workspace_detail_card_height(model : WorkbenchModel) -> Double {
  let line_count = model.workspace_detail_lines(44, max_lines=4).length().max(1)
  20.0 +
  line_count.to_double() * 20.0 +
  (line_count - 1).max(0).to_double() * 2.0
}

///|
fn inspector_file_card(
  file : FileContext,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let text_width = workbench_max_double(1.0, layout.inspector_body_width - 86.0)
  surface(
    row(
      [
        badge(file.change_kind, tone=Neutral, theme~, width=58.0),
        column(
          [
            text(file.path, role=Control, theme~, width=text_width, height=22.0),
            text(
              file.summary,
              role=Caption,
              theme~,
              width=text_width,
              height=20.0,
            ),
          ],
          spacing=0.0,
          align=Start,
        ),
      ],
      spacing=8.0,
      align=Center,
    ),
    width=layout.inspector_body_width,
    height=62.0,
    background=@core.Color::white(),
    corner_radius=8.0,
    theme~,
    padding=10.0,
  ).border(workbench_hairline_border())
}

///|
fn WorkbenchModel::workspace_runs_panel(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let rows : Array[@core.View[WorkbenchMsg]] = [
    inspector_section_title(
      "运行输出",
      self.inspector_runs_summary(),
      layout,
      theme,
    ),
  ]
  if self.should_show_focused_check_presets() {
    rows.push(inspector_focused_check_row(layout, theme))
  }
  if self.has_runtime_signal() {
    rows.push(self.inspector_runtime_signal_card(layout, theme))
  }
  match self.latest_visible_activity_event() {
    Some(event) => rows.push(inspector_event_card(event, layout, theme))
    None => ()
  }
  if self.commands.is_empty() &&
    !self.has_runtime_signal() &&
    self.latest_visible_activity_event() is None {
    rows.push(
      inspector_empty_state(
        "没有运行输出", "命令、工具调用和检查结果会显示在这里。",
        layout, theme,
      ),
    )
  } else {
    let focused_count = workbench_check_presets().length()
    if self.commands_end_with_focused_check_batch(focused_count) {
      let start = workbench_max_int(0, self.commands.length() - focused_count)
      for index in start..<self.commands.length() {
        rows.push(inspector_command_card(self.commands[index], layout, theme))
      }
    } else {
      let shown_ids : Array[Int] = []
      match self.primary_turn_evidence_command() {
        Some(command) => {
          rows.push(inspector_command_card(command, layout, theme))
          shown_ids.push(command.id)
        }
        None => ()
      }
      match self.latest_active_command() {
        Some(command) =>
          if !shown_ids.any(id => id == command.id) {
            rows.push(inspector_command_card(command, layout, theme))
          }
        None => ()
      }
    }
  }
  surface(
    column(rows, spacing=7.0, align=Stretch),
    width=layout.inspector_body_width,
    height=layout.inspector_content_height(),
    background=ui_color(0.988, 0.989, 0.985),
    corner_radius=8.0,
    theme~,
    padding=10.0,
  ).border(workbench_hairline_border())
}

///|
fn inspector_event_card(
  event : AgentEvent,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let text_width = workbench_max_double(1.0, layout.inspector_body_width - 86.0)
  surface(
    row(
      [
        badge(
          event_phase_label(event.phase),
          tone=transcript_badge_tone(event.tone),
          theme~,
          width=58.0,
        ),
        column(
          [
            text(
              event.title,
              role=Control,
              theme~,
              width=text_width,
              height=22.0,
            ),
            text(
              event.detail,
              role=Caption,
              theme~,
              width=text_width,
              height=20.0,
            ),
          ],
          spacing=0.0,
          align=Start,
        ),
      ],
      spacing=8.0,
      align=Center,
    ),
    width=layout.inspector_body_width,
    height=62.0,
    background=@core.Color::white(),
    corner_radius=8.0,
    theme~,
    padding=10.0,
  ).border(workbench_hairline_border())
}

///|
fn WorkbenchModel::inspector_runs_summary(self : WorkbenchModel) -> String {
  match self.latest_active_command() {
    Some(command) => command_status_label(command.status)
    None =>
      if self.commands.is_empty() {
        "待命"
      } else {
        self.commands.length().to_string() + " 条记录"
      }
  }
}

///|
fn inspector_focused_check_row(
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let label_width = 66.0
  let button_width = workbench_max_double(
    1.0,
    (layout.inspector_body_width - label_width - 24.0) / 4.0,
  )
  let presets = workbench_check_presets()
  let controls : Array[@core.View[WorkbenchMsg]] = [
    text("常用检查", role=Caption, theme~, width=label_width, height=30.0),
    button(
      "全部",
      on_click=QueueFocusedChecks,
      variant=Outline,
      theme~,
      width=button_width,
      height=30.0,
    ),
  ]
  let limit = workbench_min_int(3, presets.length())
  for index in 0..<limit {
    controls.push(
      button(
        presets[index].label,
        on_click=QueueCommand(presets[index].command),
        variant=Ghost,
        theme~,
        width=button_width,
        height=30.0,
      ),
    )
  }
  row(controls, spacing=6.0, align=Center)
}

///|
fn WorkbenchModel::inspector_runtime_signal_card(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let signal = self.active_agent_runtime_signal()
  surface(
    column(
      [
        text(
          signal.status_label,
          role=Control,
          theme~,
          width=layout.inspector_body_width - 20.0,
          height=22.0,
        ),
        text(
          if signal.message_preview == "" {
            "等待工具或消息事件"
          } else {
            signal.message_preview
          },
          role=Caption,
          theme~,
          width=layout.inspector_body_width - 20.0,
          height=20.0,
        ),
      ],
      spacing=2.0,
      align=Start,
    ),
    width=layout.inspector_body_width,
    height=62.0,
    background=@core.Color::white(),
    corner_radius=8.0,
    theme~,
    padding=10.0,
  ).border(workbench_hairline_border())
}

///|
fn inspector_command_card(
  command : CommandRun,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let text_width = workbench_max_double(1.0, layout.inspector_body_width - 86.0)
  let rows : Array[@core.View[WorkbenchMsg]] = [
    row(
      [
        badge(
          command_status_label(command.status),
          tone=command_status_tone(command.status),
          theme~,
          width=58.0,
        ),
        column(
          [
            text(
              command.command,
              role=Control,
              theme~,
              width=text_width,
              height=22.0,
            ),
            text(
              command_detail_label(command),
              role=Caption,
              theme~,
              width=text_width,
              height=20.0,
            ),
          ],
          spacing=0.0,
          align=Start,
        ),
      ],
      spacing=8.0,
      align=Center,
    ),
    row(
      [
        button(
          if command.details_expanded {
            "收起"
          } else {
            "展开"
          },
          on_click=ToggleCommandDetails(command.id),
          variant=Ghost,
          theme~,
          width=54.0,
          height=28.0,
        ),
        button(
          command_primary_action_label(command),
          on_click=command_primary_action_message(command),
          variant=Outline,
          theme~,
          width=54.0,
          height=28.0,
        ),
        button(
          "重跑",
          on_click=QueueCommand(command.command),
          variant=Outline,
          theme~,
          width=54.0,
          height=28.0,
        ),
        spacer(min_length=1.0, weight=1.0),
        text(
          command_exit_label(command),
          role=Caption,
          theme~,
          width=78.0,
          height=28.0,
        ),
      ],
      spacing=6.0,
      align=Center,
    ),
  ]
  if command.details_expanded {
    rows.push(inspector_command_detail(command, layout, theme))
  }
  surface(
    column(rows, spacing=6.0, align=Stretch),
    width=layout.inspector_body_width,
    height=inspector_command_card_height(command),
    background=@core.Color::white(),
    corner_radius=8.0,
    theme~,
    padding=10.0,
  ).border(workbench_hairline_border())
}

///|
fn inspector_command_detail(
  command : CommandRun,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let detail_width = workbench_max_double(
    1.0,
    layout.inspector_body_width - 20.0,
  )
  let lines : Array[@core.View[WorkbenchMsg]] = []
  for
    line in command_detail_lines(
      command,
      readable_line_char_limit(detail_width),
      max_lines=4,
    ) {
    lines.push(
      text(line, role=Caption, theme~, width=detail_width, height=19.0),
    )
  }
  surface(
    column(lines, spacing=1.0, align=Start),
    width=layout.inspector_body_width - 20.0,
    height=inspector_command_detail_height(command),
    background=ui_color(0.980, 0.982, 0.978),
    corner_radius=6.0,
    theme~,
    padding=8.0,
  )
}

///|
fn inspector_command_card_height(command : CommandRun) -> Double {
  if command.details_expanded {
    96.0 + inspector_command_detail_height(command) + 6.0
  } else {
    96.0
  }
}

///|
fn inspector_command_detail_height(command : CommandRun) -> Double {
  let line_count = command_detail_lines(command, 44, max_lines=4)
    .length()
    .max(1)
  16.0 + line_count.to_double() * 19.0 + (line_count - 1).max(0).to_double()
}

///|
fn WorkbenchModel::workspace_diagnostics_panel(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let diagnostics = self.visible_workspace_diagnostics()
  let rows : Array[@core.View[WorkbenchMsg]] = [
    self.inspector_diagnostic_header(diagnostics.length(), layout, theme),
  ]
  match self.transport_failure_message() {
    Some(reason) =>
      rows.push(inspector_error_card("传输失败", reason, layout, theme))
    None => ()
  }
  if self.should_show_focused_check_presets() {
    rows.push(inspector_focused_check_row(layout, theme))
  }
  if diagnostics.is_empty() && self.transport_failure_message() is None {
    rows.push(
      inspector_empty_state(
        "暂无诊断", "错误、警告和需要修复的输出会显示在这里。",
        layout, theme,
      ),
    )
  } else {
    let start = workbench_max_int(0, diagnostics.length() - 4)
    for index in start..<diagnostics.length() {
      rows.push(inspector_diagnostic_card(diagnostics[index], layout, theme))
    }
  }
  surface(
    column(rows, spacing=7.0, align=Stretch),
    width=layout.inspector_body_width,
    height=layout.inspector_content_height(),
    background=ui_color(0.988, 0.989, 0.985),
    corner_radius=8.0,
    theme~,
    padding=10.0,
  ).border(workbench_hairline_border())
}

///|
fn WorkbenchModel::visible_workspace_diagnostics(
  self : WorkbenchModel,
) -> Array[DiagnosticItem] {
  let visible : Array[DiagnosticItem] = []
  for diagnostic in self.diagnostics {
    if !self.workspace_diagnostic_is_command_shadow(diagnostic) {
      visible.push(diagnostic)
    }
  }
  visible
}

///|
fn WorkbenchModel::inspector_diagnostic_header(
  self : WorkbenchModel,
  count : Int,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  let action = if count > 0 {
    button(
      "清除",
      on_click=ClearDiagnostics,
      variant=Ghost,
      theme~,
      width=54.0,
      height=28.0,
    )
  } else {
    surface(
      empty(),
      width=54.0,
      height=28.0,
      background=ui_color(0.988, 0.989, 0.985),
      padding=0.0,
    )
  }
  row(
    [
      text("诊断", role=Control, theme~, width=58.0, height=28.0),
      text(
        if count == 0 {
          "全部清爽"
        } else {
          count.to_string() + " 条待处理"
        },
        role=Caption,
        theme~,
        width=workbench_max_double(1.0, layout.inspector_body_width - 120.0),
        height=28.0,
      ),
      action,
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn WorkbenchModel::transport_failure_message(self : WorkbenchModel) -> String? {
  match self.transport.status {
    Failed(reason) => Some(reason)
    _ => None
  }
}

///|
fn inspector_diagnostic_card(
  diagnostic : DiagnosticItem,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let text_width = workbench_max_double(1.0, layout.inspector_body_width - 86.0)
  surface(
    column(
      [
        row(
          [
            badge(
              diagnostic.severity,
              tone=diagnostic_badge_tone(diagnostic.severity),
              theme~,
              width=58.0,
            ),
            column(
              [
                text(
                  diagnostic.source,
                  role=Control,
                  theme~,
                  width=text_width,
                  height=22.0,
                ),
                text(
                  diagnostic.message,
                  role=Caption,
                  theme~,
                  width=text_width,
                  height=20.0,
                ),
              ],
              spacing=0.0,
              align=Start,
            ),
          ],
          spacing=8.0,
          align=Center,
        ),
        button(
          "修复",
          on_click=FixDiagnostic(
            diagnostic.source,
            diagnostic.severity,
            diagnostic.message,
          ),
          variant=Outline,
          theme~,
          width=54.0,
          height=28.0,
        ),
      ],
      spacing=6.0,
      align=Start,
    ),
    width=layout.inspector_body_width,
    height=96.0,
    background=@core.Color::white(),
    corner_radius=8.0,
    theme~,
    padding=10.0,
  ).border(workbench_hairline_border())
}

///|
fn inspector_error_card(
  title : String,
  detail : String,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let width = workbench_max_double(1.0, layout.inspector_body_width - 20.0)
  surface(
    column(
      [
        text(title, role=Control, theme~, width~, height=22.0),
        text(detail, role=Caption, theme~, width~, height=40.0),
      ],
      spacing=2.0,
      align=Start,
    ),
    width=layout.inspector_body_width,
    height=82.0,
    background=ui_color(0.995, 0.975, 0.970),
    corner_radius=8.0,
    theme~,
    padding=10.0,
  ).border(workbench_hairline_border())
}

///|
fn inspector_section_title(
  label : String,
  detail : String,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      text(label, role=Control, theme~, width=58.0, height=28.0),
      text(
        compact_label(
          detail,
          max_chars=readable_line_char_limit(layout.inspector_body_width - 66.0),
        ),
        role=Caption,
        theme~,
        width=workbench_max_double(1.0, layout.inspector_body_width - 66.0),
        height=28.0,
      ),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn inspector_key_value_row(
  label : String,
  value : String,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let clean = if value.trim().to_owned() == "" { "未设置" } else { value }
  row(
    [
      text(label, role=Caption, theme~, width=42.0, height=24.0),
      text(
        middle_ellipsis_label(
          clean,
          max_chars=readable_line_char_limit(layout.inspector_body_width - 50.0),
        ),
        role=Caption,
        theme~,
        width=workbench_max_double(1.0, layout.inspector_body_width - 50.0),
        height=24.0,
      ),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn inspector_empty_state(
  title : String,
  detail : String,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  surface(
    column(
      [
        text(
          title,
          role=Control,
          theme~,
          width=layout.inspector_body_width - 20.0,
          height=24.0,
        ),
        text(
          detail,
          role=Caption,
          theme~,
          width=layout.inspector_body_width - 20.0,
          height=42.0,
        ),
      ],
      spacing=2.0,
      align=Start,
    ),
    width=layout.inspector_body_width,
    height=88.0,
    background=@core.Color::white(),
    corner_radius=8.0,
    theme~,
    padding=10.0,
  ).border(workbench_hairline_border())
}

///|
fn WorkbenchModel::workspace_status_bar(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let width = layout.content_width +
    layout.scrollbar_width +
    (if layout.inspector_visible {
      layout.inspector_gap + layout.inspector_width
    } else {
      0.0
    })
  let left_width = workbench_max_double(1.0, width - 374.0)
  let metrics : Array[@core.View[WorkbenchMsg]] = [
    status_bar_metric_cell(self.status_bar_context_label(), width=82.0, theme~),
    status_bar_metric_cell(self.status_bar_queue_label(), width=72.0, theme~),
    status_bar_metric_cell(
      self.status_bar_diagnostic_label(),
      width=86.0,
      theme~,
    ),
    status_bar_metric_cell(
      self.status_bar_activity_label(),
      width=102.0,
      theme~,
    ),
  ]
  surface(
    row(
      [
        text(
          self.status_bar_status_label(),
          role=Caption,
          theme~,
          width=left_width,
          height=24.0,
        ),
        spacer(min_length=8.0, weight=1.0),
      ] +
      metrics,
      spacing=8.0,
      align=Center,
    ),
    width~,
    height=layout.status_bar_height,
    background=ui_color(0.945, 0.948, 0.942),
    corner_radius=8.0,
    theme~,
    padding=6.0,
  ).border(workbench_hairline_border())
}

///|
fn status_bar_metric_cell(
  label : String,
  width~ : Double,
  theme~ : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  if label == "" {
    surface(
      empty(),
      width~,
      height=24.0,
      background=ui_color(0.945, 0.948, 0.942),
      padding=0.0,
    )
  } else {
    text(label, role=Caption, theme~, width~, height=24.0)
  }
}

///|
fn WorkbenchModel::status_bar_status_label(self : WorkbenchModel) -> String {
  let status = self.last_status.trim().to_owned()
  if status == "" || status == "Ready for agent backend" {
    "就绪"
  } else if status == "Prompt is empty" {
    "输入为空"
  } else if status == "Workbench conversation created" {
    "已创建新对话"
  } else if status.contains("Agent backend switched") {
    "后端已切换"
  } else if status.contains("queued") || status.contains("排队") {
    "请求已排队"
  } else if status.contains("does not support") {
    "当前后端不支持此操作"
  } else {
    status
  }
}

///|
fn WorkbenchModel::status_bar_context_label(self : WorkbenchModel) -> String {
  if self.context_is_default() {
    ""
  } else {
    "范围 " + self.expanded_context.length().to_string()
  }
}

///|
fn WorkbenchModel::status_bar_queue_label(self : WorkbenchModel) -> String {
  let count = self.pending_transport_count()
  if count == 0 {
    ""
  } else {
    "队列 " + count.to_string()
  }
}

///|
fn WorkbenchModel::status_bar_diagnostic_label(self : WorkbenchModel) -> String {
  let count = self.visible_workspace_diagnostic_count()
  if count == 0 {
    ""
  } else {
    count.to_string() + " 诊断"
  }
}

///|
fn WorkbenchModel::status_bar_activity_label(self : WorkbenchModel) -> String {
  let commands = self.commands.length()
  let files = self.files.length()
  if commands == 0 && files == 0 {
    ""
  } else if files == 0 {
    commands.to_string() + " 运行"
  } else if commands == 0 {
    files.to_string() + " 文件"
  } else {
    commands.to_string() + " 运行 · " + files.to_string() + " 文件"
  }
}
