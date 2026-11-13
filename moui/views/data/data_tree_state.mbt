///|
pub struct TreeItem {
  id : String
  label : String
  children : Array[TreeItem]
  /// Optional leading glyph (file/folder kind). `None` keeps the historical
  /// label-only rows used by generic trees.
  icon : @style.IconName?
  /// Optional icon tint; `None` uses the ambient muted text color.
  icon_color : @core.Color?
  /// De-emphasized row (ignored/hidden entries such as dot-directories):
  /// the label renders in the muted color unless the row is selected.
  dimmed : Bool
}

///|
pub fn tree_item(
  id~ : String,
  label~ : String,
  children~ : Array[TreeItem] = [],
  icon~ : @style.IconName? = None,
  icon_color~ : @core.Color? = None,
  dimmed~ : Bool = false,
) -> TreeItem {
  { id, label, children, icon, icon_color, dimmed, }
}
