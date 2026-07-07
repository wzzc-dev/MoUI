// Message row rendering for the chat transcript.
//
// All rows are pure display (no callbacks), so changing the `Msg` type
// parameter from `WorkbenchMsg` to `CodeMsg` is the only adjustment needed
// for the workspace-scoped routing.

///|
/// Render a single chat message as a view.
/// User and assistant messages render with a small avatar circle.
fn message_row(
  msg : ChatMessage,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  let inner = match msg {
    User(text) => user_message_row(text, theme, width)
    Assistant(content, reasoning) =>
      assistant_message_row(content, reasoning, theme, width)
    ToolResult(tool_name, content, is_error, brief) =>
      tool_result_row(tool_name, content, is_error, brief, theme, width)
    RuntimeNotice(text) => runtime_notice_row(text, theme, width)
    PermissionRequest(request) => permission_request_row(request, theme, width)
    Terminal(status, message) => terminal_row(status, message, theme, width)
  }
  @views.padding_edges(inner, top=6.0, bottom=6.0)
}

///|
fn user_message_row(
  text_ : String,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  let bubble_width = width * 0.72
  let avatar_size = 28.0
  @views.container(
    @views.row(
      [
        @views.spacer(),
        @views.container(
          @views.column(
            [
              chat_message_body(
                text_,
                @views.TextRole::Body,
                theme,
                bubble_width - 24.0,
              ),
            ],
            spacing=4.0,
            align=@views.CrossAlign::Start,
          ),
          width=bubble_width,
          background=user_message_background(theme),
          corner_radius=12.0,
          padding=14.0,
        ),
        user_avatar(theme, avatar_size),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
  )
}

///|
fn user_avatar(
  theme : @moui.Theme,
  avatar_size : Double,
) -> @moui.View[CodeMsg] {
  @views.container(
    @views.center(
      @views.text(
        "U",
        role=@views.TextRole::Label,
        theme~,
        width=avatar_size,
        height=avatar_size,
      ).foreground(@graphics.Color::rgba(r=1.0, g=1.0, b=1.0, a=1.0)),
      width=avatar_size,
      height=avatar_size,
      theme~,
    ),
    width=avatar_size,
    height=avatar_size,
    background=user_avatar_color(theme),
    corner_radius=avatar_size / 2.0,
    padding=0.0,
  )
}

///|
fn assistant_message_row(
  content : String,
  reasoning : String?,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  let bubble_width = width * 0.82
  let avatar_size = 28.0
  let rows : Array[@moui.View[CodeMsg]] = []
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
    chat_message_body(
      content,
      @views.TextRole::Body,
      theme,
      bubble_width - 24.0,
    ),
  )
  @views.container(
    @views.row(
      [
        @views.container(
          @views.icon(
            @views.IconName::CodeInline,
            size=14.0,
            color=assistant_avatar_color(theme),
          ),
          width=avatar_size,
          height=avatar_size,
          background=assistant_avatar_color(theme).with_alpha(0.15),
          corner_radius=avatar_size / 2.0,
          padding=0.0,
        ),
        @views.container(
          @views.column(rows, spacing=4.0, align=@views.CrossAlign::Start),
          width=bubble_width,
          background=workbench_subtle_background(theme),
          corner_radius=12.0,
          padding=14.0,
        ).border(hairline_border(theme)),
        @views.spacer(),
      ],
      spacing=10.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
  )
}

///|
fn tool_result_row(
  tool_name : String,
  content : String,
  is_error : Bool,
  brief : String?,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  let card_width = width * 0.9
  let tone = if is_error {
    @views.BadgeTone::Danger
  } else {
    @views.BadgeTone::Neutral
  }
  let background = if is_error {
    workbench_diff_removed_soft(theme)
  } else {
    workbench_diff_added_soft(theme)
  }
  let rows : Array[@moui.View[CodeMsg]] = [
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
          background~,
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
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
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
fn permission_request_row(
  request : AgentPermissionRequest,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  let card_width = width * 0.9
  let rows : Array[@moui.View[CodeMsg]] = []
  rows.push(
    @views.row(
      [
        @views.badge(
          "Permission",
          tone=@views.BadgeTone::Warning,
          theme~,
          width=96.0,
        ),
        @views.text(
          if request.title.is_empty() {
            request.tool_call_id
          } else {
            request.title
          },
          role=@views.TextRole::Label,
          theme~,
          width=card_width - 128.0,
        ),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    ),
  )
  if !request.kind.is_empty() {
    rows.push(
      @views.text(
        request.kind,
        role=@views.TextRole::Caption,
        theme~,
        width=card_width - 24.0,
      ).foreground(theme.palette.muted),
    )
  }
  let button_width = ((card_width - 24.0) / 3.0).max(96.0)
  let buttons : Array[@moui.View[CodeMsg]] = []
  for option in request.options {
    buttons.push(
      @views.button(
        option.name,
        on_click=CodeMsg::RespondPermission(
          request.request_id,
          PermissionOutcome::Selected(option.id),
        ),
        variant=permission_button_variant(option.kind),
        theme~,
        width=button_width,
        height=34.0,
      ),
    )
  }
  buttons.push(
    @views.button(
      "Cancel",
      on_click=CodeMsg::RespondPermission(
        request.request_id,
        PermissionOutcome::Cancelled,
      ),
      variant=@views.ButtonVariant::Ghost,
      theme~,
      width=button_width,
      height=34.0,
    ),
  )
  rows.push(@views.row(buttons, spacing=8.0, align=@views.CrossAlign::Center))
  @views.container(
    @views.row(
      [
        @views.container(
          @views.column(rows, spacing=8.0, align=@views.CrossAlign::Stretch),
          width=card_width,
          background=workbench_diff_removed_soft(theme),
          corner_radius=8.0,
          padding=12.0,
        ).border(hairline_border(theme)),
        @views.spacer(),
      ],
      align=@views.CrossAlign::Start,
    ),
    width~,
    padding=4.0,
  )
}

///|
fn permission_button_variant(kind : String) -> @views.ButtonVariant {
  match kind {
    "allow_always" | "allow_once" => @views.ButtonVariant::Primary
    "reject_once" | "reject_always" => @views.ButtonVariant::Ghost
    _ => @views.ButtonVariant::Ghost
  }
}

///|
fn terminal_row(
  status : TurnStatus,
  message : String,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
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
