// macOS desktop launch wrappers. Notification permission and delivery are
// keyed by the app bundle identifier, so `moui run macos` launches the built
// executable from a minimal development `.app` bundle instead of a bare Mach-O
// binary. The bundle stays under `_build/` and is ad-hoc signed on every run.

///|
fn macos_dev_bundle_component(value : String) -> String {
  let builder = StringBuilder()
  for index in 0..<value.length() {
    let char = value[index].to_int()
    let keep = (char >= 97 && char <= 122) ||
      (char >= 65 && char <= 90) ||
      (char >= 48 && char <= 57)
    if keep {
      builder.write_char(char.unsafe_to_char())
    } else {
      builder.write_char('-')
    }
  }
  let result = builder.to_string()
  if result == "" {
    "app"
  } else {
    result
  }
}

///|
fn macos_dev_bundle_name(flow : DesktopFlow) -> String {
  @plan.product_name(base_name(flow.app_root))
}

///|
fn macos_dev_bundle_id(flow : DesktopFlow, name : String) -> String {
  // Development launches use a `.dev` identity so a previously packaged build
  // with the release bundle id cannot own the LaunchServices/notification
  // record. Include the entrypoint leaf so multiple entrypoints in one project
  // do not overwrite each other's permission state.
  let leaf = macos_dev_bundle_component(base_name(flow.package_path)).to_lower()
  match read_project_manifest(flow.app_root) {
    Ok(manifest) =>
      match manifest.bundle_id {
        Some(value) => value + ".dev"
        None =>
          "dev.wzzc.moui.dev." +
          macos_dev_bundle_component(name).to_lower() +
          "." +
          leaf
      }
    Err(_) =>
      "dev.wzzc.moui.dev." +
      macos_dev_bundle_component(name).to_lower() +
      "." +
      leaf
  }
}

///|
fn macos_dev_bundle_dir(flow : DesktopFlow, name : String) -> String {
  join_path(flow.build_base, "_build/moui-run/" + name + ".app")
}

///|
fn prepare_macos_dev_bundle(
  flow : DesktopFlow,
  artifact : String,
) -> Result[String, String] {
  let name = macos_dev_bundle_name(flow)
  let bundle_id = macos_dev_bundle_id(flow, name)
  let bundle_dir = macos_dev_bundle_dir(flow, name)
  let contents_dir = join_path(bundle_dir, "Contents")
  let macos_dir = join_path(contents_dir, "MacOS")
  let artifact_name = base_name(artifact)
  // A `.app` executable is conventionally extensionless; LaunchServices and
  // UserNotifications both expect the declared executable to be a bundle
  // member, not a `.exe` drop-in.
  let executable = if artifact_name.has_suffix(".exe") {
    artifact_name[:artifact_name.length() - 4].to_owned()
  } else {
    artifact_name
  }
  let inner = join_path(macos_dir, executable)
  remove_tree(bundle_dir)
  match mkdir_p(macos_dir) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match copy_file(artifact, inner) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match make_executable(inner) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
    "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n" +
    "<plist version=\"1.0\">\n<dict>\n" +
    "  <key>CFBundleExecutable</key>\n  <string>" +
    executable +
    "</string>\n" +
    "  <key>CFBundleIdentifier</key>\n  <string>" +
    bundle_id +
    "</string>\n" +
    "  <key>CFBundleName</key>\n  <string>" +
    name +
    "</string>\n" +
    "  <key>CFBundleDisplayName</key>\n  <string>" +
    name +
    "</string>\n" +
    "  <key>CFBundlePackageType</key>\n  <string>APPL</string>\n" +
    "  <key>CFBundleVersion</key>\n  <string>1</string>\n" +
    "  <key>CFBundleShortVersionString</key>\n  <string>0.0.0</string>\n" +
    "  <key>LSMinimumSystemVersion</key>\n  <string>12.0</string>\n" +
    "  <key>NSHighResolutionCapable</key>\n  <true/>\n" +
    "  <key>NSPrincipalClass</key>\n  <string>NSApplication</string>\n" +
    "</dict>\n</plist>\n"
  @fs.write_bytes_to_file(
    join_path(contents_dir, "Info.plist"),
    @utf8.encode(plist[:], bom=false),
  ) catch {
    _ => return Err("could not write Info.plist")
  }
  @fs.write_bytes_to_file(
    join_path(contents_dir, "PkgInfo"),
    @utf8.encode("APPL????", bom=false),
  ) catch {
    _ => return Err("could not write PkgInfo")
  }
  let signing = match
    process_exec_argv(
      ["/usr/bin/codesign", "--force", "--sign", "-", bundle_dir],
      capture=true,
    ) {
    Ok(value) => value
    Err(message) => return Err("could not run codesign: " + message)
  }
  if signing.exit_code != 0 {
    return Err("codesign failed: " + signing.stderr + signing.stdout)
  }
  // Directly exec'ing a bundle binary skips LaunchServices registration, and
  // UserNotifications only resolves a bundle that LaunchServices knows about.
  // Register the finished bundle before launching it.
  let registrar = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
  if path_is_file(registrar) {
    let registered = match
      process_exec_argv([registrar, "-f", bundle_dir], capture=true) {
      Ok(value) => value
      Err(message) => return Err("could not run lsregister: " + message)
    }
    if registered.exit_code != 0 {
      return Err("lsregister failed: " + registered.stderr + registered.stdout)
    }
  }
  Ok(inner)
}
