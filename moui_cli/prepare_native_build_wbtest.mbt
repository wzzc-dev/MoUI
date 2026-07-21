// Whitebox tests for `prepare_native_build.mbt`.
//
// Tests focus on the pure helpers (`select_renderer`, `split_flags`,
// `write_rsp`, `write_android_cmake_config`, `write_harmonyos_cmake_config`)
// and the `libc++_shared.so` size guard in `copy_android_shared_libs`.
// End-to-end preparation is exercised by integration tests that drive real
// `moon build` and `node build.js` invocations and are intentionally not
// covered here.

///|
fn prepare_native_build_test_temp_path(label : String) -> String {
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
    "moui-cli-prepare-native-" + label + "-" + @env.now().to_string(),
  )
}

///|
/// Helper: build a minimal `ManagedContract` for the requested platform.
fn prepare_test_contract(platform : String) -> ManagedContract {
  {
    app_id: "counter",
    platform,
    metadata_path: "/tmp/counter/shell.json",
    workspace_root: "/tmp/counter",
    shell_root: "/tmp/counter/moui_shell",
    entrypoint_package: platform,
    generated_c: platform + ".c",
    entrypoint_arg: "moui-counter-" + platform,
    moonbit_main_alias: "moui_embedding_moonbit_generated_main",
    embedding_exports: fixed_embedding_exports(),
    native_library: if platform == "android" {
      Some("moui_counter_android")
    } else {
      None
    },
    info_plist: if platform == "ios" {
      Some("/tmp/counter/moui_shell/ios/runner/template/Info.plist")
    } else {
      None
    },
  }
}

///|
/// Helper: assert that a string appears in the array of env pairs.
fn env_contains(pairs : Array[(String, String)], key : String) -> Bool {
  for entry in pairs {
    if entry.0 == key {
      return true
    }
  }
  false
}

///|
/// Return every value associated with `key` in an environment pair array.
fn env_values(pairs : Array[(String, String)], key : String) -> Array[String] {
  let values = []
  for entry in pairs {
    if entry.0 == key {
      values.push(entry.1)
    }
  }
  values
}

///|
test "test_select_renderer" {
  // auto -> skia-gpu when no fallback requested
  match select_renderer("auto", false) {
    Ok(value) => {
      inspect(value.requested, content="auto")
      inspect(value.selected, content="skia-gpu")
      inspect(value.gpu_promoted, content="true")
      assert_true(value.fallback_reason is None)
    }
    Err(message) => fail(message)
  }
  // auto + fallback -> skia-raster with fallback reason
  match select_renderer("auto", true) {
    Ok(value) => {
      inspect(value.selected, content="skia-raster")
      inspect(value.gpu_promoted, content="false")
      assert_true(value.fallback_reason is Some(_))
    }
    Err(message) => fail(message)
  }
  // skia-gpu -> skia-gpu (no fallback)
  match select_renderer("skia-gpu", false) {
    Ok(value) => {
      inspect(value.selected, content="skia-gpu")
      inspect(value.gpu_promoted, content="true")
    }
    Err(message) => fail(message)
  }
  // skia-gpu + fallback -> still raster (cannot provide GPU route)
  match select_renderer("skia-gpu", true) {
    Ok(value) => {
      inspect(value.selected, content="skia-raster")
      inspect(value.gpu_promoted, content="false")
    }
    Err(message) => fail(message)
  }
  // skia-raster is always raster, regardless of fallback
  match select_renderer("skia-raster", false) {
    Ok(value) => {
      inspect(value.selected, content="skia-raster")
      inspect(value.gpu_promoted, content="false")
      assert_true(value.fallback_reason is None)
    }
    Err(message) => fail(message)
  }
  match select_renderer("skia-raster", true) {
    Ok(value) => {
      inspect(value.selected, content="skia-raster")
      inspect(value.gpu_promoted, content="false")
      assert_true(value.fallback_reason is None)
    }
    Err(message) => fail(message)
  }
  // invalid renderer
  assert_true(select_renderer("vulkan", false) is Err(_))
  assert_true(select_renderer("", false) is Err(_))
}

