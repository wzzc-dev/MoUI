///|
/// 离线导出 CLI：把 `.moblocks.json` 打成自包含 MoUI 项目到目标目录。
/// 用于 CI/人工在 workspace 外验证导出产物可构建（M4 退出门证据）。
/// 产物与 Studio 内「导出为 MoUI 项目」完全一致（同一个 export_bundle），
/// Web 运行时 JS 由导出项目自身的 `.mooncakes` 依赖目录提供（见 export.mbt
/// 的 web_index_html 目录契约），本工具不拷贝任何仓库文件。
///
/// 用法：
///   moon run examples/moblocks_studio/tools/emit_bundle --target native -- \
///     <项目JSON路径> <应用名> <目标目录>

///|
async fn main {
  let raw_args = @env.args()
  let args = if raw_args.is_empty() { [] } else { raw_args[1:].to_owned() }
  if args.length() < 3 {
    println("usage: emit_bundle <project.json> <app-name> <target-dir>")
    return
  }
  ignore(run(args[0], args[1], args[2]))
}

///|
async fn run(
  source_path : String,
  app_name : String,
  target_dir : String,
) -> Int {
  let source = try {
    let data = @fs.read_file(source_path)
    data.text()
  } catch {
    err => {
      println("cannot read \{source_path}: \{err}")
      return 2
    }
  }
  let bundle = @export.export_bundle(source, app_name)
  let mut written = 0
  for pair in bundle {
    let path = target_dir + "/" + pair.0
    let parent = path_parent(path)
    if parent.is_empty() == false && parent != target_dir {
      @fs.mkdir(parent, recursive=true) catch {
        _ => ()
      }
    }
    try {
      @fs.write_file(path, pair.1, create_mode=CreateOrTruncate)
      written = written + 1
      println("wrote \{path}")
    } catch {
      err => println("failed \{path}: \{err}")
    }
  }
  println("bundle done: \{written} files")
  if written == bundle.length() {
    0
  } else {
    1
  }
}

///|
fn path_parent(path : String) -> String {
  let index = match path.rev_find("/") {
    Some(index) => index
    None => return ""
  }
  if index == 0 {
    ""
  } else {
    path[:index].to_owned()
  }
}
