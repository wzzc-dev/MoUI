///|
/// 一个最小但完整的合法 `.studio.json`（ASCII，便于测试里逐字符抽取内嵌 JSON）。
const SAMPLE_PROJECT : String = "{\"format\":\"moui.studio.project\",\"version\":1,\"window\":{\"title\":\"demo\",\"width\":640,\"height\":480},\"controls\":[{\"id\":1,\"kind\":\"button\",\"name\":\"btn\",\"text\":\"go\",\"x\":20,\"y\":20,\"width\":100,\"height\":32,\"items\":[]},{\"id\":2,\"kind\":\"label\",\"name\":\"lbl\",\"text\":\"\",\"x\":20,\"y\":80,\"width\":200,\"height\":32,\"items\":[]}],\"variables\":[],\"handlers\":[{\"control\":\"btn\",\"event\":\"on_click\",\"note\":{\"zh\":\"\",\"en\":\"\"},\"body\":[{\"op\":\"call\",\"name\":\"set_text\",\"args\":[{\"t\":\"var\",\"v\":\"lbl\"},{\"t\":\"str\",\"v\":\"hi\"}]}]}]}"

///|
test "导出的包包含全部必需文件" {
  let files = @export.export_bundle(SAMPLE_PROJECT, "demo")
  let paths = files.map(fn(pair) { pair.0 })
  assert_true(paths.any(fn(path) { path.has_suffix("/moon.mod") }))
  assert_true(paths.any(fn(path) { path.has_suffix("/app/moon.pkg") }))
  assert_true(paths.any(fn(path) { path.has_suffix("/app/project_data.mbt") }))
  assert_true(paths.any(fn(path) { path.has_suffix("/app/runner.mbt") }))
  assert_true(
    paths.any(fn(path) { path.has_suffix("/app/generated_handlers.mbt") }),
  )
  assert_true(
    paths.any(fn(path) { path.has_suffix("/compiled_runtime/moon.pkg") }),
  )
  assert_true(paths.any(fn(path) { path.has_suffix("/domain/ir/moon.pkg") }))
  assert_true(
    paths.any(fn(path) { path.has_suffix("/domain/studio_lang/moon.pkg") }),
  )
  assert_true(paths.any(fn(path) { path.has_suffix("/domain/codec/moon.pkg") }))
  assert_true(paths.any(fn(path) { path.has_suffix("/web_wasm/moon.pkg") }))
  assert_true(paths.any(fn(path) { path.has_suffix("/web_wasm/main.mbt") }))
  assert_true(paths.any(fn(path) { path.has_suffix("/web_wasm/index.html") }))
  assert_true(paths.any(fn(path) { path.has_suffix("/README.md") }))
  assert_true(paths.any(fn(path) { path.has_suffix("/deps.txt") }))
}

///|
test "模块名安全化" {
  assert_eq(@export.sanitize_name("My App"), "My-App")
  assert_eq(@export.sanitize_name("点名册 小工具"), "-")
  assert_eq(@export.sanitize_name(""), "studio-export")
}

///|
/// 导出 moon.mod 必须与 Studio 自己的 moon.mod **同版本**。
///
/// 回归意义：bundle 里的代码全部从 Studio workspace 拷出，只有依赖去注册表
/// 拉。两边版本一错开就会「Studio 编得过、导出项目编不过」——实测 pin 在
/// `moui@0.1.12` 时，那一版自己在新工具链下就过不了类型检查，整条 native
/// GUI 构建失败（用户看到的是「编译成功但运行没有界面」）。
/// 这里逐项钉住版本，漂开即失败。
test "moon.mod 与 Studio 同版本（导出可构建的前提）" {
  let files = @export.export_bundle(SAMPLE_PROJECT, "demo")
  let manifest = bundle_file(files, "/moon.mod")
  assert_true(manifest.contains("wzzc-dev/moui@0.2.0"))
  assert_true(manifest.contains("wzzc-dev/window@0.5.4-0.2.0"))
  assert_true(manifest.contains("wzzc-dev/moui_skia_renderer@0.2.0"))
  assert_true(manifest.contains("wzzc-dev/moui_web_renderer@0.2.0"))
  assert_true(manifest.contains("moonbitlang/async@0.22.4"))
  assert_true(manifest.contains("moonbitlang/x@0.5.5"))
  // 旧线不得回归：0.1.x 自己的源码在新工具链下过不了检查
  assert_false(manifest.contains("moui@0.1"))
  // deps.txt 与 moon.mod 是同一组事实，不能一处新一处旧
  let deps = bundle_file(files, "/deps.txt")
  assert_true(deps.contains("wzzc-dev/moui@0.2.0"))
  assert_true(deps.contains("wzzc-dev/moui_skia_renderer@0.2.0"))
  assert_true(deps.contains("wzzc-dev/moui_web_renderer@0.2.0"))
}

