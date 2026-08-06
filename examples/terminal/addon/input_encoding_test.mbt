///|
test "plain characters" {
  let e = @core.KeyboardEvent::new(key="a", text=Some("a"))
  debug_inspect(encode_key(e), content="Some(a)")
  let e2 = @core.KeyboardEvent::new(key="中", text=Some("中"))
  debug_inspect(encode_key(e2), content="Some(中)")
}

///|
test "special keys" {
  debug_inspect(
    encode_key(@core.KeyboardEvent::new(key="Enter")),
    content="Some(\r)",
  )
  debug_inspect(
    encode_key(@core.KeyboardEvent::new(key="Backspace")),
    content="Some(\u{7f})",
  )
  debug_inspect(
    encode_key(@core.KeyboardEvent::new(key="Tab")),
    content="Some(\t)",
  )
  debug_inspect(
    encode_key(@core.KeyboardEvent::new(key="ArrowUp")),
    content="Some(\u{1b}[A)",
  )
  debug_inspect(
    encode_key(@core.KeyboardEvent::new(key="ArrowDown")),
    content="Some(\u{1b}[B)",
  )
  debug_inspect(
    encode_key(@core.KeyboardEvent::new(key="ArrowRight")),
    content="Some(\u{1b}[C)",
  )
  debug_inspect(
    encode_key(@core.KeyboardEvent::new(key="ArrowLeft")),
    content="Some(\u{1b}[D)",
  )
  debug_inspect(
    encode_key(@core.KeyboardEvent::new(key="PageUp")),
    content="Some(\u{1b}[5~)",
  )
  debug_inspect(
    encode_key(@core.KeyboardEvent::new(key="Delete")),
    content="Some(\u{1b}[3~)",
  )
}

///|
test "ctrl combinations" {
  let ctrl = @core.KeyModifiers::new(control=true)
  debug_inspect(
    encode_key(@core.KeyboardEvent::new(key="c", modifiers=ctrl)),
    content="Some(\u{3})",
  )
  debug_inspect(
    encode_key(@core.KeyboardEvent::new(key="C", modifiers=ctrl)),
    content="Some(\u{3})",
  )
  debug_inspect(
    encode_key(@core.KeyboardEvent::new(key="d", modifiers=ctrl)),
    content="Some(\u{4})",
  )
  debug_inspect(
    encode_key(@core.KeyboardEvent::new(key="Space", modifiers=ctrl)),
    content="Some(\u{0})",
  )
}

///|
test "released keys ignored" {
  let e = @core.KeyboardEvent::new(key="a", pressed=false)
  debug_inspect(encode_key(e), content="None")
}

///|
test "modifier-only keys ignored" {
  let e = @core.KeyboardEvent::new(key="Shift", text=None)
  debug_inspect(encode_key(e), content="None")
  let e2 = @core.KeyboardEvent::new(key="Control")
  debug_inspect(encode_key(e2), content="None")
}

///|
test "function keys" {
  debug_inspect(
    encode_key(@core.KeyboardEvent::new(key="F1")),
    content="Some(\u{1b}OP)",
  )
  debug_inspect(
    encode_key(@core.KeyboardEvent::new(key="F12")),
    content="Some(\u{1b}[24~)",
  )
}

///|
test "alt prefix" {
  let alt = @core.KeyModifiers::new(alt=true)
  debug_inspect(
    encode_key(@core.KeyboardEvent::new(key="a", text=Some("a"), modifiers=alt)),
    content="Some(\u{1b}a)",
  )
  debug_inspect(
    encode_key(@core.KeyboardEvent::new(key="Enter", modifiers=alt)),
    content="Some(\r)",
  )
}
