///|
test "moon.work lists openseek only as a workspace member line" {
  assert_true(moon_work_lists_openseek("members = [\n  \"./openseek\",\n]\n"))
  assert_true(moon_work_lists_openseek("  \"./openseek\",  \n"))
  assert_false(moon_work_lists_openseek("\"./openseek\""))
  assert_false(moon_work_lists_openseek("# \"./openseek\","))
}

///|
test "valid inputs produce no errors" {
  inspect(
    validate_openseek_workbench_inputs(
      Some("members = [\n  \"./openseek\",\n]\n"),
      true,
      true,
    ).is_empty(),
    content="true",
  )
}

///|
test "reports all missing OpenSeek prerequisites" {
  let errors = validate_openseek_workbench_inputs(
    Some("members = []\n"),
    false,
    false,
  )
  inspect(errors.length(), content="3")
  inspect(
    errors[0],
    content="missing examples/mo_workbench/openseek_native_transport/moon.pkg",
  )
  inspect(
    errors[1],
    content="openseek submodule not initialized (run: git submodule update --init --recursive openseek)",
  )
  inspect(
    errors[2],
    content="moon.work must list \"./openseek\" until bobzhang/openseek is published on mooncakes.io.\n" +
      "  Run: sh scripts/openseek-dev-mode.sh on",
  )
}
