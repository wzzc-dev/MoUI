///|
pub struct TreeItem {
  id : String
  label : String
  children : Array[TreeItem]
}

///|
pub fn tree_item(
  id~ : String,
  label~ : String,
  children? : Array[TreeItem] = [],
) -> TreeItem {
  { id, label, children }
}
