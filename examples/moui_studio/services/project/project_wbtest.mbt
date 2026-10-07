///|
/// 解析器与扫描的测试。fixture 一律取**仓库真实清单**——解析器为工程
/// 资源管理器服务,只认自己编的语法是最危险的自我满足;counter 与
/// moui_studio 的实际文件就是最严的语法考卷。

///|
/// examples/counter/moon.mod 原文。
fn counter_mod_source() -> String {
  let text =
    #|name = "examples/counter"
    #|
    #|version = "0.1.0"
    #|
    #|preferred_target = "native"
    #|
    #|import {
    #|  "wzzc-dev/moui@0.2.0",
    #|  "wzzc-dev/window@0.5.4-0.2.0",
    #|  "wzzc-dev/moui_skia_renderer@0.2.0",
    #|  "wzzc-dev/moui_web_renderer@0.2.0",
    #|}
  text
}

///|
/// examples/moui_studio/moon.mod 原文(11 个依赖,含 moonbitlang 生态)。
fn studio_mod_source() -> String {
  let text =
    #|name = "examples/moui_studio"
    #|
    #|version = "0.1.0"
    #|
    #|preferred_target = "native"
    #|
    #|import {
    #|  "wzzc-dev/moui@0.2.0",
    #|  "wzzc-dev/moui_i18n@0.2.0",
    #|  "wzzc-dev/moui_devtools@0.2.0",
    #|  "wzzc-dev/moui_richtext@0.2.0",
    #|  "wzzc-dev/window@0.5.4-0.2.0",
    #|  "wzzc-dev/moui_skia_renderer@0.2.0",
    #|  "wzzc-dev/moui_web_renderer@0.2.0",
    #|  "wzzc-dev/moui_agent@0.2.0",
    #|  "wzzc-dev/moui_agent_mcp@0.2.0",
    #|  "moonbitlang/async@0.22.4",
    #|  "moonbitlang/x@0.5.5",
    #|}
  text
}

///|
/// 最小 import 块(入口包的典型 moon.pkg)。
fn entry_pkg_source() -> String {
  let text =
    #|import {
    #|  "wzzc-dev/moui",
    #|}
  text
}

///|
/// examples/moui_studio/app/moon.pkg 原文(别名 + wbtest 轨)。
fn studio_app_pkg_source() -> String {
  let text =
    #|import {
    #|  "wzzc-dev/moui",
    #|  "wzzc-dev/moui/core",
    #|  "wzzc-dev/moui_i18n" @i18n,
    #|  "wzzc-dev/moui/services",
    #|  "wzzc-dev/moui/views",
    #|  "wzzc-dev/moui/views/style",
    #|  "wzzc-dev/moui/geometry",
    #|  "wzzc-dev/moui/graphics",
    #|  "wzzc-dev/moui/text",
    #|  "wzzc-dev/moui_richtext",
    #|  "wzzc-dev/moui_richtext/code_editor",
    #|  "examples/moui_studio/domain/ir",
    #|  "examples/moui_studio/domain/studio_lang",
    #|  "examples/moui_studio/domain/codec",
    #|  "examples/moui_studio/domain/proposals",
    #|  "examples/moui_studio/domain/blocks",
    #|  "examples/moui_studio/services/export",
    #|  "examples/moui_studio/services/compiled_runtime",
    #|}
    #|
    #|import {
    #|  "wzzc-dev/moui/core",
    #|  "wzzc-dev/moui/runtime",
    #|} for "wbtest"
    #|
    #|supported_targets = "native+wasm-gc"
    #|
    #|options(
    #|  targets: { },
    #|)
  text
}

