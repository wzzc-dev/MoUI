///|
/// 工程目录树遍历(@services.FileServices → 纯扫描的适配层)。
///
/// `@services.FileServices.list_directory/read_text` 是跨平台服务(native 走宿主,
/// web 默认 unavailable 任务——失败会以结构化 @services.ServiceError 暴露,调用方
/// 显式降级,与导出能力同一纪律)。本文件把「选中的目录」变成纯扫描
/// (`scan_module`)需要的原始材料:
///
/// 1. **走目录**:BFS 队列,每个目录一次 `list_directory`;跳过构建产物
///    与依赖目录(`.git/_build/.mooncakes/target/node_modules/artifacts
///    /.studio`)——它们既拖慢扫描又没有工程语义。
/// 2. **读包**:每个含 `moon.pkg` 的目录,读清单文本,再逐个读 `.mbt`
///    源文件查 `pub fn program`(逻辑/预览 harness 的挂载点探测)。
/// 3. **读 moon.mod**(根目录)。
///
/// 整个遍历是**一个** @services.ServiceTask:内部用完成回调串起每一步(框架的
/// @services.ServiceTask 无 flat_map,回调状态机是既有惯例)。上限守卫(目录数/
/// 每包文件数)防止失控扫描。

///|
/// 纯扫描(`scan_module`)所需的全部原始材料。
pub(all) struct ProjectSource {
  root : String
  /// 根目录 moon.mod 文本
  module_manifest : String
  /// (包相对路径, moon.pkg 文本, 是否含 pub fn program, 目录内全部文件名)
  package_sources : Array[(String, String, Bool, Array[String])]
}

///|
/// 单次扫描的上限守卫。
const WALK_MAX_DIRS : Int = 2000

///|
const WALK_MAX_FILES_PER_PACKAGE : Int = 200

