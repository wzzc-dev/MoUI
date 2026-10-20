///|
pub(all) struct DateValue {
  year : Int32
  month : Int32
  day : Int32
  hour : Int32
  minute : Int32
  second : Int32
} derive(Eq, Debug, ToJson)

///|
pub extend DateValue with Debug::{to_repr}

///|
pub extend DateValue with Eq::{not_equal, equal}

///|
pub extend DateValue with ToJson::{to_json}

///|
pub fn DateValue::new(
  year~ : Int32,
  month~ : Int32,
  day~ : Int32,
  hour~ : Int32 = 0,
  minute~ : Int32 = 0,
  second~ : Int32 = 0,
) -> DateValue {
  { year, month, day, hour, minute, second, }
}

///|
pub fn DateValue::format_date(self : DateValue) -> String {
  "\{self.year}-\{self.month}-\{self.day}"
}

///|
pub fn DateValue::format_time(self : DateValue) -> String {
  "\{self.hour}:\{self.minute}"
}

///|
pub fn DateValue::format_date_time(self : DateValue) -> String {
  "\{self.format_date()} \{self.format_time()}"
}
