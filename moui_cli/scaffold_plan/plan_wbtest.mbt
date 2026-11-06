///|
fn test_project_options(
  platforms : Array[String],
  bundle_id~ : String? = None,
  template~ : String = "counter",
) -> ProjectOptions {
  {
    target: "unused",
    id: "sample_app",
    module_name: "example/sample_app",
    title: "Sample App",
    moui_version: default_moui_dependency_version,
    moui_skia_renderer_version: default_moui_skia_renderer_dependency_version,
    template,
    platforms,
    bundle_id,
  }
}

///|
fn test_planned_text(files : Array[PlannedFile], path : String) -> String raise {
  for file in files {
    if file.path == path {
      return @utf8.decode(file.bytes) catch {
        _ => fail("planned file is not valid UTF-8: " + path)
      }
    }
  }
  fail("planned file not found: " + path)
}

///|
test "default platforms include Web and the current desktop host" {
  inspect(default_platforms(Macos).join(","), content="web,macos")
  inspect(default_platforms(Windows).join(","), content="web,windows")
  inspect(default_platforms(Linux).join(","), content="web,linux")
  inspect(default_platforms(Unknown).join(","), content="web")
}

///|
test "explicit platforms are additive and normalized in canonical order" {
  match normalize_platforms(Macos, ["windows", "ANDROID", "web"]) {
    Ok(platforms) =>
      inspect(platforms.join(","), content="web,macos,windows,android")
    Err(message) => fail(message)
  }
  match normalize_platforms(Unknown, ["all"]) {
    Ok(platforms) =>
      inspect(
        platforms.join(","),
        content="web,macos,windows,linux,android,ios,harmonyos",
      )
    Err(message) => fail(message)
  }
  inspect(normalize_platforms(Linux, ["plan9"]) is Err(_), content="true")
}

///|
test "hello template emits greet app instead of counter" {
  match
    build_project_file_plan(
      test_project_options(["web"], template="hello"),
      "0.0.0-test",
    ) {
    Ok(files) => {
      let app = test_planned_text(files, "app/app.mbt")
      assert_true(app.contains("Say hello"))
      assert_true(app.contains("Greet"))
      assert_true(!app.contains("Increment"))
      let test_src = test_planned_text(files, "app/app_test.mbt")
      assert_true(test_src.contains("hello greet flips greeted"))
      let root_mod = test_planned_text(files, "moon.mod")
      assert_true(
        root_mod.contains(
          "wzzc-dev/moui_web_renderer@" +
          default_web_renderer_dependency_version,
        ),
      )
      assert_false(root_mod.contains("wzzc-dev/moui_skia_renderer"))
    }
    Err(message) => fail(message)
  }
}

///|
test "generated project includes a local dev entrypoint" {
  let files = match
    build_project_file_plan(test_project_options(["web"]), "0.0.0-test") {
    Ok(files) => files
    Err(message) => fail(message)
  }
  let dev = test_planned_text(files, ".moui/dev.mjs")
  assert_true(dev.contains("MOUI_DEV_STATE_FILE"))
  assert_true(dev.contains("__moui/status"))
}

///|
test "project names and validation reject unsafe identifiers" {
  inspect(
    project_id_from_path("/tmp/123 Hello-app"),
    content="app_123_hello_app",
  )
  inspect(product_name("sample_app"), content="SampleApp")
  inspect(
    validate_project_options(test_project_options(["web"])) is Ok(_),
    content="true",
  )
  let mobile_without_bundle = test_project_options(["web", "android"])
  inspect(
    validate_project_options(mobile_without_bundle) is Err(_),
    content="true",
  )
  let bad_module = {
    ..test_project_options(["web"]),
    module_name: "missing-owner",
  }
  inspect(validate_project_options(bad_module) is Err(_), content="true")
}

