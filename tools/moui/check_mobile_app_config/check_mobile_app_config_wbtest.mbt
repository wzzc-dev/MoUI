///|
test "accepts valid android application ids and bundle ids" {
  debug_inspect(
    valid_android_application_id("dev.wzzc.moui.counter"),
    content="true",
  )
  debug_inspect(valid_android_application_id("1bad.id"), content="false")
  debug_inspect(valid_android_application_id("single"), content="false")
  debug_inspect(valid_bundle_id("dev.wzzc.moui.counter"), content="true")
  debug_inspect(valid_bundle_id("dev.wzzc-moui.counter"), content="true")
  debug_inspect(valid_native_library("moui_counter_android"), content="true")
  debug_inspect(valid_native_library("bad-lib"), content="false")
}

///|
test "managed minSdk and deployment floors are enforced" {
  let text =
    #|{
    #|  "schemaVersion": 2,
    #|  "id": "demo",
    #|  "displayName": "Demo",
    #|  "artifactName": "demo",
    #|  "appPackage": "examples/demo/app",
    #|  "android": {
    #|    "applicationId": "dev.wzzc.moui.demo",
    #|    "shellMode": "managed",
    #|    "minSdk": 21
    #|  },
    #|  "ios": {
    #|    "bundleId": "dev.wzzc.moui.demo",
    #|    "productName": "Demo",
    #|    "shellMode": "managed",
    #|    "deploymentTarget": "14.0"
    #|  }
    #|}
    #|
  // Use empty repo root so package path existence fails too; we only assert floor messages.
  let failures = validate_mobile_app_json(".", "demo", text)
  debug_inspect(
    failures.any(item => item.contains("android.minSdk must be at least 23")),
    content="true",
  )
  debug_inspect(
    failures.any(item => {
      item.contains("ios.deploymentTarget must be at least 15.0")
    }),
    content="true",
  )
}

///|
test "rejects invalid application id" {
  let text =
    #|{
    #|  "schemaVersion": 2,
    #|  "id": "demo",
    #|  "displayName": "Demo",
    #|  "artifactName": "demo",
    #|  "appPackage": "examples/demo/app",
    #|  "android": {
    #|    "applicationId": "bad",
    #|    "shellMode": "managed",
    #|    "minSdk": 23
    #|  }
    #|}
    #|
  let failures = validate_mobile_app_json(".", "demo", text)
  debug_inspect(
    failures.any(item => {
      item.contains(
        "android.applicationId is not a valid Android application id",
      )
    }),
    content="true",
  )
}

///|
test "parse float prefix for deployment targets" {
  debug_inspect(parse_float_prefix("15.0"), content="15")
  debug_inspect(parse_float_prefix("14.5-beta"), content="14.5")
  debug_inspect(parse_float_prefix(""), content="0")
}
