///|
pub(all) enum DatePickerMode {
  Date
  DateAndTime
  Time
} derive(Eq, Debug, ToJson)

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
pub fn DateValue::today() -> DateValue {
  { year: 2024, month: 1, day: 1, hour: 0, minute: 0, second: 0 }
}

///|
pub fn DateValue::format(self : DateValue, mode : DatePickerMode) -> String {
  match mode {
    DatePickerMode::Date => "\{self.year}-\{self.month}-\{self.day}"
    DatePickerMode::DateAndTime =>
      "\{self.year}-\{self.month}-\{self.day} \{self.hour}:\{self.minute}"
    DatePickerMode::Time => "\{self.hour}:\{self.minute}"
  }
}
