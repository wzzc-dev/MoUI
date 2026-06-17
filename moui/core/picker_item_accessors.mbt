///|

///|
pub struct PickerItem {
  id : String
  label : String
}

///|
pub fn PickerItem::new(id~ : String, label~ : String) -> PickerItem {
  { id, label }
}

///|
pub fn PickerItem::id(self : PickerItem) -> String {
  self.id
}

///|
pub fn PickerItem::label(self : PickerItem) -> String {
  self.label
}
