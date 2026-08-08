///|
test "R3 accepts renderer modules in embedded composition roots" {
  let pkg =
    #|import {
    #|  "wzzc-dev/moui/backend/android",
    #|  "wzzc-dev/moui_skia_renderer",
    #|}
    #|
  let finding = check_r3_mobile_pkg(
    "examples/showcase/android_window_hosted/moon.pkg",
    Some(pkg),
  )
  assert_true(finding.ok)
}

///|
test "R3 rejects embedded composition roots without a renderer module" {
  let pkg =
    #|import {
    #|  "wzzc-dev/moui/backend/android",
    #|  "wzzc-dev/moui/render",
    #|}
    #|
  let finding = check_r3_mobile_pkg(
    "examples/showcase/android_window_hosted/moon.pkg",
    Some(pkg),
  )
  assert_false(finding.ok)
}