///|
test "moon.mod 解析 counter 真实清单:键值与版本拆分" {
  match parse_module_manifest(counter_mod_source()) {
    Ok(manifest) => {
      assert_eq(manifest.name, "examples/counter")
      assert_eq(manifest.version, "0.1.0")
      assert_eq(manifest.preferred_target, "native")
      assert_eq(manifest.imports.length(), 4)
      assert_eq(manifest.imports[0].path, "wzzc-dev/moui")
      assert_eq(manifest.imports[0].version, "0.2.0")
      // 双连字符版本段(0.5.4-0.2.0)原样保留
      assert_eq(manifest.imports[1].version, "0.5.4-0.2.0")
    }
    Err(msg) => fail("counter moon.mod 应可解析:\{msg}")
  }
}

///|
test "moon.mod 解析 studio 真实清单:11 个依赖" {
  match parse_module_manifest(studio_mod_source()) {
    Ok(manifest) => {
      assert_eq(manifest.imports.length(), 11)
      assert_eq(manifest.imports[9].path, "moonbitlang/async")
      assert_eq(manifest.imports[9].version, "0.22.4")
    }
    Err(msg) => fail("studio moon.mod 应可解析:\{msg}")
  }
}

///|
test "moon.mod 缺 name 报结构化错误" {
  match parse_module_manifest("version = \"0.1.0\"") {
    Err(msg) =>
      assert_true(msg.contains("name"), msg="报错应提到 name:\{msg}")
    Ok(_) => fail("缺 name 的清单应被拒绝")
  }
}

///|
test "moon.mod import 块未闭合报错" {
  let source =
    #|name = "a/b"
    #|import {
    #|  "wzzc-dev/moui",
  match parse_module_manifest(source) {
    Err(msg) =>
      assert_true(
        msg.contains("未闭合"),
        msg="报错应指出未闭合:\{msg}",
      )
    Ok(_) => fail("未闭合的 import 块应被拒绝")
  }
}

///|
test "moon.mod 容忍注释与未知行" {
  let source =
    #|// 模块说明注释
    #|name = "a/b" // 行尾注释
    #|contributors = "someone"
    #|preferred_target = "native"
  match parse_module_manifest(source) {
    Ok(manifest) => {
      assert_eq(manifest.name, "a/b")
      assert_eq(manifest.preferred_target, "native")
    }
    Err(msg) => fail("注释与未知行应被容忍:\{msg}")
  }
}

///|
test "moon.mod 单行 import 块" {
  let source =
    #|name = "a/b"
    #|import { "wzzc-dev/moui@0.2.0", "wzzc-dev/window@0.5.4" }
  match parse_module_manifest(source) {
    Ok(manifest) => assert_eq(manifest.imports.length(), 2)
    Err(msg) => fail("单行 import 块应可解析:\{msg}")
  }
}

///|
test "moon.pkg 解析 studio app 真实清单:别名与 wbtest 轨" {
  match parse_package_manifest(rel_path="app", studio_app_pkg_source()) {
    Ok(manifest) => {
      assert_eq(manifest.imports.length(), 18)
      assert_eq(manifest.imports[2].path, "wzzc-dev/moui_i18n")
      assert_eq(manifest.imports[2].alias_name, "i18n")
      assert_eq(manifest.wbtest_imports.length(), 2)
      assert_eq(manifest.wbtest_imports[1].path, "wzzc-dev/moui/runtime")
      assert_eq(manifest.test_imports.length(), 0)
      assert_eq(manifest.supported_targets, "native+wasm-gc")
    }
    Err(msg) => fail("studio app moon.pkg 应可解析:\{msg}")
  }
}

///|
test "moon.pkg 解析 counter app 真实清单:test 轨与 supported_targets" {
  let source =
    #|import {
    #|  "wzzc-dev/moui/views",
    #|  "wzzc-dev/moui",
    #|}
    #|
    #|import {
    #|  "wzzc-dev/moui/core",
    #|  "wzzc-dev/moui/runtime",
    #|  "wzzc-dev/moui/geometry",
    #|} for "test"
    #|
    #|supported_targets = "native+wasm-gc+wasm"
    #|
    #|options(
    #|  targets: { },
    #|)
  match parse_package_manifest(rel_path="app", source) {
    Ok(manifest) => {
      assert_eq(manifest.imports.length(), 2)
      assert_eq(manifest.test_imports.length(), 3)
      assert_eq(manifest.test_imports[2].path, "wzzc-dev/moui/geometry")
      assert_eq(manifest.supported_targets, "native+wasm-gc+wasm")
    }
    Err(msg) => fail("counter app moon.pkg 应可解析:\{msg}")
  }
}

