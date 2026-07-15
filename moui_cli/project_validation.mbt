///|
#borrow(project_root, log_path)
extern "C" fn validate_generated_project_stage_native(
  project_root : Bytes,
  log_path : Bytes,
  stage : Int,
  append : Int,
) -> Int = "moui_cli_validate_generated_project_stage"

///|
fn project_validation_stage(code : Int) -> String {
  match code % 100 {
    1 => "moon update"
    2 => "moon check --target all --warn-list +73"
    3 => "moon info --target all"
    _ => "project validation"
  }
}

///|
fn run_generated_project_validation_stage(
  project_root : String,
  log_path : String,
  stage : Int,
) -> Result[Unit, String] {
  let code = validate_generated_project_stage_native(
    nul_terminated(project_root),
    nul_terminated(log_path),
    stage,
    if stage == 1 {
      0
    } else {
      1
    },
  )
  if code == 0 {
    Ok(())
  } else {
    let log = @fs.read_file_to_string(log_path) catch {
      _ => "validation log could not be read"
    }
    Err(
      project_validation_stage(code) +
      (if code >= 100 { " could not be started" } else { " failed" }) +
      ":\n" +
      log,
    )
  }
}

///|
fn stage_local_validation_package(
  project_root : String,
  source_root : String,
  package_name : String,
) -> Result[Unit, String] {
  if !path_is_dir(source_root) ||
    !path_is_nonempty_file(join_path(source_root, "moon.mod")) {
    return Err("local validation package is incomplete: " + source_root)
  }
  let files = match collect_template_files(source_root) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let destination = join_path(
    project_root,
    ".mooncakes/wzzc-dev/" + package_name,
  )
  remove_tree(destination)
  write_file_plan_atomic(destination, files)
}

///|
fn stage_local_moui_validation_override(
  project_root : String,
) -> Result[Unit, String] {
  match @env.get_env_var("MOUI_PACKAGE_ROOT") {
    None | Some("") => Ok(())
    Some(root) => {
      match stage_local_validation_package(project_root, root, "moui") {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
      let parent = parent_dir(root)
      for
        entry in [
          ("MOUI_SKIA_ROOT", "moui_skia", "moui_skia"),
          ("MOUI_SUN_ROOT", "moui_sun", "moui_sun"),
        ] {
        let (environment, sibling, package_name) = entry
        let candidate = @env.get_env_var(environment).unwrap_or(
          join_path(parent, sibling),
        )
        if path_is_dir(candidate) {
          match
            stage_local_validation_package(
              project_root, candidate, package_name,
            ) {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
        }
      }
      Ok(())
    }
  }
}

///|
fn validate_generated_project(project_root : String) -> Result[Unit, String] {
  let log_path = join_path(project_root, ".moui-validation.log")
  match run_generated_project_validation_stage(project_root, log_path, 1) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match stage_local_moui_validation_override(project_root) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  for stage in [2, 3] {
    match
      run_generated_project_validation_stage(project_root, log_path, stage) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  @fs.remove_file(log_path) catch {
    _ => ()
  }
  Ok(())
}

///|
fn cleanup_generated_project_validation(project_root : String) -> Unit {
  for name in [".moui-validation.log", ".mooncakes", "_build"] {
    remove_tree(join_path(project_root, name))
  }
}

///|
fn write_validated_project_file_plan(
  target : String,
  files : Array[PlannedFile],
  validate : (String) -> Result[Unit, String],
) -> Result[Array[String], String] {
  let temp = match stage_file_plan(target, files) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match validate(temp) {
    Err(message) => {
      remove_tree(temp)
      return Err(message)
    }
    Ok(_) => ()
  }
  cleanup_generated_project_validation(temp)
  let validated_files = match collect_template_files(temp) {
    Ok(value) => value
    Err(message) => {
      remove_tree(temp)
      return Err(message)
    }
  }
  match commit_staged_file_plan(temp, target) {
    Ok(_) => Ok(validated_files.map(file => file.path))
    Err(message) => Err(message)
  }
}
