///|
/// 工程目录树遍历(@services.FileServices → 纯扫描的适配层)。
///
/// `@services.FileServices.list_directory/read_text` 是跨平台服务(native 走宿主,
/// web 默认 unavailable 任务——失败会以结构化 @services.ServiceError 暴露,调用方
/// 显式降级,与导出能力同一纪律)。本文件把「选中的目录」变成纯扫描
/// (`scan_module`)需要的原始材料:
///
/// 1. **探测根**：列出根目录——有 `moon.work` → 工作区模式（逐成员扫描）；
///    有 `moon.mod` → 单模块模式；都没有 → 结构化报错。
/// 2. **走目录**：BFS 队列,每个目录一次 `list_directory`;跳过构建产物
///    与依赖目录(`.git/_build/.mooncakes/target/node_modules/artifacts
///    /.studio`)——它们既拖慢扫描又没有工程语义。
/// 3. **读包**：每个含 `moon.pkg` 的目录,读清单文本;单模块模式再逐个读
///    `.mbt` 源文件查 `pub fn program`(逻辑/预览 harness 的挂载点探测);
///    工作区模式**不深读**（入口只按目录名约定判——仓库级规模下全量深读
///    是失控主因）。
///
/// 整个遍历是**一个** @services.ServiceTask:内部用完成回调串起每一步(框架的
/// @services.ServiceTask 无 flat_map,回调状态机是既有惯例)。上限守卫分三级
/// （每成员目录数 / 工作区成员数 / 总目录数）防止失控扫描;进度回调节流上报。

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
/// 扫描进度读数（scanned_dirs = 全程累计目录数;current = 正在走的路径）。
pub(all) struct WalkProgress {
  scanned_dirs : Int
  current : String
}

///|
/// 扫描产出:单模块 = Single;moon.work 工作区 = 每成员一份 ProjectSource,
/// 失败成员进 failed(一个成员坏了不挡住其余成员——但绝不静默,汇总要说话)。
pub(all) enum ProjectScanOutput {
  Single(ProjectSource)
  Workspace(WorkspaceScan)
}

///|
pub(all) struct WorkspaceScan {
  root : String
  loaded : Array[ProjectSource]
  /// (成员相对路径, 失败原因)
  failed : Array[(String, String)]
}

///|
/// 单次扫描的上限守卫:每成员目录数。
const WALK_MAX_DIRS : Int = 2000

///|
const WALK_MAX_FILES_PER_PACKAGE : Int = 200

///|
/// 工作区级上限:成员数(防恶意/手滑清单把扫描变成无界)。
const SCAN_MAX_MEMBERS : Int = 200

///|
/// 工作区级上限:全程累计目录数(本仓库根实测 ~4.7k,留一倍余量)。
const SCAN_MAX_TOTAL_DIRS : Int = 20000

///|
/// 进度回调节流:每 N 个目录回调一次。
const PROGRESS_EVERY : Int = 64

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
  /// 列根目录并判定模式(单模块 / 工作区)
  WkRoot
  /// 读根 moon.work 并解析 members
  WkWorkRead
  /// 处理当前成员的目录队列
  WkDirs
  /// 读当前成员 moon.mod
  WkMod
  /// 读当前包的 moon.pkg
  WkPkgManifest
  /// 读当前包的 .mbt 文件（仅单模块深读模式）
  WkPkgSources
}

///|
priv enum ScanMode {
  /// 根目录自身是 MoonBit 模块(现行为,含 .mbt 深读)
  SmSingle
  /// 根目录是 moon.work 工作区,逐成员扫描
  SmWorkspace
}

///|
priv struct WalkState {
  files : @services.FileServices
  root : String
  on_progress : (WalkProgress) -> Unit
  mut phase : WalkPhase
  mut mode : ScanMode
  /// 工作区聚合(单模块模式恒空)
  member_queue : Array[String]
  loaded : Array[ProjectSource]
  failed : Array[(String, String)]
  /// 全程累计目录数(跨成员)
  mut total_dirs : Int
  /// 当前成员相对工作区根的路径(单模块模式 = "")
  mut member_rel : String
  /// 当前成员已扫目录数
  mut member_dirs : Int
  /// 以下容器会被 `begin_member_state` 按成员重置（重绑定 = 需要 mut）
  mut dir_queue : Array[String]
  mut entries : Array[LayoutEntry]
  /// rel_path → 该目录的文件名列表(找 .mbt / 判清单用)
  mut file_lists : Map[String, Array[String]]
  mut pkg_queue : Array[String]
  mut results : Array[(String, String, Bool, Array[String])]
  mut current_pkg : String
  mut current_pkg_text : String
  mut current_has_program : Bool
  mut pkg_files : Array[String]
  mut mod_text : String
  /// 单模块 = 深读全部 .mbt 找 `pub fn program`(预览 harness 挂载点);
  /// 工作区 = 只按目录名约定判入口,不深读(规模治理)。
  mut deep_read : Bool
}

