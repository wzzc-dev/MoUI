///|
using @views {
  badge,
  button,
  column,
  row,
  scroll_view,
  sidebar,
  split_view,
  stat_card,
  status_bar,
  surface,
  tab_item,
  tab_view,
  table,
  table_column,
  text,
  text_field,
  toolbar,
  tree_item,
  tree_view,
}

///|
pub fn WorkbenchModel::view(self : WorkbenchModel) -> @core.View[WorkbenchMsg] {
  let theme = @views.light_theme()
  let active = self.active_session()
  let body = column(
    [
      self.header(theme, active),
      self.summary_row(theme),
      split_view(
        primary=self.session_sidebar(theme),
        detail=self.detail_panel(theme, active),
        primary_width=268.0,
        detail_width=856.0,
        height=550.0,
        spacing=theme.spacing_scale.md,
      ),
      status_bar(
        [
          self.last_status,
          "Transport: " + self.transport.status_label(),
          "Queued: " + self.pending_transport_count().to_string(),
          "Diagnostics: " + self.open_diagnostic_count().to_string(),
        ],
        theme~,
        width=1160.0,
      ),
    ],
    spacing=theme.spacing_scale.md,
    align=Stretch,
  )
  surface(
    body,
    width=1200.0,
    height=750.0,
    variant=Base,
    theme~,
    padding=theme.spacing_scale.lg,
  )
}

///|
fn WorkbenchModel::header(
  self : WorkbenchModel,
  theme : @core.Theme,
  active : WorkbenchSession,
) -> @core.View[WorkbenchMsg] {
  ignore(self)
  row(
    [
      column(
        [
          text("Mo Workbench", role=Title, theme~, width=260.0, height=36.0),
          text(
            "A Pi agent desktop",
            role=Caption,
            theme~,
            width=220.0,
            height=24.0,
          ),
        ],
        spacing=0.0,
        align=Start,
      ),
      badge("macOS Skia", tone=Accent, theme~, width=104.0),
      badge("Pi JSONL RPC", tone=Success, theme~, width=118.0),
      text(active.project_path, role=Mono, theme~, width=430.0, height=28.0),
    ],
    spacing=theme.spacing_scale.md,
    align=Center,
  )
}

///|
fn WorkbenchModel::summary_row(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      stat_card(
        "Sessions",
        self.sessions.length().to_string(),
        caption="project workspaces",
        tone=Info,
        theme~,
        width=198.0,
        height=104.0,
      ),
      stat_card(
        "Context Files",
        self.files.length().to_string(),
        caption="diff and repo scope",
        tone=Success,
        theme~,
        width=198.0,
        height=104.0,
      ),
      stat_card(
        "Queued",
        self.pending_transport_count().to_string(),
        caption="transport commands",
        tone=Warning,
        theme~,
        width=198.0,
        height=104.0,
      ),
      stat_card(
        "Diagnostics",
        self.open_diagnostic_count().to_string(),
        caption="open notes",
        tone=Danger,
        theme~,
        width=198.0,
        height=104.0,
      ),
    ],
    spacing=theme.spacing_scale.md,
    align=Start,
  )
}

///|
fn WorkbenchModel::session_sidebar(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let items : Array[@views.SidebarItem[WorkbenchMsg]] = []
  for session in self.sessions {
    items.push(
      @views.SidebarItem::new(
        id=session.id,
        label=session.title,
        message=SelectSession(session.id),
      ),
    )
  }
  column(
    [
      sidebar(
        "Project Sessions",
        items,
        selected=self.selected_session_id,
        theme~,
        width=252.0,
        height=190.0,
      ),
      self.session_summary(theme),
    ],
    spacing=theme.spacing_scale.md,
    align=Stretch,
  )
}

