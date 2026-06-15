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
fn date_value_compare(left : DateValue, right : DateValue) -> Int {
  let year = compare_int(left.year, right.year)
  if year != 0 {
    return year
  }
  let month = compare_int(left.month, right.month)
  if month != 0 {
    return month
  }
  let day = compare_int(left.day, right.day)
  if day != 0 {
    return day
  }
  let hour = compare_int(left.hour, right.hour)
  if hour != 0 {
    return hour
  }
  let minute = compare_int(left.minute, right.minute)
  if minute != 0 {
    return minute
  }
  compare_int(left.second, right.second)
}

///|
fn date_value_in_range(
  value : DateValue,
  min_date : DateValue?,
  max_date : DateValue?,
) -> Bool {
  let after_min = match min_date {
    Some(min_date) => date_value_compare(value, min_date) >= 0
    None => true
  }
  let before_max = match max_date {
    Some(max_date) => date_value_compare(value, max_date) <= 0
    None => true
  }
  after_min && before_max
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
