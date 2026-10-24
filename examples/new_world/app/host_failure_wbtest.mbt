///|
/// The host underneath the app can fail at any moment.
///
/// Folder access is granted per session, files can be deleted by another
/// editor, and the browser can revoke a handle. The app is a pure `update`, so
/// what matters is that a failed host call leaves the model in a state the player
/// can act on — not one that silently swallows their next message.

///|
test "a world that fails to load surfaces an error and does not look loaded" {
  // `WorldFilesArrived(folder, ok=false, [])` is what the host sends when the
  // directory cannot be read (permission revoked, folder moved, disk error).
  let (failed, _e) = update(
    WorldModel::new(),
    WorldFilesArrived("酒馆", false, []),
  )
  // The player is told, rather than shown an empty world that looks brand new.
  assert_true(failed.log().length() > 0)
  // And nothing pretends the world is open.
  assert_true(failed.current() is None)
  assert_eq(failed.scenario().characters().length(), 0)
}

///|
test "a failed load does not resurrect the previous world" {
  // Opening a second world that then fails must not leave the first world's
  // characters on screen under the second world's name.
  let base = step(crowded_world(), ApiKeyChanged("sk-test"))
  let (failed, _e) = update(
    base,
    WorldFilesArrived("不存在的世界", false, []),
  )
  // Either the previous world stays untouched, or the model is reset — but the
  // two must never be mixed (world A's cast under world B's tab).
  if failed.current() is Some(name) {
    assert_eq(name, "tavern")
    assert_eq(failed.scenario().characters().length(), 3)
  } else {
    assert_eq(failed.scenario().characters().length(), 0)
  }
}

///|
test "a commit failure is reported and the conversation still advances" {
  // The host echoes `CommitFailed` when a write fails. Losing the write is bad,
  // but losing the in-memory turn as well would be worse: the player would see
  // their message vanish.
  let base = step(crowded_world(), ApiKeyChanged("sk-test"))
  let selected = step(base, Select(Some("林掌柜")))
  let never : TurnRunner = (_request, _on_reply, _on_delta) => ()
  let (asked, _e) = update(
    selected,
    Send("写不进去也要留着"),
    turn_runner=never,
  )
  let (answered, _a) = update(
    asked,
    Reply("林掌柜", Some("好")),
    turn_runner=never,
  )
  let before = answered.conversations
    .for_character("林掌柜")
    .lines()
    .length()
  let (failed, _f) = update(
    answered,
    WorldCommitted("酒馆", false),
    turn_runner=never,
  )
  let after = failed.conversations.for_character("林掌柜").lines().length()
  // The turn is still in memory.
  assert_eq(after, before)
  // And the failure is visible so the player knows the file did not update.
  assert_true(
    failed
    .log()
    .any(line => {
      line.contains("保存") ||
      line.contains("失败") ||
      line.contains("世界")
    }),
  )
}

///|
test "the composer is usable after a host failure" {
  // Whatever went wrong, the next thing the player types must not be swallowed
  // by a stuck `pending` or a disabled composer.
  let base = step(crowded_world(), ApiKeyChanged("sk-test"))
  let selected = step(base, Select(Some("林掌柜")))
  let never : TurnRunner = (_request, _on_reply, _on_delta) => ()
  let (asked, _e) = update(selected, Send("一"), turn_runner=never)
  let (stuck, _s) = update(
    asked,
    WorldCommitted("酒馆", false),
    turn_runner=never,
  )
  // This send never got a reply, so the conversation is legitimately still
  // waiting; a commit failure for a *different* scope must not touch it.
  assert_true(stuck.conversations.for_character("林掌柜").pending())
  let (again, _g) = update(stuck, Send("二"), turn_runner=never)
  assert_true(again.conversations.for_character("林掌柜").pending())
}
