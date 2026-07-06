///|
fn workspace_members_from_member_block(
  text : String,
) -> Result[Array[String], String] {
  let marker = "members = ["
  match text.find(marker) {
    Some(start) => {
      let block_start = start + marker.length()
      match text[block_start:].find("]") {
        Some(end_offset) =>
          Ok(
            quoted_strings(
              text[block_start:block_start + end_offset].to_owned(),
            ),
          )
        None => Err("missing closing ']' for members block")
      }
    }
    None => Err("missing members block")
  }
}

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
fn push_workspace_member_list_match(
  path : String,
  expected : Array[String],
  actual : Array[String],
  failures : Array[String],
) -> Unit {
  let missing : Array[String] = []
  for workspace_member in expected {
    if !actual.contains(workspace_member) {
      missing.push(workspace_member)
    }
  }
  if !missing.is_empty() {
    missing.sort()
    failures.push(
      path + ": workspace member list is missing: " + @tools.comma_join(missing),
    )
  }
  let stale : Array[String] = []
  for workspace_member in actual {
    if !expected.contains(workspace_member) {
      stale.push(workspace_member)
    }
  }
  if !stale.is_empty() {
    stale.sort()
    failures.push(
      path +
      ": workspace member list has stale entries: " +
      @tools.comma_join(stale),
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
      match read_repo_text(repo_root, "docs/development.md") {
        Ok(docs_text) =>
          match workspace_members_from_member_block(docs_text) {
            Ok(documented_members) => {
              push_no_duplicate_workspace_members(
                "docs/development.md", documented_members, failures,
              )
              push_workspace_member_list_match(
                "docs/development.md", workspace_members, documented_members, failures,
              )
            }
            Err(message) => failures.push("docs/development.md: " + message)
          }
        Err(message) => failures.push(message)
      }
      for workspace_member in workspace_members {
        push_include_check(
          repo_root, "docs/development.md", workspace_member, failures,
        )
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
