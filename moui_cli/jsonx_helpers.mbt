// Generic JSON helpers for CLI metadata validation.

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
