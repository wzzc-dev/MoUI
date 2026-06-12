///|
fn WorkbenchModel::chat_transcript(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  if self.should_show_chat_empty_state() {
    return self.chat_empty_state(layout, theme)
  }
  let rows : Array[@core.View[WorkbenchMsg]] = []
  if self.has_session_status_panel_content() {
    rows.push(self.session_status_panel(layout, theme))
  }
  if self.has_transcript_panel_content() {
    rows.push(self.transcript_panel(layout, theme))
  }
  if !layout.inspector_visible && self.has_turn_evidence_card_content() {
    rows.push(self.turn_evidence_card(layout, theme))
  }
  column(rows, spacing=10.0, align=Center)
}

///|
fn WorkbenchModel::chat_content_height(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
) -> Double {
  if self.should_show_chat_empty_state() {
    return self.main_scroll_height(layout)
  }
  let mut height = 0.0
  if self.has_session_status_panel_content() {
    height = height +
      session_status_panel_height(self.session_status_row_count())
  }
  if self.has_transcript_panel_content() {
    if height > 0.0 {
      height = height + 10.0
    }
    height = height + self.transcript_panel_height(layout)
  }
  if !layout.inspector_visible && self.has_turn_evidence_card_content() {
    if height > 0.0 {
      height = height + 10.0
    }
    height = height + self.turn_evidence_card_height()
  }
  height
}

///|
fn WorkbenchModel::should_show_chat_empty_state(self : WorkbenchModel) -> Bool {
  !self.has_session_status_panel_content() &&
  !self.has_transcript_panel_content() &&
  !self.has_turn_evidence_card_content()
}

///|
fn WorkbenchModel::chat_empty_state(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  let width = layout.content_width
  let body_width = workbench_clamp_double(width - 96.0, 220.0, 520.0)
  let height = self.main_scroll_height(layout)
  column(
    [
      spacer(min_length=1.0, weight=1.0),
      text(
        "准备开始这个会话",
        role=Control,
        theme~,
        width=body_width,
        height=28.0,
      ),
      text(
        "告诉 Agent 你想推进的任务。",
        role=Caption,
        theme~,
        width=body_width,
        height=24.0,
      ),
      spacer(min_length=1.0, weight=1.0),
    ],
    spacing=2.0,
    align=Center,
  ).frame(width~, height~)
}

///|
fn WorkbenchModel::has_session_status_panel_content(
  self : WorkbenchModel,
) -> Bool {
  let active = self.active_session()
  active.active_task != "" ||
  self.pending_transport_count() > 0 ||
  !self.plan.is_empty() ||
  self.has_runtime_signal() ||
  self.next_action() is Some(_) ||
  self.should_show_session_detail_rows()
}

///|
fn WorkbenchModel::has_transcript_panel_content(self : WorkbenchModel) -> Bool {
  self.transcript.any(item => transcript_item_is_visible_conversation(item))
}

///|
fn WorkbenchModel::has_activity_panel_content(self : WorkbenchModel) -> Bool {
  self.has_raw_activity_panel_content() &&
  !self.completed_process_should_collapse()
}

///|
fn WorkbenchModel::has_raw_activity_panel_content(
  self : WorkbenchModel,
) -> Bool {
  self.should_show_focused_check_presets() ||
  self.latest_visible_activity_event() is Some(_) ||
  !self.commands.is_empty()
}

///|
fn WorkbenchModel::has_turn_evidence_card_content(
  self : WorkbenchModel,
) -> Bool {
  self.has_activity_panel_content() || self.has_workspace_digest_content()
}

///|
fn WorkbenchModel::has_workspace_digest_content(self : WorkbenchModel) -> Bool {
  self.diff.has_context() ||
  !self.files.is_empty() ||
  self.visible_workspace_diagnostic_count() > 0
}

