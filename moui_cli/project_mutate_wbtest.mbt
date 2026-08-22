///|
test "merge platform lists reports only newly added platforms" {
  match merge_platform_lists(["web", "macos"], ["android", "web", "ios"]) {
    Ok((merged, added)) => {
      inspect(merged.join(","), content="web,macos,android,ios")
      inspect(added.join(","), content="android,ios")
    }
    Err(message) => fail(message)
  }
}

///|
test "add platform updates manifest and writes entrypoints" {
  let root = test_temp_path("add-platform")
  remove_tree(root)
  let options = { ..test_project_options(["web", "macos"]), target: root }
  match generate_project_with_validator(options, _ => Ok(())) {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  match
    add_platforms_to_project({
      project_root: root,
      platforms: ["android"],
      bundle_id: Some("dev.example.sample"),
    }) {
    Ok((added, files)) => {
      inspect(added.join(","), content="android")
      inspect(files.contains("android_window_hosted/main.mbt"), content="true")
    }
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  let manifest = match read_project_manifest(root) {
    Ok(value) => value
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  inspect(manifest.platforms.join(","), content="web,macos,android")
  inspect(manifest.bundle_id.unwrap_or(""), content="dev.example.sample")
  inspect(@fs.path_exists(join_path(root, "moui.mobile.json")), content="true")
  inspect(
    @fs.path_exists(join_path(root, "android_window_hosted/moon.pkg")),
    content="true",
  )
  remove_tree(root)
}

///|

///|
test "doctor fix creates missing moon.work and README" {
  let root = test_temp_path("doctor-fix")
  remove_tree(root)
  let options = { ..test_project_options(["web"]), target: root }
  match generate_project_with_validator(options, _ => Ok(())) {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  remove_tree(join_path(root, "moon.work"))
  remove_tree(join_path(root, "README.md"))
  let fixes = match
    apply_doctor_fixes({ project_root: root, platforms: [], all: false }) {
    Ok(value) => value
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  inspect(fixes.length() >= 2, content="true")
  inspect(@fs.path_exists(join_path(root, "moon.work")), content="true")
  inspect(@fs.path_exists(join_path(root, "README.md")), content="true")
  remove_tree(root)
}

///|
test "package report includes project inventory" {
  let root = test_temp_path("package-report")
  remove_tree(root)
  let options = { ..test_project_options(["web", "macos"]), target: root }
  match generate_project_with_validator(options, _ => Ok(())) {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  let text = match
    package_report_text({
      project_root: root,
      platforms: [],
      version: None,
      output_dir: None,
      manifest_path: None,
      build: false,
      dry_run: false,
    }) {
    Ok(value) => value
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  inspect(text.contains("module: example/sample_app"), content="true")
  inspect(text.contains("platforms: web, macos"), content="true")
  remove_tree(root)
}

///|
test "package manifest is deterministic and records host release gaps" {
  let root = test_temp_path("package-manifest")
  remove_tree(root)
  let options = { ..test_project_options(["web", "macos"]), target: root }
  match generate_project_with_validator(options, _ => Ok(())) {
    Ok(_) => ()
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  let result = match
    package_manifest_json({
      project_root: root,
      platforms: ["macos"],
      version: Some("2.0.0"),
      output_dir: Some(join_path(root, "dist")),
      manifest_path: None,
      build: false,
      dry_run: true,
    }) {
    Ok(value) => value.stringify(indent=2)
    Err(message) => {
      remove_tree(root)
      fail(message)
    }
  }
  inspect(result.contains("\"status\": \"dry-run\""), content="true")
  inspect(result.contains("\"outputKind\": \"app-bundle\""), content="true")
  inspect(
    result.contains("\"notarization\": \"host-required\""),
    content="true",
  )
  remove_tree(root)
}
