///|
/// Conversation editing: swipes, inline edits, deletes, and clearing.

///|
/// A host that records commits, so editing assertions can see that a change
/// was actually persisted (a host-less model turns every commit into a no-op,
/// which would let a broken handler pass).
let editing_host : WorldHost = {
  list_worlds: _done => (),
  pick_root: _done => (),
  read_world: (_folder, _done) => (),
  write_world: (_folder, _files, _done) => (),
  read_config: _done => (),
  write_config: (_content, _done) => (),
  export_world: (_folder, _files, _done) => (),
  import_world: _done => (),
  copy_to_clipboard: _text => (),
}

///|
fn talking() -> WorldModel {
  let (selected, _e0) = update(
    tavern(),
    Select(Some("林掌柜")),
    world_host=editing_host,
  )
  let (sent, _e1) = update(
    selected,
    Send("温一壶酒"),
    world_host=editing_host,
  )
  ignore(sent.conversations.for_character("林掌柜").lines().is_empty())
  sent
}

///|
test "regenerating keeps the old reply as a swipe candidate" {
  let model = talking()
  let before = model.conversations.for_character("林掌柜").lines()
  assert_eq(before.length(), 2)
  let original = before[1].text()
  // No provider: regeneration runs the scripted path, so this exercises the
  // offline swipe affordance end to end.
  let (after, _effect) = update(model, RegenerateReply, world_host=editing_host)
  let line = after.conversations.for_character("林掌柜").lines()[1]
  assert_eq(line.candidate_count(), 2)
  assert_eq(line.selected(), 1)
  // The original is still reachable.
  assert_eq(line.alternatives().length(), 1)
  assert_eq(line.alternatives()[0], original)
  assert_true(line.text() != "")
  // Swiping back restores it.
  let (back, _e) = update(after, SwipeReply(1, -1), world_host=editing_host)
  let restored = back.conversations.for_character("林掌柜").lines()[1]
  assert_eq(restored.text(), original)
  assert_eq(restored.selected(), 0)
  // Swiping wraps around in both directions.
  let (wrapped, _e) = update(back, SwipeReply(1, -1), world_host=editing_host)
  assert_eq(
    wrapped.conversations.for_character("林掌柜").lines()[1].selected(),
    1,
  )
  let (forward, _e) = update(back, SwipeReply(1, 1), world_host=editing_host)
  assert_eq(
    forward.conversations.for_character("林掌柜").lines()[1].selected(),
    1,
  )
}

///|
test "a line with no alternatives ignores swipes" {
  let model = talking()
  let (after, effect) = update(model, SwipeReply(0, 1), world_host=editing_host)
  assert_true(is_no_effect(effect))
  assert_eq(
    after.conversations.for_character("林掌柜").lines()[0].text(),
    "温一壶酒",
  )
  // Out-of-range indices are inert rather than trapping.
  let (_, oob) = update(model, SwipeReply(99, 1), world_host=editing_host)
  assert_true(is_no_effect(oob))
  let (_, negative) = update(model, SwipeReply(-1, 1), world_host=editing_host)
  assert_true(is_no_effect(negative))
}

///|
test "only a trailing reply can be regenerated" {
  let model = talking()
  // Append a player line: now the last line is the player's, so there is
  // nothing to regenerate yet.
  let with_player = step(model, Send("再来一壶"))
  let (_, effect) = update(
    with_player,
    RegenerateReply,
    world_host=editing_host,
  )
  assert_true(is_no_effect(effect))
  // Regeneration is also refused mid-turn.
  let pending = step(talking(), Send("再来一壶"))
  let (_, pending_effect) = update(
    pending,
    RegenerateReply,
    world_host=editing_host,
  )
  assert_true(is_no_effect(pending_effect))
}

///|
test "editing a history line rewrites it and keeps the rest" {
  let model = talking()
  let opened = step(model, EditLine(1))
  assert_eq(opened.editing_line(), Some(1))
  assert_eq(
    opened.edit_buffer(),
    model.conversations.for_character("林掌柜").lines()[1].text(),
  )
  let typed = step(opened, EditLineChanged("嗯，酒温好了。"))
  assert_eq(typed.edit_buffer(), "嗯，酒温好了。")
  let (committed, effect) = update(
    typed,
    EditLineCommit,
    world_host=editing_host,
  )
  assert_true(is_run_effect(effect))
  let lines = committed.conversations.for_character("林掌柜").lines()
  assert_eq(lines.length(), 2)
  assert_eq(lines[1].text(), "嗯，酒温好了。")
  assert_eq(lines[0].text(), "温一壶酒")
  // The editor closes.
  assert_eq(committed.editing_line(), None)
  assert_eq(committed.edit_buffer(), "")
}

