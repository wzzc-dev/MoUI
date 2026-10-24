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
  let never : TurnRunner = (_request, _on_reply, _on_delta) => ()
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
  let never : TurnRunner = (_request, _on_reply, _on_delta) => ()
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
test "a streamed delta only lands while its own turn is waiting" {
  let base = step(crowded_world(), ApiKeyChanged("sk-test"))
  let selected = step(base, Select(Some("林掌柜")))
  let never : TurnRunner = (_request, _on_reply, _on_delta) => ()
  let (asked, _e) = update(selected, Send("温一壶酒"), turn_runner=never)
  // Pieces accumulate while the request is in flight.
  let (first, _f) = update(asked, ReplyDelta("林掌柜", "酒温"), turn_runner=never)
  assert_eq(first.conversations.for_character("林掌柜").streaming(), "酒温")
  let (second, _s) = update(
    first,
    ReplyDelta("林掌柜", "好了。"),
    turn_runner=never,
  )
  assert_eq(second.conversations.for_character("林掌柜").streaming(), "酒温好了。")
  // The finished reply replaces the preview.
  let (done, _d) = update(
    second,
    Reply("林掌柜", Some("酒温好了。")),
    turn_runner=never,
  )
  assert_eq(done.conversations.for_character("林掌柜").streaming(), "")
  let completed = done.conversations.for_character("林掌柜").lines()
  assert_eq(completed[completed.length() - 1].text(), "酒温好了。")
  // A piece after completion (or after a failure) is not a new preview: the
  // turn is over, and the full reply is the record.
  let (late, _l) = update(
    done,
    ReplyDelta("林掌柜", "又一句"),
    turn_runner=never,
  )
  assert_eq(late.conversations.for_character("林掌柜").streaming(), "")
  assert_eq(
    late.conversations.for_character("林掌柜").lines().length(),
    completed.length(),
  )
}

///|
test "a delta cannot create a conversation or cross channels" {
  let base = step(crowded_world(), ApiKeyChanged("sk-test"))
  let selected = step(base, Select(Some("林掌柜")))
  let never : TurnRunner = (_request, _on_reply, _on_delta) => ()
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
  // An unknown speaker must not be materialized as a ghost conversation.
  let (unknown, _u) = update(
    both,
    ReplyDelta("并不存在的人", "字"),
    turn_runner=never,
  )
  assert_true(unknown.conversations.find("并不存在的人") is None)
  // Scene deltas go to the scene channel; private deltas to the private one.
  let (crossed, _c) = update(
    unknown,
    ReplyDelta(scene_key("吧台"), "错"),
    turn_runner=never,
  )
  assert_eq(crossed.conversations.for_character(scene_key("吧台")).streaming(), "")
  let (crossed_back, _cb) = update(
    crossed,
    SceneReplyDelta("林掌柜", "林掌柜", "错"),
    turn_runner=never,
  )
  assert_eq(
    crossed_back.conversations.for_character("林掌柜").streaming(),
    "",
  )
  // Each channel still accepts its own pieces.
  let (good, _g) = update(
    crossed_back,
    SceneReplyDelta(scene_key("吧台"), "林掌柜", "场景"),
    turn_runner=never,
  )
  assert_eq(
    good.conversations.for_character(scene_key("吧台")).streaming(),
    "场景",
  )
  let (also_good, _ag) = update(
    good,
    ReplyDelta("林掌柜", "私聊"),
    turn_runner=never,
  )
  assert_eq(
    also_good.conversations.for_character("林掌柜").streaming(),
    "私聊",
  )
}

///|
test "a completion from a replaced world never lands in the new one" {
  // Character ids are only unique within a world: the second world has its own
  // 林掌柜 waiting for an answer, so an old completion must be rejected by the
  // world generation, not merely by the conversation's pending flag.
  let base = step(crowded_world(), ApiKeyChanged("sk-test"))
  let selected = step(base, Select(Some("林掌柜")))
  let never : TurnRunner = (_request, _on_reply, _on_delta) => ()
  let (asked, _e) = update(selected, Send("旧世界的问题"), turn_runner=never)
  let old_epoch = asked.world_epoch()
  let switched = step(
    asked,
    WorldFilesArrived("别处", true, tavern_files()),
  )
  assert_true(switched.world_epoch() != old_epoch)
  let new_epoch = switched.world_epoch()
  let reselected = step(switched, Select(Some("林掌柜")))
  let (waiting_again, _w) = update(
    reselected,
    Send("新世界的问题"),
    turn_runner=never,
  )
  assert_true(waiting_again.conversations.for_character("林掌柜").pending())
  // The old request's pieces and its final reply arrive after the switch.
  let (stale_delta, _sd) = update(
    waiting_again,
    InWorld(old_epoch, ReplyDelta("林掌柜", "旧")),
    turn_runner=never,
  )
  assert_eq(
    stale_delta.conversations.for_character("林掌柜").streaming(),
    "",
  )
  let (stale_reply, _sr) = update(
    stale_delta,
    InWorld(old_epoch, Reply("林掌柜", Some("旧世界的回复"))),
    turn_runner=never,
  )
  let conversation = stale_reply.conversations.for_character("林掌柜")
  let lines = conversation.lines()
  assert_eq(lines[lines.length() - 1].text(), "新世界的问题")
  assert_eq(lines.length(), 1)
  assert_true(conversation.pending())
  // The new world's own completion still goes through.
  let (fresh, _f) = update(
    stale_reply,
    InWorld(new_epoch, Reply("林掌柜", Some("新世界的回复"))),
    turn_runner=never,
  )
  let answered = fresh.conversations.for_character("林掌柜")
  let answered_lines = answered.lines()
  assert_eq(answered_lines[answered_lines.length() - 1].text(), "新世界的回复")
  assert_false(answered.pending())
}

///|
test "a scene reply and a private reply can both be in flight" {
  // Two panels, two requests: the scene must not clear the private pending flag
  // or vice versa, or one of the two composites would unlock early.
  let base = step(crowded_world(), ApiKeyChanged("sk-test"))
  let selected = step(base, Select(Some("林掌柜")))
  let never : TurnRunner = (_request, _on_reply, _on_delta) => ()
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
