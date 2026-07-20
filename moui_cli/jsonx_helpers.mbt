// Generic JSON helpers extracted from `shell_contracts.mbt`. The original
// `doctor_*` names are kept as aliases in `shell_contracts.mbt` for backward
// compatibility. New modules should use the `json_*` names directly.

///|
fn json_exact_object(
  value : Json,
  allowed : Array[String],
  required : Array[String],
  label : String,
) -> Result[Map[String, Json], String] {
  guard value is Object(fields) else {
    return Err(label + " must be an object")
  }
  for key, _ in fields {
    if !allowed.contains(key) {
      return Err(label + " contains unknown field: " + key)
    }
  }
  for key in required {
    if !fields.contains(key) {
      return Err(label + " is missing required field: " + key)
    }
  }
  Ok(fields)
}

///|
fn json_required_string(
  fields : Map[String, Json],
  key : String,
  label : String,
) -> Result[String, String] {
  match fields.get(key) {
    Some(String(value)) if value.trim() != "" => Ok(value)
    _ => Err(label + "." + key + " must be a non-empty string")
  }
}

///|
fn json_required_int(
  fields : Map[String, Json],
  key : String,
  label : String,
) -> Result[Int, String] {
  match fields.get(key) {
    Some(Number(value, repr=_)) if value.to_int().to_double() == value =>
      Ok(value.to_int())
    _ => Err(label + "." + key + " must be an integer")
  }
}

///|
fn json_unique_strings(
  value : Json,
  label : String,
  paths? : Bool = false,
) -> Result[Array[String], String] {
  guard value is Array(values) else { return Err(label + " must be an array") }
  let result : Array[String] = []
  let seen : Map[String, Bool] = Map([])
  for index, value in values {
    guard value is String(text) && text.trim() != "" else {
      return Err(
        label + "[" + index.to_string() + "] must be a non-empty string",
      )
    }
    if seen.contains(text) {
      return Err(label + " must not contain duplicates: " + text)
    }
    if paths {
      match validate_relative_path(text) {
        Ok(_) => ()
        Err(_) =>
          return Err(label + " contains an unsafe relative path: " + text)
      }
    }
    seen[text] = true
    result.push(text)
  }
  Ok(result)
}

///|
fn json_identifier(value : String, label : String) -> Result[Unit, String] {
  if value == "moui" || value.has_prefix("moui.") {
    return Err(label + " uses the reserved moui.* namespace")
  }
  if value.contains("/") || value.contains("\\") || value.contains("\u0000") {
    return Err(label + " must not contain path separators or NUL")
  }
  Ok(())
}

///|
fn json_plugins_digest(plugins : Array[DoctorPlugin]) -> String {
  file_plan_digest(plugin_digest_plan(plugins))
}
