///|
/// 工程工作台(M0):导入的 MoonBit 工程。
///
/// Studio 的主编辑上下文仍是 `.studio.json` 程序(M6 才切换真源);本文件
/// 承载「导入的代码工程」——资源管理器(M0-6)与三模式预览(M1-M3)的
/// 数据对象。导入 = 选目录 → `@project.walk_project_task` 走树 → 本文件的
/// `project_record_from_source` 解析成记录,失败一路结构化报错到 toast。

///|
/// 一个导入的 MoonBit 工程(会话内,不持久化)。
pub(all) struct ProjectRecord {
  /// 工程根目录(用户选中的绝对路径)
  root : String
  /// moon.mod 的 name(如 "examples/counter")
  module_name : String
  /// 扫描结果:包清单 + 入口判定
  scanned : @project.ScannedModule
}

///|
/// 扫描输入 → 工程记录:parse moon.mod + scan 包树。
/// 任何一步失败都是结构化 `Err(根路径:原因)`,调用方直接 with_notice。
pub fn project_record_from_source(
  source : @project.ProjectSource,
) -> Result[ProjectRecord, String] {
  match @project.parse_module_manifest(source.module_manifest) {
    Err(msg) => Err("\{source.root}:\{msg}")
    Ok(manifest) =>
      match @project.scan_module(manifest, source.package_sources) {
        Err(msg) => Err("\{source.root}:\{msg}")
        Ok(scanned) =>
          Ok(ProjectRecord::{
            root: source.root,
            module_name: manifest.name,
            scanned,
          })
      }
  }
}

///|
/// 当前选中的工程(资源管理器高亮;`active_project < 0` = 无)。
pub fn active_project_of(model : Model) -> ProjectRecord? {
  if model.active_project >= 0 && model.active_project < model.projects.length() {
    Some(model.projects[model.active_project])
  } else {
    None
  }
}

///|
/// 把导入的工程并入列表:同 root 已存在则**原位替换**(重复导入刷新扫描),
/// 否则插到表头;返回 (新列表, 该工程的新下标)。
pub fn upsert_project(
  projects : Array[ProjectRecord],
  record : ProjectRecord,
) -> (Array[ProjectRecord], Int) {
  let mut existing = -1
  let mut i = 0
  for project in projects {
    if project.root == record.root {
      existing = i
    }
    i = i + 1
  }
  let updated : Array[ProjectRecord] = []
  if existing < 0 {
    updated.push(record)
    for project in projects {
      updated.push(project)
    }
    (updated, 0)
  } else {
    let mut index = 0
    for project in projects {
      if index == existing {
        updated.push(record)
      } else {
        updated.push(project)
      }
      index = index + 1
    }
    (updated, existing)
  }
}

///|
/// 待执行构建(纯数据;执行闭包在程序包装层注入,与 CompileSubmit 同位)。
pub(all) struct ProjectBuildRequest {
  kind : @build.BuildKind
  root : String
  entry_rel : String
}

///|
/// 构建提交签名:平台入口注入(native 起 BuildOwner worker;web/测试 noop)。
pub type BuildSubmit = (
  @build.BuildKind,
  String,
  String,
  (Result[@build.BuildReport, String]) -> Unit,
) -> Unit

///|
pub fn noop_build_submit(
  _kind : @build.BuildKind,
  _root : String,
  _entry_rel : String,
  callback : (Result[@build.BuildReport, String]) -> Unit,
) -> Unit {
  callback(Err("本端没有构建执行器:构建仅在 native 入口可达"))
}

///|
/// 当前工程对应 kind 的入口包(缺 = ""):
/// FramePreview 用生成的预览 harness 包(M1 落地),
/// WebPreview / RunNative 用扫描出的 web / native 入口。
pub fn build_entry_rel(
  kind : @build.BuildKind,
  project : ProjectRecord,
) -> String {
  match kind {
    BkFramePreview => ".studio/preview"
    BkWebPreview => project.scanned.web_entry
    BkRunNative => project.scanned.native_entry
  }
}

///|
pub fn noop_build_cancel() -> Unit {
  ()
}

///|
/// 预览 harness 落盘状态:待写文件队列(绝对路径, 内容)+ 已写游标。
pub(all) struct PreviewWriteState {
  files : Array[(String, String)]
  done : Int
}

///|
/// 为导入成功的工程构造预览落盘任务:工程含 `pub fn program` 包才生成
/// (无逻辑入口的工程没有可预览的东西,诚实跳过)。
pub fn preview_write_state_for(project : ProjectRecord) -> PreviewWriteState? {
  match project.scanned.program_packages {
    [first, ..] => {
      let files = @project.preview_harness_files(project.module_name, first)
      let queued : Array[(String, String)] = []
      for file in files {
        queued.push(
          (
            project.root + "/" + @project.PREVIEW_PACKAGE_REL + "/" + file.0,
            file.1,
          ),
        )
      }
      Some(PreviewWriteState::{ files: queued, done: 0, })
    }
    [] => None
  }
}

///|
/// 预览 harness 的待写文件(结构体 spread 共享数组,按索引取,不取出改)。
pub fn preview_write_current(state : PreviewWriteState) -> (String, String)? {
  if state.done >= 0 && state.done < state.files.length() {
    Some(state.files[state.done])
  } else {
    None
  }
}

///|
/// 预览 web 控制束(M2-2):静态服务端口/目录设置 + webview 命令。
/// 平台入口在组合根装配(native 真实现;web/测试用 noop)。
pub(all) struct PreviewWebControls {
  /// 静态服务实际端口(0 = 未启动/web 不可用)
  port : Int
  /// 设置静态服务的服务目录(构建回执后调用)
  set_directory : (String) -> Unit
  /// webview 导航(返回 Effect 走运行时 effect 泵)
  navigate : (String) -> @moui.Effect[Msg]
  /// webview 刷新(重建后)
  reload : () -> @moui.Effect[Msg]
}

///|
pub fn noop_preview_web_controls() -> PreviewWebControls {
  {
    port: 0,
    set_directory: _directory => (),
    navigate: _url => @moui.Effect::none(),
    reload: () => @moui.Effect::none(),
  }
}
