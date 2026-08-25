///|
let provider_lock =
  #|{
  #|  "providers": {
  #|    "release": {
  #|      "commit": "0123456789abcdef0123456789abcdef01234567",
  #|      "tag": "m134"
  #|    },
  #|    "jetbrains": {
  #|      "commit": "89abcdef012345670123456789abcdef01234567",
  #|      "tag": "jb-2026"
  #|    }
  #|  }
  #|}

///|
let valid_status =
  #|{
  #|  "schema_version": 2,
  #|  "revision_file": "skia-revision.txt",
  #|  "platforms": {
  #|    "linux": {
  #|      "accepted": true,
  #|      "state": "accepted",
  #|      "accepted_artifact": "linux-artifact",
  #|      "accepted_commit": "0123456789abcdef0123456789abcdef01234567",
  #|      "accepted_provider": "release",
  #|      "accepted_version": "m134",
  #|      "first_acceptance_platform": true,
  #|      "source_build": true,
  #|      "required_artifact_logs": [
  #|        "linux-real-skia-smoke-preflight.log",
  #|        "linux-real-skia-smoke.log",
  #|        "linux-native-smoke-output.log",
  #|        "linux-real-skia-acceptance.log"
  #|      ],
  #|      "required_verifier": "scripts/verify-real-skia-artifact.sh --platform linux --log-dir logs",
  #|      "next_step": "Keep Linux accepted."
  #|    },
  #|    "macos": {
  #|      "accepted": false,
  #|      "state": "not accepted",
  #|      "source_build": false,
  #|      "required_artifact_logs": [
  #|        "macos-real-skia-smoke-preflight.log",
  #|        "macos-real-skia-smoke.log",
  #|        "macos-native-smoke-output.log",
  #|        "macos-real-skia-acceptance.log"
  #|      ],
  #|      "required_verifier": "scripts/verify-real-skia-artifact.sh --platform macos --log-dir logs",
  #|      "next_step": "Collect macOS evidence."
  #|    },
  #|    "windows": {
  #|      "accepted": false,
  #|      "state": "not accepted",
  #|      "source_build": false,
  #|      "required_artifact_logs": [
  #|        "windows-real-skia-smoke-preflight.log",
  #|        "windows-real-skia-smoke.log",
  #|        "windows-native-smoke-output.log",
  #|        "windows-real-skia-acceptance.log"
  #|      ],
  #|      "required_verifier": "scripts/verify-real-skia-artifact.ps1 -Platform windows -LogDir logs",
  #|      "next_step": "Collect Windows evidence."
  #|    }
  #|  }
  #|}

///|
let valid_doc =
  #|# Status
  #|
  #|## Current Matrix
  #|
  #|| Platform | State | Provider | Notes |
  #|| --- | --- | --- | --- |
  #|| Linux | Accepted | release m134 | artifact |
  #|| macOS | Not accepted | pending | collect evidence |
  #|| Windows | Not accepted | pending | collect evidence |
  #|
  #|## Next
  #|

///|
fn test_options(
  repo_root? : String = "/repo/moui_skia",
  status_file? : String = "skia-platform-status.json",
) -> CliOptions {
  {
    repo_root,
    status_file,
    revision_file: "skia-revision.txt",
    provider_lock: "skia-provider-lock.json",
    status_doc: "SKIA_PLATFORM_STATUS.md",
    status_doc_explicit: false,
    quiet: false,
    help: false,
  }
}

///|
test "default status doc check only follows repo status file" {
  inspect(path_is_default_status(test_options()), content="true")
  inspect(
    path_is_default_status(
      test_options(status_file="/tmp/fake/skia-platform-status.json"),
    ),
    content="false",
  )
}

///|
fn verify_valid(status : String) -> Result[String, String] {
  verify_platform_status_texts(
    status,
    "main\n",
    provider_lock,
    Some(valid_doc),
    "skia-platform-status.json",
    "skia-revision.txt",
    true,
    None,
  )
}

///|
fn json_escape(value : String) -> String {
  let builder = StringBuilder()
  for char in value {
    if char == '"' {
      builder.write_string("\\\"")
    } else if char == '\\' {
      builder.write_string("\\\\")
    } else {
      builder.write_char(char)
    }
  }
  builder.to_string()
}

