///|
test "atomic directory move never replaces an existing target" {
  let root = test_temp_path("rename-no-replace")
  let source = join_path(root, "source")
  let destination = join_path(root, "destination")
  remove_tree(root)
  match mkdir_p(source) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match mkdir_p(destination) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let result = rename_path(source, destination)
  let source_remains = @fs.path_exists(source)
  let destination_remains = @fs.path_exists(destination)
  remove_tree(root)
  inspect(result is Err(_), content="true")
  inspect(source_remains, content="true")
  inspect(destination_remains, content="true")
}

///|
test "executable probe rejects an ordinary data file" {
  let root = test_temp_path("executable-probe")
  let path = join_path(root, "not-a-command")
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  @fs.write_string_to_file(path, "data") catch {
    _ => {
      remove_tree(root)
      fail("could not write executable probe fixture")
    }
  }
  let executable = path_is_executable(path)
  remove_tree(root)
  inspect(executable, content="false")
}

///|
test "atomic generation supports Unicode project paths" {
  let root = test_temp_path("unicode-path")
  let target = join_path(root, "项目")
  remove_tree(root)
  let result = write_file_plan_atomic(target, [
    text_file("目录/说明.txt", "ok"),
  ])
  let content = @fs.read_file_to_string(join_path(target, "目录/说明.txt")) catch {
    _ => "missing"
  }
  remove_tree(root)
  inspect(result is Ok(_), content="true")
  inspect(content, content="ok\n")
}

///|
test "project search roots include the nearest MoonBit workspace" {
  let root = test_temp_path("workspace-search")
  let project = join_path(root, "examples/sample")
  remove_tree(root)
  match mkdir_p(project) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  @fs.write_string_to_file(join_path(root, "moon.work"), "members = []\n") catch {
    _ => {
      remove_tree(root)
      fail("could not write workspace marker fixture")
    }
  }
  let roots = project_search_roots(project)
  remove_tree(root)
  inspect(roots.length(), content="2")
  inspect(roots[0], content=project)
  inspect(roots[1], content=root)
}
