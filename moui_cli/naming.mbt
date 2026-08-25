///|
fn ascii_is_letter(unit : UInt16) -> Bool {
  (unit >= 97 && unit <= 122) || (unit >= 65 && unit <= 90)
}

///|
fn ascii_is_digit(unit : UInt16) -> Bool {
  unit >= 48 && unit <= 57
}

///|
fn project_id_from_path(path : String) -> String {
  let source = base_name(path).to_lower()
  let builder = StringBuilder()
  let previous_separator = Ref(false)
  for index in 0..<source.length() {
    let char = source[index]
    if ascii_is_letter(char) || ascii_is_digit(char) {
      builder.write_char(char.to_int().unsafe_to_char())
      previous_separator.val = false
    } else if !previous_separator.val && !builder.is_empty() {
      builder.write_char('_')
      previous_separator.val = true
    }
  }
  let value = builder.to_string()
  let value = if value.has_suffix("_") {
    value[:value.length() - 1].to_owned()
  } else {
    value
  }
  if value == "" {
    "moui_app"
  } else if ascii_is_digit(value[0]) {
    "app_" + value
  } else {
    value
  }
}

///|
fn product_name(id : String) -> String {
  let builder = StringBuilder()
  let capitalize = Ref(true)
  for index in 0..<id.length() {
    let char = id[index]
    if char == 95 || char == 45 || char == 32 {
      capitalize.val = true
    } else if capitalize.val && char >= 97 && char <= 122 {
      builder.write_char((char.to_int() - 32).unsafe_to_char())
      capitalize.val = false
    } else {
      builder.write_char(char.to_int().unsafe_to_char())
      capitalize.val = false
    }
  }
  let value = builder.to_string()
  if value == "" {
    "MoUIApp"
  } else {
    value
  }
}

///|
fn default_title(id : String) -> String {
  product_name(id)
}

///|
fn valid_project_id(id : String) -> Bool {
  if id == "" || !ascii_is_letter(id[0]) {
    return false
  }
  for index in 1..<id.length() {
    let char = id[index]
    if !ascii_is_letter(char) && !ascii_is_digit(char) && char != 95 {
      return false
    }
  }
  true
}

///|
fn valid_module_name(name : String) -> Bool {
  if name == "" ||
    name.has_prefix("/") ||
    name.has_suffix("/") ||
    !name.contains("/") {
    return false
  }
  for index in 0..<name.length() {
    let char = name[index]
    if !ascii_is_letter(char) &&
      !ascii_is_digit(char) &&
      char != 95 &&
      char != 45 &&
      char != 46 &&
      char != 47 {
      return false
    }
  }
  !name.contains("//") && !name.contains("../") && !name.contains("/..")
}

///|
fn valid_version(version : String) -> Bool {
  if version == "" {
    return false
  }
  for index in 0..<version.length() {
    let char = version[index]
    if !ascii_is_letter(char) &&
      !ascii_is_digit(char) &&
      char != 46 &&
      char != 45 &&
      char != 43 {
      return false
    }
  }
  true
}

///|
fn valid_bundle_id(value : String) -> Bool {
  if value == "" ||
    !value.contains(".") ||
    value.has_prefix(".") ||
    value.has_suffix(".") {
    return false
  }
  for index in 0..<value.length() {
    let char = value[index]
    if !ascii_is_letter(char) &&
      !ascii_is_digit(char) &&
      char != 46 &&
      char != 45 &&
      char != 95 {
      return false
    }
  }
  !value.contains("..")
}

///|
fn moon_string(value : String) -> String {
  value
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\"", new="\\\"")
  .replace_all(old="\n", new="\\n")
  .replace_all(old="\r", new="\\r")
}

///|
fn html_text(value : String) -> String {
  value
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
}
