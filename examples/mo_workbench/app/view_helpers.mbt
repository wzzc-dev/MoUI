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
          self.pending_transport_count().to_string() + " queued transport",
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
    corner_radius=10.0,
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
      self.command_catalog_panel(theme),
      self.command_evidence_panel(theme),
      self.context_panel(theme),
      self.diff_summary_card(theme),
    ],
    spacing=12.0,
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
    rows.push(
      text(
        "No Pi messages loaded yet",
        role=Caption,
        theme~,
        width=650.0,
        height=28.0,
      ),
    )
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
    corner_radius=10.0,
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
fn WorkbenchModel::command_catalog_panel(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let rows : Array[@core.View[WorkbenchMsg]] = []
  let mut visible = 0
  for command in self.command_catalog {
    if visible < 3 {
      rows.push(command_catalog_row(command, theme))
      visible = visible + 1
    }
  }
  if rows.is_empty() {
    rows.push(
      text(
        "No Pi commands loaded yet",
        role=Caption,
        theme~,
        width=650.0,
        height=28.0,
      ),
    )
  }
  surface(
    column(
      [
        row(
          [
            text("Pi commands", role=Control, theme~, width=520.0, height=28.0),
            badge(
              self.command_catalog.length().to_string() + " commands",
              tone=Accent,
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
    corner_radius=10.0,
    theme~,
    padding=12.0,
  )
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
            width=520.0,
            height=24.0,
          ),
          text(
            command_catalog_detail(command),
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
            text(
              "Session status",
              role=Control,
              theme~,
              width=368.0,
              height=28.0,
            ),
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
              "思考",
              on_click=CycleThinkingLevel,
              variant=Outline,
              theme~,
              width=62.0,
              height=34.0,
            ),
            button(
              "同步标题",
              on_click=SyncSessionName,
              variant=Outline,
              theme~,
              width=86.0,
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
fn WorkbenchModel::command_evidence_panel(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let rows : Array[@core.View[WorkbenchMsg]] = []
  let mut visible = 0
  for command in self.commands {
    if visible < 3 {
      rows.push(command_run_row(command, theme))
      visible = visible + 1
    }
  }
  if rows.is_empty() {
    rows.push(
      text(
        "No command evidence",
        role=Caption,
        theme~,
        width=650.0,
        height=28.0,
      ),
    )
  }
  surface(
    column(
      [
        row(
          [
            text(
              "Command evidence",
              role=Control,
              theme~,
              width=520.0,
              height=28.0,
            ),
            badge(
              self.commands.length().to_string() + " runs",
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
    corner_radius=10.0,
    theme~,
    padding=12.0,
  )
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
          text(command.command, role=Control, theme~, width=420.0, height=24.0),
          text(command.cwd, role=Caption, theme~, width=420.0, height=22.0),
        ],
        spacing=0.0,
        align=Start,
      ),
      text(
        command_exit_label(command),
        role=Caption,
        theme~,
        width=86.0,
        height=30.0,
      ),
    ],
    spacing=10.0,
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
fn WorkbenchModel::context_panel(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let rows : Array[@core.View[WorkbenchMsg]] = []
  let mut visible = 0
  for file in self.files {
    if visible < 3 {
      rows.push(file_context_row(file, theme))
      visible = visible + 1
    }
  }
  if rows.is_empty() {
    rows.push(
      text("No file context", role=Caption, theme~, width=650.0, height=28.0),
    )
  }
  surface(
    column(
      [
        row(
          [
            text(
              "Context files",
              role=Control,
              theme~,
              width=520.0,
              height=28.0,
            ),
            badge(
              self.files.length().to_string() + " files",
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
    corner_radius=10.0,
    theme~,
    padding=12.0,
  )
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
          text(file.path, role=Control, theme~, width=520.0, height=24.0),
          text(file.summary, role=Caption, theme~, width=520.0, height=22.0),
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
fn WorkbenchModel::diff_summary_card(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  surface(
    column(
      [
        row(
          [
            column(
              [
                text(
                  "Diff summary · " + self.diff.status,
                  role=Control,
                  theme~,
                  width=350.0,
                  height=26.0,
                ),
                text(
                  self.diff.changed_files.to_string() +
                  " files · +" +
                  self.diff.additions.to_string() +
                  " -" +
                  self.diff.deletions.to_string(),
                  role=Caption,
                  theme~,
                  width=350.0,
                  height=24.0,
                ),
              ],
              spacing=0.0,
              align=Start,
            ),
            spacer(min_length=8.0, weight=1.0),
            button(
              "停止",
              on_click=CancelRun,
              variant=Ghost,
              theme~,
              width=74.0,
              height=34.0,
            ),
            button(
              "审核",
              on_click=SelectPanel("files"),
              variant=Outline,
              theme~,
              width=64.0,
              height=34.0,
            ),
          ],
          spacing=8.0,
          align=Center,
        ),
      ],
      spacing=8.0,
      align=Start,
    ),
    width=690.0,
    height=80.0,
    background=@core.Color::white(),
    corner_radius=10.0,
    theme~,
    padding=12.0,
  )
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
          placeholder="要求后续变更",
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
            badge("Pi RPC", tone=Accent, theme~, width=76.0),
            badge("Skia native", tone=Success, theme~, width=104.0),
            spacer(min_length=10.0, weight=1.0),
            text(
              self.active_session().status,
              role=Caption,
              theme~,
              width=72.0,
              height=30.0,
            ),
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
    corner_radius=18.0,
    theme~,
    padding=12.0,
  )
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
