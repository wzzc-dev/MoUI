// Internal iOS native builder used by Xcode Run Script Phase. Migrates
// `moui_shell/scripts/build-ios-app-core.sh` (455 lines) into MoonBit.
//
// `build_ios_core` runs the same pipeline as the shell version: parse SDK /
// arch / deployment_target / fallback_skia / renderer / shell_mode from env,
// validate the ejected lock when ejected, call `prepare_native_build` (M5),
// resolve the managed iOS shell (managed mode), then drive `clang`/`clang++`/
// `swiftc` + `PlistBuddy` + `codesign` to assemble the `.app` bundle.
//
// This function is invoked from the thin `build-ios-app-core.sh` launcher
// (M13) so Xcode script phases continue to call the same path.

///|
priv struct BuildIosCoreOptions {
  app : ShellApp
  app_config : String
  workspace_root : String
  project_root : String
  moui_root : String
  skia_root : String
  sdk : String
  arch : String
  deployment_target : String
  renderer : String
  fallback_skia : Bool
  shell_mode : String
  build_dir : String
  target_build_dir : String?
  full_product_name : String?
  resolved_swift : String?
  resolved_manifest : String?
  env : Array[(String, String)]
}

///|
/// Resolve a C/C++/Swift toolchain via `xcrun --sdk <sdk> --find <tool>`.
/// Returns an empty string when the lookup fails.
fn xcrun_find_tool(sdk : String, tool : String) -> String {
  match
    process_exec_argv(["xcrun", "--sdk", sdk, "--find", tool], capture=true) {
    Ok(result) if result.exit_code == 0 => result.stdout.trim().to_string()
    _ => ""
  }
}

///|
/// Resolve the SDK sysroot path via `xcrun --sdk <sdk> --show-sdk-path`.
fn xcrun_sdk_path(sdk : String) -> String {
  match
    process_exec_argv(["xcrun", "--sdk", sdk, "--show-sdk-path"], capture=true) {
    Ok(result) if result.exit_code == 0 => result.stdout.trim().to_string()
    _ => ""
  }
}

///|
/// Invoke `clang` to compile a single C source into an object file. Mirrors
/// the `compile_c` shell function in `build-ios-app-core.sh`.
fn compile_c_source(
  cc : String,
  common_flags : Array[String],
  include_flags : Array[String],
  src : String,
  obj : String,
  extra_flags : Array[String],
) -> Result[Unit, String] {
  let argv = [
    cc, ..common_flags, ..include_flags, ..extra_flags, "-c", src, "-o", obj,
  ]
  log_command("clang", ["clang", ..extra_flags, "-c", src, "-o", obj])
  match process_exec_argv(argv, capture=false) {
    Ok(result) if result.exit_code == 0 => Ok(())
    Ok(result) =>
      Err(
        "clang failed for " +
        src +
        " (exit " +
        result.exit_code.to_string() +
        ")",
      )
    Err(message) => Err(message)
  }
}

///|
/// Invoke `clang++` to compile a C++ source into an object file. Mirrors
/// `compile_cxx`. Forces C++ language mode via `-x c++ -std=c++17`.
fn compile_cxx_source(
  cxx : String,
  common_flags : Array[String],
  include_flags : Array[String],
  skia_cxx_rsp : String,
  src : String,
  obj : String,
  extra_flags : Array[String],
) -> Result[Unit, String] {
  let argv = [cxx, ..common_flags, ..include_flags]
  if skia_cxx_rsp != "" {
    argv.push("@" + skia_cxx_rsp)
  }
  argv.push("-x")
  argv.push("c++")
  argv.push("-std=c++17")
  for flag in extra_flags {
    argv.push(flag)
  }
  argv.push("-c")
  argv.push(src)
  argv.push("-o")
  argv.push(obj)
  log_command("clang++", ["clang++", "-c", src, "-o", obj])
  match process_exec_argv(argv, capture=false) {
    Ok(result) if result.exit_code == 0 => Ok(())
    Ok(result) =>
      Err(
        "clang++ failed for " +
        src +
        " (exit " +
        result.exit_code.to_string() +
        ")",
      )
    Err(message) => Err(message)
  }
}