///|
/// 遍历任务:完成后给 `Success(Result[ProjectScanOutput, String])` /
/// `Failure(@services.ServiceError)` / `Cancelled`。调用方经
/// `@services.ServiceTask::effect` 转 Msg。域级失败(根不可导入、清单坏、
/// 全局超限)走 `Success(Err(...))`——任务本身成功完成,结论是「这不是可
/// 导入的工程」;基础设施错误(list/read 失败)才走 `Failure(ServiceError)`,
/// 调用方据此区分「不可导入」与「扫描本身坏了」。
pub fn walk_root_task(
  files : @services.FileServices,
  root : String,
  on_progress? : (WalkProgress) -> Unit,
) -> @services.ServiceTask[Result[ProjectScanOutput, String]] {
  let progress = match on_progress {
    Some(callback) => callback
    None => fn(_progress) {  }
  }
  @services.ServiceTask::new(
    key="project:scan:\{root}",
    label="扫描工程 \{root}",
    start=complete => {
      let state : WalkState = WalkState::{
        files,
        root,
        on_progress: progress,
        phase: WkRoot,
        mode: SmSingle,
        member_queue: [],
        loaded: [],
        failed: [],
        total_dirs: 0,
        member_rel: "",
        member_dirs: 0,
        dir_queue: [""],
        entries: [],
        file_lists: Map([]),
        pkg_queue: [],
        results: [],
        current_pkg: "",
        current_pkg_text: "",
        current_has_program: false,
        pkg_files: [],
        mod_text: "",
        deep_read: true,
      }
      walk_run(state, complete)
      None
    },
  )
}

///|
fn walk_run(
  state : WalkState,
  complete : (@services.ServiceTaskResult[Result[ProjectScanOutput, String]]) -> Unit,
) -> Unit {
  match state.phase {
    WkRoot => walk_root_step(state, complete)
    WkWorkRead => walk_work_read_step(state, complete)
    WkDirs => walk_dirs_step(state, complete)
    WkMod => walk_mod_step(state, complete)
    WkPkgManifest => walk_pkg_manifest_step(state, complete)
    WkPkgSources => walk_pkg_sources_step(state, complete)
  }
}

///|
/// 域级失败(整单):根不可导入、清单坏、全局超限。走 `Success(Err(...))`。
fn walk_fail(
  complete : (@services.ServiceTaskResult[Result[ProjectScanOutput, String]]) -> Unit,
  message : String,
) -> Unit {
  complete(Success(Err(message)))
}

///|
/// 当前成员的绝对根(单模块模式 = 工作区根本身)。
fn member_root_of(state : WalkState) -> String {
  if state.member_rel == "" {
    state.root
  } else {
    "\{state.root}/\{state.member_rel}"
  }
}

///|
/// 成员级域失败:单模块 = 整单失败;工作区 = 该成员进 failed,继续下一个。
fn member_fail(
  state : WalkState,
  complete : (@services.ServiceTaskResult[Result[ProjectScanOutput, String]]) -> Unit,
  reason : String,
) -> Unit {
  match state.mode {
    SmSingle => walk_fail(complete, "\{member_root_of(state)}:\{reason}")
    SmWorkspace => {
      state.failed.push((state.member_rel, reason))
      begin_next_member(state, complete)
    }
  }
}

///|
/// 成员级基础设施失败(list/read 服务坏了):单模块按整单 Failure 上抛;
/// 工作区记为该成员失败(原因带「读取失败」),继续其余成员。
fn member_infra_fail(
  state : WalkState,
  complete : (@services.ServiceTaskResult[Result[ProjectScanOutput, String]]) -> Unit,
  error : @services.ServiceError,
) -> Unit {
  match state.mode {
    SmSingle => complete(Failure(error))
    SmWorkspace => member_fail(state, complete, "读取失败:\{error.message}")
  }
}

///|
/// 进度上报:每 PROGRESS_EVERY 个目录回调一次(当前路径带成员前缀)。
fn bump_progress(state : WalkState, rel : String) -> Unit {
  if state.total_dirs % PROGRESS_EVERY != 0 {
    return
  }
  let current = if state.member_rel == "" {
    rel
  } else if rel == "" {
    state.member_rel
  } else {
    "\{state.member_rel}/\{rel}"
  }
  (state.on_progress)({ scanned_dirs: state.total_dirs, current, })
}