///|
test "default macOS project file plan is exact" {
  let files = match
    build_project_file_plan(
      test_project_options(["web", "macos"]),
      "0.0.0-test",
    ) {
    Ok(files) => files
    Err(message) => fail(message)
  }
  inspect(
    files.map(file => file.path).join("\n"),
    content=(
      #|.gitignore
      #|.moui/dev.mjs
      #|README.md
      #|app/app.mbt
      #|app/app_test.mbt
      #|app/moon.pkg
      #|macos_skia/main.mbt
      #|macos_skia/moon.pkg
      #|moon.mod
      #|moon.work
      #|moui.project.json
      #|web_wasm/index.html
      #|web_wasm/main.mbt
      #|web_wasm/moon.pkg
    ),
  )
  inspect(
    test_planned_text(files, "moon.work"),
    content=(
      #|members = [
      #|  ".",
      #|]
      #|
    ),
  )
  inspect(
    test_planned_text(files, "moui.project.json"),
    content=(
      #|{
      #|  "schemaVersion": 1,
      #|  "id": "sample_app",
      #|  "title": "Sample App",
      #|  "module": "example/sample_app",
      #|  "mouiVersion": "0.4.0",
      #|  "platforms": [
      #|    "web",
      #|    "macos"
      #|  ]
      #|}
      #|
    ),
  )
  let root_mod = test_planned_text(files, "moon.mod")
  assert_true(
    root_mod.contains("wzzc-dev/moui@" + default_moui_dependency_version),
  )
  assert_true(
    root_mod.contains(
      "wzzc-dev/moui_web_renderer@" + default_web_renderer_dependency_version,
    ),
  )
  assert_true(
    root_mod.contains(
      "wzzc-dev/moui_skia_renderer@" +
      default_moui_skia_renderer_dependency_version,
    ),
  )
  assert_true(root_mod.contains("preferred_target = \"native\""))
  let web_pkg = test_planned_text(files, "web_wasm/moon.pkg")
  assert_true(web_pkg.contains("wzzc-dev/moui_web_renderer"))
  assert_true(web_pkg.contains("@webgpu_adapter"))
  assert_true(web_pkg.contains("web_dispatch_pointer_input"))
  let web_main = test_planned_text(files, "web_wasm/main.mbt")
  assert_true(web_main.contains("@apphost.run_app"))
  assert_true(web_main.contains(".render_all(@webgpu_adapter.from_env())"))
  assert_true(web_main.contains(".backend(@web.entry())"))
  assert_true(web_main.contains("pub fn web_dispatch_pointer_input"))
  // The generated project's moon.mod pins default_moui_dependency_version and
  // its browser_runtime.js comes from that same registry package. The 0.3
  // Web pointer ABI carries pointer_id + pressure (10 args); a generated shim
  // that still forwards only 8 fails `moon build --target wasm-gc` with
  // "requires 10 arguments, but is given 8". Keep the shim, the default pin,
  // and this assertion on the same release line.
  assert_true(web_main.contains("pointer_id : Int"))
  assert_true(web_main.contains("pressure : Double"))
  assert_true(
    web_main.contains("button,\n    modifiers,\n    pointer_id,\n    pressure,"),
  )
  assert_false(web_main.contains("@web.run_app"))
  let html = test_planned_text(files, "web_wasm/index.html")
  inspect(
    html.contains("../_build/wasm-gc/debug/build/web_wasm/web_wasm.wasm"),
    content="true",
  )
  inspect(html.contains("build/example/sample_app/web_wasm"), content="false")
  let desktop_pkg = test_planned_text(files, "macos_skia/moon.pkg")
  let desktop_main = test_planned_text(files, "macos_skia/main.mbt")
  assert_true(desktop_pkg.contains("wzzc-dev/moui/backend/macos"))
  assert_true(desktop_pkg.contains("wzzc-dev/moui_skia_renderer"))
  assert_true(desktop_pkg.contains("wzzc-dev/moui/runtime"))
  assert_true(desktop_pkg.contains("wzzc-dev/moui/apphost"))
  assert_false(desktop_pkg.contains("wzzc-dev/moui/backend/macos/"))
  assert_true(desktop_main.contains("@apphost.run_app"))
  assert_true(
    desktop_main.contains(
      ".render_all(@render_skia.from_env(platform=@render_skia.NativeGpuPlatform::MacOS))",
    ),
  )
  assert_true(desktop_main.contains(".backend(@platform_host.entry())"))
}

