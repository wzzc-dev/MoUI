///|
test "导出的包包含全部必需文件" {
  let source = "{\"metadata\":{\"id\":\"p\",\"name\":\"对话机器人\",\"revision\":1},\"format\":\"moblocks.project\",\"version\":1,\"graph\":{\"nodes\":[],\"edges\":[],\"next_id\":1},\"viewport\":{\"x\":0.0,\"y\":0.0,\"zoom\":1.0},\"policy\":{\"require_confirmation\":true,\"allow_external_submit\":false,\"allow_file_read\":true,\"allow_file_write\":false},\"template_origin\":\"\"}"
  let project = parse_or_fail(source)
  let files = export_bundle(project.stringify(), "对话机器人")
  let paths = files.map(fn(pair) { pair.0 })
  assert_true(paths.any(fn(path) { path.ends_with("/moon.mod") }))
  assert_true(paths.any(fn(path) { path.ends_with("/app/moon.pkg") }))
  assert_true(paths.any(fn(path) { path.ends_with("/app/project_data.mbt") }))
  assert_true(paths.any(fn(path) { path.ends_with("/app/runner.mbt") }))
  assert_true(paths.any(fn(path) { path.ends_with("/web_wasm/moon.pkg") }))
  assert_true(paths.any(fn(path) { path.ends_with("/web_wasm/main.mbt") }))
  assert_true(paths.any(fn(path) { path.ends_with("/README.md") }))
  assert_true(paths.any(fn(path) { path.ends_with("/deps.txt") }))
}

///|
test "模块名安全化与项目数据转义" {
  assert_eq(sanitize_name("对话机器人"), "-")
  assert_eq(sanitize_name("My App"), "My-App")
  assert_eq(escape_mbt("a\"b\\c"), "a\\\"b\\\\c")
}

///|
test "README 含构建命令，project_data 可解析回原 JSON" {
  let source2 = "{\"metadata\":{\"id\":\"p\",\"name\":\"n\",\"revision\":1},\"format\":\"moblocks.project\",\"version\":1,\"graph\":{\"nodes\":[],\"edges\":[]},\"viewport\":{\"x\":0.0,\"y\":0.0,\"zoom\":1.0},\"policy\":{\"require_confirmation\":true,\"allow_external_submit\":false,\"allow_file_read\":true,\"allow_file_write\":false},\"template_origin\":\"\"}"
  let project = parse_or_fail(source2)
  let files = export_bundle(project.stringify(), "n")
  let readme = bundle_file(files, "/README.md")
  assert_true(readme.contains("moon build"))
  assert_true(readme.contains("--target wasm-gc"))
  // project_data.mbt 中的字符串常量可被 json.parse 还原
  let data = bundle_file(files, "/app/project_data.mbt")
  // 跳过源码外壳，定位转义 JSON 的起点：`{` 紧跟转义引号 `"`
  let mut start = 0
  let mut i = 0
  while i < data.length() && start == 0 {
    if data[i] == '{' && i + 1 < data.length() && data[i + 1] == '\\' {
      start = i
    }
    i = i + 1
  }
  let inner = data.exact_view(start~).to_owned()
  // project_data.mbt 结构：...\n  "<json>"\n}\n → 去掉尾部 4 个字符，再反转义
  let escaped = inner.exact_view(start=0, end=inner.length() - 4).to_owned()
  let parsed = parse_or_fail(unescape_mbt(escaped))
  assert_eq(parsed.stringify(), project.stringify())
}

///|
fn parse_or_fail(source : String) -> Json raise {
  @json.parse(source) catch {
    _ => fail("fixture JSON 应可解析")
  }
}

///|
/// 按路径后缀取 bundle 文件内容（避免依赖 files 数组顺序）。
/// 缺文件时返回空串，后续内容断言会明确指出问题。
fn bundle_file(files : Array[(String, String)], suffix : String) -> String {
  let matches = files.filter(fn(pair) { pair.0.has_suffix(suffix) })
  if matches.is_empty() {
    ""
  } else {
    matches[0].1
  }
}

