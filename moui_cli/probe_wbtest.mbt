// Whitebox tests for `probe.mbt`.
//
// Tests focus on the pure parsers (`parse_log_line`, `parse_logcat_observations`,
// `parse_hilog_observations`, `parse_oslog_observations`, `build_probe_result`)
// and JSON rendering. Real `adb` / `xcrun` / `hdc` launches are exercised by
// integration tests with hardware attached.

///|
test "test_parse_log_line_extracts_ok_observation" {
  let line = "07-20 10:23:45.678 [MOUI_PROBE] lifecycle:app_start=ok\n"
  match parse_log_line(line) {
    Some(obs) => {
      inspect(obs.kind, content="lifecycle")
      inspect(obs.name, content="app_start")
      inspect(obs.value, content="ok")
      assert_true(obs.passed)
    }
    None => fail("expected Some observation")
  }
}

///|
test "test_parse_log_line_extracts_fail_observation" {
  let line = "[MOUI_PROBE] stability:crash_free=fail\n"
  match parse_log_line(line) {
    Some(obs) => {
      inspect(obs.kind, content="stability")
      inspect(obs.name, content="crash_free")
      inspect(obs.value, content="fail")
      assert_false(obs.passed)
    }
    None => fail("expected Some observation")
  }
}

///|
test "test_parse_log_line_ignores_non_marker_lines" {
  assert_true(parse_log_line("random log line").is_none())
  assert_true(parse_log_line("").is_none())
  assert_true(parse_log_line("[MOUI] something else=ok").is_none())
}

///|
test "test_parse_log_line_ignores_unknown_observation_names" {
  let line = "[MOUI_PROBE] unknown:marker=ok\n"
  assert_true(parse_log_line(line).is_none())
}

///|
test "test_parse_logcat_observations_dedupes_repeats" {
  let output =
    #|[MOUI_PROBE] lifecycle:app_start=ok
    #|[MOUI_PROBE] lifecycle:app_resume=ok
    #|[MOUI_PROBE] lifecycle:app_start=fail
  let observations = parse_logcat_observations(output)
  // Last occurrence wins for `lifecycle:app_start` — value=fail.
  let mut start_count = 0
  let mut resume_count = 0
  let mut start_value = ""
  for obs in observations {
    if obs.name == "app_start" {
      start_count += 1
      start_value = obs.value
    } else if obs.name == "app_resume" {
      resume_count += 1
    }
  }
  inspect(start_count, content="1")
  inspect(resume_count, content="1")
  inspect(start_value, content="fail")
}

///|
test "test_parse_hilog_observations_parses_same_format" {
  let output =
    #|hilog: [MOUI_PROBE] lifecycle:app_start=ok
    #|hilog: [MOUI_PROBE] stability:first_frame=ok
  let observations = parse_hilog_observations(output)
  inspect(observations.length(), content="2")
  inspect(observations[0].name, content="app_start")
  inspect(observations[1].name, content="first_frame")
}

///|
test "test_parse_oslog_observations_parses_same_format" {
  let output =
    #|2026-07-20 10:23:45.678 demo[123:456] [MOUI_PROBE] service:clipboard_get=ok
  let observations = parse_oslog_observations(output)
  inspect(observations.length(), content="1")
  inspect(observations[0].kind, content="service")
  inspect(observations[0].name, content="clipboard_get")
  assert_true(observations[0].passed)
}

///|
test "test_build_probe_result_ok_when_all_observations_present" {
  // Construct all 27 observations as `ok`.
  let observations : Array[Observation] = []
  for name in probe_observation_names {
    match name.split_once(":") {
      Some((kind, n)) =>
        observations.push({
          kind: kind.to_string(),
          name: n.to_string(),
          value: "ok",
          passed: true,
        })
      None => ()
    }
  }
  let result = build_probe_result(observations)
  assert_true(result.ok)
  inspect(result.observations.length(), content="27")
}

///|
test "test_build_probe_result_fails_when_missing_observation" {
  // Construct only 1 observation; the rest are missing.
  let observations : Array[Observation] = [
    { kind: "lifecycle", name: "app_start", value: "ok", passed: true },
  ]
  let result = build_probe_result(observations)
  assert_false(result.ok)
  inspect(result.observations.length(), content="27")
}

