// Message row rendering for the chat transcript.

///|
/// Render a single chat message as a view.
fn message_row(
  msg : ChatMessage,
  theme : @core.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  match msg {
    User(text) => user_message_row(text, theme, width)
    Assistant(content, reasoning) =>
      assistant_message_row(content, reasoning, theme, width)
    ToolResult(tool_name, content, is_error, brief) =>
      tool_result_row(tool_name, content, is_error, brief, theme, width)
    RuntimeNotice(text) => runtime_notice_row(text, theme, width)
    Terminal(status, message) => terminal_row(status, message, theme, width)
  }
}

///|
fn user_message_row(
  text_ : String,
  theme : @core.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  let bubble_width = width * 0.75
  @views.container(
    @views.row(
      [
        @views.spacer(),
        @views.container(
          @views.text(
            text_,
            role=@views.TextRole::Body,
            theme~,
            width=bubble_width - 24.0,
          ),
          width=bubble_width,
          background=user_message_background(theme),
          corner_radius=12.0,
          padding=12.0,
        ),
      ],
      align=@views.CrossAlign::Start,
    ),
    width~,
    padding=4.0,
  )
}

///|
fn assistant_message_row(
  content : String,
  reasoning : String?,
  theme : @core.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  let bubble_width = width * 0.85
  let rows : Array[@moui.View[WorkbenchMsg]] = []
  // Optional reasoning shown as a collapsed muted block above the content.
  match reasoning {
    Some(r) =>
      if !r.is_empty() {
        rows.push(
          @views.container(
            @views.text(
              r,
              role=@views.TextRole::Caption,
              theme~,
              width=bubble_width - 24.0,
            ).foreground(theme.palette.muted),
            width=bubble_width,
            padding=8.0,
          ),
        )
      }
    None => ()
  }
  rows.push(
    @views.text(
      content,
      role=@views.TextRole::Body,
      theme~,
      width=bubble_width - 24.0,
    ),
  )
  @views.container(
    @views.row(
      [
        @views.container(
          @views.column(rows, spacing=4.0, align=@views.CrossAlign::Start),
          width=bubble_width,
          background=assistant_message_background(theme),
          corner_radius=12.0,
          padding=12.0,
        ),
        @views.spacer(),
      ],
      align=@views.CrossAlign::Start,
    ),
    width~,
    padding=4.0,
  )
}

///|
fn tool_result_row(
  tool_name : String,
  content : String,
  is_error : Bool,
  brief : String?,
  theme : @core.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  let card_width = width * 0.9
  let tone = if is_error {
    @views.BadgeTone::Danger
  } else {
    @views.BadgeTone::Neutral
  }
  let rows : Array[@moui.View[WorkbenchMsg]] = [
    @views.row(
      [@views.badge(tool_name, tone~, theme~, width=96.0), @views.spacer()],
      align=@views.CrossAlign::Center,
    ),
  ]
  // Prefer the brief for a compact one-line summary; fall back to full content.
  let shown = match brief {
    Some(b) => b
    None => content
  }
  rows.push(
    @views.text(
      shown,
      role=@views.TextRole::Mono,
      theme~,
      width=card_width - 24.0,
    ),
  )
  @views.container(
    @views.row(
      [
        @views.container(
          @views.column(rows, spacing=6.0, align=@views.CrossAlign::Start),
          width=card_width,
          background=tool_message_background(theme),
          corner_radius=8.0,
          padding=12.0,
        ),
        @views.spacer(),
      ],
      align=@views.CrossAlign::Start,
    ),
    width~,
    padding=4.0,
  )
}

///|
fn runtime_notice_row(
  text_ : String,
  theme : @core.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  @views.container(
    @views.row(
      [
        @views.spacer(),
        @views.text(
          text_,
          role=@views.TextRole::Caption,
          theme~,
          width=width - 16.0,
        ).foreground(theme.palette.muted),
        @views.spacer(),
      ],
      align=@views.CrossAlign::Center,
    ),
    width~,
    padding=4.0,
  )
}

///|
fn terminal_row(
  status : TurnStatus,
  message : String,
  theme : @core.Theme,
  width : Double,
) -> @moui.View[WorkbenchMsg] {
  let (label, tone) = match status {
    Finished => ("Done", @views.BadgeTone::Success)
    Aborted => ("Aborted", @views.BadgeTone::Warning)
    Interrupted => ("Interrupted", @views.BadgeTone::Warning)
    Failed => ("Failed", @views.BadgeTone::Danger)
  }
  @views.container(
    @views.row(
      [
        @views.badge(label, tone~, theme~, width=64.0),
        @views.text(
          message,
          role=@views.TextRole::Caption,
          theme~,
          width=width - 96.0,
        ).foreground(theme.palette.muted),
        @views.spacer(),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    padding=4.0,
  )
}
