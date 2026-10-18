///|
/// Replies that arrive after the player has moved on.
///
/// A turn takes seconds; a player clicks another character in one. The reply
/// must land in the conversation it belongs to, clear *that* conversation's
/// pending flag, and never leak into whatever is on screen.

///|
test "a reply lands in its own conversation after the player switches away" {
  let base = step(crowded_world(), ApiKeyChanged("sk-test"))
  let with_lin = step(base, Select(Some("林掌柜")))
  let never : TurnRunner = (_request, _on_reply) => ()
  let (asked, _e) = update(with_lin, Send("问林掌柜"), turn_runner=never)
  // The player switches to someone else while the request is in flight.
  let switched = step(asked, Select(Some("周跛子")))
  assert_eq(switched.selected(), Some("周跛子"))
  // Now the late reply arrives, addressed to 林掌柜.
  let (late, _l) = update(
    switched,
    Reply("林掌柜", Some("迟到的回复")),
    turn_runner=never,
  )
  // It goes to 林掌柜's history, not to the character on screen.
  let lin = late.conversations.for_character("林掌柜")
  let lin_lines = lin.lines()
  assert_eq(lin_lines[lin_lines.length() - 1].text(), "迟到的回复")
  assert_false(lin.pending())
  // And the on-screen character's history is untouched.
  let zhou = late.conversations.for_character("周跛子")
  assert_eq(zhou.lines().length(), 0)
  assert_false(zhou.pending())
  // The player still sees the character they chose.
  assert_eq(late.selected(), Some("周跛子"))
}

///|
test "a reply for a character that no longer exists is dropped, not crashed" {
  // Hand-editing the folder can delete a character mid-turn. The late reply for
  // them must degrade quietly: appending to a missing conversation would either
  // resurrect a ghost or write an orphan file.
  let base = step(crowded_world(), ApiKeyChanged("sk-test"))
  let selected = step(base, Select(Some("林掌柜")))
  let never : TurnRunner = (_request, _on_reply) => ()
  let (asked, _e) = update(selected, Send("嗨"), turn_runner=never)
  let (late, _l) = update(
    asked,
    Reply("并不存在的人", Some("我是谁")),
    turn_runner=never,
  )
  // No ghost conversation is created for the unknown id.
  let ghost = late.conversations.for_character("并不存在的人")
  assert_eq(ghost.lines().length(), 0)
  // The real conversation is untouched and no longer waiting on nothing.
  let lin = late.conversations.for_character("林掌柜")
  assert_eq(lin.lines().length(), 1)
}

///|
test "a scene reply and a private reply can both be in flight" {
  // Two panels, two requests: the scene must not clear the private pending flag
  // or vice versa, or one of the two composites would unlock early.
  let base = step(crowded_world(), ApiKeyChanged("sk-test"))
  let selected = step(base, Select(Some("林掌柜")))
  let never : TurnRunner = (_request, _on_reply) => ()
  let (private_pending, _p) = update(
    selected,
    Send("私聊"),
    turn_runner=never,
  )
  let (both, _b) = update(
    step(private_pending, EnterScene("吧台")),
    Send("场景里说"),
    turn_runner=never,
  )
  let scene_key_text = scene_key("吧台")
  assert_true(both.conversations.for_character("林掌柜").pending())
  assert_true(both.conversations.for_character(scene_key_text).pending())
  // Answering the scene must leave the private wait alone.
  let (scene_answered, _s) = update(
    both,
    SceneReply(scene_key_text, "林掌柜", Some("场景回答")),
    turn_runner=never,
  )
  assert_false(
    scene_answered.conversations.for_character(scene_key_text).pending(),
  )
  assert_true(scene_answered.conversations.for_character("林掌柜").pending())
}
