///|
priv enum ViewModifierNode[Msg] {
  KeyModifierNode(Key)
  PlainModifier(ViewModifier)
  RealizedModifier((ViewSpec) -> ViewSpec)
  TapModifier(Msg)
  LongPressModifier(Msg)
  DoubleTapModifier(Msg)
  DragModifier((DragGestureEvent) -> Msg)
  DragWithFrameModifier((DragGestureEvent, Rect) -> Msg)
  FileDropModifier((Array[String], Point) -> Msg)
}
