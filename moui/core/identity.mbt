///|
struct Key {
  value : String
} derive(Eq)

///|
pub fn Key::new(value : String) -> Key {
  { value, }
}

///|
pub fn Key::value(self : Key) -> String {
  self.value
}