///|
fn is_skipped_dir(name : String) -> Bool {
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
/// 拼绝对路径:根下第一层直接接根,其余以 `/` 相接。
fn join_path(root : String, rel : String) -> String {
  if rel == "" {
    root
  } else {
    "\{root}/\{rel}"
  }
}

///|
priv enum WalkPhase {
  /// 处理目录队列
  WkDirs
  /// 读根 moon.mod
  WkMod
  /// 读当前包的 moon.pkg
  WkPkgManifest
  /// 读当前包的 .mbt 文件
  WkPkgSources
}

///|
priv struct WalkState {
  files : @services.FileServices
  root : String
  mut phase : WalkPhase
  /// 以下容器只做 push/pop/索引写,不需要 mut(那是对字段**重绑定**的要求)
  dir_queue : Array[String]
  entries : Array[LayoutEntry]
  /// rel_path → 该目录的文件名列表(找 .mbt 用)
  file_lists : Map[String, Array[String]]
  pkg_queue : Array[String]
  results : Array[(String, String, Bool, Array[String])]
  mut current_pkg : String
  mut current_pkg_text : String
  mut current_has_program : Bool
  mut pkg_files : Array[String]
  mut mod_text : String
}

///|
/// 遍历任务:完成后给 `Success(ProjectSource)` / `Failure(@services.ServiceError)` /
/// `Cancelled`。调用方经 `@services.ServiceTask::effect` 转 Msg。
pub fn walk_project_task(
  files : @services.FileServices,
  root : String,
) -> @services.ServiceTask[Result[ProjectSource, String]] {
  @services.ServiceTask::new(
    key="project:walk:\{root}",
    label="扫描工程 \{root}",
    start=complete => {
      let state : WalkState = WalkState::{
        files,
        root,
        phase: WkDirs,
        dir_queue: [""],
        entries: [],
        file_lists: Map([]),
        pkg_queue: [],
        current_pkg: "",
        current_pkg_text: "",
        current_has_program: false,
        pkg_files: [],
        results: [],
        mod_text: "",
      }
      walk_run(state, complete)
      None
    },
  )
}

///|
fn walk_run(
  state : WalkState,
  complete : (@services.ServiceTaskResult[Result[ProjectSource, String]]) -> Unit,
) -> Unit {
  match state.phase {
    WkDirs => walk_dirs_step(state, complete)
    WkMod => walk_mod_step(state, complete)
    WkPkgManifest => walk_pkg_manifest_step(state, complete)
    WkPkgSources => walk_pkg_sources_step(state, complete)
  }
}

///|
/// 域级失败(目录没有 moon.mod、扫描超限):走 `Success(Err(...))`——任务
/// 本身成功完成,结论是「这不是可导入的工程」。基础设施错误(list/read
/// 失败)才走 `Failure(ServiceError)`,调用方据此区分「不可导入」与「扫描
/// 本身坏了」。
fn walk_fail(
  complete : (@services.ServiceTaskResult[Result[ProjectSource, String]]) -> Unit,
  message : String,
) -> Unit {
  complete(Success(Err(message)))
}

///|
fn walk_dirs_step(
  state : WalkState,
  complete : (@services.ServiceTaskResult[Result[ProjectSource, String]]) -> Unit,
) -> Unit {
  let rel = match state.dir_queue.pop() {
    Some(head) => head
    None => {
      // 目录走完:若有 moon.mod 则进入读取阶段,否则直接报告缺清单
      if state.file_lists.contains("") &&
        state.file_lists.get("").unwrap_or([]).contains("moon.mod") {
        state.phase = WkMod
      } else {
        walk_fail(
          complete,
          "\{state.root}:目录里没有 moon.mod(不是 MoonBit 模块工程?)",
        )
        return
      }
      walk_run(state, complete)
      return
    }
  }
  if state.entries.length() >= WALK_MAX_DIRS {
    walk_fail(
      complete,
      "\{state.root}:目录数超过 \{WALK_MAX_DIRS},放弃扫描",
    )
    return
  }
  let _ = (state.files.list_directory_fn)(join_path(state.root, rel)).start(result => {
    match result {
      Success(dir_entries) => {
        let names : Array[String] = []
        for entry in dir_entries {
          if entry.is_directory {
            if !is_skipped_dir(entry.name) {
              let child = if rel == "" {
                entry.name
              } else {
                "\{rel}/\{entry.name}"
              }
              state.dir_queue.push(child)
            }
          } else {
            names.push(entry.name)
          }
        }
        state.entries.push(LayoutEntry::{
          rel_path: rel,
          is_dir: true,
          files: names,
        })
        state.file_lists[rel] = names
        if names.contains("moon.pkg") {
          state.pkg_queue.push(rel)
        }
        walk_run(state, complete)
      }
      Failure(error) => complete(Failure(error))
      Cancelled => complete(Cancelled)
    }
  })
}

///|
fn walk_mod_step(
  state : WalkState,
  complete : (@services.ServiceTaskResult[Result[ProjectSource, String]]) -> Unit,
) -> Unit {
  let _ = (state.files.read_text_fn)(join_path(state.root, "moon.mod")).start(result => {
    match result {
      Success(text) => {
        state.mod_text = text
        state.phase = WkPkgManifest
        walk_run(state, complete)
      }
      Failure(error) => complete(Failure(error))
      Cancelled => complete(Cancelled)
    }
  })
}

///|
fn walk_pkg_manifest_step(
  state : WalkState,
  complete : (@services.ServiceTaskResult[Result[ProjectSource, String]]) -> Unit,
) -> Unit {
  let rel = match state.pkg_queue.pop() {
    Some(head) => head
    None => {
      complete(
        Success(
          Ok(ProjectSource::{
            root: state.root,
            module_manifest: state.mod_text,
            package_sources: state.results,
          }),
        ),
      )
      return
    }
  }
  state.current_pkg = rel
  state.current_has_program = false
  let _ = (state.files.read_text_fn)(join_path(state.root, "\{rel}/moon.pkg")).start(result => {
      match result {
        Success(text) => {
          state.current_pkg_text = text
          // 当前包的 .mbt 源文件(数量有守卫)
          let files = state.file_lists.get(rel).unwrap_or([])
          let sources : Array[String] = []
          for name in files {
            if name.has_suffix(".mbt") &&
              sources.length() < WALK_MAX_FILES_PER_PACKAGE {
              sources.push(name)
            }
          }
          state.pkg_files = sources
          state.phase = WkPkgSources
          walk_run(state, complete)
        }
        Failure(error) => complete(Failure(error))
        Cancelled => complete(Cancelled)
      }
    },
  )
}

///|
fn walk_pkg_sources_step(
  state : WalkState,
  complete : (@services.ServiceTaskResult[Result[ProjectSource, String]]) -> Unit,
) -> Unit {
  let name = match state.pkg_files.pop() {
    Some(head) => head
    None => {
      // 当前包读完:入库(带该目录全部文件名,资源管理器文件树用),回包清单阶段
      state.results.push(
        (
          state.current_pkg,
          state.current_pkg_text,
          state.current_has_program,
          state.file_lists.get(state.current_pkg).unwrap_or([]),
        ),
      )
      state.phase = WkPkgManifest
      walk_run(state, complete)
      return
    }
  }
  let rel = state.current_pkg
  let _ = (state.files.read_text_fn)(join_path(state.root, "\{rel}/\{name}")).start(result => {
      match result {
        Success(text) => {
          if text.contains("pub fn program") {
            state.current_has_program = true
          }
          walk_run(state, complete)
        }
        Failure(error) => complete(Failure(error))
        Cancelled => complete(Cancelled)
      }
    },
  )
}