///|
/// Invoke `clang++` to compile an Objective-C++ source. Mirrors
/// `compile_objcxx`.
fn compile_objcxx_source(
  cxx : String,
  common_flags : Array[String],
  include_flags : Array[String],
  src : String,
  obj : String,
) -> Result[Unit, String] {
  let argv = [
    cxx, ..common_flags, ..include_flags, "-std=c++17", "-fobjc-arc", "-c", src,
    "-o", obj,
  ]
  log_command("clang++ objcxx", ["clang++", "-c", src, "-o", obj])
  match process_exec_argv(argv, capture=false) {
    Ok(result) if result.exit_code == 0 => Ok(())
    Ok(result) =>
      Err(
        "clang++ (objcxx) failed for " +
        src +
        " (exit " +
        result.exit_code.to_string() +
        ")",
      )
    Err(message) => Err(message)
  }
}

///|
/// Invoke `swiftc` to emit a single object file for a Swift module. Mirrors
/// `compile_swift_object`.
fn compile_swift_object(
  swiftc : String,
  swift_flags : Array[String],
  module_name : String,
  output : String,
  sources : Array[String],
) -> Result[Unit, String] {
  let argv = [
    swiftc, ..swift_flags, "-parse-as-library", "-whole-module-optimization", "-module-name",
    module_name, "-emit-object",
  ]
  for source in sources {
    argv.push(source)
  }
  argv.push("-o")
  argv.push(output)
  log_command("swiftc", ["swiftc", "-module-name", module_name, "-o", output])
  match process_exec_argv(argv, capture=false) {
    Ok(result) if result.exit_code == 0 => Ok(())
    Ok(result) =>
      Err(
        "swiftc failed for module " +
        module_name +
        " (exit " +
        result.exit_code.to_string() +
        ")",
      )
    Err(message) => Err(message)
  }
}

///|
/// Invoke `swiftc` to emit a `.swiftmodule` + object file for a Swift
/// package module. Mirrors the shell snippet at lines 350-360 of
/// `build-ios-app-core.sh`.
fn compile_swift_module(
  swiftc : String,
  swift_flags : Array[String],
  module_name : String,
  module_path : String,
  output : String,
  sources : Array[String],
) -> Result[Unit, String] {
  let argv = [
    swiftc, ..swift_flags, "-parse-as-library", "-whole-module-optimization", "-module-name",
    module_name, "-emit-module", "-emit-module-path", module_path, "-emit-object",
  ]
  for source in sources {
    argv.push(source)
  }
  argv.push("-o")
  argv.push(output)
  log_command("swiftc module", [
    "swiftc", "-module-name", module_name, "-emit-module",
  ])
  match process_exec_argv(argv, capture=false) {
    Ok(result) if result.exit_code == 0 => Ok(())
    Ok(result) =>
      Err(
        "swiftc failed for module " +
        module_name +
        " (exit " +
        result.exit_code.to_string() +
        ")",
      )
    Err(message) => Err(message)
  }
}

///|
/// Invoke `PlistBuddy` with a single command. Mirrors the
/// `/usr/libexec/PlistBuddy -c <cmd> <plist>` invocations.
fn plist_buddy(plist : String, command : String) -> Unit {
  match
    process_exec_argv(
      ["/usr/libexec/PlistBuddy", "-c", command, plist],
      capture=true,
    ) {
    Ok(result) if result.exit_code == 0 => ()
    _ => log_warn("PlistBuddy command failed: " + command)
  }
}

///|
/// Quote a Swift string literal: wrap in double quotes and escape `"` and `\`.
/// Used when emitting the `MOUIShellConfiguration.generated` extension.
fn swift_string_literal(value : String) -> String {
  let buf = StringBuilder::new()
  buf.write_char('"')
  for ch in value {
    match ch {
      '"' => {
        buf.write_char('\\')
        buf.write_char('"')
      }
      '\\' => {
        buf.write_char('\\')
        buf.write_char('\\')
      }
      _ => buf.write_char(ch)
    }
  }
  buf.write_char('"')
  buf.to_string()
}

