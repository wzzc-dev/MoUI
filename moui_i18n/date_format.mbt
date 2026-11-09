///|
/// A validated proleptic Gregorian calendar date for numeric formatting.
pub(all) struct CalendarDate {
  year : Int32
  month : Int32
  day : Int32
}

///|
/// Creates a calendar date, rejecting years outside 0..=9999, months outside
/// 1..=12, and days outside the month's length (including leap-year rules).
pub fn CalendarDate::new(
  year~ : Int32,
  month~ : Int32,
  day~ : Int32,
) -> CalendarDate? {
  guard year >= 0 && year <= 9999 && month >= 1 && month <= 12 else {
    return None
  }
  guard day >= 1 && day <= days_in_month(year, month) else { return None }
  Some({ year, month, day, })
}

///|
/// Formats a date in the locale's numeric field order and separator, with a
/// four-digit year and zero-padded month and day: `11/09/2026` for `en-US`,
/// `09.11.2026` for `de`, `2026/11/09` for `ja`. Unlisted locales use the
/// ISO-style `2026-11-09` order.
pub fn Locale::format_date(self : Locale, date : CalendarDate) -> String {
  let pattern = self.date_pattern()
  let year = pad_number(date.year, 4)
  let month = pad_number(date.month, 2)
  let day = pad_number(date.day, 2)
  let fields : Array[String] = match pattern.order {
    YearFirst => [year, month, day]
    MonthFirst => [month, day, year]
    DayFirst => [day, month, year]
  }
  fields.join(pattern.separator) + pattern.suffix
}

///|
priv enum DateOrder {
  YearFirst
  MonthFirst
  DayFirst
}

///|
priv struct DatePattern {
  order : DateOrder
  separator : String
  suffix : String
}

///|
fn Locale::date_pattern(self : Locale) -> DatePattern {
  let language = self.language()
  let region = self.region().unwrap_or("")
  if language == "en" {
    return match region {
      "GB" | "AU" | "NZ" | "IE" | "IN" | "ZA" =>
        { order: DayFirst, separator: "/", suffix: "", }
      "CA" => { order: YearFirst, separator: "-", suffix: "", }
      _ => { order: MonthFirst, separator: "/", suffix: "", }
    }
  }
  match language {
    "de" | "ru" | "uk" | "pl" | "cs" | "da" | "fi" | "no" | "nb" =>
      { order: DayFirst, separator: ".", suffix: "", }
    "fr"
    | "es"
    | "it"
    | "pt"
    | "ar"
    | "hi"
    | "tr"
    | "el"
    | "th"
    | "vi"
    | "id" => { order: DayFirst, separator: "/", suffix: "", }
    "nl" => { order: DayFirst, separator: "-", suffix: "", }
    "ja" | "zh" => { order: YearFirst, separator: "/", suffix: "", }
    // CLDR ko/hu numeric patterns are `y. MM. dd.` — the final field keeps
    // its period, so the separator alone does not describe the output.
    "ko" | "hu" => { order: YearFirst, separator: ". ", suffix: ".", }
    _ => { order: YearFirst, separator: "-", suffix: "", }
  }
}

///|
fn days_in_month(year : Int32, month : Int32) -> Int32 {
  match month {
    2 =>
      if year % 4 == 0 && (year % 100 != 0 || year % 400 == 0) {
        29
      } else {
        28
      }
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
}

///|
fn pad_number(value : Int32, width : Int32) -> String {
  let text = value.to_string()
  let padding = width - text.char_length()
  if padding > 0 {
    "0".repeat(padding) + text
  } else {
    text
  }
}
