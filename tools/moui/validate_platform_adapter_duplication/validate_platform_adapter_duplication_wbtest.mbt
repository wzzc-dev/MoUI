///|
test "allowlist expiry rejects past dates but accepts future dates" {
  let expired = expired_allowlist_dates(
    "\"allowUntil\": \"2026-07-28\"\n\"allowUntil\": \"2026-10-01\"", "2026-07-29",
  )
  debug_inspect(expired, content="[\"2026-07-28\"]")
}

///|
test "bridge import and helper scans distinguish valid platform sources" {
  assert_true(
    import_is_platform_bridge("\"wzzc-dev/moui/backend/platform_bridge\""),
  )
  assert_true(uses_platform_bridge("@platform_bridge.make_surface_metrics"))
  debug_inspect(
    helper_is_redefined("fn make_surface_metrics() {}"),
    content="Some(\"make_surface_metrics\")",
  )
  debug_inspect(
    helper_is_redefined("let name = \"make_surface_metrics\""),
    content="None",
  )
}

///|
test "normalization budgets are read from the schema" {
  let budgets = duplicate_budgets_from_baseline(
    "\"@host.physical_position_to_core\": 1,\n\"@host.surface_metrics_from_physical\": 2,",
  )
  match budgets {
    Ok(values) => {
      assert_eq(values.length(), 2)
      assert_eq(values[0].maximum, 1)
      assert_eq(values[1].maximum, 2)
    }
    Err(message) => fail(message)
  }
}
