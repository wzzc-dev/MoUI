///|
test "package parser defaults to release and accepts linux" {
  let parsed = match parse_package_build_args(["linux", "app"], ".") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  inspect(parsed.platform, content="linux")
  inspect(parsed.options.release, content="true")
  inspect(parsed.options.allow_cross, content="false")
  inspect(parsed.options.no_build, content="false")
}

///|
test "package parser honors debug, release, and allow-cross flags" {
  let debug = match parse_package_build_args(["macos", "app", "--debug"], ".") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  inspect(debug.options.release, content="false")
  let release = match
    parse_package_build_args(["macos", "app", "--debug", "--release"], ".") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  inspect(release.options.release, content="true")
  let cross = match
    parse_package_build_args(["linux", "app", "--allow-cross"], ".") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  inspect(cross.options.allow_cross, content="true")
}

///|
test "package parser still rejects mobile targets" {
  let result = parse_package_build_args(["android", "app"], ".")
  match result {
    Ok(_) => fail("mobile targets must be rejected by moui package")
    Err(message) =>
      assert_true(
        message.contains("mobile artifacts are produced by `moui build"),
      )
  }
}

///|
test "package parser records the macOS icon path" {
  let parsed = match
    parse_package_build_args(["macos", "app", "--icon", "icon.icns"], "/tmp") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  inspect(parsed.options.icon.unwrap(), content="/tmp/icon.icns")
}

///|
test "package macOS writes PkgInfo and copies the icon" {
  let root = "/tmp/moui-package-macos-test"
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let artifact = join_path(root, "demo.exe")
  let icon = join_path(root, "AppIcon.icns")
  @fs.write_bytes_to_file(artifact, @utf8.encode("binary", bom=false)) catch {
    _ => fail("could not write the fake artifact")
  }
  @fs.write_bytes_to_file(icon, @utf8.encode("icon", bom=false)) catch {
    _ => fail("could not write the fake icon")
  }
  let target : DesktopTarget = {
    platform: "macos",
    package_path: "demo",
    target: "native",
  }
  let flow : DesktopFlow = {
    app_root: root,
    build_base: root,
    package_path: "demo",
    target,
  }
  let options : PackageBuildOptions = {
    output_dir: None,
    name: None,
    version: "1.0.0",
    build_number: "7",
    bundle_id: Some("dev.example.demo"),
    icon: Some(icon),
    renderer: "auto",
    release: true,
    allow_cross: false,
    no_build: true,
    dry_run: false,
  }
  let outcome = package_macos_bundle(
    flow,
    options,
    "Demo",
    join_path(root, "dist"),
    artifact,
    false,
  )
  inspect(outcome.exit_code, content="0")
  let bundle = join_path(root, "dist/Demo.app")
  assert_true(path_is_file(join_path(bundle, "Contents/PkgInfo")))
  assert_true(
    path_is_file(join_path(bundle, "Contents/Resources/AppIcon.icns")),
  )
  let plist = @fs.read_file_to_string(join_path(bundle, "Contents/Info.plist")) catch {
    _ => ""
  }
  assert_true(plist.contains("dev.example.demo"))
  assert_true(plist.contains("AppIcon.icns"))
}

///|
test "package Linux writes the launcher and desktop entry" {
  let root = "/tmp/moui-package-linux-test"
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let artifact = join_path(root, "demo")
  @fs.write_bytes_to_file(artifact, @utf8.encode("binary", bom=false)) catch {
    _ => fail("could not write the fake artifact")
  }
  let target : DesktopTarget = {
    platform: "linux",
    package_path: "demo",
    target: "native",
  }
  let flow : DesktopFlow = {
    app_root: root,
    build_base: root,
    package_path: "demo",
    target,
  }
  let options : PackageBuildOptions = {
    output_dir: None,
    name: None,
    version: "1.0.0",
    build_number: "7",
    bundle_id: None,
    icon: None,
    renderer: "auto",
    release: true,
    allow_cross: false,
    no_build: true,
    dry_run: false,
  }
  let outcome = package_linux_bundle(
    flow,
    options,
    "Demo",
    join_path(root, "dist"),
    artifact,
    false,
  )
  inspect(outcome.exit_code, content="0")
  let bundle = join_path(root, "dist/Demo")
  assert_true(path_is_file(join_path(bundle, "run.sh")))
  assert_true(path_is_file(join_path(bundle, "Demo.desktop")))
}

