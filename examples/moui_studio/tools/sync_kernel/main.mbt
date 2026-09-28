///|
/// 把 MoUI Studio domain 包的领域内核源码同步进 `services/export/` 的
/// `kernel_ir.mbt` / `kernel_studio_lang.mbt` / `kernel_codec.mbt` 常量文件，
/// 并把 runner 模板同步进 `kernel_runner.mbt`。
///
/// 导出的可执行应用需要自带一份内核（导出项目只能依赖已发布模块，不能 import
/// `examples/moui_studio/domain/*`）。本工具把 3 个领域包的全部 .mbt + runner 模板逐字节
/// 读入并写成常量（每个源文件一个常量函数）；`export_test` 的漂移测试保证
/// 「改了内核忘同步」会失败。
///
/// 用法：在仓库根目录
///   moon run examples/moui_studio/tools/sync_kernel --target native
///   moon run examples/moui_studio/tools/sync_kernel --target native -- --check

///|
/// 参与导出的内核文件（单一事实来源，顺序即写入顺序）。
/// 输出文件名 → [(常量名, 源文件相对路径)]。
fn kernel_files() -> Array[(String, Array[(String, String)])] {
  [
    (
      "kernel_ir",
      [
        ("kernel_ir_mbt", "examples/moui_studio/domain/ir/ir.mbt"),
        ("kernel_ir_invariants_mbt", "examples/moui_studio/domain/ir/invariants.mbt"),
        ("kernel_ir_signature_mbt", "examples/moui_studio/domain/ir/signature.mbt"),
      ],
    ),
    (
      "kernel_studio_lang",
      [
        (
          "kernel_studio_lang_aliases_mbt", "examples/moui_studio/domain/studio_lang/aliases.mbt",
        ),
        (
          "kernel_studio_lang_errors_mbt", "examples/moui_studio/domain/studio_lang/errors.mbt",
        ),
        (
          "kernel_studio_lang_keywords_mbt", "examples/moui_studio/domain/studio_lang/keywords.mbt",
        ),
        (
          "kernel_studio_lang_lexer_mbt", "examples/moui_studio/domain/studio_lang/lexer.mbt",
        ),
        (
          "kernel_studio_lang_parser_mbt", "examples/moui_studio/domain/studio_lang/parser.mbt",
        ),
      ],
    ),
    (
      "kernel_studio_lang_rt",
      [
        (
          "kernel_studio_lang_printer_mbt", "examples/moui_studio/domain/studio_lang/printer.mbt",
        ),
        (
          "kernel_studio_lang_interp_mbt", "examples/moui_studio/domain/studio_lang/interp.mbt",
        ),
        (
          "kernel_studio_lang_semantics_mbt", "examples/moui_studio/domain/studio_lang/semantics.mbt",
        ),
      ],
    ),
    (
      "kernel_codec",
      [("kernel_codec_mbt", "examples/moui_studio/domain/codec/codec.mbt")],
    ),
  ]
}

///|
/// 导出的可执行 runner 模板（不在任何 package 内，仅作为文本同步）。
fn runner_template_path() -> String {
  "examples/moui_studio/tools/export_runner_template/runner.mbt"
}

///|
/// 把一行源码包装成 `#|` 前缀的多行字符串行。
/// 注意：本工具链的 `#|` 多行串**不做插值**（`\{x}` 原样输出），所以源码行
/// 必须原样嵌入——任何额外转义都会把内核里的插值语法写成字面量，静默改变语义
/// （历史上就这样让校验器的占用键全部退化成同一个字符串）。
fn embed_line(line : String) -> String {
  "    #|\{line}"
}

///|
/// 生成一个返回源码的 pub 函数。前置一个空行，使多个常量相邻时也符合 moon fmt。
fn constant_block(name : String, source : String) -> String {
  let mut out = "\n///|\npub fn \{name}() -> String {\n  let source =\n"
  for view in source.split("\n") {
    out = out + embed_line(view.to_owned()) + "\n"
  }
  out + "  source\n}\n"
}

///|
/// 单个输出文件路径（与 domain 包名对应：kernel_ir.mbt 等）。
fn constant_output(name : String) -> String {
  "examples/moui_studio/services/export/\{name}.mbt"
}

///|
/// 一个领域包的全部常量：文件头 + 每个源文件一个 constant_block。
fn group_output_text(
  output_name : String,
  entries : Array[(String, String)],
) -> String raise {
  let mut out = "///|\n/// \{output_name}：domain 下若干 .mbt 的逐字节副本。\n/// 由 tools/sync_kernel 生成，勿手改；与源文件不一致时\n/// `moon run examples/moui_studio/tools/sync_kernel --target native -- --check` 会报 DRIFT。\n"
  for entry in entries {
    out = out + constant_block(entry.0, @x/fs.read_file_to_string(entry.1))
  }
  out
}

///|
/// runner 模板常量的输出文本。
fn runner_output_text() -> String raise {
  "///|\n/// 导出的可执行 runner 源码（由 tools/sync_kernel 生成，勿手改）。\n/// 模板位于 tools/export_runner_template/runner.mbt；\n/// 模板改动不同步时 `--check` 会报 DRIFT。\n" +
  constant_block(
    "runner_source",
    @x/fs.read_file_to_string(runner_template_path()),
  )
}

///|
fn all_outputs() -> Array[(String, String)] raise {
  let out : Array[(String, String)] = []
  for group in kernel_files() {
    out.push((constant_output(group.0), group_output_text(group.0, group.1)))
  }
  out.push((constant_output("kernel_runner"), runner_output_text()))
  out
}

///|
fn check_mode() -> Int raise {
  let mut ok = true
  for pair in all_outputs() {
    let current = @x/fs.read_file_to_string(pair.0) catch {
      _ => {
        println("MISSING \{pair.0}（尚未同步）")
        ok = false
        continue
      }
    }
    if current != pair.1 {
      println(
        "DRIFT \{pair.0}：与源文件不一致。请运行 moon run examples/moui_studio/tools/sync_kernel --target native",
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
    @x/fs.write_string_to_file(pair.0, pair.1)
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
