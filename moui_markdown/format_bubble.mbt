///|
/// A formatting action offered by the selection bubble.
#derive(Eq, Debug, ToJson)
pub(all) enum MarkdownFormatBubbleAction {
  Bold
  Italic
  Strikethrough
  Code
  Highlight
  Link
  Heading1
  Heading2
  UnorderedList
  Quote
}

///|
pub extend MarkdownFormatBubbleAction with Debug::{to_repr}

///|
pub extend MarkdownFormatBubbleAction with Eq::{not_equal, equal}

///|
pub extend MarkdownFormatBubbleAction with ToJson::{to_json}

///|
/// The bubble's buttons, in display order.
pub fn markdown_format_bubble_actions() -> Array[MarkdownFormatBubbleAction] {
  [
    Bold,
    Italic,
    Strikethrough,
    Highlight,
    Code,
    Heading1,
    Heading2,
    UnorderedList,
    Quote,
    Link,
  ]
}

///|
/// Short button text. The glyphs match the ones the editor chrome has always
/// shown, so the bubble reads the same as the toolbar.
pub fn markdown_format_bubble_glyph(
  action : MarkdownFormatBubbleAction,
) -> String {
  match action {
    Bold => "B"
    Italic => "I"
    Strikethrough => "S"
    Highlight => "≡"
    Code => "</>"
    Heading1 => "H1"
    Heading2 => "H2"
    UnorderedList => "•"
    Quote => "❝"
    Link => "🔗"
  }
}

///|
/// Tooltip and accessibility label for a bubble button.
pub fn markdown_format_bubble_label(
  action : MarkdownFormatBubbleAction,
) -> String {
  match action {
    Bold => "Bold"
    Italic => "Italic"
    Strikethrough => "Strikethrough"
    Highlight => "Highlight"
    Code => "Inline Code"
    Heading1 => "Heading 1"
    Heading2 => "Heading 2"
    UnorderedList => "Bullet List"
    Quote => "Quote"
    Link => "Link"
  }
}

///|
/// Place the bubble above the caret line, flip it below when it would leave
/// the viewport, then clamp it inside the viewport.
///
/// `caret` is the caret line's rect in viewport space. Only the vertical axis
/// is clamped: the caller's contract carries the viewport height, not its
/// width, so a bubble near a side edge is centred on the caret and left to
/// the caller's overlay clip.
pub fn markdown_format_bubble_rect(
  caret : @core.Rect,
  width~ : Double = 300.0,
  height~ : Double = 32.0,
  viewport_height~ : Double,
) -> @core.Rect {
  let x = caret.origin.x + caret.size.width / 2.0 - width / 2.0
  let above = caret.origin.y - height
  let below = caret.origin.y + caret.size.height
  let preferred = if above >= 0.0 { above } else { below }
  // The bubble may be taller than the viewport; in that case the usable band
  // collapses to the top edge instead of inverting.
  let limit = if viewport_height > height {
    viewport_height - height
  } else {
    0.0
  }
  let y = if preferred > limit {
    limit
  } else if preferred < 0.0 {
    0.0
  } else {
    preferred
  }
  @core.Rect::new(x~, y~, width~, height~)
}

///|
/// A floating formatting bubble anchored to the caret line.
///
/// The caller owns when it shows (a non-empty selection) and what each action
/// means; this function only builds the row and positions it over the editor.
/// Placement mirrors MoMark's parked overlay: measured at viewport size, the
/// bubble is painted at `markdown_format_bubble_rect`.
pub fn[Msg] markdown_format_bubble(
  on_action~ : (MarkdownFormatBubbleAction) -> Msg,
  caret~ : @core.Rect,
  viewport_height~ : Double,
  width~ : Double = 300.0,
  height~ : Double = 32.0,
) -> @core.View[Msg] {
  let buttons = markdown_format_bubble_actions().map(action => {
    @views.tooltip(
      @views.button(
        markdown_format_bubble_glyph(action),
        on_click=on_action(action),
        variant=@views.ButtonVariant::Ghost,
        width=28.0,
        height=28.0,
      ),
      markdown_format_bubble_label(action),
    )
  })
  let bubble = @views.container(
    @views.row(buttons, spacing=2.0, align=@views.CrossAlign::Center),
    width~,
    height~,
    variant=@views.ContainerVariant::Raised,
    padding=2.0,
  )
  @views.custom_children_layout(
    children=[bubble],
    measure=ctx => ctx.constraints.max,
    place=ctx => {
      let frame = ctx.frame
      let target = markdown_format_bubble_rect(
        caret,
        width~,
        height~,
        viewport_height~,
      )
      [
        @core.Rect::new(
          x=target.origin.x - frame.origin.x,
          y=target.origin.y - frame.origin.y,
          width=target.size.width,
          height=target.size.height,
        ),
      ]
    },
    paint=(_ctx, _frame) => (),
  )
}
