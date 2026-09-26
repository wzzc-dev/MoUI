///|
test "web pointer button normalization matches the native decode convention" {
  // Browsers report button = -1 on move/exit/cancel (no button changed since
  // the last event). The native window decoders never see that and leave Move
  // at the default 0, and the gesture modifiers treat any Move without button
  // 0 as non-primary — the regression that stalled every web drag.
  inspect(web_pointer_button(21, -1), content="0") // mouse move
  inspect(web_pointer_button(22, -1), content="0") // pointer exit
  inspect(web_pointer_button(25, -1), content="0") // pointer cancel
  inspect(web_pointer_button(30, -1), content="0") // touch/wheel move
  // Press/release map DOM codes (0 left / 1 middle / 2 right) to core codes
  // (0 left / 1 right / 2 middle), mirroring mouse_button_to_core.
  inspect(web_pointer_button(23, 0), content="0") // left down
  inspect(web_pointer_button(24, 0), content="0") // left up
  inspect(web_pointer_button(23, 1), content="2") // middle down
  inspect(web_pointer_button(24, 1), content="2") // middle up
  inspect(web_pointer_button(23, 2), content="1") // right down
  inspect(web_pointer_button(24, 2), content="1") // right up
  inspect(web_pointer_button(23, 3), content="3") // back down
  inspect(web_pointer_button(23, 4), content="4") // forward down
}
