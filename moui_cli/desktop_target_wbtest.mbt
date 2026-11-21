// White-box tests for desktop target resolution. Directory-dependent tests
// build their fixtures under a temporary directory.

///|
test "desktop_entrypoint_candidates_default_prefers_skia" {
  let candidates = desktop_entrypoint_candidates("windows").unwrap()
  inspect(
    candidates.join(","),
    content="windows_skia,windows_wgpu,windows_sun,windows,cmd/windows_skia,cmd/windows_wgpu,cmd/windows_sun,cmd/windows",
  )
}

///|
test "desktop_entrypoint_candidates_renderer_override" {
  let candidates = desktop_entrypoint_candidates("linux", renderer="wgpu").unwrap()
  inspect(candidates.join(","), content="linux_wgpu,cmd/linux_wgpu")
  let web = desktop_entrypoint_candidates("web").unwrap()
  inspect(web.join(","), content="web_wasm")
  let error = desktop_entrypoint_candidates("macos", renderer="vulkan")
  match error {
    Ok(_) => fail("expected unknown-renderer error")
    Err(message) => assert_true(message.contains("unknown renderer"))
  }
}

///|
test "relative_path_under_strips_root" {
  inspect(
    relative_path_under("/repo", "/repo/examples/showcase"),
    content="examples/showcase",
  )
  inspect(relative_path_under("/repo", "/repo"), content=".")
  inspect(relative_path_under("/repo", "/other"), content="/other")
  inspect(relative_path_under("", "windows_skia"), content="windows_skia")
}

///|
test "desktop_artifact_path_native_and_web" {
  inspect(
    desktop_artifact_path("/repo", "examples/counter/macos_skia", "native"),
    content="/repo/_build/native/debug/build/examples/counter/macos_skia/macos_skia.exe",
  )
  inspect(
    desktop_artifact_path("/repo", "web_wasm", "wasm-gc", release=true),
    content="/repo/_build/wasm-gc/release/build/web_wasm/web_wasm.wasm",
  )
}

///|
test "resolve_desktop_root_accepts_project_dir_and_entrypoint_dir" {
  let root = "/tmp/moui-cli-desktop-target-test"
  let app_dir = join_path(root, "my_app")
  let entry_dir = join_path(app_dir, "windows_skia")
  ignore(mkdir_p(entry_dir))
  @fs.write_bytes_to_file(join_path(entry_dir, "moon.pkg"), b"{}\n") catch {
    _ => ()
  }
  let resolved_project = resolve_desktop_root(root, "my_app", "windows").unwrap()
  assert_true(resolved_project.has_suffix("my_app"))
  let resolved_entry = resolve_desktop_root(
    root,
    join_path("my_app", "windows_skia"),
    "windows",
  ).unwrap()
  assert_true(resolved_entry.has_suffix("my_app"))
  let flow = resolve_desktop_flow(root, "my_app", "windows").unwrap()
  assert_eq(flow.target.package_path, "windows_skia")
  assert_eq(flow.target.target, "native")
  remove_tree(root)
}

///|
test "resolve_desktop_target_reports_missing_entrypoints" {
  let root = "/tmp/moui-cli-desktop-target-missing"
  ignore(mkdir_p(root))
  let result = resolve_desktop_target(root, "linux")
  match result {
    Ok(_) => fail("expected missing-entrypoint error")
    Err(message) => assert_true(message.contains("linux_skia"))
  }
  remove_tree(root)
}

///|
test "resolve_desktop_flow_accepts_cmd_platform_layout" {
  let root = "/tmp/moui-cli-desktop-cmd-layout"
  remove_tree(root)
  let app_dir = join_path(root, "MoSpace")
  for directory in [app_dir, join_path(app_dir, "cmd/linux")] {
    match mkdir_p(directory) {
      Ok(_) => ()
      Err(message) => fail(message)
    }
  }
  for marker in ["moon.mod", "cmd/linux/moon.pkg"] {
    @fs.write_bytes_to_file(
      join_path(app_dir, marker),
      @utf8.encode("{}\n", bom=false),
    ) catch {
      _ => fail("could not write " + marker)
    }
  }
  // `moui package linux .` from the project root.
  let flow = resolve_desktop_flow(root, "MoSpace", "linux").unwrap()
  assert_eq(flow.target.package_path, "cmd/linux")
  assert_eq(flow.package_path, "cmd/linux")
  assert_eq(flow.build_base, app_dir)
  // `moui package linux cmd` from the project root: the package path stays
  // relative to the module root (`moon.mod`), not to the `cmd` directory.
  let from_cmd = resolve_desktop_flow(root, "MoSpace/cmd", "linux").unwrap()
  assert_eq(from_cmd.target.package_path, "linux")
  assert_eq(from_cmd.package_path, "cmd/linux")
  assert_eq(from_cmd.build_base, app_dir)
  // Passing the entrypoint package itself is accepted too.
  let from_entry = resolve_desktop_flow(root, "MoSpace/cmd/linux", "linux").unwrap()
  assert_eq(from_entry.build_base, app_dir)
  assert_eq(from_entry.package_path, "cmd/linux")
  remove_tree(root)
}

///|
test "desktop_build_base_prefers_workspace_then_module_root" {
  let root = "/tmp/moui-cli-build-base"
  remove_tree(root)
  let workspace = join_path(root, "work")
  let app_dir = join_path(workspace, "apps/my_app")
  for directory in [app_dir] {
    match mkdir_p(directory) {
      Ok(_) => ()
      Err(message) => fail(message)
    }
  }
  @fs.write_bytes_to_file(
    join_path(app_dir, "moon.mod"),
    @utf8.encode("{}\n", bom=false),
  ) catch {
    _ => fail("could not write moon.mod")
  }
  // No workspace: `moon build` writes `_build` under the module root.
  assert_eq(desktop_build_base(app_dir), app_dir)
  // A workspace above the module root wins.
  @fs.write_bytes_to_file(
    join_path(workspace, "moon.work"),
    @utf8.encode("{}\n", bom=false),
  ) catch {
    _ => fail("could not write moon.work")
  }
  assert_eq(desktop_build_base(app_dir), workspace)
  remove_tree(root)
}

///|
test "strip_native_artifact_reports_missing_target" {
  match strip_native_artifact("/tmp/moui-cli-strip-missing/nothing") {
    Ok(_) => fail("expected a missing-target error")
    Err(message) => assert_true(message.contains("missing"))
  }
}
