///|
/// A normalized locale identifier consisting of a language and optional script
/// and region subtags.
pub struct Locale {
  language : String
  script : String?
  region : String?
}

///|
/// Parses a locale identifier with a language and optional script and region.
/// Both `-` and `_` separators are accepted. Canonical locale casing uses a
/// lowercase language, titlecase script, and uppercase region.
pub fn Locale::parse(raw : String) -> Locale? {
  let raw = raw.trim()
  if raw == "" {
    return None
  }
  let parts : Array[String] = raw
    .to_owned()
    .replace_all(old="_", new="-")
    .split("-")
    .map(part => part.to_owned())
    .collect()
  guard parts.length() >= 1 else { return None }
  guard is_language(parts[0]) else { return None }
  let language = parts[0].to_lower()
  let mut script : String? = None
  let mut region : String? = None
  for index, part in parts {
    if index == 0 {
      continue
    }
    if part == "" {
      return None
    }
    if script is None && is_script(part) {
      script = Some(canonical_script(part))
      continue
    }
    if region is None && is_region(part) {
      region = Some(canonical_region(part))
      continue
    }
    return None
  }
  Some({ language, script, region })
}

///|
/// Returns the canonical language subtag.
pub fn Locale::language(self : Locale) -> String {
  self.language
}

///|
/// Returns the canonical script subtag when supplied.
pub fn Locale::script(self : Locale) -> String? {
  self.script
}

///|
/// Returns the canonical region subtag when supplied.
pub fn Locale::region(self : Locale) -> String? {
  self.region
}

///|
/// Returns the canonical locale string, such as `zh-Hans-CN`.
pub fn Locale::canonical(self : Locale) -> String {
  let result = self.language
  let result = match self.script {
    Some(script) => result + "-" + script
    None => result
  }
  match self.region {
    Some(region) => result + "-" + region
    None => result
  }
}

///|
/// Returns deterministic lookup candidates from most to least specific.
/// A locale with both script and region falls back through `language-script`
/// and then `language`.
pub fn Locale::fallback_candidates(self : Locale) -> Array[String] {
  let candidates : Array[String] = []
  candidates.push(self.canonical())
  match (self.script, self.region) {
    (Some(script), Some(_)) => candidates.push(self.language + "-" + script)
    _ => ()
  }
  if candidates.last() != Some(self.language) {
    candidates.push(self.language)
  }
  candidates
}

///|
fn is_language(value : String) -> Bool {
  let length = value.char_length()
  if length < 2 || length > 8 {
    return false
  }
  for char in value {
    if !char.is_ascii_alphabetic() {
      return false
    }
  }
  true
}

///|
fn is_script(value : String) -> Bool {
  if value.char_length() != 4 {
    return false
  }
  for char in value {
    if !char.is_ascii_alphabetic() {
      return false
    }
  }
  true
}

///|
fn is_region(value : String) -> Bool {
  if value.char_length() == 2 {
    for char in value {
      if !char.is_ascii_alphabetic() {
        return false
      }
    }
    return true
  }
  if value.char_length() == 3 {
    for char in value {
      if !char.is_ascii_digit() {
        return false
      }
    }
    return true
  }
  false
}

///|
fn canonical_script(value : String) -> String {
  let chars = value.to_lower().to_array()
  let result : Array[Char] = []
  for index, char in chars {
    if index == 0 {
      result.push(char.to_ascii_uppercase())
    } else {
      result.push(char)
    }
  }
  String::from_array(result)
}

///|
fn canonical_region(value : String) -> String {
  value.to_upper()
}
