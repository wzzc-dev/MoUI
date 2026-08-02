///|
test "wechat_backend_info_has_wechat_kind" {
  let info = wechat_backend_info()
  assert_eq(info.backend, @host.HostBackendKind::Wechat)
}

///|
test "wechat_readiness_reports_experimental" {
  let readiness = wechat_readiness()
  assert_false(readiness.ready)
  assert_eq(readiness.status, "experimental")
  assert_true(readiness.blocked_by.length() >= 2)
}

///|
test "wechat_capabilities_has_pointer_and_scroll" {
  let caps = wechat_capabilities()
  assert_true(caps.pointer)
  assert_true(caps.scroll)
  assert_false(caps.keyboard)
  assert_false(caps.ime)
}

///|
test "wechat_input_capabilities_touch_only" {
  let input = wechat_input_capabilities()
  assert_true(input.pointer)
  assert_false(input.keyboard)
  assert_false(input.ime)
  assert_false(input.drag_drop)
}

///|
test "wechat_capability_summary_label" {
  let summary = wechat_capability_summary()
  assert_eq(summary.label, "WeChat Mini Program host")
}

///|
test "wechat_backend_full_info_has_all_fields" {
  let info = wechat_backend_full_info()
  assert_eq(info.host_info.backend, @host.HostBackendKind::Wechat)
  assert_true(info.capabilities.canvas_surface)
  assert_false(info.services.clipboard)
  assert_true(info.input.pointer)
  assert_false(info.readiness.ready)
}