///|
test "moon.pkg 单行块 + for 子句同行" {
  let source =
    #|import { "a/b", "c/d" @x } for "wbtest"
  match parse_package_manifest(rel_path="p", source) {
    Ok(manifest) => {
      assert_eq(manifest.imports.length(), 0)
      assert_eq(manifest.wbtest_imports.length(), 2)
      assert_eq(manifest.wbtest_imports[1].alias_name, "x")
    }
    Err(msg) => fail("单行 for 块应可解析:\{msg}")
  }
}

///|
test "moon.pkg 跨行 options 块不吞掉后续键值" {
  let source =
    #|options(
    #|  targets: { },
    #|  warnings: {
    #|    unsupported_feature: "allow",
    #|  },
    #|)
    #|supported_targets = "native"
  match parse_package_manifest(rel_path="p", source) {
    Ok(manifest) => assert_eq(manifest.supported_targets, "native")
    Err(msg) => fail("跨行 options 应被跳过:\{msg}")
  }
}

///|
test "moon.pkg 导入条目畸形报错带包路径" {
  let source =
    #|import {
    #|  foo,
    #|}
  match parse_package_manifest(rel_path="app", source) {
    Err(msg) =>
      assert_true(msg.contains("app"), msg="报错应带包相对路径:\{msg}")
    Ok(_) => fail("畸形条目应被拒绝")
  }
}

///|
test "布局扫描找含 moon.pkg 的目录" {
  let entries = [
    LayoutEntry::{ rel_path: "", is_dir: true, files: ["moon.mod"], },
    LayoutEntry::{
      rel_path: "app",
      is_dir: true,
      files: ["moon.pkg", "app.mbt"],
    },
    LayoutEntry::{
      rel_path: "web_wasm",
      is_dir: true,
      files: ["moon.pkg", "main.mbt", "index.html"],
    },
    LayoutEntry::{ rel_path: "assets", is_dir: true, files: ["logo.svg"], },
    LayoutEntry::{ rel_path: "app/app.mbt", is_dir: false, files: [], },
  ]
  assert_eq(scan_package_paths(entries), ["app", "web_wasm"])
}

///|
test "scan_module 判定 counter 三类入口" {
  match parse_module_manifest(counter_mod_source()) {
    Ok(manifest) => {
      let sources = [
        ("app", plain_two_import_pkg(), true, ["moon.pkg", "app.mbt"]),
        ("web_wasm", entry_pkg_source(), false, ["moon.pkg", "main.mbt"]),
        ("macos_skia", entry_pkg_source(), false, ["moon.pkg", "main.mbt"]),
      ]
      match scan_module(manifest, sources) {
        Ok(scanned) => {
          assert_eq(scanned.web_entry, "web_wasm")
          assert_eq(scanned.native_entry, "macos_skia")
          assert_eq(scanned.program_packages, ["app"])
          assert_eq(scanned.packages.length(), 3)
          assert_eq(scanned.packages[0].has_program, true)
          assert_eq(scanned.packages[0].files, ["moon.pkg", "app.mbt"])
        }
        Err(msg) => fail("counter 扫描应成功:\{msg}")
      }
    }
    Err(msg) => fail("fixture moon.mod 应可解析:\{msg}")
  }
}

