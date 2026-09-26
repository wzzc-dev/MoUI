///|
/// 把 Studio app 包的领域内核源码同步进 `services/export/kernel_sources.mbt`
/// 与 `services/export/runner_template.mbt`。
///
/// 导出的可执行应用需要自带一份内核（导出项目只能依赖已发布模块，不能 import
/// `examples/moblocks_studio/app`）。本工具把 5 个内核文件 + runner 模板逐字节
/// 读入并写成常量；`export_test` 的漂移测试保证「改了内核忘同步」会失败。
///
/// 用法：在仓库根目录
///   moon run examples/moblocks_studio/tools/sync_kernel --target native
///   moon run examples/moblocks_studio/tools/sync_kernel --target native -- --check

///|
/// 参与导出的内核文件（顺序即写入顺序）。
fn kernel_files() -> Array[(String, String)] {
  [
    ("kernel_block_graph", "examples/moblocks_studio/app/block_graph.mbt"),
    ("kernel_block_catalog", "examples/moblocks_studio/app/block_catalog.mbt"),
    (
      "kernel_graph_validation", "examples/moblocks_studio/app/graph_validation.mbt",
    ),
    (
      "kernel_execution_reducer", "examples/moblocks_studio/app/execution_reducer.mbt",
    ),
    ("kernel_project_codec", "examples/moblocks_studio/app/project_codec.mbt"),
  ]
}

///|
/// 导出的可执行 runner 模板（不在任何 package 内，仅作为文本同步）。
fn runner_template_path() -> String {
  "examples/moblocks_studio/tools/export_runner_template/runner.mbt"
}

///|

///|

///|
/// 把一行源码包装成 `#|` 前缀的多行字符串行。
/// 注意：本工具链的 `#|` 多行串**不做插值**（`\{x}` 原样输出），所以源码行
/// 必须原样嵌入——任何额外转义都会把内核里的插值语法写成字面量，静默改变语义
/// （历史上就这样让校验器的占用键全部退化成同一个字符串）。
fn embed_line(line : String) -> String {
  "    #|\{line}"
}

///|
/// 生成一个返回源码的 pub 函数。
fn constant_block(name : String, source : String) -> String {
  let mut out = "///|\npub fn \{name}() -> String {\n  let source =\n"
  for view in source.split("\n") {
    out = out + embed_line(view.to_owned()) + "\n"
  }
  out + "  source\n}\n"
}

///|

///|
/// 单个内核常量的输出路径（与源文件同名，便于对照）。
fn constant_output(name : String) -> String {
  "examples/moblocks_studio/services/export/kernel_\{name}.mbt"
}

///|
fn kernel_output_text(name : String, source : String) -> String raise {
  "///|\n/// 导出的领域内核源码：`app/\{name}.mbt` 的逐字节副本。\n/// 由 tools/sync_kernel 生成，勿手改；与源文件不一致时\n/// `tools/sync_kernel -- --check` 会报 DRIFT。\n\n" +
  constant_block("kernel_\{name}", source)
}

///|
fn runner_output_text() -> String raise {
  "///|\n/// 导出的可执行 runner 源码（由 tools/sync_kernel 生成，勿手改）。\n/// 模板位于 tools/export_runner_template/runner.mbt；\n/// 模板改动不同步时 `--check` 会报 DRIFT。\n\n" +
  constant_block(
    "runner_source",
    @fs.read_file_to_string(runner_template_path()),
  )
}

///|
fn all_outputs() -> Array[(String, String)] raise {
  let out : Array[(String, String)] = []
  for pair in kernel_files() {
    let name = pair.0.replace(old="kernel_", new="")
    out.push(
      (
        constant_output(name),
        kernel_output_text(name, @fs.read_file_to_string(pair.1)),
      ),
    )
  }
  out.push((constant_output("runner"), runner_output_text()))
  out
}

///|
fn check_mode() -> Int raise {
  let mut ok = true
  for pair in all_outputs() {
    let current = @fs.read_file_to_string(pair.0) catch {
      _ => {
        println("MISSING \{pair.0}（尚未同步）")
        ok = false
        continue
      }
    }
    if current != pair.1 {
      println(
        "DRIFT \{pair.0}：与源文件不一致。请运行 moon run examples/moblocks_studio/tools/sync_kernel --target native",
      )
      ok = false
    }
  }
  if ok {
    println("export kernel sync: current")
    0
  } else {
    1
  }
}

///|
fn write_mode() -> Int raise {
  let mut count = 0
  for pair in all_outputs() {
    @fs.write_string_to_file(pair.0, pair.1)
    count = count + 1
  }
  println("synced: \{count} files")
  0
}

///|
fn main {
  let args = @env.args()
  let code = try {
    if args.length() > 1 && args[1] == "--check" {
      check_mode()
    } else {
      write_mode()
    }
  } catch {
    err => {
      println("sync failed: \{err}")
      1
    }
  }
  if code != 0 {
    @sys.exit(code)
  }
}
