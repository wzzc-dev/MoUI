///|
test "accepts text without forbidden tokens" {
  inspect(
    validate_provider_text(
      "moui/backend/macos/moon.pkg",
      "import { \"wzzc-dev/window/macos\" }\n",
      ["wzzc-dev/moui/render", "wzzc-dev/moui_skia"],
    ).is_empty(),
    content="true",
  )
}

///|
test "reports each forbidden token" {
  let manifest_text =
    #|import {
    #|  "wzzc-dev/moui/render/skia",
    #|  "wzzc-dev/moui_skia",
    #|}
    #|
  let failures = validate_provider_text(
    "moui/backend/macos/moon.pkg",
    manifest_text,
    ["wzzc-dev/moui/render/skia", "wzzc-dev/moui_skia"],
  )
  inspect(failures.length(), content="2")
  inspect(
    failures[0],
    content="moui/backend/macos/moon.pkg: forbidden import/dependency token 'wzzc-dev/moui/render/skia'",
  )
}