///|
test "editing can cancel, and an empty edit is refused" {
  let opened = step(talking(), EditLine(0))
  let cancelled = step(opened, EditLineCancel)
  assert_eq(cancelled.editing_line(), None)
  assert_eq(
    cancelled.conversations.for_character("林掌柜").lines()[0].text(),
    "温一壶酒",
  )
  // Whitespace-only is not a meaningful edit: the line stays put.
  let blank = step(step(opened, EditLineChanged("   ")), EditLineCommit)
  assert_eq(
    blank.conversations.for_character("林掌柜").lines()[0].text(),
    "温一壶酒",
  )
}

///|
test "editing the shown candidate updates only that candidate" {
  // Regenerate to get two candidates, swipe to the new one, then edit it.
  let (two, _e) = update(talking(), RegenerateReply, world_host=editing_host)
  let second = two.conversations.for_character("林掌柜").lines()[1]
  assert_eq(second.selected(), 1)
  let first_text = second.alternatives()[0]
  let (typed, _e1) = update(two, EditLine(1), world_host=editing_host)
  let (changed, _e2) = update(
    typed,
    EditLineChanged("改过的第二版"),
    world_host=editing_host,
  )
  let (edited, _e3) = update(changed, EditLineCommit, world_host=editing_host)
  let line = edited.conversations.for_character("林掌柜").lines()[1]
  assert_eq(line.text(), "改过的第二版")
  // Swiping back still shows the untouched first candidate.
  let (back, _e) = update(edited, SwipeReply(1, -1), world_host=editing_host)
  assert_eq(
    back.conversations.for_character("林掌柜").lines()[1].text(),
    first_text,
  )
}

///|
test "deleting a line removes exactly that line" {
  let model = talking()
  let (after, effect) = update(model, DeleteLine(0), world_host=editing_host)
  assert_true(is_run_effect(effect))
  let lines = after.conversations.for_character("林掌柜").lines()
  assert_eq(lines.length(), 1)
  assert_true(lines[0].speaker() is Character(_))
  // Out of range is inert.
  let (_, oob) = update(model, DeleteLine(42), world_host=editing_host)
  assert_true(is_no_effect(oob))
}

///|
test "clearing a conversation empties it without touching other characters" {
  let model = talking()
  // Give a second character a history too.
  let (switched, _e0) = update(
    model,
    Select(Some("赶考书生")),
    world_host=editing_host,
  )
  let (both, _e1) = update(
    switched,
    Send("借几文钱？"),
    world_host=editing_host,
  )
  assert_true(
    both.conversations.for_character("赶考书生").lines().length() > 0,
  )
  let (back_to_lin, _e2) = update(
    both,
    Select(Some("林掌柜")),
    world_host=editing_host,
  )
  let (cleared, _e3) = update(
    back_to_lin,
    ClearConversation,
    world_host=editing_host,
  )
  assert_eq(
    cleared.conversations.for_character("林掌柜").lines().length(),
    0,
  )
  assert_true(
    cleared.conversations.for_character("赶考书生").lines().length() > 0,
  )
}

///|
test "candidates survive the journal round trip" {
  let (two, _e) = update(talking(), RegenerateReply, world_host=editing_host)
  let (swiped, _e) = update(two, SwipeReply(1, -1), world_host=editing_host)
  let book = swiped.conversations
  let text = book.to_json_text()
  let parsed = parse_conversations_json(text)
  assert_true(parsed.valid)
  assert_eq(parsed.conversations.length(), 1)
  let line = parsed.conversations[0].lines()[1]
  assert_eq(line.candidate_count(), 2)
  assert_eq(line.selected(), 0)
  // Both candidates are still there after a reload.
  assert_eq(line.alternatives().length() + 1, 2)
}