///|
test "test_write_rsp" {
  let root = prepare_native_build_test_temp_path("write-rsp")
  let rsp_path = join_path(root, "skia-cxx-flags.rsp")
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match write_rsp(rsp_path, "-I/foo/bar -L/baz/qux -lskia") {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  let content = @fs.read_file_to_string(rsp_path) catch {
    _ => {
      remove_tree(root)
      fail("could not read rsp file back")
    }
  }
  remove_tree(root)
  inspect(content, content="-I/foo/bar\n-L/baz/qux\n-lskia\n")
}

///|
test "test_moon_build_env_cleanup" {
  // Pre-populate blocked SDK env keys with sentinel values. On macOS
  // `moon_build_env()` re-injects SDKROOT/SDK_NAME/PLATFORM_NAME/CC/CXX via
  // `xcrun`, so this test focuses on the blocked keys that xcrun never
  // touches: EFFECTIVE_PLATFORM_NAME, ARCHS, VALID_ARCHS,
  // IPHONEOS_DEPLOYMENT_TARGET, LLVM_TARGET_TRIPLE_OS_VERSION.
  @env.set_env_var("EFFECTIVE_PLATFORM_NAME", "iphonesimulator")
  @env.set_env_var("ARCHS", "arm64")
  @env.set_env_var("VALID_ARCHS", "arm64")
  @env.set_env_var("IPHONEOS_DEPLOYMENT_TARGET", "15.0")
  @env.set_env_var("LLVM_TARGET_TRIPLE_OS_VERSION", "ios14.0")
  let pairs = moon_build_env()
  @env.unset_env_var("EFFECTIVE_PLATFORM_NAME")
  @env.unset_env_var("ARCHS")
  @env.unset_env_var("VALID_ARCHS")
  @env.unset_env_var("IPHONEOS_DEPLOYMENT_TARGET")
  @env.unset_env_var("LLVM_TARGET_TRIPLE_OS_VERSION")
  // Blocked keys must not appear in the cleaned env.
  assert_false(env_contains(pairs, "EFFECTIVE_PLATFORM_NAME"))
  assert_false(env_contains(pairs, "ARCHS"))
  assert_false(env_contains(pairs, "VALID_ARCHS"))
  assert_false(env_contains(pairs, "IPHONEOS_DEPLOYMENT_TARGET"))
  assert_false(env_contains(pairs, "LLVM_TARGET_TRIPLE_OS_VERSION"))
  // The three MoUI/MoonBit pins must always be injected.
  assert_true(env_contains(pairs, "MOUI_SKIA_DISABLE_PREBUILD_SKIA"))
  assert_true(env_contains(pairs, "MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM"))
  assert_true(env_contains(pairs, "MOONBIT_NEW_NATIVE"))
}

///|
test "test_normalize_moon_build_env_forces_legacy_native_mode" {
  let pairs = normalize_moon_build_env([
    ("PATH", "/bin"),
    ("MOONBIT_NEW_NATIVE", "1"),
    ("SDKROOT", "/stale/sdk"),
  ])
  let native_modes = env_values(pairs, "MOONBIT_NEW_NATIVE")
  assert_eq(native_modes.length(), 1)
  assert_eq(native_modes[0], "0")
  assert_false(env_contains(pairs, "SDKROOT"))
  assert_true(env_contains(pairs, "PATH"))
}

///|
test "test_write_android_cmake_config" {
  let root = prepare_native_build_test_temp_path("write-android-cmake")
  let cmake_path = join_path(root, "moui-shell-native.cmake")
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let contract = prepare_test_contract("android")
  let renderer = {
    requested: "auto",
    selected: "skia-gpu",
    gpu_promoted: true,
    fallback_reason: None,
  }
  let skia = {
    stub_flags: "-I/opt/skia/include",
    link_flags: "-L/opt/skia/lib -lskia",
  }
  match
    write_android_cmake_config(
      cmake_path, contract, "counter", "/tmp/counter/build/moonbit/native/debug/build/android/android.c",
      skia, "arm64-v8a", renderer, "/tmp/counter", "/tmp/moui_root", "/tmp/skia_root",
      "/tmp/moui_shell",
    ) {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  let content = @fs.read_file_to_string(cmake_path) catch {
    _ => {
      remove_tree(root)
      fail("could not read moui-shell-native.cmake back")
    }
  }
  remove_tree(root)
  assert_true(content.contains("set(MOUI_EMBEDDING_APP_ID \"counter\")"))
  assert_true(content.contains("set(MOUI_EMBEDDING_ANDROID_ABI \"arm64-v8a\")"))
  assert_true(
    content.contains("set(MOUI_EMBEDDING_RENDERER_SELECTED \"skia-gpu\")"),
  )
  assert_true(
    content.contains("set(MOUI_SKIA_CC_LINK_FLAGS \"-L/opt/skia/lib -lskia\")"),
  )
  assert_true(
    content.contains(
      "set(MOUI_EMBEDDING_LIBRARY_NAME \"moui_counter_android\")",
    ),
  )
  assert_true(
    content.contains("set(MOUI_EMBEDDING_APP_ARG \"moui-counter-android\")"),
  )
  // Verify CMake quoting escapes backslashes and quotes.
  let escaped_path = "/tmp/counter/build/moonbit/native/debug/build/android/android.c"
  assert_true(
    content.contains("set(MOUI_EMBEDDING_MOONBIT_C \"" + escaped_path + "\")"),
  )
}

///|
test "test_write_harmonyos_cmake_config" {
  let root = prepare_native_build_test_temp_path("write-harmonyos-cmake")
  let cmake_path = join_path(root, "moui-shell-harmonyos.cmake")
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let contract = prepare_test_contract("harmonyos")
  let renderer = {
    requested: "auto",
    selected: "skia-gpu",
    gpu_promoted: true,
    fallback_reason: None,
  }
  let skia = {
    stub_flags: "-I/opt/skia/include",
    link_flags: "-L/opt/skia/lib -lskia",
  }
  match
    write_harmonyos_cmake_config(
      cmake_path, contract, "counter", "/tmp/counter/build/moonbit/native/debug/build/harmonyos/harmonyos.c",
      skia, "arm64", renderer, "/tmp/counter", "/tmp/moui_root", "/tmp/skia_root",
      "/tmp/moui_shell",
    ) {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  let content = @fs.read_file_to_string(cmake_path) catch {
    _ => {
      remove_tree(root)
      fail("could not read moui-shell-harmonyos.cmake back")
    }
  }
  remove_tree(root)
  assert_true(
    content.contains("set(MOUI_EMBEDDING_HARMONYOS_OHOS_ARCH \"arm64\")"),
  )
  assert_true(
    content.contains("set(MOUI_EMBEDDING_RENDERER_REQUESTED \"auto\")"),
  )
  assert_true(
    content.contains(
      "set(MOUI_EMBEDDING_ATTACH_SURFACE_SYMBOL \"moui_embedding_attach_surface\")",
    ),
  )
  assert_true(
    content.contains(
      "set(MOUI_EMBEDDING_RESIZE_SYMBOL \"moui_embedding_resize\")",
    ),
  )
  assert_true(
    content.contains(
      "set(MOUI_EMBEDDING_RENDER_FRAME_SYMBOL \"moui_embedding_render_frame\")",
    ),
  )
  assert_true(
    content.contains("set(MOUI_EMBEDDING_APP_ARG \"moui-counter-harmonyos\")"),
  )
  assert_true(
    content.contains(
      "set(MOUI_EMBEDDING_MOONBIT_MAIN_ALIAS \"moui_embedding_moonbit_generated_main\")",
    ),
  )
}

///|
test "test_copy_android_shared_libs_size_check" {
  let root = prepare_native_build_test_temp_path("libcxx-too-small")
  let jni_libs_dir = join_path(root, "jniLibs")
  let abi = "arm64-v8a"
  let abi_dir = join_path(jni_libs_dir, abi)
  let lib_name = "libc++_shared.so"
  let lib_target = join_path(abi_dir, lib_name)
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  // Build a fake NDK prebuilt sysroot with the triple → libc++_shared.so path.
  let ndk_home = join_path(root, "ndk")
  let prebuilt = join_path(
    join_path(join_path(ndk_home, "toolchains/llvm/prebuilt"), "darwin-x86_64"),
    "sysroot/usr/lib/aarch64-linux-android",
  )
  match mkdir_p(prebuilt) {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  let libcxx_path = join_path(prebuilt, lib_name)
  // Write only 4KB — well below the 2MB guard. A stripped/minimal NDK libc++
  // copy would crash at dlopen time.
  let small_bytes = Bytes::make(4096, b'\x00')
  @fs.write_bytes_to_file(libcxx_path, small_bytes) catch {
    _ => {
      remove_tree(root)
      fail("could not write tiny libc++_shared.so fixture")
    }
  }
  let outcome = copy_android_shared_libs(abi, ndk_home, "", jni_libs_dir)
  // Even though `copy_android_shared_libs` returns Err, the file has been
  // written to the jniLibs directory. Clean it up and assert the error.
  let target_exists = @fs.path_exists(lib_target)
  remove_tree(root)
  assert_true(outcome is Err(_))
  inspect(target_exists, content="true")
}

///|
test "test_copy_android_shared_libs_passes_with_full_libcxx" {
  let root = prepare_native_build_test_temp_path("libcxx-full")
  let jni_libs_dir = join_path(root, "jniLibs")
  let abi = "arm64-v8a"
  let abi_dir = join_path(jni_libs_dir, abi)
  let lib_target = join_path(abi_dir, "libc++_shared.so")
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let ndk_home = join_path(root, "ndk")
  let prebuilt = join_path(
    join_path(join_path(ndk_home, "toolchains/llvm/prebuilt"), "darwin-x86_64"),
    "sysroot/usr/lib/aarch64-linux-android",
  )
  match mkdir_p(prebuilt) {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  let libcxx_path = join_path(prebuilt, "libc++_shared.so")
  // 3MB satisfies the >=2MB guard.
  let large_bytes = Bytes::make(3 * 1024 * 1024, b'\x00')
  @fs.write_bytes_to_file(libcxx_path, large_bytes) catch {
    _ => {
      remove_tree(root)
      fail("could not write full libc++_shared.so fixture")
    }
  }
  let outcome = copy_android_shared_libs(abi, ndk_home, "", jni_libs_dir)
  let target_exists = @fs.path_exists(lib_target)
  remove_tree(root)
  assert_true(outcome is Ok(_))
  inspect(target_exists, content="true")
}

///|
test "test_validate_harmonyos_skia_link_compatibility" {
  // raster mode never rejects anything
  assert_true(
    validate_harmonyos_skia_link_compatibility("skia-raster", "-lskia") is Ok(_),
  )
  assert_true(
    validate_harmonyos_skia_link_compatibility("skia-raster", "") is Ok(_),
  )
  // gpu + only dynamic libskia is fine
  assert_true(
    validate_harmonyos_skia_link_compatibility("skia-gpu", "-lskia") is Ok(_),
  )
  // gpu + only static ganesh extension is fine
  assert_true(
    validate_harmonyos_skia_link_compatibility(
      "skia-gpu", "/path/to/libskia_ganesh_ext.a",
    )
    is Ok(_),
  )
  // gpu + BOTH dynamic libskia AND static ganesh extension is rejected
  assert_true(
    validate_harmonyos_skia_link_compatibility(
      "skia-gpu", "-L/opt/skia/lib -lskia /path/to/libskia_ganesh_ext.a",
    )
    is Err(_),
  )
}
