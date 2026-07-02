// Static product-shaped workspaces for routes whose backend workflows are not
// wired yet. These are UI shells only; no persistence or runtime integration.

///|
fn write_workspace_view(
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  let left_width = (width * 0.58).max(340.0)
  let right_width = (width - left_width - 24.0).max(260.0)
  @views.container(
    @views.row(
      [
        static_document_panel(theme, left_width, height - 48.0),
        static_assistant_panel(theme, right_width, height - 48.0),
      ],
      spacing=24.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height~,
    background=workbench_canvas_background(theme),
    padding=24.0,
  )
}

///|
fn connect_phone_workspace_view(
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  let timeline_width = (width * 0.62).max(360.0)
  let setup_width = (width - timeline_width - 24.0).max(260.0)
  @views.container(
    @views.row(
      [
        static_timeline_panel(
          "Connect Phone",
          [
            ("System", "Feishu channel is ready for a manual test."),
            ("Agent", "Use a separate thread per channel and workspace root."),
            ("Tool", "Webhook relay and scheduled tasks are reserved."),
          ],
          theme,
          timeline_width,
          height - 48.0,
        ),
        static_stack_panel(
          "Channel Setup",
          [
            "Pick IM provider", "Set default model", "Choose workspace root", "Run manual task",
          ],
          theme,
          setup_width,
          height - 48.0,
        ),
      ],
      spacing=24.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height~,
    background=workbench_canvas_background(theme),
    padding=24.0,
  )
}

///|
fn scheduled_tasks_workspace_view(
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.container(
    @views.column(
      [
        workspace_headline(
          "Scheduled Tasks",
          "Prepare repeatable prompts and review their next run windows.",
          theme,
          width - 48.0,
        ),
        @views.row(
          [
            schedule_card(
              "Daily standup",
              "Every weekday at 09:00",
              "Ready",
              theme,
              (width - 72.0) / 3.0,
            ),
            schedule_card(
              "Dependency audit",
              "Friday at 16:00",
              "Paused",
              theme,
              (width - 72.0) / 3.0,
            ),
            schedule_card(
              "Manual release check",
              "Run on demand",
              "Draft",
              theme,
              (width - 72.0) / 3.0,
            ),
          ],
          spacing=16.0,
          align=@views.CrossAlign::Start,
        ),
        static_stack_panel(
          "Task Defaults",
          [
            "Model: V4 Pro", "Thinking: Max", "Sandbox: workspace", "Approval: ask on write",
          ],
          theme,
          width - 48.0,
          220.0,
        ),
      ],
      spacing=22.0,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    height~,
    background=workbench_canvas_background(theme),
    padding=24.0,
  )
}

///|
fn plugins_workspace_view(
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.container(
    @views.column(
      [
        workspace_headline(
          "Plugins, Skills, and MCP",
          "Inspect capability groups without changing runtime configuration.",
          theme,
          width - 48.0,
        ),
        @views.row(
          [
            capability_card(
              "Skills",
              "Reusable workflows",
              "Enabled",
              workbench_skill_soft(theme),
              theme,
              (width - 72.0) / 3.0,
            ),
            capability_card(
              "MCP servers",
              "External tool catalogs",
              "Reserved",
              workbench_accent_soft(theme),
              theme,
              (width - 72.0) / 3.0,
            ),
            capability_card(
              "Web tools",
              "Fetch and search",
              "Reserved",
              workbench_diff_added_soft(theme),
              theme,
              (width - 72.0) / 3.0,
            ),
          ],
          spacing=16.0,
          align=@views.CrossAlign::Start,
        ),
        static_stack_panel(
          "Capability Diagnostics",
          [
            "No runtime provider connected", "No MCP catalog loaded", "No install action is wired in this prototype",
          ],
          theme,
          width - 48.0,
          220.0,
        ),
      ],
      spacing=18.0,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    height~,
    background=workbench_canvas_background(theme),
    padding=24.0,
  )
}

///|
fn static_document_panel(
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.container(
    @views.column(
      [
        workspace_headline(
          "Release notes draft.md",
          "Live Markdown editor placeholder",
          theme,
          width - 32.0,
        ),
        @views.container(
          @views.text(
            "# Mo Workbench UI Refactor\n\n- Standard three-pane shell\n- Product-shaped static routes\n- Inspector panels for context, todo, plan, and changes\n\nThe real Write editor will reuse the Markdown editor package later.",
            role=@views.TextRole::Body,
            theme~,
            width=width - 48.0,
          ),
          width=width - 32.0,
          height=height - 124.0,
          background=workbench_card_background(theme),
        corner_radius=10.0,
        padding=20.0,
      ).border(hairline_border(theme)),
      ],
      spacing=20.0,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    height~,
    background=workbench_canvas_background(theme),
    padding=0.0,
  )
}

///|
fn static_assistant_panel(
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  static_stack_panel(
    "Write Assistant",
    [
      "Summarize current section", "Rewrite selected text", "Continue with a concise paragraph",
      "Export: HTML / PDF / DOCX",
    ],
    theme,
    width,
    height,
  )
}

///|
fn static_timeline_panel(
  title : String,
  rows : Array[(String, String)],
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  let views : Array[@moui.View[WorkbenchMsg]] = [
    workspace_headline(
      title,
      "Message timeline placeholder",
      theme,
      width - 32.0,
    ),
  ]
  for item in rows {
    let (label, body) = item
    views.push(
      @views.container(
        @views.column(
          [
            @views.badge(
              label,
              tone=@views.BadgeTone::Neutral,
              theme~,
              width=96.0,
            ),
            @views.text(
              body,
              role=@views.TextRole::Body,
              theme~,
              width=width - 56.0,
            ),
          ],
          spacing=10.0,
          align=@views.CrossAlign::Start,
        ),
        width=width - 32.0,
        background=workbench_card_background(theme),
        corner_radius=10.0,
        padding=14.0,
      ).border(hairline_border(theme)),
    )
  }
  @views.container(
    @views.column(views, spacing=14.0, align=@views.CrossAlign::Stretch),
    width~,
    height~,
    background=workbench_canvas_background(theme),
    padding=0.0,
  )
}

///|
fn static_stack_panel(
  title : String,
  items : Array[String],
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  let rows : Array[@moui.View[WorkbenchMsg]] = [
    @views.text(
      title,
      role=@views.TextRole::Subtitle,
      theme~,
      width=width - 32.0,
    ),
  ]
  for item in items {
    rows.push(
      @views.container(
        @views.text(
          item,
          role=@views.TextRole::Caption,
          theme~,
          width=width - 56.0,
        ).foreground(theme.palette.muted),
        width=width - 32.0,
        background=workbench_subtle_background(theme),
        corner_radius=8.0,
        padding=12.0,
      ),
    )
  }
  @views.container(
    @views.column(rows, spacing=12.0, align=@views.CrossAlign::Stretch),
    width~,
    height~,
    background=workbench_card_background(theme),
    corner_radius=10.0,
    padding=18.0,
  ).border(hairline_border(theme))
}

///|
fn workspace_headline(
  title : String,
  subtitle : String,
  theme : @core.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.column(
    [
      @views.text(title, role=@views.TextRole::Title, theme~, width~),
      @views.text(subtitle, role=@views.TextRole::Caption, theme~, width~).foreground(
        theme.palette.muted,
      ),
    ],
    spacing=6.0,
    align=@views.CrossAlign::Start,
  )
}

///|
fn schedule_card(
  title : String,
  cadence : String,
  state : String,
  theme : @core.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.container(
    @views.column(
      [
        @views.badge(state, tone=@views.BadgeTone::Neutral, theme~, width=84.0),
        @views.text(
          title,
          role=@views.TextRole::Label,
          theme~,
          width=width - 24.0,
        ),
        @views.text(
          cadence,
          role=@views.TextRole::Caption,
          theme~,
          width=width - 24.0,
        ).foreground(theme.palette.muted),
      ],
      spacing=10.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    background=workbench_card_background(theme),
    corner_radius=10.0,
    padding=14.0,
  ).border(hairline_border(theme))
}

///|
fn capability_card(
  title : String,
  detail : String,
  state : String,
  background : @core.Color,
  theme : @core.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.container(
    @views.column(
      [
        @views.badge(state, tone=@views.BadgeTone::Accent, theme~, width=92.0),
        @views.text(
          title,
          role=@views.TextRole::Label,
          theme~,
          width=width - 24.0,
        ),
        @views.text(
          detail,
          role=@views.TextRole::Caption,
          theme~,
          width=width - 24.0,
        ).foreground(theme.palette.muted),
      ],
      spacing=10.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    background~,
    corner_radius=10.0,
    padding=14.0,
  ).border(hairline_border(theme))
}
