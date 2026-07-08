// Message row rendering for the chat transcript.
//
// All rows are pure display (no callbacks), so changing the `Msg` type
// parameter from `WorkbenchMsg` to `CodeMsg` is the only adjustment needed
// for the workspace-scoped routing.

///|
/// Render a single chat message as a view.
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
  @views.padding_edges(inner, top=2.0, bottom=2.0)
}

///|
fn aligned_message_bubble(
  bubble : @moui.View[CodeMsg],
  width : Double,
  bubble_width : Double,
  align_right : Bool,
) -> @moui.View[CodeMsg] {
  @views.custom_children_layout(
    children=[bubble],
    measure=ctx => {
      let height = if ctx.child_sizes.is_empty() {
        0.0
      } else {
        ctx.child_sizes[0].height
      }
      ctx.constraints.constrain(@geometry.Size::new(width~, height~))
    },
    place=ctx => {
      let child_height = if ctx.child_sizes.is_empty() {
        0.0
      } else {
        ctx.child_sizes[0].height
      }
      let child_width = bubble_width.min(ctx.frame.size.width)
      let x = if align_right {
        (ctx.frame.size.width - child_width).max(0.0)
      } else {
        0.0
      }
      [@geometry.Rect::new(x~, y=0.0, width=child_width, height=child_height)]
    },
    paint=(_ctx, _frame) => (),
    semantics_label=if align_right {
      "User message"
    } else {
      "Assistant message"
    },
  )
}

///|
fn user_message_row(
  text_ : String,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  let bubble_width = width * 0.72
  let content_width = (bubble_width - 28.0).max(80.0)
  let bubble = @views.container(
    @views.column(
      [chat_message_body(text_, @views.TextRole::Body, theme, content_width)],
      spacing=4.0,
      align=@views.CrossAlign::Start,
    ),
    width=bubble_width,
    background=user_message_background(theme),
    corner_radius=12.0,
    padding=14.0,
  )
  aligned_message_bubble(bubble, width, bubble_width, true)
}

///|
fn assistant_message_row(
  content : String,
  reasoning : String?,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[CodeMsg] {
  let bubble_width = width * 0.82
  let content_width = (bubble_width - 28.0).max(80.0)
  let rows : Array[@moui.View[CodeMsg]] = []
  // Optional reasoning shown as a collapsed muted block above the content.
  match reasoning {
    Some(r) =>
      if !r.is_empty() {
        rows.push(
          @views.container(
            chat_message_body(
              r,
              @views.TextRole::Caption,
              theme,
              (content_width - 16.0).max(64.0),
            ).foreground(theme.palette.muted),
            width=content_width,
            padding=8.0,
          ),
        )
      }
    None => ()
  }
  rows.push(
    chat_message_body(content, @views.TextRole::Body, theme, content_width),
  )
  let bubble = @views.container(
    @views.column(rows, spacing=4.0, align=@views.CrossAlign::Start),
    width=bubble_width,
    background=user_message_background(theme),
    corner_radius=12.0,
    padding=14.0,
  )
  aligned_message_bubble(bubble, width, bubble_width, false)
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
    chat_message_body(shown, @views.TextRole::Mono, theme, card_width - 24.0),
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
        chat_message_body(text_, @views.TextRole::Caption, theme, width - 16.0).foreground(
          theme.palette.muted,
        ),
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
      chat_message_body(
        request.kind,
        @views.TextRole::Caption,
        theme,
        card_width - 24.0,
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
        chat_message_body(
          message,
          @views.TextRole::Caption,
          theme,
          width - 96.0,
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
