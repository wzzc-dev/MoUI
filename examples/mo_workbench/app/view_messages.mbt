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
/// 消息行高度估算,用于列表窗口化(只构建可视区消息行)。
///
/// 与 `view_messages.mbt` 的布局公式共享常量:行高 `chat_message_line_height`
/// (由 `theme.typography.body.size` 决定)、气泡 padding 14、reasoning 容器 padding 8、
/// tool/permission 卡片 padding 12、外层 padding 4、列表/行内 spacing、badge 高 24。
/// `PermissionRequest` 结构复杂,给一个保守估算;偏差由窗口 overscan 吸收。
/// `message_row` 外层的 `padding_edges(top=2, bottom=2)` 计入 `+4`。
fn message_row_height(
  msg : ChatMessage,
  theme : @moui.Theme,
  width : Double,
) -> Double {
  let body_size = chat_message_text_role_font(@views.TextRole::Body, theme).size
  let line_h = chat_message_line_height(body_size)
  // `message_row` 的 `padding_edges(top=2, bottom=2)`。
  let row_edge = 4.0
  match msg {
    User(text) => {
      let content_width = (width * 0.72 - 28.0).max(80.0)
      let lines = chat_message_display_lines(text, content_width, body_size).length()
      row_edge + 28.0 + lines.to_double() * line_h
    }
    Assistant(content, reasoning) => {
      let content_width = (width * 0.82 - 28.0).max(80.0)
      let mut inner_h = 0.0
      let mut row_count = 0
      match reasoning {
        Some(r) =>
          if !r.is_empty() {
            let reasoning_width = (content_width - 16.0).max(64.0)
            let r_lines = chat_message_display_lines(
              r, reasoning_width, body_size,
            ).length()
            inner_h = inner_h + 16.0 + r_lines.to_double() * line_h
            row_count = row_count + 1
          }
        None => ()
      }
      let c_lines = chat_message_display_lines(
        content, content_width, body_size,
      ).length()
      inner_h = inner_h + c_lines.to_double() * line_h
      row_count = row_count + 1
      row_edge + 28.0 + inner_h + (row_count - 1).to_double() * 4.0
    }
    ToolResult(_tool_name, content, _is_error, brief) => {
      let shown = match brief {
        Some(b) => b
        None => content
      }
      let card_width = width * 0.9
      let lines = chat_message_display_lines(
        shown,
        card_width - 24.0,
        body_size,
      ).length()
      // 外层 container padding 4 + 卡片 padding 12 + badge 行(24 + 行余量约 6)
      // + rows spacing 6 + mono 正文 + 卡片 padding 12 + message_row 边 4。
      row_edge +
      4.0 +
      12.0 +
      30.0 +
      6.0 +
      lines.to_double() * line_h +
      12.0 +
      4.0
    }
    RuntimeNotice(text) => {
      let lines = chat_message_display_lines(text, width - 16.0, body_size).length()
      row_edge + 8.0 + lines.to_double() * line_h
    }
    Terminal(_status, message) => {
      let lines = chat_message_display_lines(message, width - 96.0, body_size).length()
      row_edge + 8.0 + lines.to_double().max(1.0) * line_h
    }
    PermissionRequest(_request) =>
      row_edge + 4.0 + 12.0 + 40.0 + 8.0 + 34.0 + 12.0 + 4.0
  }
}

///|
priv struct MessageRowHeightsSnapshot {
  messages : Array[ChatMessage]
  width : Double
  body_size : Double
  heights : Array[Double]
}

///|
let message_row_heights_snapshot : Ref[MessageRowHeightsSnapshot?] = Ref(None)

///|
/// Reuse all heights while scrolling the same message array. When streaming
/// creates a copied array, reuse the physically unchanged prefix and recompute
/// only the appended or replaced tail (normally the final assistant message).
fn message_row_heights(
  messages : Array[ChatMessage],
  theme : @moui.Theme,
  width : Double,
) -> Array[Double] {
  let body_size = chat_message_text_role_font(@views.TextRole::Body, theme).size
  match message_row_heights_snapshot.val {
    Some(snapshot) if snapshot.width == width && snapshot.body_size == body_size => {
      if physical_equal(snapshot.messages, messages) {
        return snapshot.heights
      }
      let heights : Array[Double] = []
      let shared = snapshot.messages.length().min(messages.length())
      let mut first_changed = 0
      while first_changed < shared &&
            physical_equal(
              snapshot.messages[first_changed],
              messages[first_changed],
            ) {
        heights.push(snapshot.heights[first_changed])
        first_changed = first_changed + 1
      }
      for i in first_changed..<messages.length() {
        heights.push(message_row_height(messages[i], theme, width))
      }
      message_row_heights_snapshot.val = Some({
        messages,
        width,
        body_size,
        heights,
      })
      heights
    }
    _ => {
      let heights : Array[Double] = []
      for message in messages {
        heights.push(message_row_height(message, theme, width))
      }
      message_row_heights_snapshot.val = Some({
        messages,
        width,
        body_size,
        heights,
      })
      heights
    }
  }
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
      let height = if ctx.children.is_empty() {
        0.0
      } else {
        ctx.children[0].size.height
      }
      ctx.constraints.constrain(@geometry.Size::new(width~, height~))
    },
    place=ctx => {
      let child_height = if ctx.children.is_empty() {
        0.0
      } else {
        ctx.children[0].size.height
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
