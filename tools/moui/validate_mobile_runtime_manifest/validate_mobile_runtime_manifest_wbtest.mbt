///|
fn valid_manifest() -> String {
  let text =
    #|{
    #|  "schemaVersion": 1,
    #|  "mode": "mobile-runtime-smoke",
    #|  "generatedBy": "scripts/record-mobile-runtime-smoke.mjs",
    #|  "platform": "ios",
    #|  "app": "component_gallery",
    #|  "status": "passed",
    #|  "build": {
    #|    "fallbackSkia": false,
    #|    "artifact": "artifacts/ios/component_gallery/ComponentGallery.app",
    #|    "command": "scripts/build-mobile-ios-app.sh --app component_gallery"
    #|  },
    #|  "artifacts": {
    #|    "screenshotBefore": "artifacts/mobile-runtime/ios/component_gallery/screenshot-before.png",
    #|    "screenshot": "artifacts/mobile-runtime/ios/component_gallery/screenshot.png",
    #|    "log": "artifacts/mobile-runtime/ios/component_gallery/runtime.log"
    #|  },
    #|  "screenshot": {
    #|    "width": 390,
    #|    "height": 844,
    #|    "totalPixels": 329160,
    #|    "contentPixels": 42000,
    #|    "distinctColorBuckets": 20
    #|  },
    #|  "pixelChange": {
    #|    "comparable": true,
    #|    "changedPixels": 2400,
    #|    "changedRatio": 0.007
    #|  },
    #|  "observations": {
    #|    "lifecycleAttach": "yes",
    #|    "lifecycleDetach": "yes",
    #|    "nonblankFirstFrame": "yes",
    #|    "resize": "yes",
    #|    "representativeInput": "yes",
    #|    "scrollInput": "yes",
    #|    "cleanShutdown": "yes",
    #|    "ime": "yes",
    #|    "clipboard": "yes",
    #|    "accessibility": "yes",
    #|    "accessibilityTree": "yes",
    #|    "accessibilityFocus": "yes",
    #|    "accessibilityAction": "yes",
    #|    "asyncImage": "yes",
    #|    "realDeviceSigning": "pending"
    #|  },
    #|  "evidenceBoundary": "non-fallback matching-host smoke evidence; fallback builds are packaging only"
    #|}
  text
}

///|
test "valid passed manifest" {
  let failures = validate_manifest_text(valid_manifest(), true)
  inspect(failures, content="[]")
}

///|
test "fallback cannot pass" {
  let text = valid_manifest().replace(
    old="\"fallbackSkia\": false",
    new="\"fallbackSkia\": true",
  )
  let failures = validate_manifest_text(text, true)
  assert_true(failures.any(message => message.contains("fallback Skia")))
}

///|
test "component gallery requires scroll evidence" {
  let text = valid_manifest().replace(
    old="\"scrollInput\": \"yes\"",
    new="\"scrollInput\": \"pending\"",
  )
  let failures = validate_manifest_text(text, true)
  assert_true(failures.any(message => message.contains("scrollInput")))
}

///|
test "passed evidence requires visible input change" {
  let text = valid_manifest().replace(
    old="\"changedPixels\": 2400",
    new="\"changedPixels\": 0",
  )
  let failures = validate_manifest_text(text, true)
  assert_true(failures.any(message => message.contains("changedPixels")))
}

///|
test "passed evidence requires platform service observations" {
  let text = valid_manifest().replace(
    old="\"ime\": \"yes\"",
    new="\"ime\": \"pending\"",
  )
  let failures = validate_manifest_text(text, true)
  assert_true(failures.any(message => message.contains("observations.ime")))
}

///|
test "partial evidence is valid but cannot satisfy require passed" {
  let text = valid_manifest()
    .replace(old="\"status\": \"passed\"", new="\"status\": \"partial\"")
    .replace(old="\"resize\": \"yes\"", new="\"resize\": \"no\"")
  debug_inspect(validate_manifest_text(text, false), content="[]")
  let failures = validate_manifest_text(text, true)
  assert_true(failures.any(message => message.contains("--require-passed")))
}