///|
test "scan_module native 入口 macos_skia 优先于 native_app" {
  match parse_module_manifest(counter_mod_source()) {
    Ok(manifest) => {
      let sources = [
        ("native_app", entry_pkg_source(), false, ["moon.pkg"]),
        ("macos_skia", entry_pkg_source(), false, ["moon.pkg"]),
      ]
      match scan_module(manifest, sources) {
        Ok(scanned) => assert_eq(scanned.native_entry, "macos_skia")
        Err(msg) => fail("扫描应成功:\{msg}")
      }
    }
    Err(msg) => fail("fixture moon.mod 应可解析:\{msg}")
  }
}

///|
test "scan_module 包清单损坏整次报错且带包路径" {
  match parse_module_manifest(counter_mod_source()) {
    Ok(manifest) => {
      let sources = [("app", "import {\n  foo,\n}", true, [])]
      match scan_module(manifest, sources) {
        Err(msg) =>
          assert_true(msg.contains("app"), msg="报错应带包路径:\{msg}")
        Ok(_) => fail("损坏的包清单应让整次扫描失败")
      }
    }
    Err(msg) => fail("fixture moon.mod 应可解析:\{msg}")
  }
}

///|
test "目录名取最后一段;根包为空" {
  assert_eq(dir_name("domain/blocks"), "blocks")
  assert_eq(dir_name("app"), "app")
  assert_eq(dir_name(""), "")
}

///|
/// 两条普通导入的包 fixture(区别于 entry_pkg_source 的单条,用于条目计数断言)。
fn plain_two_import_pkg() -> String {
  let text =
    #|import {
    #|  "wzzc-dev/moui/views",
    #|  "wzzc-dev/moui",
    #|}
  text
}

///|
/// services/compile_native/moon.pkg 原文:斜杠别名(@x/fs)+ native 轨。
fn compile_native_pkg_source() -> String {
  let text =
    #|import {
    #|  "moonbitlang/async",
    #|  "moonbitlang/async/process",
    #|  "moonbitlang/core/env",
    #|  "moonbitlang/x/fs" @x/fs,
    #|  "examples/moui_studio/services/export",
    #|}
    #|
    #|supported_targets = "native"
    #|
    #|options(
    #|  targets: { },
    #|)
  text
}

///|
test "moon.pkg 斜杠别名:compile_native 真实清单" {
  match
    parse_package_manifest(
      rel_path="services/compile_native",
      compile_native_pkg_source(),
    ) {
    Ok(manifest) => {
      assert_eq(manifest.imports.length(), 5)
      assert_eq(manifest.imports[3].path, "moonbitlang/x/fs")
      assert_eq(manifest.imports[3].alias_name, "x/fs")
      assert_eq(manifest.supported_targets, "native")
    }
    Err(msg) => fail("compile_native moon.pkg 应可解析:\{msg}")
  }
}

///|
test "moon.pkg 容忍 pkgtype 行(executable 包声明)" {
  let source =
    #|pkgtype(kind: "executable")
    #|import {
    #|  "a/b",
    #|}
  match parse_package_manifest(rel_path="main", source) {
    Ok(manifest) => assert_eq(manifest.imports.length(), 1)
    Err(msg) => fail("pkgtype 行应被容忍:\{msg}")
  }
}

///|
/// 内存文件系统:目录 → 条目;路径 → 文本。walker 的完成回调在假任务里
/// 同步触发,整条链可确定性断言。
fn fake_file_services(
  directories : Map[String, Array[@services.DirectoryEntry]],
  texts : Map[String, String],
) -> @services.FileServices {
  @services.FileServices::new(
    list_directory=path => {
      match directories.get(path) {
        Some(entries) =>
          @services.ServiceTask::succeed(key="fake:list", value=entries)
        None =>
          @services.ServiceTask::fail(
            key="fake:list",
            error=@services.ServiceError::new(code="fake:no-dir", message=path),
          )
      }
    },
    read_text=path => {
      match texts.get(path) {
        Some(text) =>
          @services.ServiceTask::succeed(key="fake:read", value=text)
        None =>
          @services.ServiceTask::fail(
            key="fake:read",
            error=@services.ServiceError::new(code="fake:no-file", message=path),
          )
      }
    },
  )
}