///|
fn WorkbenchModel::session_summary(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let active = self.active_session()
  surface(
    column(
      [
        text("Active Task", role=Control, theme~, width=214.0, height=26.0),
        text(active.active_task, role=Body, theme~, width=214.0, height=56.0),
        text(
          "Branch: " + active.branch,
          role=Mono,
          theme~,
          width=214.0,
          height=28.0,
        ),
        text(
          "Status: " + active.status,
          role=Caption,
          theme~,
          width=214.0,
          height=24.0,
        ),
      ],
      spacing=theme.spacing_scale.xs,
      align=Start,
    ),
    width=252.0,
    height=178.0,
    variant=Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
}

///|
fn WorkbenchModel::detail_panel(
  self : WorkbenchModel,
  theme : @core.Theme,
  active : WorkbenchSession,
) -> @core.View[WorkbenchMsg] {
  let tabs = [
    tab_item(route="agent", label="Agent", view=self.agent_panel(theme, active)),
    tab_item(route="plan", label="Plan", view=self.plan_panel(theme)),
    tab_item(route="files", label="Files", view=self.files_panel(theme)),
    tab_item(
      route="commands",
      label="Commands",
      view=self.commands_panel(theme),
    ),
    tab_item(
      route="diagnostics",
      label="Diagnostics",
      view=self.diagnostics_panel(theme),
    ),
  ]
  surface(
    column(
      [
        self.prompt_bar(theme),
        tab_view(self.selected_panel, tabs, on_select=panel => {
          SelectPanel(panel)
        }),
      ],
      spacing=theme.spacing_scale.md,
      align=Stretch,
    ),
    width=856.0,
    height=550.0,
    variant=Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
}

///|
fn WorkbenchModel::prompt_bar(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  toolbar(
    [
      text_field(
        self.prompt,
        on_input=value => PromptChanged(value),
        on_submit=Some(DispatchPrompt),
        placeholder="Ask Pi to inspect code, plan changes, run a check...",
        variant=Outline,
        theme~,
        width=518.0,
        height=40.0,
      ),
      button(
        "Send",
        on_click=DispatchPrompt,
        variant=Primary,
        theme~,
        width=82.0,
        height=38.0,
      ),
      button(
        "Cancel",
        on_click=CancelRun,
        variant=Outline,
        theme~,
        width=86.0,
        height=38.0,
      ),
    ],
    theme~,
    width=810.0,
  )
}

///|
fn WorkbenchModel::agent_panel(
  self : WorkbenchModel,
  theme : @core.Theme,
  active : WorkbenchSession,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      surface(
        scroll_view(self.event_timeline(theme), width=520.0, height=332.0),
        width=544.0,
        height=356.0,
        variant=Base,
        theme~,
        padding=theme.spacing_scale.sm,
      ),
      self.transport_panel(theme, active),
    ],
    spacing=theme.spacing_scale.md,
    align=Start,
  )
}

///|
fn WorkbenchModel::event_timeline(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let rows : Array[@core.View[WorkbenchMsg]] = []
  for event in self.events {
    rows.push(
      column(
        [
          row(
            [
              badge(event.phase, tone=event.badge_tone(), theme~, width=92.0),
              text(event.title, role=Control, theme~, width=372.0, height=26.0),
            ],
            spacing=theme.spacing_scale.sm,
            align=Center,
          ),
          text(event.detail, role=Body, theme~, width=484.0, height=42.0),
        ],
        spacing=theme.spacing_scale.xs,
        align=Start,
      ),
    )
  }
  column(rows, spacing=theme.spacing_scale.md, align=Start)
}

///|
fn WorkbenchModel::transport_panel(
  self : WorkbenchModel,
  theme : @core.Theme,
  active : WorkbenchSession,
) -> @core.View[WorkbenchMsg] {
  surface(
    column(
      [
        text("PiTransport", role=Control, theme~, width=240.0, height=28.0),
        text(
          self.transport.kind.label(),
          role=Caption,
          theme~,
          width=240.0,
          height=24.0,
        ),
        text(
          "Session: " + active.id,
          role=Mono,
          theme~,
          width=240.0,
          height=28.0,
        ),
        text(
          "Status: " + self.transport.status_label(),
          role=Body,
          theme~,
          width=240.0,
          height=28.0,
        ),
        text("Last JSONL", role=Caption, theme~, width=240.0, height=24.0),
        text(
          self.transport.last_json_line,
          role=Mono,
          theme~,
          width=240.0,
          height=54.0,
        ),
        text("Queued commands", role=Caption, theme~, width=240.0, height=24.0),
        text(
          self.transport_queue_label(),
          role=Mono,
          theme~,
          width=240.0,
          height=74.0,
        ),
      ],
      spacing=theme.spacing_scale.xs,
      align=Start,
    ),
    width=276.0,
    height=356.0,
    variant=Base,
    theme~,
    padding=theme.spacing_scale.md,
  )
}

