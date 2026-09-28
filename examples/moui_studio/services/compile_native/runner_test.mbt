///|
/// compile_native 测试：
/// 1) bundle 落盘布局（工作区外真导出的第一现场）；
/// 2) 失败注入 → `moon check` 失败 → 结构化诊断（文件/行/列/错误码）；
/// 3) 成功路径依赖真工具链（耗时数十秒），由 `sh scripts/studio-export-smoke.sh`
///    与 macOS 入口 live 覆盖，单测不重复跑重活。

///|
/// 最小合法项目（与 export_test 的样例同构）。
const TEST_PROJECT : String = "{\"format\":\"moui.studio.project\",\"version\":1,\"window\":{\"title\":\"demo\",\"width\":640,\"height\":480},\"controls\":[{\"id\":1,\"kind\":\"button\",\"name\":\"btn\",\"text\":\"go\",\"x\":20,\"y\":20,\"width\":100,\"height\":32,\"items\":[]},{\"id\":2,\"kind\":\"label\",\"name\":\"lbl\",\"text\":\"\",\"x\":20,\"y\":80,\"width\":200,\"height\":32,\"items\":[]}],\"variables\":[],\"handlers\":[{\"control\":\"btn\",\"event\":\"on_click\",\"note\":{\"zh\":\"\",\"en\":\"\"},\"body\":[{\"op\":\"call\",\"name\":\"set_text\",\"args\":[{\"t\":\"var\",\"v\":\"lbl\"},{\"t\":\"str\",\"v\":\"hi\"}]}]}]}"

///|
fn test_root(name : String) -> String {
  "\{@compile_native.default_work_root()}-test/\{name}"
}

///|
fn parent_of(path : String) -> String {
  match path.rev_find("/") {
    Some(index) => if index == 0 { "/" } else { path[:index].to_owned() }
    None => "."
  }
}

///|
fn ensure_test_dir(path : String) -> Unit {
  if @x/fs.path_exists(path) {
    return
  }
  let parent = parent_of(path)
  if parent != "." && parent != "" {
    ensure_test_dir(parent)
  }
  @x/fs.create_dir(path) catch {
    _ => ()
  }
}

///|
fn write_bundle(
  root : String,
  project_json : String,
  app_name : String,
) -> Unit {
  for pair in @export.export_bundle(project_json, app_name) {
    let path = "\{root}/\{pair.0}"
    ensure_test_dir(parent_of(path))
    @x/fs.write_string_to_file(path, pair.1) catch {
      _ => ()
    }
  }
}

///|
fn clean_test_tree(path : String) -> Unit {
  if !@x/fs.path_exists(path) {
    return
  }
  let entries = @x/fs.read_dir(path) catch { _ => return }
  for name in entries {
    let child = "\{path}/\{name}"
    let is_dir = @x/fs.is_dir(child) catch { _ => false }
    if is_dir {
      clean_test_tree(child)
    } else {
      @x/fs.remove_file(child) catch {
        _ => ()
      }
    }
  }
  @x/fs.remove_dir(path) catch {
    _ => ()
  }
}

///|
test "export_bundle 落盘布局可直接构建（app/generated_handlers.mbt 在列）" {
  let root = test_root("layout")
  clean_test_tree(root)
  write_bundle(root, TEST_PROJECT, "probe")
  let generated = "\{root}/probe/app/generated_handlers.mbt"
  assert_true(@x/fs.path_exists(generated))
  assert_true(@x/fs.path_exists("\{root}/probe/moon.mod"))
  assert_true(@x/fs.path_exists("\{root}/probe/native_smoke/main.mbt"))
  let source = @x/fs.read_file_to_string(generated) catch { _ => "" }
  assert_true(source.contains("studio_dispatch_handler"))
  assert_true(source.contains("set_text"))
  clean_test_tree(root)
}

///|
async test "注入类型错误 → moon check 失败 → 结构化诊断可映射回生成源码" {
  let root = test_root("failure")
  clean_test_tree(root)
  write_bundle(root, TEST_PROJECT, "probe")
  @x/fs.write_string_to_file(
    "\{root}/probe/app/injected_error.mbt",
    "///|\nfn injected_broken() -> Unit {\n  let x : Int = \"not an int\"\n  ignore(x)\n}\n",
  ) catch {
    _ => ()
  }
  let report = @compile_native.compile_bundle_at("\{root}/probe")
  match report {
    Err(error) => fail("执行器不应自行失败：\{error}")
    Ok(report) => {
      assert_false(report.ok)
      assert_eq(report.target, "native")
      let errors = report.errors()
      assert_true(errors.length() > 0)
      let first = errors[0]
      assert_true(first.code != "")
      assert_true(first.file.has_suffix("injected_error.mbt"))
      assert_eq(first.line, 3)
      assert_true(first.column > 0)
    }
  }
  clean_test_tree(root)
}
