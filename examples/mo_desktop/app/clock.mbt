///|
fn desktop_clock_time(clock : @host.HostWallClock) -> String {
  "\{clock_two_digits(clock.hour)}:\{clock_two_digits(clock.minute)}"
}

///|
fn desktop_clock_menu_label(clock : @host.HostWallClock) -> String {
  "\{desktop_weekday_short(clock.weekday)} \{desktop_month_short(clock.month)} \{clock.day}  \{desktop_clock_time(clock)}"
}

///|
fn desktop_clock_lock_date(clock : @host.HostWallClock) -> String {
  "\{desktop_weekday_full(clock.weekday)}, \{desktop_month_full(clock.month)} \{clock.day}"
}

///|
fn desktop_month_year(clock : @host.HostWallClock) -> String {
  "\{desktop_month_full(clock.month)} \{clock.year}"
}

///|
fn clock_two_digits(value : Int) -> String {
  if value < 10 { "0" + value.to_string() } else { value.to_string() }
}

///|
fn desktop_weekday_short(weekday : Int) -> String {
  match weekday {
    0 => "Sun"
    1 => "Mon"
    2 => "Tue"
    3 => "Wed"
    4 => "Thu"
    5 => "Fri"
    _ => "Sat"
  }
}

///|
fn desktop_weekday_full(weekday : Int) -> String {
  match weekday {
    0 => "Sunday"
    1 => "Monday"
    2 => "Tuesday"
    3 => "Wednesday"
    4 => "Thursday"
    5 => "Friday"
    _ => "Saturday"
  }
}

///|
fn desktop_month_short(month : Int) -> String {
  match month {
    1 => "Jan"
    2 => "Feb"
    3 => "Mar"
    4 => "Apr"
    5 => "May"
    6 => "Jun"
    7 => "Jul"
    8 => "Aug"
    9 => "Sep"
    10 => "Oct"
    11 => "Nov"
    _ => "Dec"
  }
}

///|
fn desktop_month_full(month : Int) -> String {
  match month {
    1 => "January"
    2 => "February"
    3 => "March"
    4 => "April"
    5 => "May"
    6 => "June"
    7 => "July"
    8 => "August"
    9 => "September"
    10 => "October"
    11 => "November"
    _ => "December"
  }
}
