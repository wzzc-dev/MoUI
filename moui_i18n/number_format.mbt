///|
priv struct NumberSymbols {
  decimal : String
  group : String
  secondary_group : Int32
  min_group_digits : Int32
}

///|
/// Formats an integer with locale-aware digit grouping, such as `1,234,567`
/// for `en`, `1.234.567` for `de`, and `12,34,56,789` for `en-IN`.
pub fn Locale::format_int(self : Locale, value : Int64) -> String {
  let symbols = self.number_symbols()
  let raw = value.to_string()
  if raw.has_prefix("-") {
    "-" + group_digits(raw[1:].to_owned(), symbols)
  } else {
    group_digits(raw, symbols)
  }
}

///|
/// Formats a number with locale-aware grouping and decimal separators, such
/// as `1,234.5` for `en`, `1.234,5` for `de`, and `1 234,5` (narrow no-break
/// space) for `fr`. `fraction_digits` defaults to 2 and is clamped to 0..=15;
/// rounding is half up on the absolute value. The scaled magnitude must fit
/// in `Int64`. NaN and infinities render as `NaN`, `∞`, and `-∞`.
pub fn Locale::format_number(
  self : Locale,
  value : Double,
  fraction_digits? : Int32,
) -> String {
  if value.is_nan() {
    return "NaN"
  }
  if value.is_inf() {
    return if value < 0.0 { "-∞" } else { "∞" }
  }
  let requested = fraction_digits.unwrap_or(2)
  let digits = if requested < 0 {
    0
  } else if requested > 15 {
    15
  } else {
    requested
  }
  let mut scale = 1L
  for _ in 0..<digits {
    scale *= 10L
  }
  let scaled = (value.abs() * scale.to_double()).round().to_int64()
  let symbols = self.number_symbols()
  let mut text = group_digits((scaled / scale).to_string(), symbols)
  if digits > 0 {
    let fraction = (scaled % scale).to_string()
    text = text +
      symbols.decimal +
      "0".repeat(digits - fraction.char_length()) +
      fraction
  }
  if value < 0.0 {
    "-" + text
  } else {
    text
  }
}

///|
fn Locale::number_symbols(self : Locale) -> NumberSymbols {
  let language = self.language()
  if language == "pt" && self.region() == Some("PT") {
    return {
      decimal: ",",
      group: "\u{00A0}",
      secondary_group: 0,
      min_group_digits: 2,
    }
  }
  if language == "hi" || (language == "en" && self.region() == Some("IN")) {
    // CLDR en-IN/hi use lakh/crore grouping: #,##,##0.
    return {
      decimal: ".",
      group: ",",
      secondary_group: 2,
      min_group_digits: 1,
    }
  }
  match language {
    "de" | "es" | "it" | "pt" | "nl" | "da" | "tr" | "el" | "vi" | "id" =>
      dot_group_comma_decimal()
    "fr" =>
      {
        decimal: ",",
        group: "\u{202F}",
        secondary_group: 0,
        min_group_digits: 1,
      }
    "ru" | "uk" | "pl" | "cs" | "hu" | "sv" | "fi" | "no" | "nb" =>
      {
        decimal: ",",
        group: "\u{00A0}",
        secondary_group: 0,
        min_group_digits: 1,
      }
    _ => { decimal: ".", group: ",", secondary_group: 0, min_group_digits: 1, }
  }
}

///|
fn dot_group_comma_decimal() -> NumberSymbols {
  { decimal: ",", group: ".", secondary_group: 0, min_group_digits: 1, }
}

///|
fn group_digits(digits : String, symbols : NumberSymbols) -> String {
  let length = digits.char_length()
  if length < 3 + symbols.min_group_digits {
    return digits
  }
  let result = StringBuilder()
  for index, char in digits {
    let from_right = length - index
    if index > 0 &&
      (
        (symbols.secondary_group == 0 && from_right % 3 == 0) ||
        (
          symbols.secondary_group > 0 &&
          (
            from_right == 3 ||
            (from_right > 3 && (from_right - 3) % symbols.secondary_group == 0)
          )
        )
      ) {
      result.write_string(symbols.group)
    }
    result.write_char(char)
  }
  result.to_string()
}
