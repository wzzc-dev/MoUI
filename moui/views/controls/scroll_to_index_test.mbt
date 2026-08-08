///|
test "scroll_to_index computes offset from item stride" {
  let intent = scroll_to_index(
    request_id=7,
    index=3,
    item_height=20.0,
    spacing=2.0,
  )
  inspect(intent.id, content="7")
  inspect(intent.offset.y, content="66")
  let zero = scroll_to_index(request_id=8, index=0, item_height=44.0)
  inspect(zero.id, content="8")
  inspect(zero.offset.y, content="0")
}