///|
fn WorkbenchModel::turn_evidence_card(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let rows : Array[@core.View[WorkbenchMsg]] = [
    self.turn_evidence_header_row(layout, theme),
  ]
  if self.has_activity_panel_content() {
    if self.should_show_focused_check_presets() {
      rows.push(focused_check_preset_row(layout, theme))
    }
    if self.commands_end_with_focused_check_batch(
        workbench_check_presets().length(),
      ) {
      let command_start = self.visible_activity_command_start()
      for index in command_start..<self.commands.length() {
        rows.push(command_run_row(self.commands[index], layout, theme))
      }
    } else {
      match self.primary_turn_evidence_command() {
        Some(command) => rows.push(command_run_row(command, layout, theme))
        None =>
          match self.latest_visible_activity_event() {
            Some(event) => rows.push(event_row(event, layout, theme))
            None => ()
          }
      }
    }
  }
  match self.latest_visible_workspace_diagnostic() {
    Some(diagnostic) => rows.push(diagnostic_row(diagnostic, layout, theme))
    None =>
      if self.diff.has_context() {
        rows.push(self.workspace_summary_row(layout, theme))
      } else if !self.files.is_empty() {
        rows.push(
          file_context_row(self.files[self.files.length() - 1], layout, theme),
        )
      }
  }
  surface(
    column(rows, spacing=7.0, align=Start),
    width=layout.panel_width,
    height=self.turn_evidence_card_height(),
    background=workbench_panel_background(theme),
    corner_radius=8.0,
    theme~,
    padding=12.0,
  ).border(workbench_hairline_border(theme))
}

