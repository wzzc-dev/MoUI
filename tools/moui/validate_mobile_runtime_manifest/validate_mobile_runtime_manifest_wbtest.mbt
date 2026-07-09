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
    #|  "observations": {
    #|    "lifecycleAttach": "yes",
    #|    "lifecycleDetach": "yes",
    #|    "nonblankFirstFrame": "yes",
    #|    "resize": "yes",
    #|    "representativeInput": "yes",
    #|    "scrollInput": "yes",
    #|    "cleanShutdown": "yes",
    #|    "ime": "pending",
    #|    "clipboard": "pending",
    #|    "accessibility": "pending",
    #|    "asyncImage": "pending",
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
