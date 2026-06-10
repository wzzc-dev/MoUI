///|
fn sample_status() -> String {
  let text =
    #|{
    #|  "native_smoke_capabilities": [
    #|    { "id": "surface.descriptor", "marker": "native smoke surface descriptor backend" },
    #|    { "id": "text.shaper-availability", "marker": "native smoke shaper availability" },
    #|    { "id": "text.resource-plan", "marker": "native smoke text run resource plan count" }
    #|  ],
    #|  "native_smoke_expected_values": [
    #|    { "marker": "native smoke text run resource plan count", "value": "3" }
    #|  ],
    #|  "native_smoke_conditional_capabilities": [
    #|    {
    #|      "id": "text.shaped-glyph-count",
    #|      "marker": "native smoke shaped glyph count",
    #|      "when_marker": "native smoke shaper availability",
    #|      "when_value": "1"
    #|    }
    #|  ]
    #|}
  text
}

///|
fn sample_contract() -> SmokeContract {
  {
    stage_markers: [
      "native smoke surface descriptor backend", "native smoke shaper availability",
      "native smoke text run resource plan count",
    ],
    expected_values: [
      { marker: "native smoke text run resource plan count", value: "3" },
    ],
    conditional_markers: [
      {
        marker: "native smoke shaped glyph count",
        when_marker: "native smoke shaper availability",
        when_value: "1",
      },
    ],
  }
}

///|
fn valid_log() -> String {
  let text =
    #|native smoke surface descriptor backend
    #|raster
    #|native smoke shaper availability
    #|1
    #|native smoke shaped glyph count
    #|12
    #|native smoke text run resource plan count
    #|3
    #|moui_skia native smoke test passed
  text
}

///|
test "parses status contract" {
  match parse_smoke_contract(sample_status()) {
    Ok(contract) => {
      inspect(contract.stage_markers.length(), content="3")
      inspect(contract.expected_values.length(), content="1")
      inspect(contract.conditional_markers.length(), content="1")
    }
    Err(message) => fail(message)
  }
}

///|
test "accepts required expected and enabled conditional markers" {
  match
    verify_smoke_log_text(
      valid_log(),
      default_success_marker,
      sample_contract(),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
}

///|
test "requires exact success marker line" {
  let result = verify_smoke_log_text(
    valid_log().replace(
      old=default_success_marker,
      new="not_" + default_success_marker,
    ),
    default_success_marker,
    sample_contract(),
  )
  inspect(
    match result {
      Err(message) => message.contains("success marker")
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "requires every declared stage marker" {
  let missing_log =
    #|native smoke shaper availability
    #|1
    #|native smoke text run resource plan count
    #|3
    #|moui_skia native smoke test passed
  let result = verify_smoke_log_text(
    missing_log,
    default_success_marker,
    sample_contract(),
  )
  inspect(
    match result {
      Err(message) => message.contains("required stage marker")
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "checks exact expected stage marker values" {
  let result = verify_smoke_log_text(
    valid_log().replace(
      old="native smoke text run resource plan count\n3",
      new="native smoke text run resource plan count\n2",
    ),
    default_success_marker,
    sample_contract(),
  )
  inspect(
    match result {
      Err(message) => message.contains("unexpected stage marker value")
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "requires enabled conditional marker value line" {
  let result = verify_smoke_log_text(
    valid_log().replace(old="native smoke shaped glyph count\n12\n", new=""),
    default_success_marker,
    sample_contract(),
  )
  inspect(
    match result {
      Err(message) => message.contains("conditional stage marker")
      Ok(_) => false
    },
    content="true",
  )
}

///|
test "skips conditional marker when capability is unavailable" {
  let unavailable_log = valid_log()
    .replace(
      old="native smoke shaper availability\n1",
      new="native smoke shaper availability\n0",
    )
    .replace(old="native smoke shaped glyph count\n12\n", new="")
  match
    verify_smoke_log_text(
      unavailable_log,
      default_success_marker,
      sample_contract(),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
}
