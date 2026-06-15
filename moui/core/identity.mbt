///|
struct Key {
  value : String
} derive(Eq)

///|
struct ElementId {
  value : Int
} derive(Eq, Debug, ToJson)

///|
fn Key::new(value : String) -> Key {
  { value, }
}

///|
pub fn ElementId::new(value : Int) -> ElementId {
  { value, }
}

///|
pub fn ElementId::value(self : ElementId) -> Int {
  self.value
}