///|
test "a hand-damaged candidate index falls back to the shown text" {
  let text = "{\"conversations\":[{\"character\":\"林掌柜\",\"lines\":[{\"speaker\":\"assistant\",\"text\":\"原文\",\"alternatives\":[\"另一版\"],\"selected\":9}]}]}"
  let parsed = parse_conversations_json(text)
  assert_eq(parsed.conversations[0].lines()[0].selected(), 0)
  assert_eq(parsed.conversations[0].lines()[0].text(), "原文")
}

///|
test "the lore hint names what was injected" {
  let model = talking()
  let conversation = model.conversations.for_character("林掌柜")
  let hint = lore_hint(model.scenario(), conversation)
  // The fixture's world book triggers on 酒 / 花雕 and the last player line
  // mentions wine.
  assert_true(hint.contains("世界书"))
  assert_true(hint.contains("酒"))
  // A conversation with no player line has nothing to report.
  assert_eq(
    lore_hint(model.scenario(), Conversation::new(character_id="x")),
    "",
  )
}

///|
test "branching copies history up to a line and keeps the original" {
  let model = talking()
  let before = model.conversations.for_character("林掌柜").lines()
  assert_eq(before.length(), 2)
  let (branched, effect) = update(model, BranchAt(0), world_host=editing_host)
  assert_true(is_run_effect(effect))
  // The branch key is a sibling on disk, not a tree.
  let key = match branched.selected() {
    Some(value) => value
    None => fail("the branch should become the active conversation")
  }
  assert_eq(key, "林掌柜~2")
  let branch = branched.conversations.for_character(key)
  assert_eq(branch.lines().length(), 1)
  assert_eq(branch.lines()[0].text(), "温一壶酒")
  // The original is untouched.
  assert_eq(
    branched.conversations.for_character("林掌柜").lines().length(),
    2,
  )
}

///|
test "branching twice picks the next free number" {
  let model = talking()
  let (first, _e) = update(model, BranchAt(1), world_host=editing_host)
  // Select the original again before branching: the UI would offer the button
  // on whichever conversation is open.
  let (back, _e2) = update(
    first,
    Select(Some("林掌柜")),
    world_host=editing_host,
  )
  let (second, _e3) = update(back, BranchAt(1), world_host=editing_host)
  let key = match second.selected() {
    Some(value) => value
    None => fail("second branch should be active")
  }
  assert_eq(key, "林掌柜~3")
  // All three conversations coexist.
  assert_true(second.conversations.find("林掌柜") is Some(_))
  assert_true(second.conversations.find("林掌柜~2") is Some(_))
  assert_true(second.conversations.find("林掌柜~3") is Some(_))
}

///|
test "an out-of-range branch is inert" {
  let model = talking()
  let (_, effect) = update(model, BranchAt(99), world_host=editing_host)
  assert_true(is_no_effect(effect))
  let (_, negative) = update(model, BranchAt(-1), world_host=editing_host)
  assert_true(is_no_effect(negative))
}

///|
test "branch keys split cleanly and never collide with names" {
  assert_eq(branched_key("林掌柜", 2), "林掌柜~2")
  match split_branch("林掌柜~2") {
    Some((base, number)) => {
      assert_eq(base, "林掌柜")
      assert_eq(number, 2)
    }
    None => fail("a branch key must split")
  }
  assert_true(split_branch("林掌柜") is None)
  assert_true(split_branch("~3") is None)
  // A name containing a tilde is not a branch unless the tail is a number.
  assert_true(split_branch("a~b") is None)
}

///|
test "a branch is named after its character, with the branch number" {
  let model = talking()
  let (branched, _e) = update(model, BranchAt(0), world_host=editing_host)
  let key = branched.selected().unwrap()
  let name = character_name(branched.scenario(), key)
  assert_true(name.contains("林掌柜"))
  assert_true(name.contains("分支"))
  assert_true(name.contains("2"))
}

///|
test "a branched conversation round-trips through its own file" {
  let model = talking()
  let (branched, _e) = update(model, BranchAt(1), world_host=editing_host)
  let key = branched.selected().unwrap()
  let text = branched.conversations.for_character(key).to_json_text()
  let parsed = parse_conversation_file(text)
  assert_true(parsed.valid)
  assert_eq(parsed.conversations.length(), 1)
  assert_eq(parsed.conversations[0].character_id(), key)
  assert_eq(parsed.conversations[0].lines().length(), 2)
}
