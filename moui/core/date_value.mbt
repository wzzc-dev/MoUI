///|
pub(all) struct DateValue {
  year : Int
  month : Int
  day : Int
  hour : Int
  minute : Int
  second : Int
} derive(Eq, Debug, ToJson)

///|
pub fn DateValue::new(
  year~ : Int,
  month~ : Int,
  day~ : Int,
  hour? : Int = 0,
  minute? : Int = 0,
  second? : Int = 0,
) -> DateValue {
  { year, month, day, hour, minute, second }
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
