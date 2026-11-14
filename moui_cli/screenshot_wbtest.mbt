///|
test "screenshot parser takes project defaults and options" {
  let parsed = parse_screenshot_args(
    [
      "examples/gallery", "--out", "shot.png", "--width", "800", "--height=600",
      "--scale", "1.5", "--scheme", "dark", "--renderer", "sun", "--json",
    ],
    "/workspace",
  )
  guard parsed is Ok({ options, json, .. }) else {
    fail("expected screenshot arguments to parse")
  }
  inspect(options.project_root, content="/workspace/examples/gallery")
  inspect(options.app_package, content="app")
  inspect(options.out, content="/workspace/shot.png")
  inspect(options.width, content="800")
  inspect(options.height, content="600")
  inspect(options.scale.to_string(), content="1.5")
  inspect(options.scheme, content="dark")
  inspect(options.renderer, content="sun")
  inspect(json, content="true")
}

///|
test "screenshot parser rejects invalid dimensions and schemes" {
  match parse_screenshot_args(["--width", "0"], "/workspace") {
    Err(message) =>
      inspect(message, content="--width must be a positive integer")
    Ok(_) => fail("expected zero width to be rejected")
  }
  match parse_screenshot_args(["--scale", "9"], "/workspace") {
    Err(message) => inspect(message, content="--scale must be in (0, 8]")
    Ok(_) => fail("expected an oversized scale to be rejected")
  }
  match parse_screenshot_args(["--scheme", "sepia"], "/workspace") {
    Err(message) =>
      inspect(message, content="--scheme must be light, dark, or system")
    Ok(_) => fail("expected an unknown scheme to be rejected")
  }
}

///|
test "screenshot reads the module name from moon.mod" {
  let text =
    #|name = "local/demo"
    #|version = "0.1.0"
    #|import {
    #|  "wzzc-dev/moui@0.6.1",
    #|}
  inspect(screenshot_module_name(text).unwrap_or(""), content="local/demo")
  inspect(
    screenshot_module_name("version = \"0.1.0\"").unwrap_or("none"),
    content="none",
  )
}

///|
test "screenshot resolves a module and app package on disk" {
  let root = join_path(
    process_tmp_dir(),
    "moui-shot-resolve-" + @env.now().to_string(),
  )
  let module_root = join_path(root, "demo")
  let app_dir = join_path(module_root, "app")
  let cleanup = fn() { remove_tree(root) }
  match mkdir_p(app_dir) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let write = fn(path : String, text : String) {
    match write_file_bytes_result(path, @utf8.encode(text[:], bom=false)) {
      Ok(_) => ()
      Err(message) => abort(message)
    }
  }
  write(
    join_path(module_root, "moon.mod"),
    (
      #|name = "local/demo"
      #|import {
      #|  "wzzc-dev/moui@0.6.1",
      #|  "wzzc-dev/moui_skia_renderer@0.6.1",
      #|}
    ),
  )
  write(join_path(app_dir, "moon.pkg"), "import {\n  \"wzzc-dev/moui\",\n}\n")
  let target = match screenshot_resolve_target(module_root, "app") {
    Ok(target) => target
    Err(message) => {
      cleanup()
      fail("resolve failed: " + message)
    }
  }
  inspect(target.module_name, content="local/demo")
  inspect(target.app_relative, content="app")
  if !screenshot_has_dependency(
      read_file_string_optional(join_path(module_root, "moon.mod")).unwrap_or(
        "",
      ),
      "wzzc-dev/moui_skia_renderer",
    ) {
    cleanup()
    fail("expected the renderer dependency to be detected")
  }
  cleanup()
}

///|
test "screenshot package templates select the requested renderer" {
  let skia = screenshot_package_main("skia")
  let sun = screenshot_package_main("sun")
  assert_true(skia.contains("SkiaPresentTarget"))
  assert_true(!skia.contains("SunPresentTarget"))
  assert_true(sun.contains("SunPresentTarget"))
  assert_true(!sun.contains("SkiaPresentTarget"))
  assert_true(
    screenshot_package_moon_pkg("skia").contains("wzzc-dev/moui_skia_renderer"),
  )
}

///|
test "screenshot output keeps png paths and appends a suffix otherwise" {
  inspect(screenshot_output_png_path("/tmp/shot.png"), content="/tmp/shot.png")
  inspect(screenshot_output_png_path("/tmp/"), content="/tmp/screenshot.png")
  inspect(screenshot_output_png_path("/tmp/shot"), content="/tmp/shot.png")
}

///|
test "screenshot help is reachable through the CLI" {
  let outcome = run_cli(["screenshot", "--help"], "/workspace")
  inspect(outcome.exit_code, content="0")
  assert_true(outcome.stdout.contains("Usage: moui screenshot"))
}

///|
test "screenshot detects the app program constructor" {
  let root = join_path(
    process_tmp_dir(),
    "moui-shot-program-" + @env.now().to_string(),
  )
  let cleanup = fn() { remove_tree(root) }
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let source = join_path(root, "app.mbt")
  match
    write_file_bytes_result(
      source,
      @utf8.encode("pub fn view() -> Unit { () }\n"[:], bom=false),
    ) {
    Ok(_) => ()
    Err(message) => {
      cleanup()
      fail(message)
    }
  }
  match screenshot_app_exposes_program(root) {
    Ok(false) => ()
    Ok(true) => {
      cleanup()
      fail("expected a package without program() to be reported as unsupported")
    }
    Err(message) => {
      cleanup()
      fail(message)
    }
  }
  match
    write_file_bytes_result(
      source,
      @utf8.encode("pub fn program() -> Unit { () }\n"[:], bom=false),
    ) {
    Ok(_) => ()
    Err(message) => {
      cleanup()
      fail(message)
    }
  }
  match screenshot_app_exposes_program(root) {
    Ok(true) => ()
    Ok(false) => {
      cleanup()
      fail("expected program() to be detected")
    }
    Err(message) => {
      cleanup()
      fail(message)
    }
  }
  cleanup()
}
