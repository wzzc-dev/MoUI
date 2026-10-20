///|
/// The three-field composer: 说【】 / 做【】 / 旁白【】, one turn.
///
/// The old design had a single segmented control that chose the mode of the one
/// line, plus a staging step to combine several. These tests pin the
/// replacement: each field frames its own line, one send composes the
/// non-empty fields in 说 → 做 → 旁白 order, and the storage format stays a
/// single readable player line.

///|
test "a plain send stores exactly what the player typed" {
  let parts = composer_field_parts("  温一壶酒  ", "", "")
  assert_eq(parts.length(), 1)
  assert_eq(parts[0].intent(), Say)
  // The turn text is the trimmed draft, with no marker: a plain message keeps
  // the journal byte-identical to a world written before this feature.
  assert_eq(composer_turn_text(parts), "温一壶酒")
}

///|
test "the three fields keep their intents and are stored with markers" {
  let parts = composer_field_parts(
    "掌柜的，还有酒吗？", "推开门", "雨声更大了。",
  )
  assert_eq(parts.length(), 3)
  assert_eq(parts[0].intent(), Say)
  assert_eq(parts[1].intent(), Do)
  assert_eq(parts[2].intent(), Story)
  let text = composer_turn_text(parts)
  assert_eq(
    text, "掌柜的，还有酒吗？\n（动作）推开门\n（旁白）雨声更大了。",
  )
  // Parsing it back yields the same three parts, in order.
  let parsed = parse_player_parts(text)
  assert_eq(parsed.length(), 3)
  assert_eq(parsed[0].intent(), Say)
  assert_eq(parsed[0].text(), "掌柜的，还有酒吗？")
  assert_eq(parsed[1].intent(), Do)
  assert_eq(parsed[1].text(), "推开门")
  assert_eq(parsed[2].intent(), Story)
  assert_eq(parsed[2].text(), "雨声更大了。")
}

///|
test "a single action field keeps its marker so the file knows it was an action" {
  let parts = composer_field_parts("", "推开门", "")
  assert_eq(composer_turn_text(parts), "（动作）推开门")
  let parsed = parse_player_parts("（动作）推开门")
  assert_eq(parsed.length(), 1)
  assert_eq(parsed[0].intent(), Do)
}

///|
test "a legacy line with no marker parses as one spoken part" {
  // Worlds written before multi-part turns have plain lines; they must keep
  // loading as speech and keep their exact text.
  let parsed = parse_player_parts("温一壶酒")
  assert_eq(parsed.length(), 1)
  assert_eq(parsed[0].intent(), Say)
  assert_eq(parsed[0].text(), "温一壶酒")
  // A multi-line plain message stays one spoken part per line, and framing it
  // leaves the text alone.
  let multiline = "第一行\n第二行"
  assert_eq(frame_player_turn(multiline, Say), multiline)
}

///|
test "empty and whitespace-only fields are dropped" {
  assert_false(composer_has_content("", "", ""))
  assert_false(composer_has_content("", "  ", ""))
  assert_true(composer_has_content("温一壶酒", "", ""))
  assert_eq(composer_field_parts("  ", "", "").length(), 0)
  let parts = composer_field_parts("", "推开门", "  ")
  assert_eq(parts.length(), 1)
  assert_eq(composer_turn_text(parts), "（动作）推开门")
}

///|
test "a multi-part turn is framed for the model with a sequence header" {
  let text = "（动作）推开门\n掌柜的，还有酒吗？"
  let framed = frame_player_turn(text, Say)
  // The header tells the model the turn is a sequence, not one quote.
  assert_true(framed.contains("按顺序"))
  // Each part keeps its own framing instruction.
  assert_true(framed.contains("动作"))
  assert_true(framed.contains("推开门"))
  assert_true(framed.contains("还有酒吗"))
  // Exactly one copy of each part: framing must replace, not append.
  let mut copies = 0
  let mut rest = framed
  while rest.find("推开门") is Some(at) {
    copies += 1
    rest = rest[at + 3:].to_owned()
  }
  assert_eq(copies, 1)
}

///|
test "a raw Send line is plain speech on the wire" {
  // The direct path (tests, scripted turns) sends the line text itself; it
  // reaches the model verbatim.
  assert_eq(frame_player_turn("推开门", Say), "推开门")
}

///|
test "SendComposer lands one player line and clears the fields" {
  let selected = step(opened_world(), Select(Some("林掌柜")))
  let typed = step(
    step(selected, DoDraftChanged("推开门")),
    SayDraftChanged("掌柜的，还有酒吗？"),
  )
  let (sent, _effect) = update(typed, SendComposer, world_host=editing_host)
  let lines = sent.conversations.for_character("林掌柜").lines()
  // One player line, carrying both fields in order.
  assert_eq(lines.length(), 2)
  match lines[0].speaker() {
    Player => ()
    Character(_) => fail("the first line must be the player's turn")
  }
  assert_eq(
    lines[0].text(),
    "掌柜的，还有酒吗？\n（动作）推开门",
  )
  assert_eq(sent.say_draft(), "")
  assert_eq(sent.do_draft(), "")
  assert_eq(sent.story_draft(), "")
}

///|
test "an empty SendComposer is a no-op" {
  let selected = step(opened_world(), Select(Some("林掌柜")))
  let (sent, effect) = update(selected, SendComposer)
  assert_eq(sent.conversations.for_character("林掌柜").lines().length(), 0)
  assert_true(is_no_effect(effect))
}
