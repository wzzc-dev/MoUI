///|
pub struct DataFilter[Msg] {
  id : String
  label : String
  selected : Bool
  message : Msg
  enabled : Bool
}

///|
pub fn[Msg] data_filter(
  id~ : String,
  label~ : String,
  selected~ : Bool,
  message~ : Msg,
  enabled? : Bool = true,
) -> DataFilter[Msg] {
  { id, label, selected, message, enabled }
}