///|
/// 导出 bundle 必须带 **native GUI 入口**（`native_app/`）。
///
/// 回归意义：旧 bundle 只有 `native_smoke`（无头存活探针：打印标记就退出），
/// 编译轨把它当 native 产物交出去，用户运行后**看不到任何窗口**。GUI 入口
/// 是「编译出来的东西能当应用跑」的唯一凭据。
test "bundle ships a native GUI entrypoint, not just a headless probe" {
  let files = @export.export_bundle(SAMPLE_PROJECT, "demo")
  let pkg = bundle_file(files, "/native_app/moon.pkg")
  let main = bundle_file(files, "/native_app/main.mbt")
  // GUI 组合根必须接真实窗口后端 + 渲染器 + 运行时
  assert_true(pkg.contains("wzzc-dev/moui/backend/macos"))
  assert_true(pkg.contains("wzzc-dev/moui_skia_renderer"))
  assert_true(pkg.contains("wzzc-dev/moui/runtime"))
  assert_true(pkg.contains("pkgtype(kind: \"executable\")"))
  // main 用 run_app 开窗（不是打印标记退出）
  assert_true(main.contains("@runtime.run_app"))
  assert_true(main.contains("@macos.entry()"))
  assert_true(main.contains("@render_skia.from_env"))
  assert_false(main.contains("@sys.exit"))
  // 标题与尺寸取自项目，而不是写死
  assert_true(main.contains("@app.window_title()"))
  assert_true(main.contains("@app.window_size()"))
  // 无头探针仍在（它是启动自检的证据），但它是**另一个**包
  assert_true(
    bundle_file(files, "/native_smoke/main.mbt").contains("@sys.exit"),
  )
}

///|
test "README 含构建命令，project_data 内嵌可解析回原 JSON" {
  let files = @export.export_bundle(SAMPLE_PROJECT, "demo")
  let readme = bundle_file(files, "/README.md")
  assert_true(readme.contains("moon build"))
  assert_true(readme.contains("--target wasm-gc"))
  // project_data.mbt 的 #| 字面量逐字节嵌入紧凑 JSON，且可被 json.parse 还原
  let data = bundle_file(files, "/app/project_data.mbt")
  let compact = parse_or_fail(SAMPLE_PROJECT).stringify()
  assert_true(data.contains(compact))
  let reparsed = parse_or_fail(compact)
  assert_eq(reparsed.stringify(), compact)
  // #| 原样输出：反斜杠/引号不被转义（紧凑 JSON 里没有转义换行序列）
  assert_false(data.contains("\\n"))
  assert_true(data.contains("#|"))
}

///|
test "转义覆盖换行与控制字符" {
  let messy = "a\"b\\c\nd\te\rf"
  let escaped = @export.escape_mbt(messy)
  assert_true(escaped.contains("\\n"))
  assert_true(escaped.contains("\\t"))
  assert_true(escaped.contains("\\r"))
}

