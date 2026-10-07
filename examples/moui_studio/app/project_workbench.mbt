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
/// 单模块导入(旧 ProjectWalkCompleted 单模块臂原样):upsert + 通知 +
/// 预览 harness 落盘(逐文件写 .studio/preview,回执推进游标)。
pub fn import_single_source(
  model : Model,
  files : @services.FileServices,
  source : @project.ProjectSource,
) -> (Model, @moui.Effect[Msg]) {
  match project_record_from_source(source) {
    Ok(record) => {
      // 同 root 原位替换（重复导入=刷新扫描），新工程成为当前选中
      let (projects, index) = upsert_project(model.projects, record)
      let notified = with_notice(
        { ..model, projects, active_project: index, scan_progress: None, },
        text_with(translator(model), "app.project.imported", [
          ("name", record.module_name),
        ]),
        false,
      )
      mark_projects_dirty(notified)
      match preview_write_state_for(record) {
        None => (notified, @moui.Effect::none())
        Some(state) =>
          match preview_write_current(state) {
            None => (notified, @moui.Effect::none())
            Some((path, content)) =>
              (
                { ..notified, preview_write: Some(state), },
                files
                .write_text(path, content)
                .effect(map=r => PreviewFileWritten(r)),
              )
          }
      }
    }
    Err(msg) => (with_notice(model, msg, true), @moui.Effect::none())
  }
}

///|
/// 工作区导入(G2):逐成员建记录并 upsert(最后一个成功成员成为 active);
/// 失败成员与坏成员全部进汇总通知——绝不静默。无预览 harness
/// (workspace 成员按单模块重新导入即得,见计划 Non-goals)。
pub fn import_workspace_scan(
  model : Model,
  scan : @project.WorkspaceScan,
) -> (Model, @moui.Effect[Msg]) {
  let t = translator(model)
  let mut projects = model.projects
  let mut last_index = model.active_project
  let mut imported = 0
  let skipped : Array[String] = []
  for source in scan.loaded {
    match project_record_from_source(source) {
      Ok(record) => {
        let (next, index) = upsert_project(projects, record)
        projects = next
        last_index = index
        imported = imported + 1
      }
      Err(msg) => skipped.push(msg)
    }
  }
  for entry in scan.failed {
    let (path, reason) = entry
    skipped.push("\{path}:\{reason}")
  }
  if imported == 0 {
    // 全部失败:用第一条原因说话(逐条列 54 行没人读,修复指引在原因里)
    let reason = if skipped.length() > 0 { skipped[0] } else { "无成员" }
    (
      with_notice(
        { ..model, scan_progress: None, },
        text_with(t, "app.project.import_failed", [("reason", reason)]),
        true,
      ),
      @moui.Effect::none(),
    )
  } else {
    let message = if skipped.is_empty() {
      text_with(t, "app.project.imported_n", [("n", imported.to_string())])
    } else {
      text_with(t, "app.project.import_summary", [
        ("n", imported.to_string()),
        ("m", skipped.length().to_string()),
        ("reason", skipped[0]),
      ])
    }
    let notified = with_notice(
      { ..model, projects, active_project: last_index, scan_progress: None, },
      message,
      false,
    )
    mark_projects_dirty(notified)
    (notified, @moui.Effect::none())
  }
}

///|
/// 工程工作台存储格式（G2 W3）：`.studio/projects.json` 的
/// `moui.studio.projects v1`。只存 {root, module_name} + active_root——
/// 不落扫描树（数千目录的 JSON 又大又立刻陈旧），启动重扫拿新鲜树。
/// 未知版本/格式拒绝不迁移（与 ai-sessions 同纪律）。
const PROJECTS_STORE_FORMAT : String = "moui.studio.projects"

///|
const PROJECTS_STORE_VERSION : Int = 1

///|
/// 编码当前工程列表（root/module_name 摘要 + active_root）。
pub fn encode_project_store(model : Model) -> String {
  let items : Array[Json] = []
  for project in model.projects {
    let item = Map([])
    item["root"] = Json::string(project.root)
    item["module_name"] = Json::string(project.module_name)
    items.push(Json::object(item))
  }
  let active_root = if model.active_project >= 0 &&
    model.active_project < model.projects.length() {
    model.projects[model.active_project].root
  } else {
    ""
  }
  let root = Map([])
  root["format"] = Json::string(PROJECTS_STORE_FORMAT)
  root["version"] = Json::number(PROJECTS_STORE_VERSION.to_double())
  root["active_root"] = Json::string(active_root)
  root["projects"] = Json::array(items)
  Json::object(root).stringify()
}

