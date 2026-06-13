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

///|
fn compare_int(a : Int, b : Int) -> Int {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
fn DateValue::compare(self : DateValue, other : DateValue) -> Int {
  let year = compare_int(self.year, other.year)
  if year != 0 {
    year
  } else {
    let month = compare_int(self.month, other.month)
    if month != 0 {
      month
    } else {
      let day = compare_int(self.day, other.day)
      if day != 0 {
        day
      } else {
        let hour = compare_int(self.hour, other.hour)
        if hour != 0 {
          hour
        } else {
          let minute = compare_int(self.minute, other.minute)
          if minute != 0 {
            minute
          } else {
            compare_int(self.second, other.second)
          }
        }
      }
    }
  }
}

///|
fn date_value_in_range(
  value : DateValue,
  min_date : DateValue?,
  max_date : DateValue?,
) -> Bool {
  let after_min = match min_date {
    Some(min_date) => value.compare(min_date) >= 0
    None => true
  }
  let before_max = match max_date {
    Some(max_date) => value.compare(max_date) <= 0
    None => true
  }
  after_min && before_max
}

///|
fn first_weekday_of_month_sunday0(year : Int, month : Int) -> Int {
  let q = 1
  let zeller_month = if month < 3 { month + 12 } else { month }
  let zeller_year = if month < 3 { year - 1 } else { year }
  let k = zeller_year % 100
  let j = zeller_year / 100
  let h = (q + 13 * (zeller_month + 1) / 5 + k + k / 4 + j / 4 + 5 * j) % 7
  if h == 0 {
    6
  } else {
    h - 1
  }
}

///|
fn is_leap_year(year : Int) -> Bool {
  year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

///|
fn days_in_month(year : Int, month : Int) -> Int {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if is_leap_year(year) { 29 } else { 28 }
    _ => 31
  }
}