///|
test "mobile config contains window-hosted platform defaults" {
  let options = test_project_options(
    ["web", "android", "ios", "harmonyos"],
    bundle_id=Some("dev.example.sample"),
  )
  let files = match build_project_file_plan(options, "0.0.0-test") {
    Ok(files) => files
    Err(message) => fail(message)
  }
  let mobile = test_planned_text(files, "moui.mobile.json")
  let root_mod = test_planned_text(files, "moon.mod")
  inspect(
    root_mod.contains(
      "wzzc-dev/moui_skia_renderer@" +
      default_moui_skia_renderer_dependency_version,
    ),
    content="true",
  )
  inspect(
    root_mod.contains(
      "wzzc-dev/moui_web_renderer@" + default_web_renderer_dependency_version,
    ),
    content="true",
  )
  for platform in ["android", "ios", "harmonyos"] {
    let package_text = test_planned_text(
      files,
      platform + "_window_hosted/moon.pkg",
    )
    let main_text = test_planned_text(
      files,
      platform + "_window_hosted/main.mbt",
    )
    inspect(package_text.contains("wzzc-dev/moui/runtime"), content="true")
    inspect(package_text.contains("wzzc-dev/moui/apphost"), content="true")
    inspect(
      package_text.contains("wzzc-dev/moui/backend/" + platform),
      content="true",
    )
    inspect(
      package_text.contains("wzzc-dev/moui_skia_renderer"),
      content="true",
    )
    inspect(
      package_text.contains("wzzc-dev/moui/backend/" + platform + "/"),
      content="false",
    )
    inspect(main_text.contains("@apphost.run_app"), content="true")
    inspect(
      main_text.contains(".render_all(@render_skia.from_env(platform="),
      content="true",
    )
    inspect(
      main_text.contains(".backend(@platform_host.entry())"),
      content="true",
    )
  }
  let parsed = @json.parse(mobile) catch {
    _ => fail("generated moui.mobile.json must parse")
  }
  guard parsed is Object(root) else {
    fail("generated moui.mobile.json must be an object")
  }
  inspect(
    root.get("schemaVersion") is Some(Number(1.0, repr=_)),
    content="true",
  )
  inspect(root.get("appPackage") is Some(String("app")), content="true")
  guard root.get("android") is Some(Object(android)) else {
    fail("missing Android defaults")
  }
  inspect(android.get("minSdk") is Some(Number(23.0, repr=_)), content="true")
  guard root.get("ios") is Some(Object(ios)) else {
    fail("missing iOS defaults")
  }
  inspect(ios.get("deploymentTarget") is Some(String("15.0")), content="true")
  guard root.get("harmonyos") is Some(Object(harmonyos)) else {
    fail("missing HarmonyOS defaults")
  }
  inspect(
    harmonyos.get("compatibleSdkVersion") is Some(Number(20.0, repr=_)),
    content="true",
  )
}

///|
test "project manifest parser rejects unsupported and duplicate platforms" {
  let unsupported = test_project_options(["web"])
  let unsupported_manifest : ProjectManifest = {
    schema_version: 1,
    id: unsupported.id,
    title: unsupported.title,
    module_name: unsupported.module_name,
    moui_version: unsupported.moui_version,
    platforms: ["web", "plan9"],
    bundle_id: None,
  }
  inspect(
    parse_project_manifest(unsupported_manifest.to_json_text()) is Err(_),
    content="true",
  )
  let duplicate_manifest = {
    ..unsupported_manifest,
    platforms: ["web", "web"],
  }
  inspect(
    parse_project_manifest(duplicate_manifest.to_json_text()) is Err(_),
    content="true",
  )
}

///|
test "addon template emits a library module without platform entrypoints" {
  match
    build_project_file_plan(
      test_project_options([], template="addon"),
      "0.0.0-test",
    ) {
    Ok(files) => {
      let paths : Array[String] = []
      for file in files {
        paths.push(file.path)
      }
      assert_true(paths.contains("sample_app/moon.pkg"))
      assert_true(paths.contains("sample_app/sample_app_control.mbt"))
      assert_true(paths.contains("sample_app/sample_app_control_test.mbt"))
      assert_false(paths.contains("app/app.mbt"))
      assert_false(paths.contains(".moui/dev.mjs"))
      assert_false(paths.any(path => path.contains("_skia")))
      let control = test_planned_text(
        files, "sample_app/sample_app_control.mbt",
      )
      assert_true(control.contains("impl @core.ViewNode for SampleApp"))
      assert_true(control.contains("pub fn[Msg] sample_app_badge("))
      assert_true(control.contains("@core.View::from_node("))
      let test_src = test_planned_text(
        files, "sample_app/sample_app_control_test.mbt",
      )
      assert_true(
        test_src.contains("sample_app_badge(label=\"Addon\", count=3)"),
      )
      assert_true(test_src.contains("draw_commands"))
      let pkg = test_planned_text(files, "sample_app/moon.pkg")
      assert_true(pkg.contains("for \"test\""))
      assert_true(pkg.contains("wzzc-dev/moui/runtime"))
      assert_false(pkg.contains("test_support"))
      let root_mod = test_planned_text(files, "moon.mod")
      assert_true(root_mod.contains("wzzc-dev/moui@"))
      assert_false(root_mod.contains("moui_web_renderer"))
      assert_false(root_mod.contains("moui_skia_renderer"))
      let readme = test_planned_text(files, "README.md")
      assert_true(readme.contains("MoUI addon"))
    }
    Err(message) => fail(message)
  }
}
