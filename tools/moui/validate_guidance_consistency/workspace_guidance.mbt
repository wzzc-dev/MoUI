///|
fn push_no_duplicate_workspace_members(
  path : String,
  members : Array[String],
  failures : Array[String],
) -> Unit {
  let duplicates = duplicate_values(members)
  if !duplicates.is_empty() {
    duplicates.sort()
    failures.push(
      path +
      ": workspace member list contains duplicates: " +
      @tools.comma_join(duplicates),
    )
  }
}

///|
fn push_moon_work_member_checks(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  match read_repo_text(repo_root, "moon.work") {
    Ok(text) => {
      let workspace_members = quoted_strings(text)
      push_no_duplicate_workspace_members(
        "moon.work", workspace_members, failures,
      )
      push_include_check(
        repo_root, "docs/development.md", "repository-facts.md", failures,
      )
      for workspace_member in workspace_members {
        if workspace_member.has_prefix("./examples/") {
          let package_name = workspace_member["./examples/".length():].to_owned()
          let app_package_path = "examples/" + package_name + "/app/moon.pkg"
          let docs_token = if @tools.file_exists(
              @tools.resolve_path(repo_root, app_package_path),
            ) {
            "examples/" + package_name + "/app/"
          } else {
            "examples/" + package_name + "/"
          }
          push_include_check(
            repo_root, "docs/examples.md", docs_token, failures,
          )
        }
      }
    }
    Err(message) => failures.push(message)
  }
}
