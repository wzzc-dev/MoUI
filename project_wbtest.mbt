
///|
/// 内存文件系统:目录 → 条目;路径 → 文本。walker 的完成回调在假任务里
/// 同步触发,整条链可确定性断言。
fn fake_file_services(
  directories : Map[String, Array[@services.DirectoryEntry]],
  texts : Map[String, String],
) -> FileServices {
  FileServices::new(
    list_directory=path =>
      match directories.get(path) {
        Some(entries) => .ServiceTask::succeed(key="fake:list", value=entries)
        None => .ServiceTask::fail(
          key="fake:list",
          error=@services.ServiceError::new(code="fake:no-dir", message=path),
        )
      },
    read_text=path =>
      match texts.get(path) {
        Some(text) => .ServiceTask::succeed(key="fake:read", value=text)
        None => .ServiceTask::fail(
          key="fake:read",
          error=@services.ServiceError::new(code="fake:no-file", message=path),
        )
      },
  )
}

///|
fn dir_entry(name : String, parent : String, is_directory : Bool) -> @services.DirectoryEntry {
  @services.DirectoryEntry::{ name, path: "\{parent}/\{name}", is_directory }
}

///|
test "walk 走完 counter 形目录树并喂饱纯扫描(全链)" {
  let directories : Map[String, Array[@services.DirectoryEntry]] = Map([])
  let texts : Map[String, String] = Map([])
  directories["/root"] = [
    dir_entry("app", "/root", true),
    dir_entry("web_wasm", "/root", true),
    dir_entry("macos_skia", "/root", true),
    dir_entry("moon.mod", "/root", false),
  ]
  directories["/root/app"] = [
    dir_entry("moon.pkg", "/root/app", false),
    dir_entry("app.mbt", "/root/app", false),
  ]
  directories["/root/web_wasm"] = [dir_entry("moon.pkg", "/root/web_wasm", false), dir_entry("main.mbt", "/root/web_wasm", false)]
  directories["/root/macos_skia"] = [dir_entry("moon.pkg", "/root/macos_skia", false), dir_entry("main.mbt", "/root/macos_skia", false)]
  texts["/root/moon.mod"] = counter_mod_source()
  texts["/root/app/moon.pkg"] = plain_two_import_pkg()
  texts["/root/app/app.mbt"] = "pub fn program() -> @moui.Program[Model, Msg] {\n  ignore\n}"
  texts["/root/web_wasm/moon.pkg"] = entry_pkg_source()
  texts["/root/web_wasm/main.mbt"] = "fn main { }"
  texts["/root/macos_skia/moon.pkg"] = entry_pkg_source()
  texts["/root/macos_skia/main.mbt"] = "fn main { }"
  let files = fake_file_services(directories, texts)
  let outcome : @services.ServiceTaskResult[Result[ProjectSource, String]]? = Ref(None)
  walk_project_task(files, "/root").start(result => {
    outcome.val = Some(result)
  })
  let walked = match outcome.val {
    Some(result) => result
    None => fail("walker 未完成")
  }
  match walked {
    Success(project) => {
      assert_eq(project.root, "/root")
      assert_eq(project.package_sources.length(), 3)
      // app 包:清单文本 + program 探测命中
      assert_eq(project.package_sources[0].0, "app")
      assert_eq(project.package_sources[0].2, true)
      // 全链:parse + scan 得到入口判定
      match parse_module_manifest(project.module_manifest) {
        Ok(manifest) =>
          match scan_module(manifest, project.package_sources) {
            Ok(scanned) => {
              assert_eq(scanned.web_entry, "web_wasm")
              assert_eq(scanned.native_entry, "macos_skia")
              assert_eq(scanned.program_packages, ["app"])
            }
            Err(msg) => fail("扫描应成功:\{msg}")
          }
        Err(msg) => fail("moon.mod 应可解析:\{msg}")
      }
    }
    Failure(error) => fail("walk 不应失败:\{error.message}")
    Cancelled => fail("walk 不应被取消")
  }
}

///|
test "walk 跳过 .git 等构建目录" {
  let directories : Map[String, Array[@services.DirectoryEntry]] = Map([])
  let texts : Map[String, String] = Map([])
  directories["/root"] = [
    dir_entry(".git", "/root", true),
    dir_entry("app", "/root", true),
    dir_entry("moon.mod", "/root", false),
  ]
  directories["/root/.git"] = [dir_entry("config", "/root/.git", false)]
  directories["/root/app"] = [dir_entry("moon.pkg", "/root/app", false), dir_entry("a.mbt", "/root/app", false)]
  texts["/root/moon.mod"] = counter_mod_source()
  texts["/root/app/moon.pkg"] = entry_pkg_source()
  texts["/root/app/a.mbt"] = ""
  let files = fake_file_services(directories, texts)
  let outcome : @services.ServiceTaskResult[Result[ProjectSource, String]]? = Ref(None)
  walk_project_task(files, "/root").start(result => {
    outcome.val = Some(result)
  })
  match outcome.val {
    Some(Success(project)) =>
      // 只访问了根与 app;.git 不产生条目
      assert_eq(project.package_sources, [("app", entry_pkg_source(), false)])
    Some(Failure(error)) => fail("walk 不应失败:\{error.message}")
    Some(Cancelled) => fail("walk 不应被取消")
    None => fail("walker 未完成")
  }
}

///|
test "walk 无 moon.mod 报结构化错误" {
  let directories : Map[String, Array[@services.DirectoryEntry]] = Map([])
  let texts : Map[String, String] = Map([])
  directories["/root"] = [dir_entry("readme.md", "/root", false)]
  let files = fake_file_services(directories, texts)
  let outcome : @services.ServiceTaskResult[Result[ProjectSource, String]]? = Ref(None)
  walk_project_task(files, "/root").start(result => {
    outcome.val = Some(result)
  })
  match outcome.val {
    Some(Failure(error)) => assert_true(
      error.message.contains("moon.mod"),
      msg="报错应提到 moon.mod:\{error.message}",
    )
    Some(Success(_)) => fail("无 moon.mod 应失败")
    Some(Cancelled) => fail("不应被取消")
    None => fail("walker 未完成")
  }
}
