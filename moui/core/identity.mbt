///|
#derive(Eq)
struct Key {
  value : String
}

///|
pub extend Key with Eq::{not_equal, equal}

///|
pub fn Key::new(value : String) -> Key {
  { value, }
}

///|
pub fn Key::value(self : Key) -> String {
  self.value
}
