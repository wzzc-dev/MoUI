///|
/// Resolves messages from a catalog using requested and default locale
/// fallback candidates.
pub struct Translator {
  catalog : Catalog
  locale : Locale
  default_locale : Locale
}

///|
/// Creates a translator for a catalog, requested locale, and default locale.
pub fn Translator::new(
  catalog~ : Catalog,
  locale~ : Locale,
  default_locale~ : Locale,
) -> Translator {
  { catalog, locale, default_locale, }
}

///|
/// Translates a message key and interpolates named values. Missing messages
/// return a nonfatal `[[key]]` marker.
pub fn Translator::translate(
  self : Translator,
  key : String,
  values? : ArrayView[(String, String)],
) -> String {
  match self.lookup(key) {
    Some(message) => interpolate(message, values.unwrap_or([]))
    None => "[[" + key + "]]"
  }
}

///|
/// Translates a plural message using the CLDR cardinal plural category for
/// the requested locale (see `Locale::plural_category`). When the selected
/// category variant is absent, the `.other` variant is used. The `count`
/// value is always available as the `{count}` placeholder.
pub fn Translator::translate_count(
  self : Translator,
  key : String,
  count : Int32,
  values? : ArrayView[(String, String)],
) -> String {
  let plural_key = key + "." + self.locale.plural_category(count).key()
  let interpolation_values : Array[(String, String)] = [
    ("count", count.to_string()),
  ]
  for value in values.unwrap_or([]) {
    if value.0 != "count" {
      interpolation_values.push(value)
    }
  }
  let message = match self.lookup(plural_key) {
    Some(message) => Some(message)
    None => self.lookup(key + ".other")
  }
  match message {
    Some(message) => interpolate(message, interpolation_values)
    None => "[[" + key + "]]"
  }
}

///|
fn Translator::lookup(self : Translator, key : String) -> String? {
  for candidate in self.locale.fallback_candidates() {
    match self.catalog.lookup(candidate, key) {
      Some(message) => return Some(message)
      None => ()
    }
  }
  for candidate in self.default_locale.fallback_candidates() {
    match self.catalog.lookup(candidate, key) {
      Some(message) => return Some(message)
      None => ()
    }
  }
  None
}

///|
fn interpolate(
  template : String,
  values : ArrayView[(String, String)],
) -> String {
  let result = StringBuilder()
  let chars = template.to_array()
  let mut index = 0
  while index < chars.length() {
    let char = chars[index]
    if char == '{' {
      if index + 1 < chars.length() && chars[index + 1] == '{' {
        result.write_char('{')
        index += 2
      } else {
        match closing_brace(chars, index + 1) {
          Some(end) => {
            let name = String::from_array(chars[index + 1:end])
            match lookup_value(values, name) {
              Some(value) => result.write_string(value)
              None => result.write_string("{" + name + "}")
            }
            index = end + 1
          }
          None => {
            result.write_char(char)
            index += 1
          }
        }
      }
    } else if char == '}' &&
      index + 1 < chars.length() &&
      chars[index + 1] == '}' {
      result.write_char('}')
      index += 2
    } else {
      result.write_char(char)
      index += 1
    }
  }
  result.to_string()
}

///|
fn closing_brace(chars : Array[Char], start : Int32) -> Int32? {
  let mut index = start
  while index < chars.length() {
    if chars[index] == '}' {
      return Some(index)
    }
    if chars[index] == '{' {
      return None
    }
    index += 1
  }
  None
}

///|
fn lookup_value(values : ArrayView[(String, String)], name : String) -> String? {
  for value in values {
    if value.0 == name {
      return Some(value.1)
    }
  }
  None
}
