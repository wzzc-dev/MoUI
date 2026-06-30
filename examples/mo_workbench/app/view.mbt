// Codex-style minimal layout: sidebar + main surface (top bar + message list + composer).

///|
/// The top-level view. Uses the environment for viewport size and theme.
fn workbench_view(
  model : WorkbenchModel,
  env : @core.ViewEnvironment,
) -> @moui.View[WorkbenchMsg] {
  let theme = workbench_theme(model.appearance, env)
  let viewport = env.viewport_size()
  let sidebar_width = 220.0
  let main_width = (viewport.width - sidebar_width).max(320.0)
  let main_height = viewport.height
  @views.container(
    @views.row(
      [
        sidebar_view(model, theme, sidebar_width, main_height),
        main_surface(model, theme, main_width, main_height),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Stretch,
    ),
    width=viewport.width,
    height=viewport.height,
    background=panel_background(theme),
  )
}

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------

///|
fn sidebar_view(
  model : WorkbenchModel,
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  let rows : Array[@moui.View[WorkbenchMsg]] = []
  // Brand
  rows.push(
    @views.padding_xy(
      @views.text(
        "Mo Workbench",
        role=@views.TextRole::Title,
        theme~,
        width=width - 32.0,
      ),
      horizontal=16.0,
      vertical=16.0,
    ),
  )
  // New session button
  rows.push(
    @views.padding_xy(
      @views.button(
        "New Chat",
        on_click=WorkbenchMsg::NewSession,
        variant=@views.ButtonVariant::Primary,
        width=width - 32.0,
      ),
      horizontal=16.0,
      vertical=4.0,
    ),
  )
  // Session list label
  rows.push(
    @views.padding_xy(
      @views.text(
        "History",
        role=@views.TextRole::Overline,
        theme~,
        width=width - 32.0,
      ).foreground(theme.palette.muted),
      horizontal=16.0,
      vertical=12.0,
    ),
  )
  // Session list
  if model.sessions.is_empty() {
    rows.push(
      @views.padding_xy(
        @views.text(
          "No sessions yet",
          role=@views.TextRole::Caption,
          theme~,
          width=width - 32.0,
        ).foreground(theme.palette.muted),
        horizontal=16.0,
        vertical=4.0,
      ),
    )
  } else {
    let session_rows : Array[@moui.View[WorkbenchMsg]] = []
    for s in model.sessions {
      let is_active = model.active_session_id == Some(s.id)
      let label = if s.first_prompt.is_empty() { s.id } else { s.first_prompt }
      let truncated = truncate_text(label, 24)
      session_rows.push(session_row(s.id, truncated, is_active, width - 32.0))
    }
    rows.push(
      @views.padding_xy(
        @views.list(session_rows, spacing=2.0),
        horizontal=16.0,
        vertical=0.0,
      ),
    )
  }
  rows.push(@views.spacer())
  // Appearance toggle at the bottom
  rows.push(
    @views.padding_xy(
      @views.button(
        appearance_label(model.appearance),
        on_click=WorkbenchMsg::ToggleAppearance,
        variant=@views.ButtonVariant::Ghost,
        width=width - 32.0,
      ),
      horizontal=16.0,
      vertical=12.0,
    ),
  )
  @views.container(
    @views.column(rows, spacing=0.0, align=@views.CrossAlign::Stretch),
    width~,
    height~,
    background=sidebar_background(theme),
  ).border(hairline_border(theme))
}

///|
fn session_row(
  id : String,
  label : String,
  is_active : Bool,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  // A ghost button acts as the clickable row; active state is conveyed by the
  // label prefix. Keeping it simple avoids needing a custom clickable container.
  let prefix = if is_active { "● " } else { "  " }
  @views.button(
    prefix + label,
    on_click=WorkbenchMsg::SelectSession(id),
    variant=@views.ButtonVariant::Ghost,
    width~,
    height=36.0,
  )
}

///|
fn appearance_label(appearance : AppearanceMode) -> String {
  match appearance {
    System => "Appearance: System"
    Light => "Appearance: Light"
    Dark => "Appearance: Dark"
  }
}

// ---------------------------------------------------------------------------
// Main surface: top bar + message list + composer
// ---------------------------------------------------------------------------

///|
fn main_surface(
  model : WorkbenchModel,
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  let top_bar_height = 48.0
  let composer_height = 96.0
  let list_height = (height - top_bar_height - composer_height).max(120.0)
  @views.column(
    [
      top_bar(model, theme, width, top_bar_height),
      @views.divider(theme~),
      message_list(model, theme, width, list_height),
      @views.divider(theme~),
      composer(model, theme, width, composer_height),
    ],
    spacing=0.0,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn top_bar(
  model : WorkbenchModel,
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  let model_label = match model.current_model {
    V4Flash => "V4 Flash"
    V4Pro => "V4 Pro"
  }
  let thinking_label = match model.current_thinking {
    No => "Think: Off"
    High => "Think: High"
    Max => "Think: Max"
  }
  let status = if model.is_streaming {
    @views.PresenceStatus::Busy
  } else {
    @views.PresenceStatus::Available
  }
  let session_label = match model.active_session_id {
    Some(id) => truncate_text(id, 20)
    None => "New Chat"
  }
  @views.container(
    @views.row(
      [
        @views.padding_xy(
          @views.badge(
            model_label,
            tone=@views.BadgeTone::Accent,
            theme~,
            width=80.0,
          ),
          horizontal=0.0,
          vertical=0.0,
        ),
        @views.badge(
          thinking_label,
          tone=@views.BadgeTone::Neutral,
          theme~,
          width=96.0,
        ),
        @views.spacer(),
        @views.text(
          session_label,
          role=@views.TextRole::Label,
          theme~,
          width=160.0,
        ),
        @views.presence_dot(status, theme~),
      ],
      spacing=12.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height~,
    background=panel_background(theme),
    padding=12.0,
  )
}

///|
fn message_list(
  model : WorkbenchModel,
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  let inner_width = width - 32.0
  if model.messages.is_empty() {
    @views.container(
      @views.column(
        [
          @views.spacer(),
          @views.text(
            "Start a new conversation",
            role=@views.TextRole::Subtitle,
            theme~,
            width=inner_width,
          ).foreground(theme.palette.muted),
          @views.text(
            "Give the agent a task in the box below.",
            role=@views.TextRole::Caption,
            theme~,
            width=inner_width,
          ).foreground(theme.palette.muted),
          @views.spacer(),
        ],
        align=@views.CrossAlign::Center,
      ),
      width~,
      height~,
      padding=16.0,
    )
  } else {
    let rows : Array[@moui.View[WorkbenchMsg]] = []
    for msg in model.messages {
      rows.push(message_row(msg, theme, inner_width))
    }
    @views.container(
      @views.scroll_view(
        @views.list(rows, spacing=4.0),
        state=Some(model.scroll_state),
        width~,
        height~,
      ),
      width~,
      height~,
      padding=16.0,
    )
  }
}

///|
fn composer(
  model : WorkbenchModel,
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @moui.View[WorkbenchMsg] {
  let input_width = width - 32.0
  let rows : Array[@moui.View[WorkbenchMsg]] = []
  // Error line (if any)
  match model.error {
    Some(err) =>
      rows.push(
        @views.text(
          err,
          role=@views.TextRole::Caption,
          theme~,
          width=input_width,
        ).foreground(theme.palette.danger),
      )
    None => ()
  }
  // Main input row
  rows.push(
    @views.row(
      [
        @views.text_field(
          model.prompt,
          on_input=value => WorkbenchMsg::PromptChanged(value),
          on_submit=Some(WorkbenchMsg::SubmitPrompt),
          placeholder="Give the agent a task…",
          variant=@views.TextFieldVariant::Plain,
          width=input_width - 96.0,
          height=40.0,
        ),
        @views.button(
          "Send",
          on_click=WorkbenchMsg::SubmitPrompt,
          variant=@views.ButtonVariant::Primary,
          width=80.0,
        ),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    ),
  )
  // Steering row (only visible while streaming)
  if model.is_streaming {
    rows.push(
      @views.row(
        [
          @views.text_field(
            model.steer_text,
            on_input=value => WorkbenchMsg::SteerChanged(value),
            on_submit=Some(WorkbenchMsg::SubmitSteer),
            placeholder="Steer (optional)…",
            variant=@views.TextFieldVariant::Plain,
            width=input_width - 96.0,
            height=32.0,
          ),
          @views.button(
            "Steer",
            on_click=WorkbenchMsg::SubmitSteer,
            variant=@views.ButtonVariant::Ghost,
            width=80.0,
          ),
        ],
        spacing=8.0,
        align=@views.CrossAlign::Center,
      ),
    )
  }
  @views.container(
    @views.column(rows, spacing=6.0, align=@views.CrossAlign::Stretch),
    width~,
    height~,
    background=panel_background(theme),
    padding=16.0,
  )
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

///|
fn truncate_text(text : String, max : Int) -> String {
  let chars = text.to_array()
  if chars.length() <= max {
    text
  } else {
    let buf = StringBuilder::new()
    for c in chars[0:max] {
      buf.write_char(c)
    }
    buf.write_char('…')
    buf.to_string()
  }
}