///|
/// 解码存储文本 → (active_root, [(root, module_name)])。任何结构不符都
/// 结构化报错，调用方决定是否说话（boot 首跑文件不存在 = Failure 静默）。
pub fn decode_project_store(
  text : String,
) -> Result[(String, Array[(String, String)]), String] {
  let payload = @json.parse(text) catch {
    _ => return Err("projects.json:不是合法 JSON")
  }
  let fields = match payload {
    Object(fields) => fields
    _ => return Err("projects.json:不是 JSON 对象")
  }
  let format_ok = match fields.get("format") {
    Some(String(value)) => value == PROJECTS_STORE_FORMAT
    _ => false
  }
  if !format_ok {
    return Err("projects.json:格式标识不符")
  }
  let version_ok = match fields.get("version") {
    Some(Number(value, ..)) => value == PROJECTS_STORE_VERSION.to_double()
    _ => false
  }
  if !version_ok {
    return Err("projects.json:未知版本(拒绝迁移,请重新导入)")
  }
  let active_root = match fields.get("active_root") {
    Some(String(value)) => value
    _ => ""
  }
  let items = match fields.get("projects") {
    Some(Array(values)) => values
    _ => return Err("projects.json:缺少 projects 数组")
  }
  let records : Array[(String, String)] = []
  for item in items {
    match item {
      Object(item_fields) => {
        let root = match item_fields.get("root") {
          Some(String(value)) => value
          _ => return Err("projects.json:成员缺 root")
        }
        let name = match item_fields.get("module_name") {
          Some(String(value)) => value
          _ => return Err("projects.json:成员缺 module_name")
        }
        records.push((root, name))
      }
      _ => return Err("projects.json:成员不是对象")
    }
  }
  Ok((active_root, records))
}

///|
/// 工程列表结构性变化的统一出口（ai-sessions 同款）：进 outbox 事件,
/// 由总线翻译成写盘请求（未配置存储路径的组合根不注册监听器 → 零开销）。
pub fn mark_projects_dirty(model : Model) -> Unit {
  model.outbox.push(EvProjectsDirty)
}