///|
test "web fallback packager rewrites module paths into a flat bundle" {
  let root = "/tmp/moui-web-package-test"
  remove_tree(root)
  let web_dir = join_path(root, "web_wasm")
  let build_dir = join_path(root, "_build/wasm-gc/release/build/web_wasm")
  let runtime_dir = join_path(root, ".mooncakes/wzzc-dev/moui_web_renderer")
  let browser_dir = join_path(root, ".mooncakes/wzzc-dev/moui/backend/web")
  for directory in [web_dir, build_dir, runtime_dir, browser_dir] {
    match mkdir_p(directory) {
      Ok(_) => ()
      Err(message) => fail(message)
    }
  }
  let index =
    #|<!doctype html><script type="module">
    #|import { bootMouiWasmGcApp } from "../.mooncakes/wzzc-dev/moui_web_renderer/runtime.js";
    #|bootMouiWasmGcApp({ wasmUrl: new URL("../_build/wasm-gc/debug/build/web_wasm/web_wasm.wasm", import.meta.url) });
    #|</script>
  @fs.write_bytes_to_file(
    join_path(web_dir, "index.html"),
    @utf8.encode(index[:], bom=false),
  ) catch {
    _ => fail("could not write the fake index")
  }
  @fs.write_bytes_to_file(
    join_path(build_dir, "web_wasm.wasm"),
    @utf8.encode("wasm", bom=false),
  ) catch {
    _ => fail("could not write the fake wasm")
  }
  @fs.write_bytes_to_file(
    join_path(runtime_dir, "runtime.js"),
    @utf8.encode(
      "import { connectWindowWeb } from \"../moui/backend/web/browser_runtime.js\";\n",
      bom=false,
    ),
  ) catch {
    _ => fail("could not write the fake runtime")
  }
  @fs.write_bytes_to_file(
    join_path(browser_dir, "browser_runtime.js"),
    @utf8.encode("export const WEB_INPUT_FLAGS = {};\n", bom=false),
  ) catch {
    _ => fail("could not write the fake browser runtime")
  }
  @fs.write_bytes_to_file(
    join_path(runtime_dir, "canvas2d_runtime.js"),
    @utf8.encode(
      "export const createCanvas2dImports = () => ({});\n",
      bom=false,
    ),
  ) catch {
    _ => fail("could not write the fake canvas runtime")
  }
  let target : DesktopTarget = {
    platform: "web",
    package_path: "web_wasm",
    target: "wasm-gc",
  }
  let flow : DesktopFlow = {
    app_root: root,
    build_base: root,
    package_path: "web_wasm",
    target,
  }
  let options : PackageBuildOptions = {
    output_dir: None,
    name: None,
    version: "1.0.0",
    build_number: "7",
    bundle_id: None,
    icon: None,
    renderer: "auto",
    release: true,
    allow_cross: false,
    no_build: true,
    dry_run: false,
  }
  let outcome = package_web_bundle_fallback(
    flow,
    options,
    "Demo",
    join_path(root, "dist"),
    false,
  )
  inspect(outcome.exit_code, content="0")
  let bundle = join_path(root, "dist/moui-web-package-test")
  let bundled_index = @fs.read_file_to_string(join_path(bundle, "index.html")) catch {
    _ => ""
  }
  assert_true(bundled_index.contains("./runtime.js"))
  assert_true(bundled_index.contains("./web_wasm.wasm"))
  let bundled_runtime = @fs.read_file_to_string(join_path(bundle, "runtime.js")) catch {
    _ => ""
  }
  assert_true(bundled_runtime.contains("./browser_runtime.js"))
  assert_true(path_is_file(join_path(bundle, "web_wasm.wasm")))
  assert_true(path_is_file(join_path(bundle, "browser_runtime.js")))
  assert_true(path_is_file(join_path(bundle, "canvas2d_runtime.js")))
}

///|
test "package Windows copies icudtl.dat from the Skia release cache" {
  let root = "/tmp/moui-package-windows-test"
  remove_tree(root)
  let icu_dir = join_path(root, "moui_skia/.skia-cache/release/lib")
  match mkdir_p(icu_dir) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let artifact = join_path(root, "demo.exe")
  @fs.write_bytes_to_file(artifact, @utf8.encode("binary", bom=false)) catch {
    _ => fail("could not write the fake artifact")
  }
  @fs.write_bytes_to_file(
    join_path(icu_dir, "icudtl.dat"),
    @utf8.encode("icu", bom=false),
  ) catch {
    _ => fail("could not write the fake ICU data")
  }
  let target : DesktopTarget = {
    platform: "windows",
    package_path: "demo",
    target: "native",
  }
  let flow : DesktopFlow = {
    app_root: root,
    build_base: root,
    package_path: "demo",
    target,
  }
  let options : PackageBuildOptions = {
    output_dir: None,
    name: None,
    version: "1.0.0",
    build_number: "7",
    bundle_id: None,
    icon: None,
    renderer: "auto",
    release: true,
    allow_cross: false,
    no_build: true,
    dry_run: false,
  }
  let outcome = package_windows_portable(
    flow,
    options,
    "Demo",
    join_path(root, "dist"),
    artifact,
    false,
  )
  inspect(outcome.exit_code, content="0")
  assert_true(path_is_file(join_path(root, "dist/Demo/icudtl.dat")))
}
