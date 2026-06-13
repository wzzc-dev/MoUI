///|
let macos_manifest =
  #|{
  #|  "schemaVersion": 1,
  #|  "platform": "macos",
  #|  "outputKind": "app-bundle",
  #|  "appName": "MoUI Showcase",
  #|  "moonPackage": "examples/showcase/macos_skia",
  #|  "version": "1.0.0",
  #|  "buildNumber": "1",
  #|  "executable": "MoUI Showcase",
  #|  "bundleName": "MoUI Showcase.app",
  #|  "bundleIdentifier": "dev.wzzc.moui.showcase",
  #|  "runtimeFiles": []
  #|}

///|
let windows_manifest =
  #|{
  #|  "schemaVersion": 1,
  #|  "platform": "windows",
  #|  "outputKind": "portable-folder",
  #|  "appName": "MoUI Showcase",
  #|  "moonPackage": "examples/showcase/windows_skia",
  #|  "version": "1.0.0",
  #|  "buildNumber": "1",
  #|  "executable": "Showcase.EXE",
  #|  "bundleName": "MoUI Showcase",
  #|  "runtimeFiles": [],
  #|  "externalRuntimeDependencies": [
  #|    "Microsoft Edge WebView2 Evergreen Runtime"
  #|  ]
  #|}

///|
test "accepts macos package manifest" {
  match validate_manifest_text(macos_manifest, "macos") {
    Ok((platform, output_kind)) =>
      inspect(platform + " " + output_kind, content="macos app-bundle")
    Err(failures) => fail(@tools.comma_join(failures))
  }
}

///|
test "accepts windows package manifest case-insensitive exe" {
  match validate_manifest_text(windows_manifest, "windows") {
    Ok((platform, output_kind)) =>
      inspect(platform + " " + output_kind, content="windows portable-folder")
    Err(failures) => fail(@tools.comma_join(failures))
  }
}

///|
test "rejects missing required fields and wrong runtime files" {
  let text =
    #|{
    #|  "schemaVersion": 2,
    #|  "platform": "macos",
    #|  "outputKind": "portable-folder",
    #|  "runtimeFiles": "nope"
    #|}
  match validate_manifest_text(text, "macos") {
    Err(failures) => {
      inspect(failures.contains("schemaVersion must be 1"), content="true")
      inspect(
        failures.contains("runtimeFiles must be an array"),
        content="true",
      )
      inspect(
        failures.contains("macOS outputKind must be 'app-bundle'"),
        content="true",
      )
    }
    Ok(_) => fail("expected manifest validation failure")
  }
}

///|
test "rejects wrong external runtime dependency metadata" {
  let text =
    #|{
    #|  "schemaVersion": 1,
    #|  "platform": "windows",
    #|  "outputKind": "portable-folder",
    #|  "appName": "MoUI WebView Demo",
    #|  "moonPackage": "examples/webview_demo/windows_skia",
    #|  "version": "1.0.0",
    #|  "buildNumber": "1",
    #|  "executable": "MoUIWebViewDemo.exe",
    #|  "bundleName": "MoUIWebViewDemo",
    #|  "runtimeFiles": [],
    #|  "externalRuntimeDependencies": "WebView2 Runtime"
    #|}
  match validate_manifest_text(text, "windows") {
    Err(failures) =>
      inspect(
        failures.contains("externalRuntimeDependencies must be an array"),
        content="true",
      )
    Ok(_) => fail("expected manifest validation failure")
  }
}

///|
test "rejects expected platform mismatch" {
  match validate_manifest_text(windows_manifest, "macos") {
    Err(failures) =>
      inspect(failures.contains("platform must be 'macos'"), content="true")
    Ok(_) => fail("expected platform mismatch")
  }
}