///|
/// boot 恢复收尾：全部重扫回来后按存储的 active_root 落位选中（找不到
/// 就 -1 = 无），并清掉临时恢复态。
pub fn finish_restore_active(model : Model) -> Model {
  let mut index = -1
  let mut i = 0
  for project in model.projects {
    if project.root == model.restore_active_root {
      index = i
    }
    i = i + 1
  }
  { ..model, active_project: index, restore_active_root: "", }
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
/// 构建提交签名与预览 web 控制束的类型定义已收编进内核服务注册表
/// （`kernel/services.mbt`，M1 插件化）；这里保留公开别名，既有引用零改动
/// （`PreviewWebControls` 在内核泛型于消息类型，app 侧固化为本包 Msg）。
pub type BuildSubmit = @kernel.BuildSubmit

///|
pub type PreviewWebControls = @kernel.PreviewWebControls[Msg]

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
/// 预览 web 控制束的类型定义与 noop 已收编进内核
/// （`kernel/services.mbt` 的 `PreviewWebControls[Msg]`，M1 插件化）；
/// app 侧别名见本文件顶部。

///|
/// active tab（G4 多标签;下标越界 = None）。
pub fn active_project_file(model : Model) -> OpenProjectFile? {
  if model.open_file_index >= 0 &&
    model.open_file_index < model.open_project_files.length() {
    Some(model.open_project_files[model.open_file_index])
  } else {
    None
  }
}

///|
/// tab 脏标记：草稿偏离落盘基准。
pub fn file_is_dirty(open : OpenProjectFile) -> Bool {
  open.draft != open.saved_content
}

///|
/// 任一 tab 脏（「保存全部」chip 的出现条件）。
pub fn any_file_dirty(model : Model) -> Bool {
  for file in model.open_project_files {
    if file_is_dirty(file) {
      return true
    }
  }
  false
}

///|
/// 打开文件 upsert:同 rel 原位替换（重新读取=刷新内容）,否则追加并激活。
pub fn upsert_open_file(
  files : Array[OpenProjectFile],
  open : OpenProjectFile,
) -> (Array[OpenProjectFile], Int) {
  let mut existing = -1
  let mut i = 0
  for file in files {
    if file.rel == open.rel {
      existing = i
    }
    i = i + 1
  }
  let next : Array[OpenProjectFile] = []
  for j, file in files {
    if j == existing {
      next.push(open)
    } else {
      next.push(file)
    }
  }
  if existing >= 0 {
    (next, existing)
  } else {
    next.push(open)
    (next, files.length())
  }
}

///|
/// 按 rel 找 tab 下标（无则 None）。
pub fn open_file_index_of(files : Array[OpenProjectFile], rel : String) -> Int? {
  let mut found : Int? = None
  for i, file in files {
    if file.rel == rel {
      found = Some(i)
    }
  }
  found
}

///|
/// 关闭下标处的 tab,并把 active 收敛到合法范围（删的是 active 时停在
/// 同位置的下一个 tab,尾部则回退一格）。
pub fn close_open_file_at(model : Model, index : Int) -> Model {
  if index < 0 || index >= model.open_project_files.length() {
    return model
  }
  let files : Array[OpenProjectFile] = []
  for i, file in model.open_project_files {
    if i != index {
      files.push(file)
    }
  }
  let next_index = if files.is_empty() {
    -1
  } else if index < files.length() {
    index
  } else {
    files.length() - 1
  }
  { ..model, open_project_files: files, open_file_index: next_index, }
}

///|
/// 原位替换下标处的 tab（光标/草稿/脏基准回写）。
pub fn replace_open_file_at(
  files : Array[OpenProjectFile],
  index : Int,
  open : OpenProjectFile,
) -> Array[OpenProjectFile] {
  let next : Array[OpenProjectFile] = []
  for i, file in files {
    if i == index {
      next.push(open)
    } else {
      next.push(file)
    }
  }
  next
}

///|
/// 新文件 rel 校验（G4 CRUD）：非空、不以 `/` 开头（工程内相对路径）、
/// 不含 `..`（不逃逸工程根）。空格等其余字符交给文件系统裁决。
pub fn valid_new_file_rel(rel : String) -> Bool {
  rel != "" && !rel.has_prefix("/") && !rel.contains("..")
}

///|
/// 改名后同步 open tabs:rel 替换,内容与光标状态原样保留。
pub fn rename_open_file(
  files : Array[OpenProjectFile],
  old : String,
  new : String,
) -> Array[OpenProjectFile] {
  let next : Array[OpenProjectFile] = []
  for file in files {
    if file.rel == old {
      next.push({ ..file, rel: new, })
    } else {
      next.push(file)
    }
  }
  next
}

///|
/// 工程文件树里是否已有该 rel（新建重名拒绝的依据）。
pub fn project_has_file(model : Model, rel : String) -> Bool {
  match active_project_of(model) {
    None => false
    Some(project) => {
      let mut found = false
      for pkg in project.scanned.packages {
        for name in pkg.files {
          let file_rel = if pkg.rel_path == "" {
            name
          } else {
            "\{pkg.rel_path}/\{name}"
          }
          if file_rel == rel {
            found = true
          }
        }
      }
      found
    }
  }
}

///|
/// 保存后的 live 诊断（G4 F4）：保存的 .mbt 且编译轨可用、构建空闲、
/// 工程有 web 入口时，发一次 web 构建事件（诊断汇 Problems 的既有链）。
/// 条件不满足全部静默——诊断是顺手送的,不该变成打扰。
pub fn auto_build_after_save(
  model : Model,
  rel : String,
) -> (Model, @moui.Effect[Msg]) {
  if !rel.has_suffix(".mbt") ||
    !model.compile_track_available ||
    model.build_busy {
    return (model, @moui.Effect::none())
  }
  match active_project_of(model) {
    None => (model, @moui.Effect::none())
    Some(project) => {
      let entry_rel = build_entry_rel(BkWebPreview, project)
      if entry_rel == "" {
        (model, @moui.Effect::none())
      } else {
        // 过门即发构建事件（M1 事件化同款）:busy 置位防重复排队
        model.outbox.push(EvBuildSubmit(BkWebPreview, project.root, entry_rel))
        ({ ..model, build_busy: true, }, @moui.Effect::none())
      }
    }
  }
}

///|
/// 插件管理（G7.3）：禁用判定。静态装配的诚实口径——禁用 = 贡献项入口
/// 被过滤（Feature 状态保留），不是运行时卸载；「安装新插件需重新构建」。
pub fn plugin_active(model : Model, id : String) -> Bool {
  !model.plugin_disabled.contains(id)
}

///|
/// 插件存储编码（settings 值是字符串）:逗号连接的禁用 id 列表。
pub fn encode_plugin_disabled(model : Model) -> String {
  let buf = StringBuilder()
  let mut first = true
  for id in model.plugin_disabled {
    if !first {
      buf.write_string(",")
    }
    buf.write_string(id)
    first = false
  }
  buf.to_string()
}

///|
/// 解析存储的禁用清单（空串 = 全部启用;未知 id 忽略）。
pub fn decode_plugin_disabled(text : String) -> Array[String] {
  let ids : Array[String] = []
  if text == "" {
    return ids
  }
  for piece in text.split(",") {
    let id = piece.to_owned()
    if id == "ai" || id == "terminal" || id == "markdown" {
      ids.push(id)
    }
  }
  ids
}
