///|
fn bubble_caret(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> @core.Rect {
  @core.Rect::new(x~, y~, width~, height~)
}

///|
/// The ten buttons keep their display order and each has a glyph and a label.
test "markdown_format_bubble_actions lists every button in order" {
  let actions = markdown_format_bubble_actions()
  assert_eq(actions.length(), 10)
  assert_true(actions[0] is Bold)
  assert_true(actions[1] is Italic)
  assert_true(actions[2] is Strikethrough)
  assert_true(actions[3] is Highlight)
  assert_true(actions[4] is Code)
  assert_true(actions[5] is Heading1)
  assert_true(actions[6] is Heading2)
  assert_true(actions[7] is UnorderedList)
  assert_true(actions[8] is Quote)
  assert_true(actions[9] is Link)
  let glyphs : Array[String] = []
  let labels : Array[String] = []
  for action in actions {
    glyphs.push(markdown_format_bubble_glyph(action))
    labels.push(markdown_format_bubble_label(action))
  }
  assert_eq(glyphs[0], "B")
  assert_eq(glyphs[2], "S")
  assert_eq(glyphs[3], "≡")
  assert_eq(glyphs[4], "</>")
  assert_eq(glyphs[5], "H1")
  assert_eq(glyphs[7], "•")
  assert_eq(labels[0], "Bold")
  assert_eq(labels[2], "Strikethrough")
  assert_eq(labels[4], "Inline Code")
  assert_eq(labels[6], "Heading 2")
  assert_eq(labels[7], "Bullet List")
  assert_eq(labels[9], "Link")
}

///|
/// Above the caret line is the default, and the bubble is centred on the caret
/// horizontally.
test "markdown_format_bubble_rect sits above the caret line" {
  let caret = bubble_caret(100.0, 200.0, 2.0, 20.0)
  let rect = markdown_format_bubble_rect(
    caret,
    width=300.0,
    height=32.0,
    viewport_height=600.0,
  )
  assert_eq(rect.origin.y, 168.0)
  assert_eq(rect.origin.x, 100.0 + 1.0 - 150.0)
  assert_eq(rect.size.width, 300.0)
  assert_eq(rect.size.height, 32.0)
}

///|
/// With no room above, the bubble flips below the caret line.
test "markdown_format_bubble_rect flips below when the top would clip" {
  let caret = bubble_caret(10.0, 10.0, 2.0, 20.0)
  let rect = markdown_format_bubble_rect(
    caret,
    width=300.0,
    height=32.0,
    viewport_height=600.0,
  )
  assert_eq(rect.origin.y, 30.0)
}

///|
/// A flipped bubble that would also cross the bottom edge is clamped so its
/// bottom sits on the viewport bottom.
test "markdown_format_bubble_rect clamps a flipped bubble inside the viewport" {
  let caret = bubble_caret(10.0, 10.0, 2.0, 20.0)
  let rect = markdown_format_bubble_rect(
    caret,
    width=300.0,
    height=32.0,
    viewport_height=40.0,
  )
  assert_eq(rect.origin.y, 8.0)
}

///|
/// A caret on the very top edge has no room above and an exactly fitting
/// viewport, so the bubble lands at the top instead of going negative.
test "markdown_format_bubble_rect never leaves the viewport at the top edge" {
  let caret = bubble_caret(4.0, 0.0, 2.0, 20.0)
  let rect = markdown_format_bubble_rect(
    caret,
    width=300.0,
    height=32.0,
    viewport_height=32.0,
  )
  assert_eq(rect.origin.y, 0.0)
}

///|
/// The horizontal axis is not clamped: the contract only carries the viewport
/// height, so a bubble near a side edge is centred and left to the overlay's
/// clip.
test "markdown_format_bubble_rect centres without clamping x" {
  let caret = bubble_caret(2.0, 200.0, 2.0, 20.0)
  let rect = markdown_format_bubble_rect(
    caret,
    width=300.0,
    height=32.0,
    viewport_height=600.0,
  )
  assert_eq(rect.origin.x, 2.0 + 1.0 - 150.0)
}

///|
/// Building the bubble only positions and returns a view; the caller owns the
/// message type, so each button routes its own action.
test "markdown_format_bubble builds a positioned view" {
  let caret = bubble_caret(100.0, 200.0, 2.0, 20.0)
  let view = markdown_format_bubble(
    on_action=fn(action) {
      match action {
        Bold => "bold"
        Link => "link"
        _ => "other"
      }
    },
    caret~,
    viewport_height=600.0,
  )
  ignore(view)
}
