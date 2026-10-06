///|
/// Studio 跨域事件（M1 插件化）：取代「update 置位 flag → 包装层 diff 消费」
/// 的三个跨域标记（`pending_code_project`/`pending_build`/`build_seq`）。
///
/// 纪律（与 kernel 事件总线同源）：
/// 1. 事件在**事实发生处**发出，载荷显式携带消费方需要的全部数据——消费方
///    （组合根监听器）不回查模型；
/// 2. 事件进 `model.outbox`，程序包装层每趟**排空一次**并经总线翻译成消息；
/// 3. 事件发完即忘：不回读、不计数（顺序由 outbox 数组保持）。
pub(all) enum StudioEvent {
  /// 代码工程骨架待落盘（SelectTemplate / 提案采纳 / .studio.json 迁移器
  /// 三条路的汇合点）。载荷 = 目标目录 + form.mbt + handlers.mbt 全文
  /// （解析在发出点完成，见 `emit_code_project_write`）。
  EvCodeProjectWrite(String, String, String)
  /// 构建请求已过门（工具链可达 + busy 互斥 + 工程在册 + 入口在册）。
  /// 载荷 = kind + 工程根 + 入口包相对路径。
  EvBuildSubmit(@build.BuildKind, String, String)
  /// Web 预览重建完成且 URL 变化（含首次）→ webview 导航。
  EvPreviewWebNavigate(String)
  /// Web 预览重建完成且 URL 未变 → webview 刷新。
  EvPreviewWebReload
  /// 提案被采纳（M3）：语义事实的扩展点——落盘事实由 EvCodeProjectWrite
  /// 承载，本事件供未来插件订阅（当前无消费者 → 排空时零开销 NoEffect）。
  EvProposalAccepted(Int, String)
}

///|
/// 代码工程写盘事件的统一发出点：目录优先取 `pending_open_dir`（迁移器：
/// 旧 .studio.json 所在目录，消费即清位），否则打开工程的首个程序包；
/// 两者皆无时静默不发（与原包装层「静默清位」同语义——首次体验不弹写盘噪音）。
/// `code_project_files` 从当前 IR 快照派生双腿（form.mbt / handlers.mbt），
/// 与导出 bundle 同源。
pub fn emit_code_project_write(model : Model) -> Model {
  let (dir_override, model) = match model.pending_open_dir {
    Some(dir) => (Some(dir), { ..model, pending_open_dir: None, })
    None => (None, model)
  }
  match dir_override {
    Some(dir) => emit_code_project_write_to(model, dir)
    None =>
      match active_project_of(model) {
        Some(project) =>
          match code_project_target(project) {
            Some(pkg) =>
              emit_code_project_write_to(model, "\{project.root}/\{pkg}")
            None => model
          }
        None => model
      }
  }
}

///|
fn emit_code_project_write_to(model : Model, dir : String) -> Model {
  let files = code_project_files(model.program)
  model.outbox.push(EvCodeProjectWrite(dir, files.form_mbt, files.handlers_mbt))
  model
}
