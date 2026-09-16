// White-box tests for desktop target resolution. Directory-dependent tests
// build their fixtures under a temporary directory.

///|
test "desktop_entrypoint_candidates_default_prefers_skia" {
  let candidates = desktop_entrypoint_candidates("windows").unwrap()
  inspect(
    candidates.join(","),
    content="windows_skia,windows_wgpu,windows_sun,windows",
  )
}

///|
test "desktop_entrypoint_candidates_renderer_override" {
  let candidates = desktop_entrypoint_candidates("linux", renderer="wgpu").unwrap()
  inspect(candidates.join(","), content="linux_wgpu")
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
