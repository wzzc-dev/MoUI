///|
/// What a failed provider call leaves behind.
///
/// Networks fail, keys expire, and a provider returns 500. The user-visible
/// question is not "was the request sent" but "can I carry on": a failure that
/// leaves `pending` set bricks the composer, and one that drops the player's
/// line loses what they wrote.

///|
test "a failed turn clears the wait and keeps the player's line" {
  let base = step(crowded_world(), ApiKeyChanged("sk-test"))
  let selected = step(base, Select(Some("林掌柜")))
  let never : TurnRunner = (_request, _on_reply) => ()
  let (asked, _e) = update(
    selected,
    Send("这句话不能丢"),
    turn_runner=never,
  )
  // The composer must refuse a second send while the first is in flight.
  assert_true(asked.conversations.for_character("林掌柜").pending())
  let (failed, _f) = update(asked, Reply("林掌柜", None), turn_runner=never)
  let conversation = failed.conversations.for_character("林掌柜")
  // No longer waiting: otherwise the composer stays disabled forever.
  assert_false(conversation.pending())
  // The player's line survives the failure: retyping it is not their job.
  let lines = conversation.lines()
  assert_eq(lines[lines.length() - 1].text(), "这句话不能丢")
  assert_true(lines[lines.length() - 1].speaker() is Player)
  // And the player is told, rather than left wondering why nothing happened.
  assert_true(failed.log().length() > 0)
  let notice = failed.log()[0]

  assert_true(
    notice.contains("失败") ||
    notice.contains("错误") ||
    notice.contains("超时"),
  )
}

///|
test "a failed turn can be retried immediately" {
  let base = step(crowded_world(), ApiKeyChanged("sk-test"))
  let selected = step(base, Select(Some("林掌柜")))
  let never : TurnRunner = (_request, _on_reply) => ()
  let (asked, _e) = update(selected, Send("再来一次"), turn_runner=never)
  let (failed, _f) = update(asked, Reply("林掌柜", None), turn_runner=never)
  // Sending again must be allowed; a stuck pending flag would silently drop this.
  let (retried, _r) = update(failed, Send("再来一次"), turn_runner=never)
  assert_true(retried.conversations.for_character("林掌柜").pending())
  // The retry appended a fresh player line rather than corrupting history.
  let lines = retried.conversations.for_character("林掌柜").lines()
  assert_eq(lines[lines.length() - 1].text(), "再来一次")
}

///|
test "a failed regenerate leaves the existing reply intact" {
  // Regenerating a reply that already exists must not blank it when the second
  // attempt fails: the player would lose a good answer to a transient error.
  let base = step(crowded_world(), ApiKeyChanged("sk-test"))
  let selected = step(base, Select(Some("林掌柜")))
  let never : TurnRunner = (_request, _on_reply) => ()
  let (asked, _e) = update(selected, Send("嗨"), turn_runner=never)
  let (answered, _a) = update(
    asked,
    Reply("林掌柜", Some("原来的好回复")),
    turn_runner=never,
  )
  let (regenerating, _g) = update(answered, RegenerateReply, turn_runner=never)
  let (failed, _f) = update(regenerating, Regenerated(None), turn_runner=never)
  let conversation = failed.conversations.for_character("林掌柜")
  let lines = conversation.lines()
  assert_eq(lines[lines.length() - 1].text(), "原来的好回复")
  // And the wait is over.
  assert_false(conversation.pending())
}

///|
test "an empty reply is treated as no reply, not as an empty message" {
  // Providers sometimes return `""` or whitespace. Persisting that would put a
  // blank bubble in the transcript that the player can never edit away.
  let base = step(crowded_world(), ApiKeyChanged("sk-test"))
  let selected = step(base, Select(Some("林掌柜")))
  let never : TurnRunner = (_request, _on_reply) => ()
  let (asked, _e) = update(selected, Send("说点什么"), turn_runner=never)
  let (replied, _r) = update(
    asked,
    Reply("林掌柜", Some("   \n  ")),
    turn_runner=never,
  )
  let conversation = replied.conversations.for_character("林掌柜")
  let lines = conversation.lines()
  assert_true(lines[lines.length() - 1].speaker() is Player)
  assert_false(conversation.pending())
}