///|
/// 反转义 MoonBit 字符串字面量（与 export.escape_mbt 对偶，仅测试用）。
fn unescape_mbt(text : String) -> String {
  let mut out = ""
  let mut escaped = false
  for c in text {
    if escaped {
      out = out + c.to_string()
      escaped = false
    } else if c == '\\' {
      escaped = true
    } else {
      out = out + c.to_string()
    }
  }
  out
}

///|
test "转义覆盖换行与控制字符，紧凑化 JSON 无换行" {
  let messy = "a\"b\\c\nd\te\rf"
  let escaped = escape_mbt(messy)
  assert_true(escaped.contains("\\n"))
  assert_true(escaped.contains("\\t"))
  assert_true(escaped.contains("\\r"))
  // 多行 JSON 经 project_data_mbt 紧凑化后为单行字面量（无裸换行断串）
  let multiline = "{\n  \"metadata\": { \"name\": \"n\" },\n  \"format\": \"moblocks.project\"\n}"
  let data = project_data_mbt(multiline)
  let mut newlines = 0
  for c in data {
    if c == '\n' {
      newlines = newlines + 1
    }
  }
  // 紧凑化后 JSON 字面量单行；整段源码的换行只来自外壳（<= 5）
  assert_true(newlines <= 5)
  assert_true(data.contains("moblocks.project"))
}

///|
test "导出包含 Web 宿主页且引用相对 wasm 路径" {
  let files = export_bundle("{}", "n")
  let html = files.filter(fn(pair) { pair.0.has_suffix("index.html") })
  assert_eq(html.length(), 1)
  let page = html[0].1
  assert_true(page.contains("canvas-host"))
  assert_true(page.contains("<!doctype html>"))
  // 目录契约：runtime.js 从 bundle 自己的 .mooncakes 依赖目录加载
  // （moon build 后存在，版本与 moon.mod 固定的一致）；页面不要再注入
  // importModule 之类的假导入（wasm 只导入 window_web/webgpu）。
  assert_true(
    page.contains("../.mooncakes/wzzc-dev/moui_web_renderer/runtime.js"),
  )
  assert_false(page.contains("from \"../moui_web_renderer/runtime.js\""))
  assert_false(page.contains("importModule"))
}

///|
test "导出的 Web 依赖在 moon.mod 中固定（.mooncakes 契约的前提）" {
  let files = export_bundle("{}", "n")
  let manifest = bundle_file(files, "/moon.mod")
  // index.html 的运行时闭包来自这两个依赖；缺一个则页面停在 Loading
  assert_true(manifest.contains("wzzc-dev/moui@"))
  assert_true(manifest.contains("wzzc-dev/moui_web_renderer@"))
}

///|
test "导出可执行包含 ABI 垫片（Moon 只导出可执行包自身定义的函数）" {
  let files = export_bundle("{}", "n")
  let abi = bundle_file(files, "/web_wasm/abi.mbt")
  let pkg = bundle_file(files, "/web_wasm/moon.pkg")
  // link.exports 列出的宿主入口必须在可执行包内定义，否则链接时被 DCE
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
  let files = export_bundle("{}", "n")
  // 领域内核 5 个文件
  for
    name in [
      "block_graph", "block_catalog", "graph_validation", "execution_reducer", "project_codec",
    ] {
    let source = bundle_file(files, "/app/\{name}.mbt")
    assert_true(source.length() > 100)
  }
  let runner = bundle_file(files, "/app/runner.mbt")
  let pkg = bundle_file(files, "/app/moon.pkg")
  // runner 驱动执行引擎的关键调用
  assert_true(runner.contains("start_execution("))
  assert_true(runner.contains("apply_exec_event("))
  assert_true(runner.contains("validate_graph("))
  // 外发闸门是真实按钮交互
  assert_true(runner.contains("确认外发"))
  assert_true(runner.contains("ConfirmExternal"))
  // TEA 组合根与依赖导入
  assert_true(runner.contains("pub fn program("))
  assert_true(pkg.contains("wzzc-dev/moui/views"))
}
