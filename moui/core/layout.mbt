///|
pub(all) struct LayoutResult {
  frame : Rect
  children : Array[LayoutResult]
} derive(Eq, Debug, ToJson)

///|
pub fn hit_test(layout : LayoutResult, point : Point) -> Bool {
  if !layout.frame.contains(point) {
    false
  } else if layout.children.length() == 0 {
    true
  } else {
    layout.children.any(child => hit_test(child, point))
  }
}