///|
test "test_build_probe_result_fails_when_one_fails" {
  // Construct all 27 observations but mark one as failed.
  let observations : Array[Observation] = []
  for name in probe_observation_names {
    match name.split_once(":") {
      Some((kind, n)) =>
        observations.push({
          kind: kind.to_string(),
          name: n.to_string(),
          value: if name == "stability:crash_free" {
            "fail"
          } else {
            "ok"
          },
          passed: name != "stability:crash_free",
        })
      None => ()
    }
  }
  let result = build_probe_result(observations)
  assert_false(result.ok)
  inspect(result.observations.length(), content="27")
}

///|
test "test_probe_observation_names_count_is_27" {
  inspect(probe_observation_names.length(), content="27")
}

///|
test "test_probe_observation_names_covers_five_categories" {
  let kinds = Set::new()
  for name in probe_observation_names {
    match name.split_once(":") {
      Some((kind, _)) => kinds.add(kind.to_string())
      None => ()
    }
  }
  // Five categories: lifecycle, service, platformView, hostChannel, stability.
  inspect(kinds.size(), content="5")
  assert_true(kinds.contains("lifecycle"))
  assert_true(kinds.contains("service"))
  assert_true(kinds.contains("platformView"))
  assert_true(kinds.contains("hostChannel"))
  assert_true(kinds.contains("stability"))
}

///|
test "test_probe_result_to_json_emits_schema_and_observations" {
  let result : ProbeResult = {
    ok: false,
    observations: [
      { kind: "lifecycle", name: "app_start", value: "ok", passed: true },
      { kind: "stability", name: "crash_free", value: "fail", passed: false },
    ],
  }
  let json = probe_result_to_json(result)
  let text = json.stringify(indent=2)
  assert_true(text.contains("\"schemaVersion\": 1"))
  assert_true(text.contains("\"ok\": false"))
  assert_true(text.contains("\"observations\":"))
  assert_true(text.contains("\"app_start\""))
  assert_true(text.contains("\"crash_free\""))
  assert_true(text.contains("\"passed\": true"))
  assert_true(text.contains("\"passed\": false"))
}

///|
test "test_probe_result_to_text_emits_status_lines" {
  let result : ProbeResult = {
    ok: false,
    observations: [
      { kind: "lifecycle", name: "app_start", value: "ok", passed: true },
      { kind: "stability", name: "crash_free", value: "fail", passed: false },
    ],
  }
  let text = probe_result_to_text(result)
  assert_true(text.contains("[probe] one or more observations failed"))
  assert_true(text.contains("ok\tlifecycle:app_start\tok"))
  assert_true(text.contains("FAIL\tstability:crash_free\tfail"))
}

///|
test "test_probe_result_to_text_emits_passed_when_ok" {
  let result : ProbeResult = {
    ok: true,
    observations: [
      { kind: "lifecycle", name: "app_start", value: "ok", passed: true },
    ],
  }
  let text = probe_result_to_text(result)
  assert_true(text.contains("[probe] all observations passed"))
}

///|
test "test_parse_log_line_handles_extra_whitespace" {
  let line = "   [MOUI_PROBE]  lifecycle:app_resume=ok   \n"
  match parse_log_line(line) {
    Some(obs) => {
      inspect(obs.name, content="app_resume")
      inspect(obs.value, content="ok")
    }
    None => fail("expected Some observation")
  }
}

///|
test "test_parse_log_line_preserves_unknown_value_format" {
  // Custom values (e.g. integers) are preserved verbatim.
  let line = "[MOUI_PROBE] stability:frame_rendered=42\n"
  match parse_log_line(line) {
    Some(obs) => {
      inspect(obs.value, content="42")
      assert_false(obs.passed) // Only "ok" is treated as pass.
    }
    None => fail("expected Some observation")
  }
}

///|
test "test_is_known_observation_recognizes_canonical_set" {
  assert_true(is_known_observation("lifecycle:app_start"))
  assert_true(is_known_observation("stability:crash_free"))
  assert_true(is_known_observation("hostChannel:complete"))
  assert_false(is_known_observation("lifecycle:unknown_step"))
  assert_false(is_known_observation("unknown:marker"))
}