///|
fn write_json_string_field(
  builder : StringBuilder,
  name : String,
  value : String,
  first : Bool,
) -> Unit {
  if !first {
    builder.write_string(",")
  }
  builder.write_string("\"")
  builder.write_string(name)
  builder.write_string("\":\"")
  builder.write_string(json_escape(value))
  builder.write_string("\"")
}

///|
fn write_capability_entry(
  builder : StringBuilder,
  first : Ref[Bool],
  capability_id : String,
  area : String,
  marker : String,
) -> Unit {
  if !first.val {
    builder.write_string(",")
  }
  first.val = false
  builder.write_string("{")
  write_json_string_field(builder, "id", capability_id, true)
  write_json_string_field(builder, "area", area, false)
  write_json_string_field(builder, "marker", marker, false)
  builder.write_string("}")
}

///|
fn write_extra_marker_capability(
  builder : StringBuilder,
  first : Ref[Bool],
  seen_markers : Map[String, Bool],
  capability_id : String,
  area : String,
  marker : String,
) -> Unit {
  if !seen_markers.contains(marker) {
    seen_markers[marker] = true
    write_capability_entry(builder, first, capability_id, area, marker)
  }
}

///|
fn write_required_capabilities(builder : StringBuilder) -> Unit {
  builder.write_string("\"native_smoke_capabilities\":[")
  let first = Ref(true)
  let seen_markers : Map[String, Bool] = Map([])
  let areas = required_native_smoke_areas()
  let area_index = Ref(0)
  for capability_id in required_native_smoke_capability_ids() {
    let marker = "required capability marker " + capability_id
    seen_markers[marker] = true
    write_capability_entry(
      builder,
      first,
      capability_id,
      areas[area_index.val],
      marker,
    )
    area_index.val += 1
    if area_index.val >= areas.length() {
      area_index.val = 0
    }
  }
  for index in 0..<required_native_smoke_expected_values().length() {
    let expected = required_native_smoke_expected_values()[index]
    write_extra_marker_capability(
      builder,
      first,
      seen_markers,
      "expected-value-marker-\{index}",
      "Text",
      expected.marker,
    )
  }
  for index in 0..<required_native_smoke_conditionals().length() {
    let conditional = required_native_smoke_conditionals()[index]
    write_extra_marker_capability(
      builder,
      first,
      seen_markers,
      "conditional-source-\{index}",
      conditional.area,
      conditional.when_marker,
    )
  }
  builder.write_string("]")
}

///|
fn write_required_conditionals(builder : StringBuilder) -> Unit {
  builder.write_string("\"native_smoke_conditional_capabilities\":[")
  for index in 0..<required_native_smoke_conditionals().length() {
    if index > 0 {
      builder.write_string(",")
    }
    let conditional = required_native_smoke_conditionals()[index]
    builder.write_string("{")
    write_json_string_field(builder, "id", conditional.id, true)
    write_json_string_field(builder, "area", conditional.area, false)
    write_json_string_field(builder, "marker", conditional.marker, false)
    write_json_string_field(
      builder,
      "when_marker",
      conditional.when_marker,
      false,
    )
    write_json_string_field(
      builder,
      "when_value",
      conditional.when_value,
      false,
    )
    builder.write_string("}")
  }
  builder.write_string("]")
}

///|
fn write_required_expected_values(
  builder : StringBuilder,
  wrong_first_expected : Bool,
) -> Unit {
  builder.write_string("\"native_smoke_expected_values\":[")
  for index in 0..<required_native_smoke_expected_values().length() {
    if index > 0 {
      builder.write_string(",")
    }
    let expected = required_native_smoke_expected_values()[index]
    let value = if wrong_first_expected && index == 0 {
      expected.value + "-wrong"
    } else {
      expected.value
    }
    builder.write_string("{")
    write_json_string_field(
      builder,
      "id",
      "expected-value-marker-\{index}",
      true,
    )
    write_json_string_field(builder, "marker", expected.marker, false)
    write_json_string_field(builder, "value", value, false)
    builder.write_string("}")
  }
  builder.write_string("]")
}