///|
test "导出包含 Web 宿主页且引用相对 wasm 路径" {
  let files = @export.export_bundle(SAMPLE_PROJECT, "demo")
  let html = bundle_file(files, "/web_wasm/index.html")
  assert_true(html.length() > 0)
  assert_true(html.contains("canvas-host"))
  assert_true(html.contains("<!doctype html>"))
  assert_true(
    html.contains("../.mooncakes/wzzc-dev/moui_web_renderer/runtime.js"),
  )
  assert_false(html.contains("importModule"))
}

///|
test "导出可执行包含 ABI 垫片（Moon 只导出可执行包自身定义的函数）" {
  let files = @export.export_bundle(SAMPLE_PROJECT, "demo")
  let abi = bundle_file(files, "/web_wasm/abi.mbt")
  let pkg = bundle_file(files, "/web_wasm/moon.pkg")
  for
    name in [
      "web_dispatch_event", "web_dispatch_pointer_input", "web_dispatch_semantics_action",
      "web_dispatch_route", "web_complete_async_clipboard_read", "web_complete_async_file_dialog",
    ] {
    assert_true(pkg.contains("\"" + name + "\""))
    assert_true(abi.contains("pub fn " + name + "("))
    assert_true(abi.contains("@web." + name + "("))
  }
}

///|
test "导出应用是可执行的（含领域内核 + runner 驱动）" {
  let files = @export.export_bundle(SAMPLE_PROJECT, "demo")
  // 领域内核 11 个 .mbt（ir 3 + studio_lang 8）+ 编译轨运行时 + runner + project_data
  for
    rel in [
      "domain/ir/ir.mbt", "domain/ir/invariants.mbt", "domain/ir/signature.mbt",
      "domain/studio_lang/aliases.mbt", "domain/studio_lang/errors.mbt", "domain/studio_lang/keywords.mbt",
      "domain/studio_lang/lexer.mbt", "domain/studio_lang/parser.mbt", "domain/studio_lang/printer.mbt",
      "domain/studio_lang/interp.mbt", "domain/studio_lang/semantics.mbt", "domain/codec/codec.mbt",
      "compiled_runtime/runtime.mbt",
    ] {
    let source = bundle_file(files, "/\{rel}")
    assert_true(source.length() > 100)
  }
  let runner = bundle_file(files, "/app/runner.mbt")
  let pkg = bundle_file(files, "/app/moon.pkg")
  let generated = bundle_file(files, "/app/generated_handlers.mbt")
  // runner 走编译轨：分派到生成源码 + compiled_runtime 执行面，
  // 不再有指令流解释器入口。
  assert_true(runner.contains("decode_program("))
  assert_true(runner.contains("studio_dispatch_handler("))
  assert_true(runner.contains("@compiled_runtime.run_handler("))
  assert_true(runner.contains("@compiled_runtime.answer_gate("))
  assert_true(runner.contains("runtime_for_program("))
  assert_false(runner.contains("start_run_stmts("))
  assert_false(runner.contains("run_to_end("))
  // 生成源码是本 bundle 真正编译的一份源码（预览同源）
  assert_true(generated.contains("studio_dispatch_handler"))
  assert_true(generated.contains("@compiled_runtime.Handler("))
  assert_false(generated.contains("start_run_stmts"))
  // TEA 组合根与依赖导入
  assert_true(runner.contains("pub fn program("))
  assert_true(pkg.contains("domain/ir"))
  assert_true(pkg.contains("domain/codec"))
  assert_true(pkg.contains("compiled_runtime"))
  assert_true(pkg.contains("wzzc-dev/moui/views"))
}

///|
/// 按路径后缀取 bundle 文件内容（避免依赖 files 数组顺序）。
fn bundle_file(files : Array[(String, String)], suffix : String) -> String {
  let matches = files.filter(fn(pair) { pair.0.has_suffix(suffix) })
  if matches.is_empty() {
    ""
  } else {
    matches[0].1
  }
}

///|
fn parse_or_fail(source : String) -> Json raise {
  @json.parse(source) catch {
    _ => fail("fixture JSON 应可解析")
  }
}