///|
/// Ad-hoc sign the simulator app bundle with `codesign -f -s -`. Mirrors
/// lines 434-440 of `build-ios-app-core.sh`.
fn adhoc_sign_simulator_app(app_bundle : String) -> Unit {
  match
    process_exec_argv(
      ["codesign", "--force", "--sign", "-", app_bundle],
      capture=true,
    ) {
    Ok(result) if result.exit_code == 0 =>
      log_info("[moui-shell-ios] Ad-hoc signed simulator app bundle")
    _ =>
      log_warn("Ad-hoc codesign failed; leaving unsigned simulator app bundle")
  }
}

///|
/// Build the iOS app bundle by directly driving clang/clang++/swiftc. This
/// replaces the build-ios-app-core.sh script and is called from Xcode Run
/// Script Phases via the thin M13 launcher.
fn build_ios_core(
  options : BuildIosCoreOptions,
  host : HostPlatform,
) -> Result[BuildResult, String] {
  let _ = host
  // 1. Validate deployment target floor (>= 15).
  let major = parse_dotted_version(options.deployment_target)
  if major.is_empty() || major[0] < 15 {
    return Err(
      "MoUI iOS requires deployment target 15.0 or newer: " +
      options.deployment_target,
    )
  }
  // 2. Validate ejected lock if applicable.
  if options.shell_mode == "ejected" {
    let shell_root = join_path(options.moui_root, "../moui_shell")
    let lock_path = join_path(shell_root, ".moui-shell.json")
    match
      validate_ejected_lock(
        lock_path,
        "ios",
        options.moui_root,
        shell_root,
        options.project_root,
        options.app_config,
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  // 3. Call prepare_native_build (M5).
  let contract = match
    managed_platform_contract(
      options.app,
      "ios",
      options.workspace_root,
      join_path(options.moui_root, "../moui_shell"),
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let prepare_options : PrepareOptions = {
    app: options.app,
    app_config_path: options.app_config,
    workspace_root: options.workspace_root,
    moui_root: options.moui_root,
    skia_root: options.skia_root,
    build_dir: options.build_dir,
    abi: "",
    android_shell: "",
    sdk: options.sdk,
    arch: options.arch,
    renderer: options.renderer,
    fallback_skia: options.fallback_skia,
    shell_root: join_path(options.moui_root, "../moui_shell"),
    contract,
  }
  let prepare_result = match prepare_native_build(prepare_options) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  // 4. Resolve xcrun toolchain paths.
  let sdk_path = xcrun_sdk_path(options.sdk)
  if sdk_path == "" {
    return Err("could not resolve SDK path for " + options.sdk)
  }
  let cc = xcrun_find_tool(options.sdk, "clang")
  if cc == "" {
    return Err("could not resolve clang for " + options.sdk)
  }
  let cxx = xcrun_find_tool(options.sdk, "clang++")
  if cxx == "" {
    return Err("could not resolve clang++ for " + options.sdk)
  }
  let swiftc = xcrun_find_tool(options.sdk, "swiftc")
  if swiftc == "" {
    return Err("could not resolve swiftc for " + options.sdk)
  }
  let moon_home = @env.get_env_var("MOON_HOME").unwrap_or_else(() => {
    let home = @env.get_env_var("HOME").unwrap_or("")
    join_path(home, ".moon")
  })
  // 5. Compile each source. The shell script assembles ~6-8 objects; we
  // delegate to the helper functions above. Since this is invoked from Xcode
  // Run Script Phase, individual compile failures surface as the script exit
  // code.
  let shell_root = join_path(options.moui_root, "../moui_shell")
  let obj_dir = join_path(
    options.build_dir,
    "obj/" + options.sdk + "-" + options.arch + "-Debug",
  )
  remove_tree(obj_dir)
  match mkdir_p(obj_dir) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let min_version_flag = if options.sdk == "iphonesimulator" {
    "-mios-simulator-version-min"
  } else {
    "-miphoneos-version-min"
  }
  let common_flags = [
    "-arch",
    options.arch,
    "-isysroot",
    sdk_path,
    min_version_flag + "=" + options.deployment_target,
  ]
  let include_flags = [
    "-I",
    join_path(shell_root, "include"),
    "-I",
    join_path(shell_root, "ios/embedder/include"),
    "-I",
    join_path(shell_root, "ios/embedder/bridge/include"),
    "-I",
    join_path(moon_home, "include"),
    "-I",
    join_path(options.skia_root, "native"),
  ]
  let swift_target = if options.sdk == "iphonesimulator" {
    options.arch + "-apple-ios" + options.deployment_target + "-simulator"
  } else {
    options.arch + "-apple-ios" + options.deployment_target
  }
  let swift_flags = [
    "-swift-version",
    "5",
    "-target",
    swift_target,
    "-sdk",
    sdk_path,
    "-I",
    join_path(shell_root, "ios/embedder/bridge/include"),
    // Include the obj_dir so `MoUIShellApp.swift` can find the
    // `MoUIShellShell.swiftmodule` emitted below.
    "-I",
    obj_dir,
  ]
  let objects : Array[String] = []
  let moonbit_c = prepare_result.moonbit_c
  let compiled_main_alias = "moui_embedding_moonbit_generated_main"
  // moonbit C
  match
    compile_c_source(
      cc,
      common_flags,
      include_flags,
      moonbit_c,
      join_path(obj_dir, "moonbit.o"),
      ["-Dmain=" + compiled_main_alias],
    ) {
    Ok(_) => objects.push(join_path(obj_dir, "moonbit.o"))
    Err(message) => return Err(message)
  }
  // runtime.c
  match
    compile_c_source(
      cc,
      common_flags,
      include_flags,
      join_path(moon_home, "lib/runtime.c"),
      join_path(obj_dir, "runtime.o"),
      ["-Dgetentropy=moui_ios_getentropy"],
    ) {
    Ok(_) => objects.push(join_path(obj_dir, "runtime.o"))
    Err(message) => return Err(message)
  }
  // fs_native.c (moonbitlang/x)
  let fs_native = join_path(
    options.workspace_root,
    ".mooncakes/moonbitlang/x/fs/fs_native.c",
  )
  match
    compile_c_source(
      cc,
      common_flags,
      include_flags,
      fs_native,
      join_path(obj_dir, "fs_native.o"),
      [],
    ) {
    Ok(_) => objects.push(join_path(obj_dir, "fs_native.o"))
    Err(message) => return Err(message)
  }
  // moui_ios_compat.c
  match
    compile_c_source(
      cc,
      common_flags,
      include_flags,
      join_path(shell_root, "ios/moui_ios_compat.c"),
      join_path(obj_dir, "moui_ios_compat.o"),
      [],
    ) {
    Ok(_) => objects.push(join_path(obj_dir, "moui_ios_compat.o"))
    Err(message) => return Err(message)
  }
  // moui_embedding_api_v1.cpp
  match
    compile_cxx_source(
      cxx,
      common_flags,
      include_flags,
      "",
      join_path(shell_root, "embedding/native/moui_embedding_api_v1.cpp"),
      join_path(obj_dir, "moui_embedding_api_v1.o"),
      ["-DMOUI_EMBEDDING_API_APP_MAIN=" + compiled_main_alias],
    ) {
    Ok(_) => objects.push(join_path(obj_dir, "moui_embedding_api_v1.o"))
    Err(message) => return Err(message)
  }
  // MoUIMobileRuntimeBridge.mm
  match
    compile_objcxx_source(
      cxx,
      common_flags,
      include_flags,
      join_path(shell_root, "ios/embedder/bridge/MoUIMobileRuntimeBridge.mm"),
      join_path(obj_dir, "MoUIMobileRuntimeBridge.o"),
    ) {
    Ok(_) => objects.push(join_path(obj_dir, "MoUIMobileRuntimeBridge.o"))
    Err(message) => return Err(message)
  }
  // iOS Skia backend glue (ObjC++). Provides `_moui_ios_present_skia_pixels_to_view`,
  // `_moui_ios_skia_configure_metal_layer`, `_moui_ios_skia_metal_layer_for_view`.
  let ios_skia_backend_dir = join_path(options.moui_root, "backend/ios/skia")
  let ios_skia_mm_sources = [
    join_path(ios_skia_backend_dir, "ios_skia_presenter.mm"),
    join_path(ios_skia_backend_dir, "ios_skia_view_glue.mm"),
  ]
  for mm in ios_skia_mm_sources {
    if path_is_file(mm) {
      let obj_name = basename(mm)
      let obj_name_no_ext = obj_name
        .substring(end=obj_name.length() - 3)
        .to_string()
      let obj_path = join_path(obj_dir, obj_name_no_ext + ".o")
      match
        compile_objcxx_source(cxx, common_flags, include_flags, mm, obj_path) {
        Ok(_) => objects.push(obj_path)
        Err(message) => return Err(message)
      }
    }
  }
  // Skia stub sources (each .cpp). The stub list is shared with
  // `prepare_native_build.mbt::prepare_ios` (which writes them into
  // shell-build.json). Resolve each path against `skia_root` to match
  // the absolute paths produced there.
  let stub_sources = skia_stub_sources
    .copy()
    .map(path => join_path(options.skia_root, path))
  for stub in stub_sources {
    let obj_name = basename(stub)
    let obj_name_no_ext = if obj_name.has_suffix(".cpp") {
      obj_name.substring(end=obj_name.length() - 4).to_string()
    } else {
      obj_name
    }
    let obj_path = join_path(obj_dir, obj_name_no_ext + ".o")
    match
      compile_cxx_source(
        cxx,
        common_flags,
        include_flags,
        prepare_result.skia_cxx_rsp.unwrap_or(""),
        stub,
        obj_path,
        [],
      ) {
      Ok(_) => objects.push(obj_path)
      Err(message) => return Err(message)
    }
  }
  // Swift shell library + app entry point. The staged Xcode project template
  // has NO native compile phase; `build_ios_core` is responsible for every
  // source file that ends up in the executable. The SwiftPM package at
  // `moui_shell/ios/Package.swift` defines the `MoUIShellShell` library target
  // (4 Swift files under `embedder/Sources/MoUIMobileShell/`). Compile them as
  // a single Swift module first, then compile `MoUIMobileApp.swift` (which
  // `import MoUIShellShell`) referencing that `.swiftmodule`.
  let shell_swift_dir = join_path(
    join_path(shell_root, "ios/embedder/Sources"),
    "MoUIMobileShell",
  )
  let shell_swift_sources = [
    join_path(shell_swift_dir, "MoUIMobileCapabilities.swift"),
    join_path(shell_swift_dir, "MoUIMobileHostAdapters.swift"),
    join_path(shell_swift_dir, "MoUIMobilePlugins.swift"),
    join_path(shell_swift_dir, "MoUIMobileShell.swift"),
  ]
  let shell_module_path = join_path(obj_dir, "MoUIShellShell.swiftmodule")
  let shell_obj_path = join_path(obj_dir, "MoUIShellShell.o")
  match
    compile_swift_module(
      swiftc, swift_flags, "MoUIShellShell", shell_module_path, shell_obj_path, shell_swift_sources,
    ) {
    Ok(_) => objects.push(shell_obj_path)
    Err(message) => return Err(message)
  }
  // Generate the Swift configuration extension that `MoUIMobileApp.swift`
  // references via `MOUIShellConfiguration.generated`. This replaces
  // `moui_shell/ios/runner/resolve-shell.mjs` — the MoonBit
  // `resolve_ios_shell` helper returns the same data; we serialize it to the
  // Swift extension literal that the .mjs emitted.
  let resolution = match
    resolve_ios_shell(
      options.app,
      options.workspace_root,
      options.moui_root,
      options.renderer,
      options.shell_mode,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let plugin_types_list = if resolution.plugin_types.is_empty() {
    ""
  } else {
    let parts : Array[String] = []
    for plugin_type in resolution.plugin_types {
      parts.push(plugin_type + ".self")
    }
    parts.join(", ")
  }
  // Serialize the Swift configuration extension that `MoUIMobileApp.swift`
  // references via `MOUIShellConfiguration.generated`. Replaces
  // `moui_shell/ios/runner/resolve-shell.mjs`.
  let app_arg_lit = swift_string_literal(resolution.entrypoint_arg)
  let renderer_lit = swift_string_literal(options.renderer)
  let status_bar_lit = swift_string_literal(resolution.status_bar)
  let orientation_lit = swift_string_literal(resolution.orientation)
  let fullscreen_lit = if resolution.fullscreen { "true" } else { "false" }
  let swift_config = "import MoUIShellShell\n\n" +
    "extension MOUIShellConfiguration {\n" +
    "    public static let generated = MOUIShellConfiguration(\n" +
    "        appArgument: " +
    app_arg_lit +
    ",\n" +
    "        renderer: " +
    renderer_lit +
    ",\n" +
    "        fullscreen: " +
    fullscreen_lit +
    ",\n" +
    "        statusBar: MOUIShellStatusBarMode(rawValue: " +
    status_bar_lit +
    ") ?? .auto,\n" +
    "        orientation: MOUIShellOrientation(rawValue: " +
    orientation_lit +
    ") ?? .any,\n" +
    "        plugins: [" +
    plugin_types_list +
    "]\n" +
    "    )\n" +
    "}\n"
  let swift_config_path = join_path(obj_dir, "MoUIShellConfig.swift")
  // `String.to_bytes()` produces UTF-16 bytes on MoonBit; use
  // `write_string_to_file` which correctly emits UTF-8 (required by swiftc).
  @fs.write_string_to_file(swift_config_path, swift_config) catch {
    _ => return Err("could not write file: " + swift_config_path)
  }
  // Swift app entry point. The staged Xcode project template ships
  // `Sources/MoUIMobileApp.swift` (with `@main`) — compile it together with
  // the generated `MoUIShellConfig.swift` as a single Swift module so the link
  // step has `_main` and the `.generated` extension is in scope.
  let swift_app_source = join_path(
    join_path(options.build_dir, "ios-project"),
    "Sources/MoUIMobileApp.swift",
  )
  if path_is_file(swift_app_source) {
    let swift_module_path = join_path(obj_dir, "MoUIShellApp.swiftmodule")
    let swift_obj_path = join_path(obj_dir, "MoUIShellApp.o")
    match
      compile_swift_module(
        swiftc,
        swift_flags,
        "MoUIShellApp",
        swift_module_path,
        swift_obj_path,
        [swift_app_source, swift_config_path],
      ) {
      Ok(_) => objects.push(swift_obj_path)
      Err(message) => return Err(message)
    }
  }
  // 6. Link the executable with swiftc.
  let product_name = options.full_product_name.unwrap_or(options.app.id)
  let app_bundle = if options.output_app() != "" {
    options.output_app()
  } else {
    join_path(options.build_dir, product_name + ".app")
  }
  let executable_path = join_path(app_bundle, product_name)
  remove_tree(app_bundle)
  match mkdir_p(app_bundle) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let link_argv : Array[String] = [swiftc, ..swift_flags, "-o", executable_path]
  for obj in objects {
    link_argv.push(obj)
  }
  let skia_link_rsp = prepare_result.skia_link_rsp.unwrap_or("")
  if skia_link_rsp != "" {
    link_argv.push("@" + skia_link_rsp)
  }
  // iOS frameworks + libc.
  for
    flag in [
      "-framework", "UIKit", "-framework", "Foundation", "-framework", "CoreFoundation",
      "-framework", "CoreGraphics", "-framework", "CoreText", "-framework", "ImageIO",
      "-framework", "QuartzCore", "-framework", "Metal", "-framework", "SwiftUI",
      "-lz", "-lobjc", "-lc++",
      // Swift runtime backport libraries. `libswiftCompatibility56.a`
      // references `swift::VoucherManager` symbols that live in
      // `libswift_Concurrency`. Xcode auto-injects these for Swift code with
      // deployment target < concurrency baseline; direct `swiftc` invocation
      // does not, so add them explicitly. `libswiftCompatibilityPolicies`
      // is not present in the iPhoneSimulator SDK, so omit it.
       "-lswift_Concurrency", "-lswiftCompatibilityDynamicReplacements",
    ] {
    link_argv.push(flag)
  }
  log_command("swiftc link", ["swiftc", "-o", executable_path])
  match process_exec_argv(link_argv, capture=false) {
    Ok(result) if result.exit_code == 0 => ()
    Ok(result) =>
      return Err(
        "swiftc link failed (exit " + result.exit_code.to_string() + ")",
      )
    Err(message) => return Err(message)
  }
  // 7. Copy Info.plist + patch via PlistBuddy.
  let info_plist = contract.info_plist.unwrap_or("")
  if info_plist != "" && path_is_file(info_plist) {
    let plist_dest = join_path(app_bundle, "Info.plist")
    match read_file_bytes_optional(info_plist) {
      Some(bytes) =>
        match write_file_bytes_result(plist_dest, bytes) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      None => return Err("could not read Info.plist: " + info_plist)
    }
    plist_buddy(plist_dest, "Set :CFBundleExecutable " + product_name)
    // CFBundleIdentifier must come from `ios.bundle_id` in shell.json (e.g.
    // "dev.wzzc.moui.showcase"), not from `app.id` ("showcase"). SpringBoard's
    // FBSApplicationLibrary looks up installed bundles by bundle id; launching
    // `xcrun simctl launch <udid> <bundle_id>` fails with
    // `FBSOpenApplicationErrorDomain code=4 ("NotFound")` when the installed
    // bundle's CFBundleIdentifier does not match the requested id.
    let bundle_id = match options.app.ios {
      Some(ios) => ios.bundle_id
      None => options.app.id
    }
    plist_buddy(plist_dest, "Set :CFBundleIdentifier " + bundle_id)
    plist_buddy(
      plist_dest,
      "Set :MinimumOSVersion " + options.deployment_target,
    )
    // The Info.plist template already defines `MOUIShellMode` as
    // `$(MOUI_EMBEDDING_IOS_SHELL)` so PlistBuddy's `Add` command would fail
    // (the key already exists). Use `Set` which is idempotent: it updates the
    // existing value without complaint. Without this, the unresolved Xcode
    // build variable leaks into the final Info.plist and SpringBoard rejects
    // the bundle during launch.
    plist_buddy(plist_dest, "Set :MOUIShellMode " + options.shell_mode)
  }
  // Write PkgInfo.
  match write_file_bytes_result(join_path(app_bundle, "PkgInfo"), b"APPL????") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  // 8. Ad-hoc sign simulator bundle.
  if options.sdk == "iphonesimulator" {
    adhoc_sign_simulator_app(app_bundle)
  }
  // 9. Stage into TARGET_BUILD_DIR if set.
  match (options.target_build_dir, options.full_product_name) {
    (Some(target), Some(product)) =>
      if target != "" && product != "" {
        let xcode_product = join_path(target, product)
        if xcode_product != app_bundle {
          remove_tree(xcode_product)
          match copy_tree(app_bundle, xcode_product) {
            Ok(_) =>
              log_info(
                "[moui-shell-ios] Staged native target product at " +
                xcode_product,
              )
            Err(message) => return Err(message)
          }
        }
      }
    _ => ()
  }
  log_info("[moui-shell-ios] Wrote " + app_bundle)
  Ok({
    platform: "ios",
    build_dir: options.build_dir,
    output_artifact: app_bundle,
    prepare_result,
  })
}

///|
/// Helper accessor for the output_app fallback (extracted for clarity).
fn BuildIosCoreOptions::output_app(self : BuildIosCoreOptions) -> String {
  match @env.get_env_var("MOUI_EMBEDDING_OUTPUT_APP") {
    Some(value) => value
    None => ""
  }
}
