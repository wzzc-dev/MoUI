///|
/// 离线导出 CLI：把 `.studio.json` 打成自包含 MoUI 项目到目标目录。
/// 用于 CI/人工在 workspace 外验证导出产物可构建（P3 退出门证据）。
/// 产物与 Studio 内「导出为 MoUI 项目」完全一致（同一个 export_bundle），
/// Web 运行时 JS 由导出项目自身的 `.mooncakes` 依赖目录提供（见 export.mbt
/// 的 web_index_html 目录契约），本工具不拷贝任何仓库文件。
///
/// 用法：
///   moon run examples/moui_studio/tools/emit_bundle --target native -- \
///     <项目JSON路径> <应用名> <目标目录>

///|
fn main {
  let args = @env.args()
  let rest = if args.is_empty() { [] } else { args[1:].to_owned() }
  if rest.length() < 3 {
    println("usage: emit_bundle <project.json> <app-name> <target-dir>")
    return
  }
  let code = run(rest[0], rest[1], rest[2])
  if code != 0 {
    @sys.exit(code)
  }
}

///|
fn run(source_path : String, app_name : String, target_dir : String) -> Int {
  let source = @x/fs.read_file_to_string(source_path) catch {
    _ => {
      println("cannot read \{source_path}")
      return 2
    }
  }
  let bundle = @export.export_bundle(source, app_name)
  let mut written = 0
  for pair in bundle {
    let path = "\{target_dir}/\{pair.0}"
    ensure_parent_dir(path)
    try {
      @x/fs.write_string_to_file(path, pair.1)
      written = written + 1
      println("wrote \{path}")
    } catch {
      _ => println("failed \{path}")
    }
  }
  println("bundle done: \{written}/\{bundle.length()} files")
  if written == bundle.length() {
    0
  } else {
    1
  }
}

///|
/// 逐级创建父目录（x/fs 无 recursive mkdir，显式上溯）。
fn ensure_parent_dir(path : String) -> Unit {
  let idx = match path.rev_find("/") {
    Some(index) => index
    None => return
  }
  let parent = path[:idx].to_owned()
  if parent.is_empty() {
    return
  }
  if @x/fs.path_exists(parent) {
    return
  }
  ensure_parent_dir(parent)
  @x/fs.create_dir(parent) catch {
    _ => ()
  }
}