///|
fn WorkbenchModel::turn_evidence_header_row(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      text("当前证据", role=Control, theme~, width=104.0, height=28.0),
      text(
        self.turn_evidence_summary_label(),
        role=Caption,
        theme~,
        width=workbench_max_double(1.0, layout.panel_body_width - 112.0),
        height=28.0,
      ),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn WorkbenchModel::turn_evidence_summary_label(self : WorkbenchModel) -> String {
  match self.primary_turn_evidence_command() {
    Some(command) => command_turn_summary(command)
    None =>
      match self.latest_visible_workspace_diagnostic() {
        Some(diagnostic) => "诊断 · " + diagnostic_detail_label(diagnostic)
        None =>
          if self.diff.has_context() {
            self.workspace_summary_label()
          } else if !self.files.is_empty() {
            self.workspace_summary_label()
          } else {
            match self.latest_visible_activity_event() {
              Some(event) => event.title
              None => "等待证据"
            }
          }
      }
  }
}

///|
fn WorkbenchModel::latest_visible_activity_event(
  self : WorkbenchModel,
) -> AgentEvent? {
  let mut visible : AgentEvent? = None
  for event in self.events {
    if event_is_visible_activity_evidence(event) {
      visible = Some(event)
    }
  }
  visible
}

///|
fn event_is_visible_activity_evidence(event : AgentEvent) -> Bool {
  match event.phase {
    "user" | "control" | "transport" => false
    _ => true
  }
}

///|
fn command_turn_summary(command : CommandRun) -> String {
  let parts : Array[String] = [
    compact_label(command.command, max_chars=44),
    command_status_label(command.status),
  ]
  match command.exit_code {
    Some(code) => parts.push("退出码 " + code.to_string())
    None => ()
  }
  if command.output_path != "" {
    parts.push("输出可用")
  }
  parts.join(" · ")
}

///|
fn WorkbenchModel::workspace_summary_row(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let summary_width = workbench_max_double(
    1.0,
    layout.panel_body_width - layout.row_badge_width - 124.0 - 16.0,
  )
  let rows : Array[@core.View[WorkbenchMsg]] = [
    row(
      [
        badge("工作区", tone=Accent, theme~, width=layout.row_badge_width),
        column(
          [
            text(
              self.workspace_summary_label(),
              role=Control,
              theme~,
              width=summary_width,
              height=24.0,
            ),
            text(
              self.workspace_summary_detail_label(),
              role=Caption,
              theme~,
              width=summary_width,
              height=22.0,
            ),
          ],
          spacing=0.0,
          align=Start,
        ),
        self.workspace_summary_actions(theme),
      ],
      spacing=8.0,
      align=Center,
    ),
  ]
  if self.workspace_details_expanded {
    rows.push(self.workspace_detail_panel(layout, theme))
  }
  column(rows, spacing=7.0, align=Start)
}

///|
fn WorkbenchModel::workspace_summary_label(self : WorkbenchModel) -> String {
  let parts : Array[String] = []
  if self.diff.has_context() {
    parts.push(self.diff.changed_files.to_string() + " 文件")
  } else if !self.files.is_empty() {
    parts.push(self.files.length().to_string() + " 文件")
  }
  if self.diff.has_context() {
    parts.push(
      "+" +
      self.diff.additions.to_string() +
      " -" +
      self.diff.deletions.to_string(),
    )
  }
  let diagnostic_count = self.visible_workspace_diagnostic_count()
  if diagnostic_count > 0 {
    parts.push(diagnostic_count.to_string() + " 诊断")
  }
  if parts.is_empty() {
    "工作区无新证据"
  } else {
    parts.join(" · ")
  }
}

///|
fn WorkbenchModel::workspace_summary_detail_label(
  self : WorkbenchModel,
) -> String {
  if self.diff.has_context() {
    self.diff.status_label()
  } else if !self.files.is_empty() {
    self.files[self.files.length() - 1].summary
  } else {
    "等待文件、变更或诊断"
  }
}

///|
fn WorkbenchModel::workspace_summary_actions(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
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
        width=58.0,
        height=32.0,
      ),
      self.workspace_summary_action_button(theme),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn WorkbenchModel::workspace_summary_action_button(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  if self.diff.has_context() {
    button(
      "审核",
      on_click=ReviewDiff,
      variant=Outline,
      theme~,
      width=58.0,
      height=32.0,
    )
  } else if !self.files.is_empty() {
    let file = self.files[self.files.length() - 1]
    button(
      "聚焦",
      on_click=InspectFile(file.path),
      variant=Outline,
      theme~,
      width=58.0,
      height=32.0,
    )
  } else {
    blank_cell(width=58.0, height=32.0)
  }
}

///|
fn WorkbenchModel::workspace_detail_panel(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let detail_width = workbench_max_double(
    1.0,
    layout.panel_body_width - layout.row_badge_width - 8.0,
  )
  let max_chars = readable_line_char_limit(detail_width)
  let lines : Array[@core.View[WorkbenchMsg]] = []
  for line in self.workspace_detail_lines(max_chars, max_lines=5) {
    lines.push(
      text(line, role=Caption, theme~, width=detail_width, height=22.0),
    )
  }
  row(
    [
      blank_cell(width=layout.row_badge_width, height=1.0),
      surface(
        column(lines, spacing=2.0, align=Start),
        width=detail_width,
        height=self.workspace_detail_panel_height(),
        background=workbench_panel_nested_background(theme),
        corner_radius=6.0,
        theme~,
        padding=8.0,
      ).border(workbench_hairline_border(theme)),
    ],
    spacing=8.0,
    align=Start,
  )
}

///|
fn WorkbenchModel::workspace_detail_lines(
  self : WorkbenchModel,
  max_chars : Int,
  max_lines~ : Int,
) -> Array[String] {
  let lines : Array[String] = []
  if self.diff.has_context() {
    for
      line in readable_text_lines(
        "diff " + diff_next_action_detail(self.diff),
        max_chars,
        max_lines=2,
      ) {
      lines.push(line)
    }
  }
  match self.latest_visible_workspace_diagnostic() {
    Some(diagnostic) =>
      if lines.length() < max_lines {
        for
          line in readable_text_lines(
            "诊断 " + diagnostic_detail_label(diagnostic),
            max_chars,
            max_lines=max_lines - lines.length(),
          ) {
          lines.push(line)
        }
      }
    None => ()
  }
  if !self.files.is_empty() && lines.length() < max_lines {
    let file = self.files[self.files.length() - 1]
    for
      line in readable_text_lines(
        "文件 " + file.path + " · " + file.summary,
        max_chars,
        max_lines=max_lines - lines.length(),
      ) {
      lines.push(line)
    }
  }
  if lines.is_empty() {
    lines.push("暂无工作区详情")
  }
  lines
}

///|
fn WorkbenchModel::workspace_detail_panel_height(
  self : WorkbenchModel,
) -> Double {
  let line_count = self.workspace_detail_lines(68, max_lines=5).length().max(1)
  16.0 +
  line_count.to_double() * 22.0 +
  (line_count - 1).max(0).to_double() * 2.0
}

///|
fn WorkbenchModel::turn_evidence_card_height(self : WorkbenchModel) -> Double {
  let mut height = 24.0 + 28.0
  if self.has_activity_panel_content() {
    if self.should_show_focused_check_presets() {
      height = height + 7.0 + 30.0
    }
    if self.commands_end_with_focused_check_batch(
        workbench_check_presets().length(),
      ) {
      let command_start = self.visible_activity_command_start()
      for index in command_start..<self.commands.length() {
        height = height + 7.0 + command_run_row_height(self.commands[index])
      }
    } else {
      match self.primary_turn_evidence_command() {
        Some(command) => height = height + 7.0 + command_run_row_height(command)
        None =>
          if self.latest_visible_activity_event() is Some(_) {
            height = height + 7.0 + 46.0
          }
      }
    }
  }
  if self.latest_visible_workspace_diagnostic() is Some(_) {
    height = height + 7.0 + 46.0
  } else if self.diff.has_context() || !self.files.is_empty() {
    height = height + 7.0 + self.workspace_summary_row_height()
  }
  height.max(54.0)
}

///|
fn WorkbenchModel::primary_turn_evidence_command(
  self : WorkbenchModel,
) -> CommandRun? {
  match self.latest_failed_command() {
    Some(command) => Some(command)
    None =>
      match self.latest_active_command() {
        Some(command) => Some(command)
        None =>
          if self.commands.is_empty() {
            None
          } else {
            Some(self.commands[self.commands.length() - 1])
          }
      }
  }
}

///|
fn WorkbenchModel::latest_active_command(self : WorkbenchModel) -> CommandRun? {
  let mut active : CommandRun? = None
  for command in self.commands {
    if shell_command_status_is_active(command.status) {
      active = Some(command)
    }
  }
  active
}

///|
fn WorkbenchModel::transcript_panel(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let rows : Array[@core.View[WorkbenchMsg]] = []
  for item in self.transcript {
    if transcript_item_is_visible_conversation(item) {
      if self.should_show_process_summary_before_item(item) {
        rows.push(self.process_summary_row(layout, theme))
        if self.should_show_expanded_process_details() {
          rows.push(self.process_detail_panel(layout, theme))
        }
      }
      rows.push(self.transcript_row(item, layout, theme))
      let fork_points = self.active_agent_fork_points_for_transcript_item(item)
      for point in fork_points {
        rows.push(fork_affordance_row(point, layout, theme))
      }
    }
  }
  surface(
    column(rows, spacing=4.0, align=Start),
    width=layout.panel_width,
    height=self.transcript_panel_height(layout),
    background=workbench_panel_background(theme),
    corner_radius=8.0,
    theme~,
    padding=8.0,
  ).border(workbench_hairline_border(theme))
}

///|
fn WorkbenchModel::transcript_panel_height(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
) -> Double {
  if !self.transcript.any(item => transcript_item_is_visible_conversation(item)) {
    0.0
  } else {
    let mut height = 16.0
    let mut row_count = 0
    for item in self.transcript {
      if transcript_item_is_visible_conversation(item) {
        if row_count > 0 {
          height = height + 4.0
        }
        if self.should_show_process_summary_before_item(item) {
          height = height + process_summary_row_height()
          row_count = row_count + 1
          if self.should_show_expanded_process_details() {
            height = height + 4.0 + self.process_detail_panel_height()
            row_count = row_count + 1
          }
        }
        if row_count > 0 {
          height = height + 4.0
        }
        height = height + transcript_row_height(item, layout)
        row_count = row_count + 1
        let fork_points = self.active_agent_fork_points_for_transcript_item(
          item,
        )
        for point in fork_points {
          height = height + 4.0 + fork_affordance_row_height(point, layout)
          row_count = row_count + 1
        }
      }
    }
    height
  }
}

///|
fn WorkbenchModel::should_show_process_summary_before_item(
  self : WorkbenchModel,
  item : TranscriptItem,
) -> Bool {
  self.completed_process_should_collapse() &&
  item.role == "assistant" &&
  self.latest_visible_assistant_transcript_item_id() == item.id
}

///|
fn WorkbenchModel::completed_process_should_collapse(
  self : WorkbenchModel,
) -> Bool {
  self.has_process_evidence() &&
  !self.has_live_process_signal() &&
  self.latest_visible_assistant_transcript_item_id() != ""
}

///|
fn WorkbenchModel::should_show_expanded_process_details(
  self : WorkbenchModel,
) -> Bool {
  self.workspace_details_expanded && self.completed_process_should_collapse()
}

///|
fn WorkbenchModel::latest_visible_assistant_transcript_item_id(
  self : WorkbenchModel,
) -> String {
  let mut id = ""
  for item in self.transcript {
    if item.role == "assistant" && transcript_item_is_visible_conversation(item) {
      id = item.id
    }
  }
  id
}

///|
fn WorkbenchModel::has_process_evidence(self : WorkbenchModel) -> Bool {
  let signal = self.active_agent_runtime_signal()
  !self.commands.is_empty() ||
  self.transcript.any(item => transcript_item_is_process_evidence(item)) ||
  self.events.any(event => event_is_process_evidence(event)) ||
  signal.message_preview != "" ||
  signal.active_tool_name != ""
}

///|
fn WorkbenchModel::has_live_process_signal(self : WorkbenchModel) -> Bool {
  self.active_agent_runtime_signal().has_active_signal() ||
  self.latest_active_command() is Some(_)
}

///|
fn event_is_process_evidence(event : AgentEvent) -> Bool {
  event.phase == "tool" ||
  event.title.contains("Pi agent") ||
  event.title.contains("Pi turn") ||
  event.title.contains("Pi message") ||
  event.title.contains("Pi tool")
}

///|
fn WorkbenchModel::process_summary_row(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let badge_width = transcript_compact_badge_width(layout)
  let action_width = 58.0
  let text_width = workbench_max_double(
    1.0,
    layout.panel_body_width - badge_width - action_width - 24.0,
  )
  surface(
    row(
      [
        badge("过程", tone=Neutral, theme~, width=badge_width),
        column(
          [
            text(
              self.process_summary_title(),
              role=Body,
              theme~,
              width=text_width,
              height=20.0,
            ),
            text(
              self.process_summary_detail(),
              role=Caption,
              theme~,
              width=text_width,
              height=18.0,
            ),
          ],
          spacing=1.0,
          align=Start,
        ),
        button(
          if self.workspace_details_expanded {
            "收起"
          } else {
            "展开"
          },
          on_click=ToggleWorkspaceDetails,
          variant=Ghost,
          theme~,
          width=action_width,
          height=28.0,
        ),
      ],
      spacing=8.0,
      align=Start,
    ),
    width=layout.panel_body_width,
    height=process_summary_row_height(),
    background=workbench_panel_subtle_background(theme),
    corner_radius=6.0,
    theme~,
    padding=7.0,
  )
}

///|
fn process_summary_row_height() -> Double {
  14.0 + 39.0
}

///|
fn WorkbenchModel::process_detail_panel(
  self : WorkbenchModel,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let detail_width = layout.process_detail_text_width()
  let lines = self.process_detail_lines(readable_line_char_limit(detail_width))
  let views : Array[@core.View[WorkbenchMsg]] = []
  for line in lines {
    views.push(
      text(line, role=Caption, theme~, width=detail_width, height=20.0),
    )
  }
  row(
    [
      blank_cell(width=transcript_compact_badge_width(layout), height=1.0),
      surface(
        column(views, spacing=2.0, align=Start),
        width=detail_width + 16.0,
        height=self.process_detail_panel_height(),
        background=workbench_panel_nested_background(theme),
        corner_radius=6.0,
        theme~,
        padding=8.0,
      ).border(workbench_hairline_border(theme)),
    ],
    spacing=8.0,
    align=Start,
  )
}

///|
fn WorkbenchLayout::process_detail_text_width(self : WorkbenchLayout) -> Double {
  workbench_max_double(
    1.0,
    self.panel_body_width - transcript_compact_badge_width(self) - 24.0,
  )
}

///|
fn WorkbenchModel::process_detail_panel_height(self : WorkbenchModel) -> Double {
  let line_count = self.process_detail_lines(72).length().max(1)
  16.0 +
  line_count.to_double() * 20.0 +
  (line_count - 1).max(0).to_double() * 2.0
}

///|
fn WorkbenchModel::process_summary_title(self : WorkbenchModel) -> String {
  ignore(self)
  "已处理"
}

///|
fn WorkbenchModel::process_summary_detail(self : WorkbenchModel) -> String {
  let signal = self.active_agent_runtime_signal()
  let parts : Array[String] = []
  if !self.commands.is_empty() {
    parts.push(self.commands.length().to_string() + " 命令")
  }
  let event_count = self.process_event_count()
  if event_count > 0 {
    parts.push(event_count.to_string() + " 事件")
  }
  if signal.thinking_level != "" {
    parts.push("思考 " + self.thinking_level_label())
  }
  let transcript_count = self.process_transcript_item_count()
  if transcript_count > 0 {
    parts.push(transcript_count.to_string() + " 工具")
  }
  if parts.is_empty() {
    "过程已收起"
  } else {
    parts.join(" · ")
  }
}

///|
fn WorkbenchModel::process_transcript_item_count(self : WorkbenchModel) -> Int {
  let mut count = 0
  for item in self.transcript {
    if transcript_item_is_process_evidence(item) {
      count = count + 1
    }
  }
  count
}

///|
fn WorkbenchModel::process_event_count(self : WorkbenchModel) -> Int {
  let mut count = 0
  for event in self.events {
    if event_is_process_evidence(event) {
      count = count + 1
    }
  }
  count
}

///|
fn WorkbenchModel::process_detail_lines(
  self : WorkbenchModel,
  max_chars : Int,
) -> Array[String] {
  let signal = self.active_agent_runtime_signal()
  let max_lines = 8
  let lines : Array[String] = []
  if signal.thinking_level != "" {
    lines.push("思考等级 " + self.thinking_level_label())
  }
  if signal.message_preview != "" && lines.length() < max_lines {
    for
      line in readable_text_lines(
        "消息 " + signal.message_preview,
        max_chars,
        max_lines=max_lines - lines.length(),
      ) {
      lines.push(line)
    }
  }
  for item in self.transcript {
    if lines.length() >= max_lines {
      break
    }
    if transcript_item_is_process_evidence(item) {
      for
        line in readable_text_lines(
          transcript_process_detail_label(item),
          max_chars,
          max_lines=max_lines - lines.length(),
        ) {
        lines.push(line)
      }
    }
  }
  let command_start = workbench_max_int(0, self.commands.length() - 4)
  for index in command_start..<self.commands.length() {
    if lines.length() >= max_lines {
      break
    }
    let command = self.commands[index]
    for
      line in readable_text_lines(
        "命令 " +
        command_status_label(command.status) +
        " · " +
        command.command +
        " · " +
        command_detail_label(command),
        max_chars,
        max_lines=max_lines - lines.length(),
      ) {
      lines.push(line)
    }
  }
  let event_start = workbench_max_int(0, self.events.length() - 6)
  for index in event_start..<self.events.length() {
    if lines.length() >= max_lines {
      break
    }
    let event = self.events[index]
    if event_is_process_evidence(event) {
      for
        line in readable_text_lines(
          event_phase_label(event.phase) +
          " · " +
          event.title +
          " · " +
          event.detail,
          max_chars,
          max_lines=max_lines - lines.length(),
        ) {
        lines.push(line)
      }
    }
  }
  if lines.is_empty() {
    lines.push("过程已收起，暂无可显示细节")
  }
  lines
}

///|
fn WorkbenchModel::fork_points_for_transcript_item(
  self : WorkbenchModel,
  item : TranscriptItem,
) -> Array[AgentForkPoint] {
  let points : Array[AgentForkPoint] = []
  if item.role == "assistant" {
    for message in self.fork_messages {
      let point = message.as_agent_fork_point()
      if self.assistant_transcript_item_id_for_fork_point(point) == item.id {
        points.push(point)
      }
    }
  }
  points
}

///|
fn WorkbenchModel::assistant_transcript_item_id_for_fork_point(
  self : WorkbenchModel,
  point : AgentForkPoint,
) -> String {
  let mut matched_index = -1
  for index in 0..<self.transcript.length() {
    if matched_index == -1 &&
      self.fork_point_matches_transcript_item(point, self.transcript[index]) {
      matched_index = index
    }
  }
  if matched_index == -1 {
    ""
  } else if self.transcript[matched_index].role == "assistant" {
    self.transcript[matched_index].id
  } else {
    for index in (matched_index + 1)..<self.transcript.length() {
      if self.transcript[index].role == "assistant" &&
        transcript_item_is_visible_conversation(self.transcript[index]) {
        return self.transcript[index].id
      }
    }
    ""
  }
}

///|
fn WorkbenchModel::active_agent_fork_points_for_transcript_item(
  self : WorkbenchModel,
  item : TranscriptItem,
) -> Array[AgentForkPoint] {
  let points : Array[AgentForkPoint] = []
  if !self.active_agent_backend_capabilities().supports_fork {
    return points
  }
  let seen : Array[String] = []
  for point in self.fork_points_for_transcript_item(item) {
    let key = point.entry_id + "\n" + point.text
    if !seen.any(value => value == key) {
      seen.push(key)
      points.push(point)
    }
  }
  points
}

///|
fn WorkbenchModel::fork_point_matches_transcript_item(
  self : WorkbenchModel,
  point : AgentForkPoint,
  item : TranscriptItem,
) -> Bool {
  ignore(self)
  point.entry_id == item.id || fork_point_text_matches_item(point.text, item)
}

///|
fn fork_point_text_matches_item(text : String, item : TranscriptItem) -> Bool {
  let clean = text.trim().to_owned()
  clean != "" &&
  (
    item.summary.trim().to_owned() == clean ||
    item.detail.trim().to_owned() == clean
  )
}

///|
fn transcript_item_is_visible_conversation(item : TranscriptItem) -> Bool {
  match item.role {
    "assistantProcess" | "toolResult" | "bashExecution" => false
    "assistant" =>
      item.summary.trim().to_owned() != "" ||
      item.detail.trim().to_owned() != ""
    _ => true
  }
}

///|
fn transcript_item_is_process_evidence(item : TranscriptItem) -> Bool {
  match item.role {
    "assistantProcess" | "toolResult" | "bashExecution" => true
    _ => false
  }
}

///|
fn transcript_process_detail_label(item : TranscriptItem) -> String {
  let title = item.summary.trim().to_owned()
  let detail = item.detail.trim().to_owned()
  let label = match item.role {
    "assistantProcess" => "Agent 过程"
    "toolResult" => "工具结果"
    "bashExecution" => "命令"
    _ => transcript_role_label(item.role)
  }
  if title == "" && detail == "" {
    label
  } else if detail == "" || detail == title {
    label + " · " + title
  } else if title == "" {
    label + " · " + detail
  } else {
    label + " · " + title + " · " + detail
  }
}

///|
fn WorkbenchModel::transcript_row(
  self : WorkbenchModel,
  item : TranscriptItem,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  transcript_compact_row(
    item,
    layout,
    theme,
    badge_label=transcript_role_label(item.role),
    tone=transcript_badge_tone(item.tone),
    background=transcript_row_background(item.role, theme),
  )
}

///|
fn transcript_compact_row(
  item : TranscriptItem,
  layout : WorkbenchLayout,
  theme : @core.Theme,
  badge_label~ : String,
  tone~ : @views.BadgeTone,
  background~ : @core.Color,
) -> @core.View[WorkbenchMsg] {
  let badge_width = transcript_compact_badge_width(layout)
  let text_width = transcript_row_text_width(layout)
  surface(
    row(
      [
        badge(badge_label, tone~, theme~, width=badge_width),
        transcript_text_block(item, text_width, theme),
      ],
      spacing=8.0,
      align=Start,
    ),
    width=layout.panel_body_width,
    height=transcript_row_height(item, layout),
    background~,
    corner_radius=8.0,
    theme~,
    padding=8.0,
  )
}

///|
fn transcript_text_block(
  item : TranscriptItem,
  width : Double,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let max_chars = readable_line_char_limit(width)
  let lines : Array[@core.View[WorkbenchMsg]] = []
  for line in readable_text_lines(item.summary, max_chars, max_lines=2) {
    lines.push(text(line, role=Body, theme~, width~, height=22.0))
  }
  for line in readable_text_lines(item.detail, max_chars, max_lines=4) {
    lines.push(text(line, role=Caption, theme~, width~, height=20.0))
  }
  if lines.is_empty() {
    lines.push(text("空消息", role=Caption, theme~, width~, height=20.0))
  }
  column(lines, spacing=1.0, align=Start)
}

///|
fn transcript_row_height(
  item : TranscriptItem,
  layout : WorkbenchLayout,
) -> Double {
  let text_width = transcript_row_text_width(layout)
  16.0 +
  workbench_max_double(28.0, readable_text_block_height(item, text_width))
}

///|
fn readable_text_block_height(item : TranscriptItem, width : Double) -> Double {
  let max_chars = readable_line_char_limit(width)
  let summary_count = readable_text_lines(item.summary, max_chars, max_lines=2).length()
  let detail_count = readable_text_lines(item.detail, max_chars, max_lines=4).length()
  let line_count = summary_count + detail_count
  if line_count == 0 {
    20.0
  } else {
    summary_count.to_double() * 22.0 +
    detail_count.to_double() * 20.0 +
    (line_count - 1).max(0).to_double() * 1.0
  }
}

///|
fn transcript_compact_badge_width(layout : WorkbenchLayout) -> Double {
  if layout.panel_width < 620.0 {
    60.0
  } else {
    72.0
  }
}

///|
fn transcript_row_text_width(layout : WorkbenchLayout) -> Double {
  workbench_max_double(
    1.0,
    layout.panel_body_width - 16.0 - transcript_compact_badge_width(layout),
  )
}

///|
fn transcript_row_background(role : String, theme : @core.Theme) -> @core.Color {
  match role {
    "assistant" => workbench_transcript_assistant_background(theme)
    "user" => workbench_transcript_user_background(theme)
    _ => workbench_panel_subtle_background(theme)
  }
}

///|
fn readable_line_char_limit(width : Double) -> Int {
  workbench_clamp_int((width / 7.2).to_int(), 24, 92)
}

///|
fn readable_text_lines(
  value : String,
  max_chars : Int,
  max_lines~ : Int,
) -> Array[String] {
  let clean = value.trim().to_owned()
  let lines : Array[String] = []
  if clean == "" || max_lines <= 0 {
    return lines
  }
  let chars = clean.to_array()
  let limit = max_chars.max(1)
  let mut start = 0
  while start < chars.length() && lines.length() < max_lines {
    let end = workbench_min_int(chars.length(), start + limit)
    if lines.length() + 1 == max_lines && end < chars.length() {
      let trim_end = workbench_max_int(start, end - 3)
      lines.push(String::from_array(chars[start:trim_end]) + "...")
    } else {
      lines.push(String::from_array(chars[start:end]))
    }
    start = end
  }
  lines
}

///|
fn end_ellipsis_label(value : String, max_chars~ : Int) -> String {
  let clean = value.trim().to_owned()
  let chars = clean.to_array()
  let limit = max_chars.max(4)
  if chars.length() <= limit {
    clean
  } else {
    let end = workbench_max_int(1, limit - 3)
    String::from_array(chars[0:end]) + "..."
  }
}

///|
fn middle_ellipsis_label(value : String, max_chars~ : Int) -> String {
  let clean = value.trim().to_owned()
  let chars = clean.to_array()
  let limit = max_chars.max(5)
  if chars.length() <= limit {
    clean
  } else {
    let available = workbench_max_int(2, limit - 3)
    let head = workbench_max_int(1, (available.to_double() * 0.45).to_int())
    let tail = workbench_max_int(1, available - head)
    let tail_start = workbench_max_int(head, chars.length() - tail)
    String::from_array(chars[0:head]) +
    "..." +
    String::from_array(chars[tail_start:])
  }
}

///|
fn workbench_clamp_int(value : Int, min : Int, max : Int) -> Int {
  workbench_min_int(max, workbench_max_int(min, value))
}

///|
fn workbench_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn workbench_min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn fork_affordance_row_height(
  point : AgentForkPoint,
  layout : WorkbenchLayout,
) -> Double {
  ignore(point)
  ignore(layout)
  34.0
}

///|
fn fork_affordance_row(
  point : AgentForkPoint,
  layout : WorkbenchLayout,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let indent = transcript_compact_badge_width(layout) + 8.0
  let width = workbench_max_double(1.0, layout.panel_body_width - indent)
  let action_width = 54.0
  let text_width = workbench_max_double(1.0, width - action_width - 22.0)
  row(
    [
      blank_cell(width=transcript_compact_badge_width(layout), height=1.0),
      surface(
        row(
          [
            button(
              "分叉",
              on_click=ForkFromMessage(point.entry_id),
              variant=Ghost,
              theme~,
              width=action_width,
              height=26.0,
            ),
            text(
              end_ellipsis_label(
                fork_affordance_detail(point),
                max_chars=readable_line_char_limit(text_width),
              ),
              role=Caption,
              theme~,
              width=text_width,
              height=24.0,
            ),
          ],
          spacing=8.0,
          align=Center,
        ),
        width~,
        height=fork_affordance_row_height(point, layout),
        background=workbench_panel_nested_background(theme),
        corner_radius=6.0,
        theme~,
        padding=4.0,
      ),
    ],
    spacing=8.0,
    align=Start,
  )
}

///|
fn fork_affordance_detail(point : AgentForkPoint) -> String {
  if point.text.trim().to_owned() == "" {
    "从这条回复创建分支"
  } else {
    point.text
  }
}

///|
fn transcript_badge_tone(tone : String) -> @views.BadgeTone {
  match tone {
    "success" => Success
    "warning" => Warning
    "danger" => Danger
    "info" => Accent
    _ => Neutral
  }
}

///|
fn agent_activity_queue_badge_tone(tone : String) -> @views.BadgeTone {
  match tone {
    "success" => Success
    "warning" => Warning
    "danger" => Danger
    "accent" | "info" => Accent
    _ => Neutral
  }
}

///|
fn transcript_role_label(role : String) -> String {
  match role {
    "user" => "用户"
    "assistant" => "Agent"
    "toolResult" => "工具"
    "bashExecution" => "命令"
    "branchSummary" => "分支"
    "compactionSummary" => "压缩"
    "message" => "消息"
    _ => role
  }
}

///|
fn count_badge(
  count : Int,
  label~ : String,
  tone~ : @views.BadgeTone,
  theme~ : @core.Theme,
  width~ : Double,
) -> @core.View[WorkbenchMsg] {
  if count == 0 {
    blank_cell(width~, height=24.0)
  } else {
    badge(label, tone~, theme~, width~)
  }
}
