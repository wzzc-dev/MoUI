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
