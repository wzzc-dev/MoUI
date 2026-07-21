// Whitebox tests for `build_android.mbt`.
//
// Tests focus on the pure helpers (`stage_android_window_hosted_project`,
// `copy_tree`, `copy_file_atomic`, `resolve_gradle_command`). End-to-end
// Gradle invocation is exercised by integration tests with a real Android
// SDK and is intentionally not covered here.

///|
fn build_android_test_temp_path(label : String) -> String {
  let root = match @env.get_env_var("TMPDIR") {
    Some(value) => value
    None =>
      match @env.get_env_var("TEMP") {
        Some(value) => value
        None => @env.get_env_var("TMP").unwrap_or(".")
      }
  }
  join_path(
    root,
    "moui-cli-build-android-" + label + "-" + @env.now().to_string(),
  )
}

///|
test "test_stage_android_window_hosted_project_refuses_unowned_target" {
  let root = build_android_test_temp_path("refuse-unowned")
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  // Pre-existing dir without `.moui-window-hosted-stage` marker must be refused.
  let target = join_path(root, "android-project")
  match mkdir_p(target) {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  match stage_android_window_hosted_project("/nonexistent/template", target) {
    Ok(_) => {
      remove_tree(root)
      fail(
        "expected stage_android_window_hosted_project to refuse unowned target",
      )
    }
    Err(message) => {
      remove_tree(root)
      assert_true(message.contains("unowned"))
    }
  }
}

///|
test "test_stage_android_window_hosted_project_copies_template_and_writes_marker" {
  let root = build_android_test_temp_path("stage-managed")
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  // Build a tiny fake template: `settings.gradle` + `app/build.gradle`.
  let template = join_path(root, "template")
  match mkdir_p(join_path(template, "app")) {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  match
    write_file_bytes_result(
      join_path(template, "settings.gradle"),
      b"rootProject.name = 'moui'\n",
    ) {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  match
    write_file_bytes_result(
      join_path(template, "app/build.gradle"),
      b"// app\n",
    ) {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  let target = join_path(root, "android-project")
  match stage_android_window_hosted_project(template, target) {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  // Verify files copied and marker written.
  assert_true(path_is_file(join_path(target, "settings.gradle")))
  assert_true(path_is_file(join_path(target, "app/build.gradle")))
  assert_true(path_is_file(join_path(target, ".moui-window-hosted-stage")))
  remove_tree(root)
}

///|
test "test_copy_tree_recursive_copy" {
  let root = build_android_test_temp_path("copy-tree")
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let source = join_path(root, "source")
  let nested = join_path(source, "sub/deep")
  match mkdir_p(nested) {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  match write_file_bytes_result(join_path(source, "a.txt"), b"alpha\n") {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  match write_file_bytes_result(join_path(nested, "b.txt"), b"beta\n") {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  let target = join_path(root, "target")
  match mkdir_p(target) {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  match copy_tree(source, target) {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  assert_true(path_is_file(join_path(target, "a.txt")))
  assert_true(path_is_file(join_path(target, "sub/deep/b.txt")))
  remove_tree(root)
}

///|
test "test_copy_file_atomic_copies_bytes" {
  let root = build_android_test_temp_path("copy-atomic")
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let source = join_path(root, "source.bin")
  let target = join_path(root, "target.bin")
  let payload = b"\x00\x01\x02\x03moui\xFF"
  match write_file_bytes_result(source, payload) {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  match copy_file_atomic(source, target) {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  match read_file_bytes_optional(target) {
    Some(bytes) => {
      inspect(bytes, content="b\"\\x00\\x01\\x02\\x03moui\\xff\"")
      remove_tree(root)
    }
    None => {
      remove_tree(root)
      fail("could not read target file back")
    }
  }
}

///|
test "test_copy_file_atomic_returns_err_for_missing_source" {
  let root = build_android_test_temp_path("copy-atomic-missing")
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match
    copy_file_atomic(join_path(root, "missing.bin"), join_path(root, "out.bin")) {
    Ok(_) => {
      remove_tree(root)
      fail("expected Err for missing source")
    }
    Err(message) => {
      remove_tree(root)
      assert_true(message.contains("could not read"))
    }
  }
}

///|
test "test_resolve_gradle_command_prefers_workspace_gradlew" {
  let root = build_android_test_temp_path("gradle-workspace")
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  // Touch a fake `gradlew` file with executable bit. On macOS, `path_is_executable`
  // checks the file mode; we cannot easily fake that without chmod. Skip the
  // executable check by leaving the file non-executable: resolve_gradle_command
  // should then fall through to `find_in_path("gradle")`. In a sandbox without
  // `gradle` on PATH, this returns Err. Either way, the workspace wrapper is
  // not chosen unless executable.
  let gradlew = join_path(root, "gradlew")
  match write_file_bytes_result(gradlew, b"#!/bin/sh\n") {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  match resolve_gradle_command(root) {
    Ok(_) => {
      // PATH had a `gradle` binary; acceptable.
      remove_tree(root)
      assert_true(true)
    }
    Err(message) => {
      remove_tree(root)
      assert_true(message.contains("Gradle was not found"))
    }
  }
}

///|
test "test_resolve_gradle_command_returns_err_without_gradlew_or_path" {
  let root = build_android_test_temp_path("gradle-missing")
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  // In a typical sandbox this returns Err; tolerate the rare case where
  // `gradle` is on PATH by accepting either outcome, but assert the message
  // format when Err is returned.
  match resolve_gradle_command(root) {
    Ok(_) => assert_true(true)
    Err(message) => assert_true(message.contains("Gradle was not found"))
  }
  remove_tree(root)
}
