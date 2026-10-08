///|
/// 直接扫描（G7.2 性能修复）：不走 ServiceTask 回调链（每个目录一次
/// effect 派发 = 大项目 UI 冻结），改为同步 @x/fs I/O 一次函数调用
/// 完成整棵树。app 层直接在 dispatch 回调里调用（同步、无 raise）。
///
/// 与 walk_root_task 逻辑一致（同一 BFS + 跳过规则 + 上限 + 结构化报错），
/// 但用直接 I/O 替代 ServiceTask。

///|
/// 跳过目录清单（与 walk.mbt 同一规则）。
fn ds_skip_dir(name : String) -> Bool {
  match name {
    ".git"
    | ".mooncakes"
    | "_build"
    | "target"
    | "node_modules"
    | "artifacts"
    | ".studio"
    | ".vscode"
    | ".github" => true
    _ => false
  }
}

///|
/// 列目录条目：返回 (name, is_dir) 对；IO 错误返回空（该目录跳过）。
fn ds_list_dir(path : String) -> Array[(String, Bool)] {
  let result : Array[(String, Bool)] = []
  try {
    for name in @x/fs.read_dir(path) {
      if name.has_prefix(".") {
        continue
      }
      let is_dir = @x/fs.is_dir(path + "/" + name) catch { _ => false }
      result.push((name, is_dir))
    }
  } catch {
    _ => ()
  }
  result
}

///|
/// 读文本（不存在或不可读返回空串——扫描韧性口径）。
fn ds_read_text(path : String) -> String {
  @x/fs.read_file_to_string(path) catch { _ => "" }
}

///|
const DS_WALK_MAX_DIRS : Int = 2000

///|
const DS_WALK_MAX_FILES_PER_PACKAGE : Int = 200

///|
const DS_SCAN_MAX_MEMBERS : Int = 200

///|
const DS_SCAN_MAX_TOTAL_DIRS : Int = 20000

///|
const DS_PROGRESS_EVERY : Int = 64

///|
/// 直接扫描入口（G7.2 性能修复）。同步、不 raise——所有 IO 错误内部
/// 消化（读不了的目录跳过，moon.mod 缺失 = 结构化 Err）。
pub fn direct_scan(
  root : String,
  on_progress? : (@project.WalkProgress) -> Unit,
) -> Result[@project.ProjectScanOutput, String] {
  let progress = match on_progress {
    Some(cb) => cb
    None => fn(_) { }
  }
  let entries = ds_list_dir(root)
  let names : Array[String] = []
  let subdirs : Array[String] = []
  for pair in entries {
    let (name, is_dir) = pair
    if is_dir {
      if !ds_skip_dir(name) {
        subdirs.push(name)
      }
    } else {
      names.push(name)
    }
  }
  if names.contains("moon.work") {
    ds_scan_workspace(root, subdirs, progress)
  } else if names.contains("moon.mod") {
    Ok(@project.ProjectScanOutput::Single(ds_scan_module(root, "", progress)))
  } else {
    Err("\{root}:目录里没有 moon.mod(不是 MoonBit 模块工程?)")
  }
}

///|
/// 扫描单个 MoonBit 模块。
fn ds_scan_module(
  root : String,
  member_rel : String,
  progress : (@project.WalkProgress) -> Unit,
) -> @project.ProjectSource {
  let abs = if member_rel == "" {
    root
  } else {
    "\{root}/\{member_rel}"
  }
  let entries = ds_list_dir(abs)
  let dir_queue : Array[String] = []
  let file_lists : Map[String, Array[String]] = Map([])
  let pkg_queue : Array[String] = []
  let mut total = 0
  let root_files : Array[String] = []
  for pair in entries {
    let (name, is_dir) = pair
    if is_dir {
      dir_queue.push(name)
    } else {
      root_files.push(name)
    }
  }
  file_lists[""] = root_files
  if root_files.contains("moon.pkg") {
    pkg_queue.push("")
  }
  let mut idx = 0
  while idx < dir_queue.length() && total < DS_WALK_MAX_DIRS {
    let rel = dir_queue[idx]
    idx = idx + 1
    total = total + 1
    if total % DS_PROGRESS_EVERY == 0 {
      let current = if member_rel == "" {
        rel
      } else {
        "\{member_rel}/\{rel}"
      }
      progress(@project.WalkProgress::{ scanned_dirs: total, current })
    }
    let child_files : Array[String] = []
    for pair in ds_list_dir("\{abs}/\{rel}") {
      let (name, is_dir) = pair
      if is_dir {
        if !ds_skip_dir(name) {
          dir_queue.push("\{rel}/\{name}")
        }
      } else {
        child_files.push(name)
      }
    }
    file_lists[rel] = child_files
    if child_files.contains("moon.pkg") {
      pkg_queue.push(rel)
    }
  }
  let mod_text = ds_read_text("\{abs}/moon.mod")
  let results : Array[(String, String, Bool, Array[String])] = []
  for pkg_rel in pkg_queue {
    let pkg_text = ds_read_text("\{abs}/\{pkg_rel}/moon.pkg")
    let files = file_lists.get(pkg_rel).unwrap_or([])
    let sources : Array[String] = []
    let mut has_program = false
    for name in files {
      if name.has_suffix(".mbt") &&
        sources.length() < DS_WALK_MAX_FILES_PER_PACKAGE {
        sources.push(name)
      }
    }
    let is_entry = pkg_rel == "" ||
      pkg_rel == "web_wasm" ||
      pkg_rel == "macos_skia" ||
      pkg_rel == "native_app"
    for name in sources {
      let source = ds_read_text("\{abs}/\{pkg_rel}/\{name}")
      if source.contains("pub fn program") {
        has_program = true
      }
    }
    results.push((pkg_rel, pkg_text, has_program, files))
  }
  @project.ProjectSource::{
    root: abs,
    module_manifest: mod_text,
    package_sources: results,
  }
}

///|
/// 扫描 moon.work 工作区。
fn ds_scan_workspace(
  root : String,
  _root_subdirs : Array[String],
  progress : (@project.WalkProgress) -> Unit,
) -> Result[@project.ProjectScanOutput, String] {
  let work_text = ds_read_text("\{root}/moon.work")
  let members = match @project.parse_moon_work(work_text) {
    Ok(members) => members
    Err(message) => return Err("\{root}:\{message}")
  }
  if members.is_empty() {
    return Err("\{root}:moon.work 没有可导入的成员")
  }
  if members.length() > DS_SCAN_MAX_MEMBERS {
    return Err("\{root}:工作区成员数超过 \{DS_SCAN_MAX_MEMBERS},放弃扫描")
  }
  let loaded : Array[@project.ProjectSource] = []
  let failed : Array[(String, String)] = []
  for member in members {
    progress(@project.WalkProgress::{ scanned_dirs: 0, current: member })
    loaded.push(ds_scan_module(root, member, progress))
  }
  Ok(
    @project.ProjectScanOutput::Workspace(
      @project.WorkspaceScan::{ root, loaded, failed },
    ),
  )
}
