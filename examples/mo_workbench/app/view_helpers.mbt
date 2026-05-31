///|
using @views {
  badge,
  button,
  column,
  empty,
  row,
  scroll_view,
  spacer,
  surface,
  text,
  text_field,
}

///|
pub fn WorkbenchModel::view(self : WorkbenchModel) -> @core.View[WorkbenchMsg] {
  let theme = @views.light_theme()
  surface(
    row(
      [self.app_sidebar(theme), self.conversation_surface(theme)],
      spacing=0.0,
      align=Stretch,
    ),
    width=1200.0,
    height=750.0,
    background=ui_color(0.98, 0.98, 0.97),
    corner_radius=0.0,
    theme~,
    padding=0.0,
  )
}

///|
fn WorkbenchModel::app_sidebar(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  surface(
    column(
      [
        self.sidebar_brand(theme),
        self.sidebar_section_label("会话", theme),
        self.pinned_threads(theme),
        self.sidebar_section_label("工作区", theme),
        self.workspace_summary(theme),
        spacer(min_length=8.0, weight=1.0),
        self.sidebar_footer(theme),
      ],
      spacing=theme.spacing_scale.sm,
      align=Stretch,
    ),
    width=292.0,
    height=750.0,
    background=ui_color(0.91, 0.92, 0.92),
    corner_radius=0.0,
    theme~,
    padding=14.0,
  )
}

///|
fn WorkbenchModel::sidebar_brand(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  column(
    [
      text("Mo Workbench", role=Title, theme~, width=246.0, height=34.0),
      text("A Pi agent desktop", role=Caption, theme~, width=246.0, height=24.0),
    ],
    spacing=0.0,
    align=Start,
  )
}

///|
fn WorkbenchModel::pinned_threads(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let rows : Array[@core.View[WorkbenchMsg]] = []
  for session in self.sessions {
    rows.push(
      self.thread_button(
        session.title,
        SelectSession(session.id),
        theme,
        selected=self.selected_session_id == session.id,
        meta=session.status,
      ),
    )
  }
  column(rows, spacing=2.0, align=Stretch)
}

///|
fn WorkbenchModel::workspace_summary(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let active = self.active_session()
  surface(
    column(
      [
        text(
          active.project_path,
          role=Caption,
          theme~,
          width=230.0,
          height=40.0,
        ),
        text(active.branch, role=Control, theme~, width=230.0, height=26.0),
        text(
          "Queue " + self.pending_transport_count().to_string(),
          role=Caption,
          theme~,
          width=230.0,
          height=24.0,
        ),
      ],
      spacing=2.0,
      align=Start,
    ),
    width=260.0,
    height=112.0,
    background=ui_color(0.88, 0.89, 0.89),
    corner_radius=8.0,
    theme~,
    padding=10.0,
  )
}