///|
/// 重置「当前成员」的扫描容器(每成员独立 BFS;dir_queue 置空,
/// 由调用方播种——单模块播种根级子目录,工作区播种 "")。
fn begin_member_state(state : WalkState) -> Unit {
  state.dir_queue = []
  state.entries = []
  state.file_lists = Map([])
  state.pkg_queue = []
  state.results = []
  state.current_pkg = ""
  state.current_pkg_text = ""
  state.current_has_program = false
  state.pkg_files = []
  state.mod_text = ""
}

///|
/// 列根目录并判定模式:moon.work → 工作区;moon.mod → 单模块(根 listing
/// 直接播种,不重列);都没有 → 结构化报错。
fn walk_root_step(
  state : WalkState,
  complete : (@services.ServiceTaskResult[Result[ProjectScanOutput, String]]) -> Unit,
) -> Unit {
  let _ = (state.files.list_directory_fn)(state.root).start(result => {
    match result {
      Success(dir_entries) => {
        let names : Array[String] = []
        let subdirs : Array[String] = []
        for entry in dir_entries {
          if entry.is_directory {
            if !is_skipped_dir(entry.name) {
              subdirs.push(entry.name)
            }
          } else {
            names.push(entry.name)
          }
        }
        if names.contains("moon.work") {
          state.phase = WkWorkRead
          walk_run(state, complete)
        } else if names.contains("moon.mod") {
          // 单模块:根 listing 已在手,播种后直接进 BFS(行为与旧 walk 一致)
          begin_member_state(state)
          state.dir_queue = subdirs
          state.entries.push(LayoutEntry::{
            rel_path: "",
            is_dir: true,
            files: names,
          })
          state.file_lists[""] = names
          if names.contains("moon.pkg") {
            state.pkg_queue.push("")
          }
          state.phase = WkDirs
          walk_run(state, complete)
        } else {
          walk_fail(
            complete,
            "\{state.root}:目录里没有 moon.mod(不是 MoonBit 模块工程?)",
          )
        }
      }
      Failure(error) => complete(Failure(error))
      Cancelled => complete(Cancelled)
    }
  })
}

///|
/// 读根 moon.work → 解析 members → 逐成员扫描。
fn walk_work_read_step(
  state : WalkState,
  complete : (@services.ServiceTaskResult[Result[ProjectScanOutput, String]]) -> Unit,
) -> Unit {
  let _ = (state.files.read_text_fn)(join_path(state.root, "moon.work")).start(result => {
    match result {
      Success(text) =>
        match parse_moon_work(text) {
          Ok(members) => {
            if members.is_empty() {
              walk_fail(
                complete,
                "\{state.root}:moon.work 没有可导入的成员",
              )
              return
            }
            if members.length() > SCAN_MAX_MEMBERS {
              walk_fail(
                complete,
                "\{state.root}:工作区成员数超过 \{SCAN_MAX_MEMBERS},放弃扫描",
              )
              return
            }
            state.mode = SmWorkspace
            state.deep_read = false
            for member_path in members {
              state.member_queue.push(member_path)
            }
            state.phase = WkDirs
            begin_next_member(state, complete)
          }
          Err(message) => walk_fail(complete, "\{state.root}:\{message}")
        }
      Failure(error) => complete(Failure(error))
      Cancelled => complete(Cancelled)
    }
  })
}

///|
/// 开始下一个成员:队列空 = 工作区扫描完成;超全局上限 = 整单放弃。
fn begin_next_member(
  state : WalkState,
  complete : (@services.ServiceTaskResult[Result[ProjectScanOutput, String]]) -> Unit,
) -> Unit {
  let next_member = match state.member_queue.pop() {
    Some(head) => head
    None => {
      complete(
        Success(
          Ok(
            ProjectScanOutput::Workspace(WorkspaceScan::{
              root: state.root,
              loaded: state.loaded,
              failed: state.failed,
            }),
          ),
        ),
      )
      return
    }
  }
  if state.total_dirs >= SCAN_MAX_TOTAL_DIRS {
    walk_fail(
      complete,
      "\{state.root}:总目录数超过 \{SCAN_MAX_TOTAL_DIRS},放弃扫描",
    )
    return
  }
  state.member_rel = next_member
  state.member_dirs = 0
  begin_member_state(state)
  state.dir_queue.push("")
  state.phase = WkDirs
  bump_progress(state, "")
  walk_run(state, complete)
}

