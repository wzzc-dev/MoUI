///|
struct Key {
  value : String
} derive(Eq)

///|
struct ElementId {
  value : Int
} derive(Eq, Debug, ToJson)

///|
pub fn Key::new(value : String) -> Key {
  { value, }
}

///|
pub fn Key::value(self : Key) -> String {
  self.value
}

///|
pub fn ElementId::new(value : Int) -> ElementId {
  { value, }
}

///|
pub fn ElementId::value(self : ElementId) -> Int {
  self.value
}
