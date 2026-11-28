///|
/// Copy / cut / paste shortcuts were not recognised at all before this: only
/// select-all, undo and redo existed, so Ctrl+C did nothing on every platform.
/// Plain Ctrl+C is Interrupt now; copy stays on Cmd+C, Ctrl+Shift+C, and
/// Ctrl+Insert.
test "text editing recognises copy, cut and paste shortcuts" {
  let event = fn(key : String, modifiers : @core.KeyModifiers) {
    @core.KeyboardEvent::new(
      key~,
      text=None,
      pressed=true,
      repeat=false,
      modifiers~,
    )
  }
  let control = @core.KeyModifiers::new(control=true)
  let shifted_control = @core.KeyModifiers::new(shift=true, control=true)
  let meta = @core.KeyModifiers::new(meta=true)
  assert_true(@core.is_copy_shortcut(event("c", shifted_control)))
  assert_true(@core.is_copy_shortcut(event("c", meta)))
  assert_true(@core.is_copy_shortcut(event("Insert", control)))
  assert_true(@core.is_cut_shortcut(event("x", control)))
  assert_true(@core.is_paste_shortcut(event("v", control)))
  // Without a modifier these are plain text keys.
  let none = @core.KeyModifiers::none()
  assert_false(@core.is_copy_shortcut(event("c", none)))
  assert_false(@core.is_paste_shortcut(event("v", none)))
  // Plain Ctrl+C is the interrupt chord, not copy.
  assert_false(@core.is_copy_shortcut(event("c", control)))
}
