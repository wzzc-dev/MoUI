///|
priv enum ViewModifierNode[Msg] {
  KeyModifierNode(Key)
  PlainModifier(ViewModifier)
  TapModifier(Msg)
  LongPressModifier(Msg)
  DoubleTapModifier(Msg)
  DragModifier((DragGestureEvent) -> Msg)
  DragWithFrameModifier((DragGestureEvent, Rect) -> Msg)
  FileDropModifier((Array[String], Point) -> Msg)
}