///|
fn walk_dirs_step(
  state : WalkState,
  complete : (@services.ServiceTaskResult[Result[ProjectScanOutput, String]]) -> Unit,
) -> Unit {
  let rel = match state.dir_queue.pop() {
    Some(head) => head
    None => {
      // 成员目录走完:有 moon.mod 则进入读取阶段,否则成员失败
      if state.file_lists.contains("") &&
        state.file_lists.get("").unwrap_or([]).contains("moon.mod") {
        state.phase = WkMod
      } else {
        member_fail(
          state, complete, "目录里没有 moon.mod(不是 MoonBit 模块工程?)",
        )
        return
      }
      walk_run(state, complete)
      return
    }
  }
  if state.member_dirs >= WALK_MAX_DIRS {
    member_fail(
      state,
      complete,
      "目录数超过 \{WALK_MAX_DIRS},放弃扫描",
    )
    return
  }
  if state.mode is SmWorkspace && state.total_dirs >= SCAN_MAX_TOTAL_DIRS {
    walk_fail(
      complete,
      "\{state.root}:总目录数超过 \{SCAN_MAX_TOTAL_DIRS},放弃扫描",
    )
    return
  }
  state.member_dirs = state.member_dirs + 1
  state.total_dirs = state.total_dirs + 1
  bump_progress(state, rel)
  let _ = (state.files.list_directory_fn)(join_path(member_root_of(state), rel)).start(result => {
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
        Failure(error) => member_infra_fail(state, complete, error)
        Cancelled => complete(Cancelled)
      }
    },
  )
}

///|
fn walk_mod_step(
  state : WalkState,
  complete : (@services.ServiceTaskResult[Result[ProjectScanOutput, String]]) -> Unit,
) -> Unit {
  let _ = (state.files.read_text_fn)(
    join_path(member_root_of(state), "moon.mod"),
  ).start(result => {
    match result {
      Success(text) => {
        state.mod_text = text
        state.phase = WkPkgManifest
        walk_run(state, complete)
      }
      Failure(error) => member_infra_fail(state, complete, error)
      Cancelled => complete(Cancelled)
    }
  })
}

///|
/// 当前包读完入库（带该目录全部文件名,资源管理器文件树用）。
fn record_current_package(state : WalkState) -> Unit {
  state.results.push(
    (
      state.current_pkg,
      state.current_pkg_text,
      state.current_has_program,
      state.file_lists.get(state.current_pkg).unwrap_or([]),
    ),
  )
}

///|
fn walk_pkg_manifest_step(
  state : WalkState,
  complete : (@services.ServiceTaskResult[Result[ProjectScanOutput, String]]) -> Unit,
) -> Unit {
  let rel = match state.pkg_queue.pop() {
    Some(head) => head
    None => {
      // 当前成员读完:入库,单模块完成 / 工作区继续下一成员
      let source = ProjectSource::{
        root: member_root_of(state),
        module_manifest: state.mod_text,
        package_sources: state.results,
      }
      match state.mode {
        SmSingle => complete(Success(Ok(ProjectScanOutput::Single(source))))
        SmWorkspace => {
          state.loaded.push(source)
          begin_next_member(state, complete)
        }
      }
      return
    }
  }
  state.current_pkg = rel
  state.current_has_program = false
  let _ = (state.files.read_text_fn)(
    join_path(member_root_of(state), "\{rel}/moon.pkg"),
  ).start(result => {
    match result {
      Success(text) => {
        state.current_pkg_text = text
        // 当前包的 .mbt 源文件(数量有守卫;工作区模式不收集,直接入库)
        if state.deep_read {
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
        } else {
          record_current_package(state)
          state.phase = WkPkgManifest
        }
        walk_run(state, complete)
      }
      Failure(error) => member_infra_fail(state, complete, error)
      Cancelled => complete(Cancelled)
    }
  })
}

///|
fn walk_pkg_sources_step(
  state : WalkState,
  complete : (@services.ServiceTaskResult[Result[ProjectScanOutput, String]]) -> Unit,
) -> Unit {
  let name = match state.pkg_files.pop() {
    Some(head) => head
    None => {
      // 当前包读完:入库,回包清单阶段
      record_current_package(state)
      state.phase = WkPkgManifest
      walk_run(state, complete)
      return
    }
  }
  let rel = state.current_pkg
  let _ = (state.files.read_text_fn)(
    join_path(member_root_of(state), "\{rel}/\{name}"),
  ).start(result => {
    match result {
      Success(text) => {
        if text.contains("pub fn program") {
          state.current_has_program = true
        }
        walk_run(state, complete)
      }
      Failure(error) => member_infra_fail(state, complete, error)
      Cancelled => complete(Cancelled)
    }
  })
}