///|
fn dir_entry(
  name : String,
  parent : String,
  is_directory : Bool,
) -> @services.DirectoryEntry {
  @services.DirectoryEntry::{ name, path: "\{parent}/\{name}", is_directory, }
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
  directories["/root/web_wasm"] = [
    dir_entry("moon.pkg", "/root/web_wasm", false),
    dir_entry("main.mbt", "/root/web_wasm", false),
  ]
  directories["/root/macos_skia"] = [
    dir_entry("moon.pkg", "/root/macos_skia", false),
    dir_entry("main.mbt", "/root/macos_skia", false),
  ]
  texts["/root/moon.mod"] = counter_mod_source()
  texts["/root/app/moon.pkg"] = plain_two_import_pkg()
  texts["/root/app/app.mbt"] = "pub fn program() -> @moui.Program[Model, Msg] {\n  ignore\n}"
  texts["/root/web_wasm/moon.pkg"] = entry_pkg_source()
  texts["/root/web_wasm/main.mbt"] = "fn main { }"
  texts["/root/macos_skia/moon.pkg"] = entry_pkg_source()
  texts["/root/macos_skia/main.mbt"] = "fn main { }"
  let files = fake_file_services(directories, texts)
  let outcome : Ref[
    @services.ServiceTaskResult[Result[ProjectScanOutput, String]]?,
  ] = Ref(None)
  let _ = walk_root_task(files, "/root").start(result => {
    outcome.val = Some(result)
  })
  let walked = match outcome.val {
    Some(result) => result
    None => fail("walker 未完成")
  }
  match walked {
    Success(Ok(Single(project))) => {
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
    Success(Err(msg)) => fail("walk 不应报域错误:\{msg}")
    Success(Ok(Workspace(_))) => fail("单模块不应走工作区模式")
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
  directories["/root/app"] = [
    dir_entry("moon.pkg", "/root/app", false),
    dir_entry("a.mbt", "/root/app", false),
  ]
  texts["/root/moon.mod"] = counter_mod_source()
  texts["/root/app/moon.pkg"] = entry_pkg_source()
  texts["/root/app/a.mbt"] = ""
  let files = fake_file_services(directories, texts)
  let outcome : Ref[
    @services.ServiceTaskResult[Result[ProjectScanOutput, String]]?,
  ] = Ref(None)
  let _ = walk_root_task(files, "/root").start(result => {
    outcome.val = Some(result)
  })
  match outcome.val {
    Some(Success(Ok(Single(project)))) =>
      // 只访问了根与 app;.git 不产生包条目
      assert_eq(project.package_sources, [
        ("app", entry_pkg_source(), false, ["moon.pkg", "a.mbt"]),
      ])
    Some(Success(Err(msg))) => fail("walk 不应报域错误:\{msg}")
    Some(Success(Ok(Workspace(_)))) => fail("单模块不应走工作区模式")
    Some(Failure(error)) => fail("walk 不应失败:\{error.message}")
    Some(Cancelled) => fail("walk 不应被取消")
    None => fail("walker 未完成")
  }
}

///|
test "walk 无 moon.mod 报域错误" {
  let directories : Map[String, Array[@services.DirectoryEntry]] = Map([])
  let texts : Map[String, String] = Map([])
  directories["/root"] = [dir_entry("readme.md", "/root", false)]
  let files = fake_file_services(directories, texts)
  let outcome : Ref[
    @services.ServiceTaskResult[Result[ProjectScanOutput, String]]?,
  ] = Ref(None)
  let _ = walk_root_task(files, "/root").start(result => {
    outcome.val = Some(result)
  })
  match outcome.val {
    Some(Success(Err(msg))) =>
      assert_true(
        msg.contains("moon.mod"),
        msg="报错应提到 moon.mod:\{msg}",
      )
    Some(Success(Ok(_))) => fail("无 moon.mod 应报域错误")
    Some(Failure(error)) => fail("不应走基础设施失败:\{error.message}")
    Some(Cancelled) => fail("不应被取消")
    None => fail("walker 未完成")
  }
}

///|
/// 本仓库根 moon.work 的缩影(含 `//` 注释行,考注释剥离与成员归一)。
fn repo_work_source() -> String {
  let text =
    #|members = [
    #|  // 框架核心
    #|  "./moui",
    #|  "./moui_richtext",
    #|  // 示例
    #|  "./examples/moui_studio",
    #|  "./examples/momark",
    #|]
  text
}

///|
test "moon.work 解析:真实样例 + 注释剥离 + ./ 归一" {
  match parse_moon_work(repo_work_source()) {
    Ok(members) =>
      assert_eq(members, [
        "moui", "moui_richtext", "examples/moui_studio", "examples/momark",
      ])
    Err(msg) => fail("moon.work 应可解析:\{msg}")
  }
}

///|
test "moon.work 单行块与根自身条目拒绝" {
  match parse_moon_work("members = [ \"./a\", \".\", \"./b\" ]") {
    Ok(members) => assert_eq(members, ["a", "b"])
    Err(msg) => fail("单行块应可解析:\{msg}")
  }
}

///|
test "moon.work 坏清单结构化报错" {
  match parse_moon_work("name = \"x\"") {
    Ok(_) => fail("缺 members 应报错")
    Err(msg) => assert_true(msg.contains("members"), msg~)
  }
  match parse_moon_work("members = [\n  \"./a\",\n") {
    Ok(_) => fail("未闭合块应报错")
    Err(msg) => assert_true(msg.contains("未闭合"), msg~)
  }
}

///|
test "walk 根目录 moon.work → 工作区逐成员扫描,成员失败不炸单" {
  let directories : Map[String, Array[@services.DirectoryEntry]] = Map([])
  let texts : Map[String, String] = Map([])
  directories["/root"] = [
    dir_entry("moon.work", "/root", false),
    dir_entry("good", "/root", true),
    dir_entry("bad", "/root", true),
  ]
  directories["/root/good"] = [
    dir_entry("moon.mod", "/root/good", false),
    dir_entry("app", "/root/good", true),
  ]
  directories["/root/good/app"] = [
    dir_entry("moon.pkg", "/root/good/app", false),
    dir_entry("app.mbt", "/root/good/app", false),
  ]
  // bad 成员:目录存在但没有 moon.mod
  directories["/root/bad"] = [dir_entry("readme.md", "/root/bad", false)]
  texts["/root/moon.work"] = "members = [ \"./good\", \"./bad\" ]"
  texts["/root/good/moon.mod"] = counter_mod_source()
  texts["/root/good/app/moon.pkg"] = plain_two_import_pkg()
  let files = fake_file_services(directories, texts)
  let outcome : Ref[
    @services.ServiceTaskResult[Result[ProjectScanOutput, String]]?,
  ] = Ref(None)
  let _ = walk_root_task(files, "/root").start(result => {
    outcome.val = Some(result)
  })
  match outcome.val {
    Some(Success(Ok(Workspace(scan)))) => {
      assert_eq(scan.root, "/root")
      assert_eq(scan.loaded.length(), 1)
      assert_eq(scan.loaded[0].root, "/root/good")
      assert_eq(scan.failed.length(), 1)
      let (path, reason) = scan.failed[0]
      assert_eq(path, "bad")
      assert_true(reason.contains("moon.mod"), msg=reason)
    }
    Some(Success(Ok(Single(_)))) => fail("moon.work 应走工作区模式")
    Some(Success(Err(msg))) => fail("成员失败不应炸整单:\{msg}")
    Some(Failure(error)) => fail("walk 不应失败:\{error.message}")
    Some(Cancelled) => fail("walk 不应被取消")
    None => fail("walker 未完成")
  }
}

///|
test "walk 工作区模式不深读 .mbt(program 探测关闭)" {
  let directories : Map[String, Array[@services.DirectoryEntry]] = Map([])
  let texts : Map[String, String] = Map([])
  directories["/root"] = [
    dir_entry("moon.work", "/root", false),
    dir_entry("m", "/root", true),
  ]
  directories["/root/m"] = [
    dir_entry("moon.mod", "/root/m", false),
    dir_entry("app", "/root/m", true),
  ]
  directories["/root/m/app"] = [
    dir_entry("moon.pkg", "/root/m/app", false),
    dir_entry("app.mbt", "/root/m/app", false),
  ]
  texts["/root/moon.work"] = "members = [ \"./m\" ]"
  texts["/root/m/moon.mod"] = counter_mod_source()
  texts["/root/m/app/moon.pkg"] = plain_two_import_pkg()
  // 工作区模式不读 .mbt——假 FS 里根本不提供该文件,读到了反而说明越界
  let files = fake_file_services(directories, texts)
  let outcome : Ref[
    @services.ServiceTaskResult[Result[ProjectScanOutput, String]]?,
  ] = Ref(None)
  let _ = walk_root_task(files, "/root").start(result => {
    outcome.val = Some(result)
  })
  match outcome.val {
    Some(Success(Ok(Workspace(scan)))) => {
      assert_eq(scan.loaded.length(), 1)
      assert_eq(scan.loaded[0].package_sources.length(), 1)
      // has_program 恒 false(入口判定只按目录名约定,规模治理)
      assert_eq(scan.loaded[0].package_sources[0].2, false)
    }
    Some(Success(Ok(Single(_)))) => fail("moon.work 应走工作区模式")
    Some(Success(Err(msg))) => fail("不应报域错误:\{msg}")
    Some(Failure(error)) => fail("不应触发 .mbt 读取:\{error.message}")
    Some(Cancelled) => fail("walk 不应被取消")
    None => fail("walker 未完成")
  }
}

///|
test "walk 工作区成员超每成员目录上限 → 成员失败不炸单" {
  let directories : Map[String, Array[@services.DirectoryEntry]] = Map([])
  let texts : Map[String, String] = Map([])
  directories["/root"] = [
    dir_entry("moon.work", "/root", false),
    dir_entry("big", "/root", true),
    dir_entry("ok", "/root", true),
  ]
  // big 成员铺 WALK_MAX_DIRS + 1 个子目录,逼出每成员上限
  let big_entries : Array[@services.DirectoryEntry] = []
  for i in 0..<(WALK_MAX_DIRS + 1) {
    let name = "d\{i}"
    big_entries.push(dir_entry(name, "/root/big", true))
    directories["/root/big/\{name}"] = []
  }
  directories["/root/big"] = big_entries
  directories["/root/ok"] = [dir_entry("moon.mod", "/root/ok", false)]
  texts["/root/moon.work"] = "members = [ \"./big\", \"./ok\" ]"
  texts["/root/ok/moon.mod"] = counter_mod_source()
  let files = fake_file_services(directories, texts)
  let outcome : Ref[
    @services.ServiceTaskResult[Result[ProjectScanOutput, String]]?,
  ] = Ref(None)
  let _ = walk_root_task(files, "/root").start(result => {
    outcome.val = Some(result)
  })
  match outcome.val {
    Some(Success(Ok(Workspace(scan)))) => {
      assert_eq(scan.loaded.length(), 1)
      assert_eq(scan.loaded[0].root, "/root/ok")
      assert_eq(scan.failed.length(), 1)
      let (path, reason) = scan.failed[0]
      assert_eq(path, "big")
      assert_true(reason.contains("目录数超过"), msg=reason)
    }
    Some(Success(Ok(Single(_)))) => fail("moon.work 应走工作区模式")
    Some(Success(Err(msg))) => fail("成员超限不应炸整单:\{msg}")
    Some(Failure(error)) => fail("walk 不应失败:\{error.message}")
    Some(Cancelled) => fail("walk 不应被取消")
    None => fail("walker 未完成")
  }
}
