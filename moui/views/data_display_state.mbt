///|
pub struct DescriptionItem {
  term : String
  detail : String
}

///|
pub fn description_item(term : String, detail : String) -> DescriptionItem {
  { term, detail }
}
