///|
pub let default_success_marker : String = "moui_skia native smoke test passed"

///|
pub(all) struct MarkerValue {
  marker : String
  value : String
}

///|
pub(all) struct ConditionalMarker {
  marker : String
  when_marker : String
  when_value : String
}

///|
pub(all) struct SmokeContract {
  stage_markers : Array[String]
  expected_values : Array[MarkerValue]
  conditional_markers : Array[ConditionalMarker]
}

///|
fn json_object(
  value : Json,
  label : String,
) -> Result[Map[String, Json], String] {
  match value {
    Json::Object(fields) => Ok(fields)
    _ => Err(label)
  }
}

///|
fn json_string_field(fields : Map[String, Json], key : String) -> String {
  match fields.get(key) {
    Some(Json::String(value)) => value.trim().to_owned()
    _ => ""
  }
}

///|
fn json_array_field(
  fields : Map[String, Json],
  key : String,
  required : Bool,
) -> Result[Array[Json], String] {
  match fields.get(key) {
    Some(Json::Array(values)) => Ok(values)
    Some(_) => Err("Skia platform status " + key + " must be a list")
    None if required => Err("Skia platform status is missing " + key)
    None => Ok([])
  }
}

///|
pub fn parse_smoke_contract(
  status_text : String,
) -> Result[SmokeContract, String] {
  let parsed = @json.parse(status_text) catch {
    _ => return Err("Skia platform status JSON is invalid")
  }
  let status = match
    json_object(parsed, "Skia platform status JSON root must be an object") {
    Ok(fields) => fields
    Err(message) => return Err(message)
  }

  let capability_values = match
    json_array_field(status, "native_smoke_capabilities", true) {
    Ok(values) => values
    Err(message) => return Err(message)
  }
  if capability_values.is_empty() {
    return Err(
      "Skia platform status is missing native smoke capability markers",
    )
  }

  let stage_markers : Array[String] = []
  let seen_markers : Map[String, Bool] = Map([])
  for capability in capability_values {
    let fields = match
      json_object(
        capability, "native_smoke_capabilities entries must be objects",
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let marker = json_string_field(fields, "marker")
    let capability_id = json_string_field(fields, "id")
    if marker == "" {
      return Err("native smoke capability is missing marker: " + capability_id)
    }
    if seen_markers.contains(marker) {
      return Err("duplicate native smoke capability marker: " + marker)
    }
    seen_markers[marker] = true
    stage_markers.push(marker)
  }

  let expected_values : Array[MarkerValue] = []
  let expected_value_entries = match
    json_array_field(status, "native_smoke_expected_values", false) {
    Ok(values) => values
    Err(message) => return Err(message)
  }
  for expected in expected_value_entries {
    let fields = match
      json_object(
        expected, "native_smoke_expected_values entries must be objects",
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let marker = json_string_field(fields, "marker")
    let value = json_string_field(fields, "value")
    if marker != "" && value != "" {
      if !seen_markers.contains(marker) {
        return Err(
          "native smoke expected value references unknown marker: " + marker,
        )
      }
      expected_values.push({ marker, value })
    }
  }

  let conditional_markers : Array[ConditionalMarker] = []
  let conditional_entries = match
    json_array_field(status, "native_smoke_conditional_capabilities", false) {
    Ok(values) => values
    Err(message) => return Err(message)
  }
  for conditional in conditional_entries {
    let fields = match
      json_object(
        conditional, "native_smoke_conditional_capabilities entries must be objects",
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let marker = json_string_field(fields, "marker")
    let when_marker = json_string_field(fields, "when_marker")
    let when_value = json_string_field(fields, "when_value")
    let capability_id = json_string_field(fields, "id")
    if marker == "" && when_marker == "" && when_value == "" {
      continue
    }
    if marker == "" {
      return Err(
        "native smoke conditional capability is missing marker: " +
        capability_id,
      )
    }
    if when_marker == "" {
      return Err(
        "native smoke conditional capability is missing when_marker: " +
        capability_id,
      )
    }
    if when_value == "" {
      return Err(
        "native smoke conditional capability is missing when_value: " +
        capability_id,
      )
    }
    if seen_markers.contains(marker) {
      return Err("duplicate native smoke capability marker: " + marker)
    }
    if !seen_markers.contains(when_marker) {
      return Err(
        "native smoke conditional capability references an unknown condition marker: " +
        capability_id +
        ": " +
        when_marker,
      )
    }
    conditional_markers.push({ marker, when_marker, when_value })
  }

  Ok({ stage_markers, expected_values, conditional_markers })
}

///|
fn log_lines(text : String) -> Array[String] {
  let lines : Array[String] = []
  for line in text.split("\n") {
    lines.push(line.to_owned())
  }
  lines
}

///|
fn has_exact_line(lines : Array[String], expected : String) -> Bool {
  lines.any(line => line.trim().to_owned() == expected)
}

///|
fn marker_value(
  lines : Array[String],
  marker : String,
) -> Result[String, String] {
  for index in 0..<lines.length() {
    if lines[index].trim().to_owned() == marker {
      if index + 1 >= lines.length() {
        return Err("native smoke executable log marker has no value: " + marker)
      }
      return Ok(lines[index + 1].trim().to_owned())
    }
  }
  Err(
    "native smoke executable log is missing exact stage marker line: " + marker,
  )
}

///|
pub fn verify_smoke_log_text(
  log_text : String,
  marker : String,
  contract : SmokeContract,
) -> Result[Unit, String] {
  let lines = log_lines(log_text)
  if !has_exact_line(lines, marker) {
    return Err(
      "native smoke executable log is missing the success marker: " + marker,
    )
  }

  for stage_marker in contract.stage_markers {
    if !has_exact_line(lines, stage_marker) {
      return Err(
        "native smoke executable log is missing required stage marker: " +
        stage_marker,
      )
    }
  }

  for expected in contract.expected_values {
    let actual_value = match marker_value(lines, expected.marker) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    if actual_value != expected.value {
      return Err(
        "native smoke executable log has unexpected stage marker value: " +
        expected.marker +
        "\n  expected=" +
        expected.value +
        "\n  actual=" +
        actual_value,
      )
    }
  }

  for conditional in contract.conditional_markers {
    let actual_when_value = match marker_value(lines, conditional.when_marker) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    if actual_when_value == conditional.when_value {
      if !has_exact_line(lines, conditional.marker) {
        return Err(
          "native smoke executable log is missing conditional stage marker: " +
          conditional.marker +
          "\n  when_marker=" +
          conditional.when_marker +
          "\n  when_value=" +
          conditional.when_value,
        )
      }
      match marker_value(lines, conditional.marker) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
  }
  Ok(())
}

///|
pub fn verify_smoke_log_contract(
  log_text : String,
  status_text : String,
  marker : String,
) -> Result[Unit, String] {
  let contract = match parse_smoke_contract(status_text) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  verify_smoke_log_text(log_text, marker, contract)
}