///|
fn WorkbenchModel::sidebar_footer(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let status = self.transport.status_label()
  row(
    [
      text("Pi RPC", role=Control, theme~, width=56.0, height=28.0),
      text(status, role=Caption, theme~, width=168.0, height=28.0),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn WorkbenchModel::thread_button(
  self : WorkbenchModel,
  label : String,
  message : WorkbenchMsg,
  theme : @core.Theme,
  selected~ : Bool,
  meta~ : String,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  let background = if selected {
    ui_color(0.84, 0.85, 0.85)
  } else {
    ui_color(0.91, 0.92, 0.92)
  }
  surface(
    row(
      [
        button(
          label,
          on_click=message,
          variant=Ghost,
          theme~,
          width=188.0,
          height=32.0,
        ),
        text(meta, role=Caption, theme~, width=54.0, height=28.0),
      ],
      spacing=4.0,
      align=Center,
    ),
    width=260.0,
    height=38.0,
    background~,
    corner_radius=8.0,
    theme~,
    padding=2.0,
  )
}

///|
fn WorkbenchModel::conversation_surface(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  surface(
    column(
      [
        self.top_bar(theme),
        divider(908.0),
        scroll_view(self.chat_transcript(theme), width=908.0, height=594.0),
        self.composer(theme),
      ],
      spacing=0.0,
      align=Stretch,
    ),
    width=908.0,
    height=750.0,
    background=@core.Color::white(),
    corner_radius=0.0,
    theme~,
    padding=0.0,
  )
}

///|
fn WorkbenchModel::top_bar(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let active = self.active_session()
  surface(
    row(
      [
        text("◆", role=Caption, theme~, width=26.0, height=30.0),
        text(active.title, role=Control, theme~, width=280.0, height=30.0),
        text(
          active.project_path,
          role=Caption,
          theme~,
          width=330.0,
          height=28.0,
        ),
        spacer(min_length=10.0, weight=1.0),
        text(active.branch, role=Caption, theme~, width=120.0, height=28.0),
        text("…", role=Title, theme~, width=34.0, height=30.0),
      ],
      spacing=6.0,
      align=Center,
    ),
    width=908.0,
    height=48.0,
    background=@core.Color::white(),
    theme~,
    padding=10.0,
  )
}

///|
fn WorkbenchModel::chat_transcript(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  column(
    [
      self.session_status_panel(theme),
      self.transcript_panel(theme),
      self.activity_panel(theme),
      self.workspace_digest_panel(theme),
    ],
    spacing=10.0,
    align=Center,
  )
}

///|
fn WorkbenchModel::transcript_panel(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let rows : Array[@core.View[WorkbenchMsg]] = []
  let mut visible = 0
  for item in self.transcript {
    if visible < 3 {
      rows.push(transcript_row(item, theme))
      visible = visible + 1
    }
  }
  if rows.is_empty() {
    rows.push(text("-", role=Caption, theme~, width=650.0, height=28.0))
  }
  surface(
    column(
      [
        row(
          [
            text(
              "Pi transcript",
              role=Control,
              theme~,
              width=520.0,
              height=28.0,
            ),
            badge(
              self.transcript.length().to_string() + " messages",
              tone=Neutral,
              theme~,
              width=116.0,
            ),
          ],
          spacing=8.0,
          align=Center,
        ),
        column(rows, spacing=6.0, align=Start),
      ],
      spacing=8.0,
      align=Start,
    ),
    width=690.0,
    height=178.0,
    background=@core.Color::white(),
    corner_radius=8.0,
    theme~,
    padding=12.0,
  )
}

///|
fn transcript_row(
  item : TranscriptItem,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      badge(
        item.role,
        tone=transcript_badge_tone(item.tone),
        theme~,
        width=104.0,
      ),
      column(
        [
          text(item.summary, role=Control, theme~, width=520.0, height=24.0),
          text(item.detail, role=Caption, theme~, width=520.0, height=22.0),
        ],
        spacing=0.0,
        align=Start,
      ),
    ],
    spacing=10.0,
    align=Center,
  )
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
fn command_catalog_row(
  command : PiCommandInfo,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      badge(
        command.source,
        tone=command_source_tone(command.source),
        theme~,
        width=104.0,
      ),
      column(
        [
          text(
            "/" + command.name,
            role=Control,
            theme~,
            width=430.0,
            height=24.0,
          ),
          text(
            command_catalog_detail(command),
            role=Caption,
            theme~,
            width=430.0,
            height=22.0,
          ),
        ],
        spacing=0.0,
        align=Start,
      ),
      button(
        "运行",
        on_click=InvokeCommand(command.name),
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
fn command_catalog_detail(command : PiCommandInfo) -> String {
  let description = if command.description == "" {
    "No description"
  } else {
    command.description
  }
  let scope = if command.source_scope == "" {
    ""
  } else {
    " · " + command.source_scope
  }
  let path = if command.source_path == "" {
    ""
  } else {
    " · " + command.source_path
  }
  description + scope + path
}

///|
fn command_source_tone(source : String) -> @views.BadgeTone {
  match source {
    "prompt" => Accent
    "skill" => Success
    "extension" => Warning
    _ => Neutral
  }
}

///|
fn WorkbenchModel::session_status_panel(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let active = self.active_session()
  surface(
    column(
      [
        row(
          [
            text("Session", role=Control, theme~, width=368.0, height=28.0),
            badge(active.status, tone=Success, theme~, width=92.0),
            badge(
              self.pending_transport_count().to_string() + " queued",
              tone=Neutral,
              theme~,
              width=104.0,
            ),
          ],
          spacing=8.0,
          align=Center,
        ),
        text(active.active_task, role=Body, theme~, width=650.0, height=28.0),
        session_stats_row(self.pi_session_stats, theme),
        row(
          [
            text(
              "Transport: " + self.transport.status_label(),
              role=Caption,
              theme~,
              width=310.0,
              height=30.0,
            ),
            text(
              "Agent: " + self.pi_agent.status_label(),
              role=Caption,
              theme~,
              width=310.0,
              height=30.0,
            ),
          ],
          spacing=8.0,
          align=Center,
        ),
        row(
          [
            text(
              "Thinking: " + self.thinking_level_label(),
              role=Caption,
              theme~,
              width=176.0,
              height=30.0,
            ),
            spacer(min_length=8.0, weight=1.0),
            button(
              "刷新",
              on_click=RefreshSession,
              variant=Outline,
              theme~,
              width=58.0,
              height=34.0,
            ),
            button(
              "思考",
              on_click=CycleThinkingLevel,
              variant=Outline,
              theme~,
              width=62.0,
              height=34.0,
            ),
            button(
              "同步",
              on_click=SyncSessionName,
              variant=Outline,
              theme~,
              width=66.0,
              height=34.0,
            ),
            button(
              "停止",
              on_click=CancelRun,
              variant=Ghost,
              theme~,
              width=58.0,
              height=34.0,
            ),
          ],
          spacing=8.0,
          align=Center,
        ),
      ],
      spacing=6.0,
      align=Start,
    ),
    width=690.0,
    height=202.0,
    background=@core.Color::white(),
    corner_radius=8.0,
    theme~,
    padding=12.0,
  )
}

///|
fn WorkbenchModel::thinking_level_label(self : WorkbenchModel) -> String {
  if self.pi_agent.thinking_level == "" {
    "default"
  } else {
    self.pi_agent.thinking_level
  }
}

///|
fn session_stats_row(
  stats : PiSessionStatsSnapshot,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      text(
        "Messages " + stats.total_messages.to_string(),
        role=Caption,
        theme~,
        width=128.0,
        height=28.0,
      ),
      text(
        "Tools " +
        stats.tool_calls.to_string() +
        "/" +
        stats.tool_results.to_string(),
        role=Caption,
        theme~,
        width=108.0,
        height=28.0,
      ),
      text(
        "Tokens " + stats.token_total.to_string(),
        role=Caption,
        theme~,
        width=138.0,
        height=28.0,
      ),
      text(
        session_stats_context_label(stats),
        role=Caption,
        theme~,
        width=112.0,
        height=28.0,
      ),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
fn session_stats_context_label(stats : PiSessionStatsSnapshot) -> String {
  match stats.context_percent {
    Some(percent) => "Context " + compact_percent(percent)
    None => "Context n/a"
  }
}

///|
fn compact_percent(percent : Double) -> String {
  if percent > 0.0 && percent < 1.0 {
    "<1%"
  } else {
    percent.to_int().to_string() + "%"
  }
}

///|
fn WorkbenchModel::activity_panel(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  surface(
    column(
      [
        row(
          [
            text("Activity", role=Control, theme~, width=414.0, height=28.0),
            badge(
              self.commands.length().to_string() + " runs",
              tone=Neutral,
              theme~,
              width=94.0,
            ),
            badge(
              self.command_catalog.length().to_string() + " cmds",
              tone=Accent,
              theme~,
              width=94.0,
            ),
          ],
          spacing=8.0,
          align=Center,
        ),
        self.primary_command_run_row(theme),
        self.primary_command_catalog_row(theme),
      ],
      spacing=7.0,
      align=Start,
    ),
    width=690.0,
    height=136.0,
    background=@core.Color::white(),
    corner_radius=8.0,
    theme~,
    padding=12.0,
  )
}

///|
fn WorkbenchModel::primary_command_run_row(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  if self.commands.is_empty() {
    text("-", role=Caption, theme~, width=650.0, height=28.0)
  } else {
    command_run_row(self.commands[0], theme)
  }
}

///|
fn WorkbenchModel::primary_command_catalog_row(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  if self.command_catalog.is_empty() {
    text("-", role=Caption, theme~, width=650.0, height=28.0)
  } else {
    command_catalog_row(self.command_catalog[0], theme)
  }
}

///|
fn command_run_row(
  command : CommandRun,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      badge(
        command.status,
        tone=command_status_tone(command.status),
        theme~,
        width=104.0,
      ),
      column(
        [
          text(command.command, role=Control, theme~, width=356.0, height=24.0),
          text(
            command_detail_label(command),
            role=Caption,
            theme~,
            width=356.0,
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
        width=76.0,
        height=30.0,
      ),
      button(
        "重跑",
        on_click=QueueCommand(command.command),
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
fn command_exit_label(command : CommandRun) -> String {
  match command.exit_code {
    Some(code) => "exit " + code.to_string()
    None => command.status
  }
}

///|
fn command_detail_label(command : CommandRun) -> String {
  if command.output_path == "" {
    command.cwd
  } else {
    "output " + command.output_path
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
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      badge(file.change_kind, tone=Neutral, theme~, width=104.0),
      column(
        [
          text(file.path, role=Control, theme~, width=430.0, height=24.0),
          text(file.summary, role=Caption, theme~, width=430.0, height=22.0),
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
fn WorkbenchModel::workspace_digest_panel(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  surface(
    column(
      [
        row(
          [
            text("Workspace", role=Control, theme~, width=318.0, height=28.0),
            badge(
              self.files.length().to_string() + " files",
              tone=Neutral,
              theme~,
              width=86.0,
            ),
            badge(
              self.open_diagnostic_count().to_string() + " diag",
              tone=diagnostic_count_tone(self.open_diagnostic_count()),
              theme~,
              width=86.0,
            ),
            button(
              "清除",
              on_click=ClearDiagnostics,
              variant=Ghost,
              theme~,
              width=58.0,
              height=34.0,
            ),
            button(
              "审核",
              on_click=ReviewDiff,
              variant=Outline,
              theme~,
              width=64.0,
              height=34.0,
            ),
          ],
          spacing=8.0,
          align=Center,
        ),
        diff_digest_row(self.diff, theme),
        self.primary_file_context_row(theme),
        self.primary_diagnostic_row(theme),
      ],
      spacing=7.0,
      align=Start,
    ),
    width=690.0,
    height=178.0,
    background=@core.Color::white(),
    corner_radius=8.0,
    theme~,
    padding=12.0,
  )
}

///|
fn diagnostic_count_tone(count : Int) -> @views.BadgeTone {
  if count > 0 {
    Warning
  } else {
    Neutral
  }
}

///|
fn diff_digest_row(
  diff : DiffOverview,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      badge(diff.status, tone=Neutral, theme~, width=126.0),
      text(
        diff.changed_files.to_string() +
        " files · +" +
        diff.additions.to_string() +
        " -" +
        diff.deletions.to_string(),
        role=Caption,
        theme~,
        width=492.0,
        height=28.0,
      ),
    ],
    spacing=10.0,
    align=Center,
  )
}

///|
fn diagnostic_row(
  diagnostic : DiagnosticItem,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      badge(
        diagnostic.severity,
        tone=diagnostic_badge_tone(diagnostic.severity),
        theme~,
        width=104.0,
      ),
      column(
        [
          text(
            diagnostic.source,
            role=Control,
            theme~,
            width=520.0,
            height=24.0,
          ),
          text(
            diagnostic.message,
            role=Caption,
            theme~,
            width=520.0,
            height=22.0,
          ),
        ],
        spacing=0.0,
        align=Start,
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
fn WorkbenchModel::primary_file_context_row(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  if self.files.is_empty() {
    text("-", role=Caption, theme~, width=650.0, height=28.0)
  } else {
    file_context_row(self.files[0], theme)
  }
}

///|
fn WorkbenchModel::primary_diagnostic_row(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  if self.diagnostics.is_empty() {
    text("-", role=Caption, theme~, width=650.0, height=28.0)
  } else {
    diagnostic_row(self.diagnostics[self.diagnostics.length() - 1], theme)
  }
}

///|
fn WorkbenchModel::composer(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  surface(
    column(
      [
        text_field(
          self.prompt,
          on_input=value => PromptChanged(value),
          on_submit=Some(DispatchPrompt),
          placeholder="给 Pi 一个任务",
          variant=Plain,
          theme~,
          width=748.0,
          height=54.0,
        ),
        row(
          [
            button(
              "+",
              on_click=ToggleContext("repo"),
              variant=Ghost,
              theme~,
              width=38.0,
              height=34.0,
            ),
            badge("RPC", tone=Accent, theme~, width=54.0),
            button(
              self.steering_mode_label(),
              on_click=ToggleSteeringMode,
              variant=Outline,
              theme~,
              width=76.0,
              height=34.0,
            ),
            button(
              self.follow_up_mode_label(),
              on_click=ToggleFollowUpMode,
              variant=Outline,
              theme~,
              width=82.0,
              height=34.0,
            ),
            spacer(min_length=10.0, weight=1.0),
            button(
              "↑",
              on_click=DispatchPrompt,
              variant=Primary,
              theme~,
              width=42.0,
              height=36.0,
            ),
          ],
          spacing=8.0,
          align=Center,
        ),
      ],
      spacing=6.0,
      align=Stretch,
    ),
    width=760.0,
    height=126.0,
    background=@core.Color::white(),
    corner_radius=8.0,
    theme~,
    padding=12.0,
  )
}

///|
fn WorkbenchModel::steering_mode_label(self : WorkbenchModel) -> String {
  "Steer " + mode_short_label(self.pi_agent.steering_mode)
}

///|
fn WorkbenchModel::follow_up_mode_label(self : WorkbenchModel) -> String {
  "Follow " + mode_short_label(self.pi_agent.follow_up_mode)
}

///|
fn mode_short_label(mode : String) -> String {
  if mode == "all" {
    "all"
  } else {
    "1"
  }
}

///|
fn WorkbenchModel::sidebar_section_label(
  self : WorkbenchModel,
  label : String,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  text(label, role=Caption, theme~, width=246.0, height=30.0)
}

///|
fn divider(width : Double) -> @core.View[WorkbenchMsg] {
  surface(
    empty(),
    width~,
    height=1.0,
    background=ui_color(0.90, 0.90, 0.90),
    padding=0.0,
  )
}

///|
fn ui_color(r : Double, g : Double, b : Double) -> @core.Color {
  @core.Color::rgba(r~, g~, b~)
}
