///|
fn event_row(
  event : AgentEvent,
  layout : WorkbenchLayout,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  let text_width = workbench_max_double(
    1.0,
    layout.panel_body_width - layout.row_badge_width - 8.0,
  )
  row(
    [
      badge(
        event_phase_label(event.phase),
        tone=transcript_badge_tone(event.tone),
        theme~,
        width=layout.row_badge_width,
      ),
      column(
        [
          text(event.title, role=Control, theme~, width=text_width, height=24.0),
          text(
            event.detail,
            role=Caption,
            theme~,
            width=text_width,
            height=22.0,
          ),
        ],
        spacing=0.0,
        align=Start,
      ),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn event_phase_label(phase : String) -> String {
  match phase {
    "user" => "用户"
    "agent" => "Agent"
    "assistant" => "Agent"
    "tool" => "工具"
    "transport" => "传输"
    "diagnostic" => "诊断"
    "context" => "上下文"
    "diff" => "变更"
    "plan" => "计划"
    "control" => "操作"
    _ => phase
  }
}

///|
fn command_run_row(
  command : CommandRun,
  layout : WorkbenchLayout,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  let rows : Array[@moui.View[WorkbenchMsg]] = [
    command_run_summary_row(command, layout, theme),
  ]
  if command.details_expanded {
    rows.push(command_detail_panel(command, layout, theme))
  }
  column(rows, spacing=7.0, align=Start)
}

///|
fn command_run_summary_row(
  command : CommandRun,
  layout : WorkbenchLayout,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  row(
    [
      badge(
        command_status_label(command.status),
        tone=command_status_tone(command.status),
        theme~,
        width=layout.row_badge_width,
      ),
      column(
        [
          text(
            command.command,
            role=Control,
            theme~,
            width=layout.command_text_width,
            height=24.0,
          ),
          text(
            command_detail_label(command),
            role=Caption,
            theme~,
            width=layout.command_text_width,
            height=22.0,
          ),
        ],
        spacing=0.0,
        align=Start,
      ),
      text(
        command_exit_label(command),
        role=Caption,
        theme~,
        width=68.0,
        height=30.0,
      ),
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
        height=32.0,
      ),
      button(
        command_primary_action_label(command),
        on_click=command_primary_action_message(command),
        variant=Outline,
        theme~,
        width=54.0,
        height=32.0,
      ),
      button(
        "重跑",
        on_click=QueueCommand(command.command),
        variant=Outline,
        theme~,
        width=54.0,
        height=32.0,
      ),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn command_detail_panel(
  command : CommandRun,
  layout : WorkbenchLayout,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  let detail_width = workbench_max_double(
    1.0,
    layout.panel_body_width - layout.row_badge_width - 8.0,
  )
  let max_chars = readable_line_char_limit(detail_width)
  let lines : Array[@moui.View[WorkbenchMsg]] = []
  for line in command_detail_lines(command, max_chars, max_lines=7) {
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
        height=command_detail_panel_height(command),
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
fn command_primary_action_label(command : CommandRun) -> String {
  if command.status == "failed" {
    "修复"
  } else {
    "分析"
  }
}

///|
fn command_primary_action_message(command : CommandRun) -> WorkbenchMsg {
  if command.status == "failed" {
    FixCommandRun(
      command.command,
      command_status_context(command),
      command.cwd,
      command.output_path,
    )
  } else {
    InspectCommandRun(
      command.command,
      command_status_context(command),
      command.cwd,
      command.output_path,
    )
  }
}

///|
fn command_status_context(command : CommandRun) -> String {
  let status = command.status.trim().to_owned()
  match command.exit_code {
    Some(code) =>
      if status == "" {
        "exit code " + code.to_string()
      } else {
        status + ", exit code " + code.to_string()
      }
    None => status
  }
}

///|
fn command_exit_label(command : CommandRun) -> String {
  match command.exit_code {
    Some(code) => "退出码 " + code.to_string()
    None => command_status_label(command.status)
  }
}

///|
fn command_detail_label(command : CommandRun) -> String {
  if command_has_output_details(command) {
    command_output_available_label(command) + " · " + command.cwd
  } else if command.cwd == "" {
    "等待命令输出"
  } else {
    command.cwd
  }
}

///|
fn command_has_output_details(command : CommandRun) -> Bool {
  command.output.trim().to_owned() != "" || command.output_path != ""
}

///|
fn command_output_available_label(command : CommandRun) -> String {
  if command.output_truncated {
    "输出可用 · 已截断"
  } else {
    "输出可用"
  }
}

///|
fn command_run_row_height(command : CommandRun) -> Double {
  if command.details_expanded {
    46.0 + 7.0 + command_detail_panel_height(command)
  } else {
    46.0
  }
}

///|
fn command_detail_panel_height(command : CommandRun) -> Double {
  let line_count = command_detail_lines(command, 68, max_lines=7)
    .length()
    .max(1)
  16.0 +
  line_count.to_double() * 22.0 +
  (line_count - 1).max(0).to_double() * 2.0
}

///|
fn command_detail_lines(
  command : CommandRun,
  max_chars : Int,
  max_lines~ : Int,
) -> Array[String] {
  let lines : Array[String] = []
  if command.output_path != "" {
    for
      line in readable_text_lines(
        "日志 " + command.output_path,
        max_chars,
        max_lines=2,
      ) {
      lines.push(line)
    }
  }
  let output = command.output.trim().to_owned()
  if output != "" && lines.length() < max_lines {
    lines.push(
      if command.output_truncated {
        "stdout 已截断"
      } else {
        "stdout"
      },
    )
    for raw_line in output.split("\n") {
      if lines.length() >= max_lines {
        break
      }
      let clean = raw_line.to_owned()
      let wrapped = readable_text_lines(
        if clean == "" {
          " "
        } else {
          clean
        },
        max_chars,
        max_lines=max_lines - lines.length(),
      )
      for line in wrapped {
        if lines.length() < max_lines {
          lines.push(line)
        }
      }
    }
  }
  if lines.is_empty() {
    lines.push("暂无详细输出")
  }
  lines
}

///|
fn WorkbenchModel::workspace_summary_row_height(
  self : WorkbenchModel,
) -> Double {
  if self.workspace_details_expanded {
    46.0 + 7.0 + self.workspace_detail_panel_height()
  } else {
    46.0
  }
}

///|
fn command_status_label(status : String) -> String {
  match status {
    "passed" | "ready" => "通过"
    "running" => "运行中"
    "queued" => "排队"
    "cancelling" => "停止中"
    "failed" => "失败"
    "cancelled" => "已取消"
    "manual" => "手动"
    _ => status
  }
}

///|
fn command_status_tone(status : String) -> @views.BadgeTone {
  match status {
    "passed" | "ready" => Success
    "running" | "queued" | "cancelling" => Accent
    "failed" => Danger
    "cancelled" | "manual" => Warning
    _ => Neutral
  }
}

///|
fn file_context_row(
  file : FileContext,
  layout : WorkbenchLayout,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  row(
    [
      badge(
        file.change_kind,
        tone=Neutral,
        theme~,
        width=layout.row_badge_width,
      ),
      column(
        [
          text(
            file.path,
            role=Control,
            theme~,
            width=layout.row_text_width,
            height=24.0,
          ),
          text(
            file.summary,
            role=Caption,
            theme~,
            width=layout.row_text_width,
            height=22.0,
          ),
        ],
        spacing=0.0,
        align=Start,
      ),
      button(
        "聚焦",
        on_click=InspectFile(file.path),
        variant=Outline,
        theme~,
        width=58.0,
        height=32.0,
      ),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn WorkbenchModel::visible_workspace_diagnostic_count(
  self : WorkbenchModel,
) -> Int {
  let mut count = 0
  for diagnostic in self.diagnostics {
    if !self.workspace_diagnostic_is_command_shadow(diagnostic) {
      count = count + 1
    }
  }
  count
}

///|
fn WorkbenchModel::latest_visible_workspace_diagnostic(
  self : WorkbenchModel,
) -> DiagnosticItem? {
  let mut latest : DiagnosticItem? = None
  for diagnostic in self.diagnostics {
    if !self.workspace_diagnostic_is_command_shadow(diagnostic) {
      latest = Some(diagnostic)
    }
  }
  latest
}

///|
fn WorkbenchModel::workspace_diagnostic_is_command_shadow(
  self : WorkbenchModel,
  diagnostic : DiagnosticItem,
) -> Bool {
  let source = diagnostic.source.trim().to_owned()
  let message = diagnostic.message.trim().to_owned()
  source == "Pi bash" &&
  (
    (message.contains("bash exited with code") && self.has_failed_command()) ||
    (message == "bash command was cancelled" && self.has_cancelled_command())
  )
}

///|
fn WorkbenchModel::has_failed_command(self : WorkbenchModel) -> Bool {
  self.commands.any(command => command.status == "failed")
}

///|
fn WorkbenchModel::has_cancelled_command(self : WorkbenchModel) -> Bool {
  self.commands.any(command => command.status == "cancelled")
}

///|
fn diagnostic_row(
  diagnostic : DiagnosticItem,
  layout : WorkbenchLayout,
  theme : @moui.Theme,
) -> @moui.View[WorkbenchMsg] {
  row(
    [
      badge(
        diagnostic.severity,
        tone=diagnostic_badge_tone(diagnostic.severity),
        theme~,
        width=layout.row_badge_width,
      ),
      column(
        [
          text(
            diagnostic.source,
            role=Control,
            theme~,
            width=layout.row_text_width,
            height=24.0,
          ),
          text(
            diagnostic.message,
            role=Caption,
            theme~,
            width=layout.row_text_width,
            height=22.0,
          ),
        ],
        spacing=0.0,
        align=Start,
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
        width=58.0,
        height=32.0,
      ),
    ],
    spacing=10.0,
    align=Center,
  )
}

///|
fn diagnostic_badge_tone(severity : String) -> @views.BadgeTone {
  match severity {
    "error" => Danger
    "warning" | "watch" => Warning
    "note" => Accent
    _ => Neutral
  }
}

///|
fn blank_row(height : Double) -> @moui.View[WorkbenchMsg] {
  blank_cell(width=650.0, height~)
}

///|
fn blank_cell(width~ : Double, height~ : Double) -> @moui.View[WorkbenchMsg] {
  surface(
    empty(),
    width~,
    height~,
    background=workbench_transparent(),
    padding=0.0,
  )
}