///|
fn WorkbenchModel::plan_panel(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  table(
    [
      table_column(id="status", label="Status", width=92.0),
      table_column(id="title", label="Plan Item", width=274.0),
      table_column(id="owner", label="Owner", width=90.0),
      table_column(id="detail", label="Detail", width=314.0),
    ],
    self.plan.map(step => [step.status, step.title, step.owner, step.detail]),
    theme~,
  )
}

///|
fn WorkbenchModel::files_panel(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  row(
    [
      tree_view(
        [
          tree_item(id="repo", label="MoUI", children=[
            tree_item(id="examples", label="examples", children=[
              tree_item(id="mo_workbench", label="mo_workbench"),
            ]),
            tree_item(id="render", label="render/skia"),
            tree_item(id="backend", label="backend/macos/skia"),
          ]),
        ],
        expanded=self.expanded_context,
        selected="mo_workbench",
        on_toggle=Some(id => ToggleContext(id)),
        theme~,
        width=250.0,
      ),
      table(
        [
          table_column(id="path", label="Path", width=278.0),
          table_column(id="kind", label="Kind", width=86.0),
          table_column(id="lines", label="Lines", width=74.0),
          table_column(id="summary", label="Summary", width=284.0),
        ],
        self.files.map(file => {
          [
            file.path,
            file.change_kind,
            file.lines_changed.to_string(),
            file.summary,
          ]
        }),
        theme~,
      ),
    ],
    spacing=theme.spacing_scale.md,
    align=Start,
  )
}

///|
fn WorkbenchModel::commands_panel(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  column(
    [
      row(
        [
          button(
            "Queue Tests",
            on_click=QueueCommand(
              "moon test examples/mo_workbench/app --target native",
            ),
            variant=Primary,
            theme~,
            width=126.0,
            height=36.0,
          ),
          button(
            "Queue Build",
            on_click=QueueCommand(
              "moon build examples/mo_workbench/macos_skia --target native",
            ),
            variant=Outline,
            theme~,
            width=126.0,
            height=36.0,
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=Center,
      ),
      table(
        [
          table_column(id="command", label="Command", width=420.0),
          table_column(id="cwd", label="CWD", width=210.0),
          table_column(id="status", label="Status", width=118.0),
        ],
        self.commands.map(command => {
          [command.command, command.cwd, command.status_label()]
        }),
        theme~,
      ),
    ],
    spacing=theme.spacing_scale.md,
    align=Start,
  )
}

///|
fn WorkbenchModel::diagnostics_panel(
  self : WorkbenchModel,
  theme : @core.Theme,
) -> @core.View[WorkbenchMsg] {
  let body : @core.View[WorkbenchMsg] = if self.diagnostics.length() == 0 {
    @views.empty_state(
      "No diagnostics",
      "The current session has no open notes.",
      theme~,
      width=420.0,
    )
  } else {
    table(
      [
        table_column(id="source", label="Source", width=142.0),
        table_column(id="severity", label="Severity", width=94.0),
        table_column(id="message", label="Message", width=500.0),
      ],
      self.diagnostics.map(item => [item.source, item.severity, item.message]),
      theme~,
    )
  }
  column(
    [
      button(
        "Clear Diagnostics",
        on_click=ClearDiagnostics,
        variant=Outline,
        theme~,
        width=152.0,
        height=36.0,
      ),
      body,
    ],
    spacing=theme.spacing_scale.md,
    align=Start,
  )
}

///|
fn AgentEvent::badge_tone(self : AgentEvent) -> @views.BadgeTone {
  match self.tone {
    "success" => Success
    "warning" => Warning
    "danger" => Danger
    "info" => Accent
    _ => Neutral
  }
}

///|
fn CommandRun::status_label(self : CommandRun) -> String {
  match self.exit_code {
    Some(code) => self.status + " (" + code.to_string() + ")"
    None => self.status
  }
}

///|
fn WorkbenchModel::transport_queue_label(self : WorkbenchModel) -> String {
  if self.transport.command_queue.length() == 0 {
    "none"
  } else {
    self.transport.command_queue[0].label()
  }
}
