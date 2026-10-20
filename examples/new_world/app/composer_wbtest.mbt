///|
/// The multi-part composer: say / do / story can be combined in one turn.
///
/// The old design had a single segmented control that chose the mode of the one
/// line, so "我推开门" (do) and "掌柜的，还有酒吗？" (say) could never be sent
/// together. These tests pin the replacement: parts are staged with their own
/// intent, one turn carries all of them, and the storage format stays a single
/// readable player line.

///|
test "a plain send stores exactly what the player typed" {
  let parts = composer_parts_with_draft([], Say, "  温一壶酒  ")
  assert_eq(parts.length(), 1)
  assert_eq(parts[0].intent(), Say)
  // The turn text is the trimmed draft, with no marker: a plain message keeps
  // the journal byte-identical to a world written before this feature.
  assert_eq(composer_turn_text(parts), "温一壶酒")
}

///|
test "staged parts keep their intent and are stored with markers" {
  let parts : Array[ComposerPart] = [
    ComposerPart::new(Do, "推开门"),
    ComposerPart::new(Say, "掌柜的，还有酒吗？"),
    ComposerPart::new(Story, "雨声更大了。"),
  ]
  let text = composer_turn_text(parts)
  assert_eq(
    text, "（动作）推开门\n掌柜的，还有酒吗？\n（旁白）雨声更大了。",
  )
  // Parsing it back yields the same three parts, in order.
  let parsed = parse_player_parts(text)
  assert_eq(parsed.length(), 3)
  assert_eq(parsed[0].intent(), Do)
  assert_eq(parsed[0].text(), "推开门")
  assert_eq(parsed[1].intent(), Say)
  assert_eq(parsed[1].text(), "掌柜的，还有酒吗？")
  assert_eq(parsed[2].intent(), Story)
  assert_eq(parsed[2].text(), "雨声更大了。")
}

///|
test "a single action part keeps its marker so the file knows it was an action" {
  let parts = composer_parts_with_draft([], Do, "推开门")
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
test "the composer can send staged parts with an empty input box" {
  let staged : Array[ComposerPart] = [ComposerPart::new(Do, "推开门")]
  assert_true(composer_has_content(staged, ""))
  assert_false(composer_has_content([], "   "))
  let parts = composer_parts_with_draft(staged, Say, "")
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
test "a raw Send under the selected intent still frames the wire" {
  // The legacy path: the view sends the draft text directly, and the intent
  // lives on the model. It must still reach the model as an action.
  let framed = frame_player_turn("推开门", Do)
  assert_true(framed.contains("动作"))
  assert_false(framed.contains("推开门\n"))
}

///|
test "staging moves the draft into a part and clears the box" {
  let selected = step(opened_world(), Select(Some("林掌柜")))
  let typing = step(selected, DraftChanged("推开门"))
  let acting = step(typing, IntentChanged(1))
  let staged = step(acting, StageComposerPart)
  assert_eq(staged.composer_parts().length(), 1)
  assert_eq(staged.composer_parts()[0].intent(), Do)
  assert_eq(staged.composer_parts()[0].text(), "推开门")
  assert_eq(staged.draft(), "")
  // A second part is appended, not replaced.
  let second = step(
    step(step(staged, DraftChanged("还有酒吗？")), IntentChanged(0)),
    StageComposerPart,
  )
  assert_eq(second.composer_parts().length(), 2)
  assert_eq(second.composer_parts()[1].intent(), Say)
}

///|
test "staging an empty draft is refused with a notice" {
  let model = opened_world()
  let staged = step(model, StageComposerPart)
  assert_eq(staged.composer_parts().length(), 0)
  assert_true(staged.log()[0].contains("先"))
}

///|
test "removing a staged part drops only that part" {
  let selected = step(opened_world(), Select(Some("林掌柜")))
  let one = step(step(selected, DraftChanged("甲")), StageComposerPart)
  let two = step(step(one, DraftChanged("乙")), StageComposerPart)
  assert_eq(two.composer_parts().length(), 2)
  let removed = step(two, RemoveComposerPart(0))
  assert_eq(removed.composer_parts().length(), 1)
  assert_eq(removed.composer_parts()[0].text(), "乙")
  // Out-of-range indices are ignored rather than panicking.
  assert_eq(step(removed, RemoveComposerPart(9)).composer_parts().length(), 1)
}

///|
test "SendComposer lands one player line and clears the staged parts" {
  let selected = step(opened_world(), Select(Some("林掌柜")))
  let acting = step(step(selected, IntentChanged(1)), DraftChanged("推开门"))
  let staged = step(acting, StageComposerPart)
  let typing = step(
    step(staged, IntentChanged(0)),
    DraftChanged("掌柜的，还有酒吗？"),
  )
  let (sent, _effect) = update(typing, SendComposer, world_host=editing_host)
  let lines = sent.conversations.for_character("林掌柜").lines()
  // One player line, carrying both parts.
  assert_eq(lines.length(), 2)
  match lines[0].speaker() {
    Player => ()
    Character(_) => fail("the first line must be the player's turn")
  }
  assert_eq(
    lines[0].text(),
    "（动作）推开门\n掌柜的，还有酒吗？",
  )
  assert_eq(sent.composer_parts().length(), 0)
  assert_eq(sent.draft(), "")
}

///|
test "an empty SendComposer is a no-op" {
  let selected = step(opened_world(), Select(Some("林掌柜")))
  let (sent, effect) = update(selected, SendComposer)
  assert_eq(sent.conversations.for_character("林掌柜").lines().length(), 0)
  assert_true(is_no_effect(effect))
}
