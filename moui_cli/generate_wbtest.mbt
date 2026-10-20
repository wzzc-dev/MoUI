///|
fn test_project_options(
  platforms : Array[String],
  bundle_id~ : String? = None,
  template~ : String = "counter",
) -> @plan.ProjectOptions {
  {
    target: "unused",
    id: "sample_app",
    module_name: "example/sample_app",
    title: "Sample App",
    moui_version: @plan.default_moui_dependency_version,
    moui_skia_renderer_version: @plan.default_moui_skia_renderer_dependency_version,
    template,
    platforms,
    bundle_id,
  }
}

///|
fn test_temp_path(label : String) -> String {
  let root = match @env.get_env_var("TMPDIR") {
    Some(value) => value
    None =>
      match @env.get_env_var("TEMP") {
        Some(value) => value
        None => @env.get_env_var("TMP").unwrap_or(".")
      }
  }
  join_path(root, "moui-cli-" + label + "-" + @env.now().to_string())
}

///|
test "generation refuses an existing target without changing it" {
  let target = test_temp_path("existing-target")
  remove_tree(target)
  let options = { ..test_project_options(["web"]), target, }
  let first = generate_project_with_validator(options, _ => Ok(()))
  let marker = join_path(target, "keep.txt")
  @fs.write_string_to_file(marker, "keep") catch {
    _ => {
      remove_tree(target)
      fail("could not write target marker")
    }
  }
  let second = generate_project_with_validator(options, _ => Ok(()))
  let marker_text = @fs.read_file_to_string(marker) catch { _ => "missing" }
  remove_tree(target)
  inspect(first is Ok(_), content="true")
  inspect(second is Err(_), content="true")
  inspect(marker_text, content="keep")
}

///|
test "failed project validation leaves no target directory" {
  let target = test_temp_path("validation-rollback")
  remove_tree(target)
  let options = { ..test_project_options(["web"]), target, }
  let result = generate_project_with_validator(options, _ => {
    Err("injected validation failure")
  })
  let target_exists = @fs.path_exists(target)
  remove_tree(target)
  inspect(result is Err("injected validation failure"), content="true")
  inspect(target_exists, content="false")
}