///|
fn synthetic_native_smoke_status(
  include_conditionals : Bool,
  include_expected_values : Bool,
  wrong_first_expected : Bool,
) -> Map[String, Json] {
  let builder = StringBuilder()
  builder.write_string("{")
  write_required_capabilities(builder)
  if include_conditionals {
    builder.write_string(",")
    write_required_conditionals(builder)
  }
  if include_expected_values {
    builder.write_string(",")
    write_required_expected_values(builder, wrong_first_expected)
  }
  builder.write_string("}")
  parse_object_or_fail(builder.to_string())
}

///|
fn parse_object_or_fail(text : String) -> Map[String, Json] {
  let parsed = try! @json.parse(text)
  match parsed {
    Json::Object(fields) => fields
    _ => Map([])
  }
}

///|
test "accepts valid release platform status contract" {
  inspect(verify_valid(valid_status) is Ok(_), content="true")
}

///|
test "rejects source acceptance while revision remains main" {
  let status = valid_status
    .replace(
      old="\"accepted_provider\": \"release\"",
      new="\"accepted_provider\": \"source\"",
    )
    .replace(
      old="\"accepted_version\": \"m134\"",
      new="\"accepted_version\": \"main\"",
    )
  inspect(
    match verify_valid(status) {
      Err(message) => message.contains("source platforms cannot be accepted")
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "rejects release provider lock mismatch" {
  let lock = provider_lock.replace(
    old="0123456789abcdef0123456789abcdef01234567",
    new="1111111111111111111111111111111111111111",
  )
  inspect(
    match
      verify_platform_status_texts(
        valid_status,
        "main\n",
        lock,
        Some(valid_doc),
        "skia-platform-status.json",
        "skia-revision.txt",
        true,
        None,
      ) {
      Err(message) => message.contains("accepted release platform commit")
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "rejects wrong artifact log contract" {
  let status = valid_status.replace(
    old="linux-real-skia-smoke.log",
    new="linux-other.log",
  )
  inspect(
    match verify_valid(status) {
      Err(message) => message.contains("required_artifact_logs")
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "rejects windows source build claim" {
  let status = valid_status.replace(
    old="\"windows\": {\n      \"accepted\": false,\n      \"state\": \"not accepted\",\n      \"source_build\": false",
    new="\"windows\": {\n      \"accepted\": false,\n      \"state\": \"not accepted\",\n      \"source_build\": true",
  )
  inspect(
    match verify_valid(status) {
      Err(message) =>
        message.contains("Windows status must not claim source_build")
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "rejects markdown matrix missing provider version" {
  let doc = valid_doc.replace(old="release m134", new="release")
  inspect(
    match
      verify_platform_status_texts(
        valid_status,
        "main\n",
        provider_lock,
        Some(doc),
        "skia-platform-status.json",
        "skia-revision.txt",
        true,
        None,
      ) {
      Err(message) => message.contains("missing accepted version")
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "rejects missing required native smoke capability id" {
  let text =
    #|{
    #|  "native_smoke_capabilities": [
    #|    {
    #|      "id": "surface.descriptor",
    #|      "area": "Surface",
    #|      "marker": "native smoke surface descriptor backend"
    #|    }
    #|  ]
    #|}
  let status = parse_object_or_fail(text)
  inspect(
    match verify_native_smoke_contract(status, 3) {
      Err(message) =>
        message.contains("native smoke capability coverage is missing ids")
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "rejects missing required native smoke conditional list" {
  let status = synthetic_native_smoke_status(false, false, false)
  inspect(
    match verify_native_smoke_contract(status, 4) {
      Err(message) =>
        message.contains(
          "schema v4 platform status is missing native_smoke_conditional_capabilities list",
        )
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "rejects native smoke expected value mismatch" {
  let status = synthetic_native_smoke_status(true, true, true)
  inspect(
    match verify_native_smoke_contract(status, 4) {
      Err(message) => message.contains("native smoke expected value mismatch")
      Ok(_) => false
    },
    content="true",
  )
}
