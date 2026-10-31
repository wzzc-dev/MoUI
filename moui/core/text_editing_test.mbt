///|
/// Copy / cut / paste shortcuts were not recognised at all before this: only
/// select-all, undo and redo existed, so Ctrl+C did nothing on every platform.
test "text editing recognises copy, cut and paste shortcuts" {
  let event = fn(key : String, control : Bool) {
    @core.KeyboardEvent::new(
      key~,
      text=None,
      pressed=true,
      repeat=false,
      modifiers=@core.KeyModifiers::new(
        shift=false,
        control~,
        alt=false,
        meta=false,
      ),
    )
  }
  assert_true(@core.is_copy_shortcut(event("c", true)))
  assert_true(@core.is_cut_shortcut(event("x", true)))
  assert_true(@core.is_paste_shortcut(event("v", true)))
  // Without a modifier these are plain text keys.
  assert_false(@core.is_copy_shortcut(event("c", false)))
  assert_false(@core.is_paste_shortcut(event("v", false)))
  // Shift+Ctrl+C is not copy (it is a different chord on every platform).
  let shifted = @core.KeyboardEvent::new(
    key="c",
    text=None,
    pressed=true,
    repeat=false,
    modifiers=@core.KeyModifiers::new(
      shift=true,
      control=true,
      alt=false,
      meta=false,
    ),
  )
  assert_false(@core.is_copy_shortcut(shifted))
}
