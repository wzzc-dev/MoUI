///|
test "KeyboardEvent keeps physical code separate from logical key" {
  let event = @core.KeyboardEvent::new(
    key="a",
    code="KeyA",
    text=Some("a"),
    pressed=true,
  )
  inspect(event.key, content="a")
  inspect(event.code, content="KeyA")
  inspect(event.pressed, content="true")
  let logical_only = @core.KeyboardEvent::new(key="Enter")
  inspect(logical_only.code, content="")
}
