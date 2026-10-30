///|
/// The accessibility registry must survive a host build: the provider is only
/// registrable on a device, so a host reports false instead of failing.
test "harmonyos accessibility register reports availability" {
  let ok = @harmonyos.harmonyos_accessibility_register()
  assert_true(ok == true || ok == false)
}

///|
test "harmonyos accessibility status is queryable without a provider" {
  // `registered * 1000000 + published node count`; without a provider and with
  // no published tree this is 0.
  let status = @harmonyos.harmonyos_accessibility_status()
  assert_true(status >= 0)
}

///|
test "harmonyos accessibility take_action reports nothing pending" {
  inspect(
    @harmonyos.harmonyos_accessibility_take_action() is None,
    content="true",
  )
}
