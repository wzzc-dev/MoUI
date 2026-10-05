///|
/// MoUI Studio 应用装配：Program 组合根 + 文件服务流（保存/打开/导出）
/// + 真实 provider 派发。平台入口只负责把 provider_submit 与 timer 接上。

///|
fn noop_compile_cancel() -> Unit {
  ()
}

///|
/// 提案 system prompt（真实 provider 用；从领域包转出，入口只认 app）。
pub fn proposal_system_prompt() -> String {
  @proposals.proposal_system_prompt()
}

///|
/// 讲解 system prompt（真实 provider 的「解释这个程序」）。
pub fn explanation_system_prompt() -> String {
  "You explain a MoUI Studio program to a beginner in Chinese or English (match the source). Walk through it step by step in plain words: what each statement does, why the order matters, and what the user can try changing. Never rewrite the program; only explain."
}

///|
/// 语言持久化键（SettingsServices）。
pub const LANGUAGE_SETTINGS_KEY : String = "studio.language"

///|
/// 真实 provider 请求规格：由 app 组装（面板里的模型名 + 按请求类型
/// 选择的 system 提示），平台入口只负责投递，不再自行拼提示。
pub(all) struct ProviderRequestSpec {
  endpoint : String
  key : String
  model : String
  system : String
  prompt : String
}

///|
/// 真实 provider 提交签名：入口注入，UI 线程从不等待网络。
pub type ProviderSubmit = (
  ProviderRequestSpec,
  (Result[String, String]) -> Unit,
) -> Unit

///|
fn noop_provider_submit(
  _spec : ProviderRequestSpec,
  callback : (Result[String, String]) -> Unit,
) -> Unit {
  callback(Err("真实 provider 未接入"))
}

///|
/// 真编译提交签名：由平台入口注入（macOS 起 native worker；Web/测试用
/// noop）。UI 线程同步返回、从不等待 moon 工具链；工具链进程全部在
/// async worker 上跑，进度与结果都经回调回到 UI 线程（与 provider 同一模式）。
///
/// `on_progress` 让界面在编译过程中就能显示「正在做第 N 步」——没有它，
/// 用户点完编译只能看着一个静态徽标等十几秒，读起来像「卡住了」。
pub type CompileSubmit = (
  String,
  String,
  (@export.CompileProgress) -> Unit,
  (Result[@export.CompileReport, String]) -> Unit,
) -> Unit

///|
fn noop_compile_submit(
  _project_json : String,
  _app_name : String,
  _on_progress : (@export.CompileProgress) -> Unit,
  callback : (Result[@export.CompileReport, String]) -> Unit,
) -> Unit {
  callback(
    Err("本端没有真编译执行器：编译轨仅在 native 入口可达"),
  )
}

///|
/// 产物启动提交签名：由平台入口注入（macOS 起 native worker；Web/测试用
/// noop）。与编译同一模式——UI 线程同步返回，`spawn` 在 worker 上做。
///
/// 启动是**脱离式**的：进程 reparent 到系统 init，Studio 退出不带走它。
/// 所以回调只报「起没起来」，不含退出码（见 services/launch_native）。
pub type LaunchSubmit = (String, (Result[Unit, String]) -> Unit) -> Unit

///|
fn noop_launch_submit(
  _path : String,
  callback : (Result[Unit, String]) -> Unit,
) -> Unit {
  callback(Err("本端没有产物启动执行器：仅 native 入口可达"))
}

///|
/// 产物旁路动作 → 成功 toast 的 i18n 键（三种动作各说各的事实）。
pub fn artifact_done_key(what : ArtifactAction) -> String {
  match what {
    ArtifactCopy => "app.compile.path_copied"
    ArtifactReveal => "app.compile.revealed"
    ArtifactLaunch => "app.compile.launched"
  }
}

///|
/// 服务流入口（**供组合根与测试共用**）：把启动执行器也一并接进来。
///
/// 为什么单独一层：`update_with_provider` 是内部实现，签名会随服务增长而
/// 变；测试要验证「RunArtifact 真的走到启动通道」就得有个稳定入口。
/// 这层不做任何转换，只是把 `LaunchSubmit` 显式传进去。
pub fn update_with_launch_for_test(
  model : Model,
  msg : Msg,
  services : @services.AppServices,
  launch_submit : LaunchSubmit,
) -> (Model, @moui.Effect[Msg]) {
  update_with_provider(
    model,
    msg,
    services,
    noop_provider_submit,
    launch_submit,
    _tag => (),
  )
}

///|
/// 文件服务流：保存 / 打开 / 导出独立应用 / 产物旁路动作。
pub fn update_with_services(
  model : Model,
  msg : Msg,
  services : @services.AppServices,
  preview_web? : PreviewWebControls = noop_preview_web_controls(),
) -> (Model, @moui.Effect[Msg]) {
  match msg {
    // 复制产物路径：走系统剪贴板（native 是 NSPasteboard，Web 是可用的
    // navigator.clipboard 垫片）。成功/失败都回一条 ArtifactActionDone，
    // 让 notice 如实说话——静默失败会让用户以为「复制了」。
    CopyArtifactPath(path) =>
      (
        model,
        services
        .clipboard()
        .write_text(path)
        .effect(map=r => ArtifactActionDone(ArtifactCopy, r)),
      )
    // 在文件夹中打开：把产物**所在目录**交给系统文件管理器。
    //
    // 为什么传目录而不是文件：`file:///…/app` 这类 URL 在 macOS 上会按
    // 默认关联程序「打开」它（.mbt 没有关联时会弹选择器或什么都不做），
    // 而目录 URL 会被 Finder 直接打开——这正是「在文件夹中查看产物」
    // 要的效果，且不需要任何新的平台能力（`UrlServices` 已在三端接好）。
    RevealArtifact(path) =>
      (
        model,
        services
        .urls()
        .open(folder_url_of(path))
        .effect(map=r => ArtifactActionDone(ArtifactReveal, r)),
      )
    ArtifactActionDone(what, result) =>
      // 反馈走 toast（`with_notice` 同一通道）：成功/失败都必须可见——
      // 静默失败会让用户以为「复制了」。
      match result {
        Success(_) =>
          (
            push_toast(
              model,
              text(translator(model), artifact_done_key(what)),
              false,
            ),
            @moui.Effect::none(),
          )
        Failure(error) =>
          (push_toast(model, error.message, true), @moui.Effect::none())
        Cancelled => (model, @moui.Effect::none())
      }
    SaveRequested => {
      let options = @services.FileDialogOptions::new(
        title=text(translator(model), "app.dialog.save"),
        filters=["json"],
        default_name=Some("project.studio.json"),
      )
      (
        model,
        services.files().save_file(options~).effect(map=r => SavePathPicked(r)),
      )
    }
    SavePathPicked(result) =>
      match result {
        Success(path) =>
          // 选中路径本身不是要给用户看的事实（完成/失败马上会说话），
          // 不写 notice 不弹 toast，直接落盘。
          (
            model,
            services
            .files()
            .write_text(path, @codec.encode_program(model.program))
            .effect(map=r => SaveCompleted(r)),
          )
        Failure(error) =>
          (with_notice(model, error.message, true), @moui.Effect::none())
        Cancelled => (model, @moui.Effect::none())
      }
    SaveCompleted(result) =>
      match result {
        Success(_) =>
          (
            // 保存成功：基线对齐当前程序，脏标记由 program() 的集中
            // 包装按 saved_encoding 自动清除。
            with_notice(
              { ..model, saved_encoding: @codec.encode_program(model.program), },
              text(translator(model), "app.status.saved"),
              false,
            ),
            @moui.Effect::none(),
          )
        Failure(error) =>
          (with_notice(model, error.message, true), @moui.Effect::none())
        Cancelled => (model, @moui.Effect::none())
      }
    OpenRequested => {
      let options = @services.FileDialogOptions::new(
        title=text(translator(model), "app.dialog.open"),
        filters=["json"],
      )
      (
        model,
        services.files().open_file(options~).effect(map=r => OpenPathPicked(r)),
      )
    }
    OpenPathPicked(result) =>
      match result {
        Success(path) =>
          // 记下旧文件所在目录（M6③）：迁移器把 form.mbt/handlers.mbt
          // 写到这里，一次性完成格式转换。
          (
            { ..model, pending_open_dir: Some(dirname_of(path)), },
            services
            .files()
            .read_text(path)
            .effect(map=r => OpenReadCompleted(r)),
          )
        Failure(error) =>
          (with_notice(model, error.message, true), @moui.Effect::none())
        Cancelled => (model, @moui.Effect::none())
      }
    OpenReadCompleted(result) =>
      match result {
        Success(source) =>
          // M6③：打开 .studio.json = 一次性迁移。解码失败是结构化报错
          // （携带 codec 原因并指向迁移器口径），不再笼统「打开失败」。
          match migrate_studio_source(
            model.pending_open_dir.unwrap_or("."),
            source,
          ) {
            Ok(outcome) => {
              let program = outcome.program
              let next = {
                ..model,
                program,
                pending: None,
                prompt_draft: "",
                prompt_error: "",
                explanation: "",
                ai_busy: false,
                selected_block: -1,
                block_draft: "",
                drag: None,
                block_drag: None,
                run: None,
                mode: ModeDesign,
                runtime_values: @studio_lang.initial_values(program),
                runtime_texts: @studio_lang.initial_texts(program),
                runtime_rows: @studio_lang.initial_rows(program),
                runtime_selections: Map([], capacity=4),
                undo_stack: [],
                redo_stack: [],
                proposal_history: [],
                // 打开成功：基线对齐新程序（脏标记随之清除）
                saved_encoding: @codec.encode_program(program),
                selected_control: first_control_name(program.controls),
                selected_handler: first_handler_key(program.handlers),
                // 迁移器落盘：组合根写 form.mbt + handlers.mbt 到旧文件目录
                pending_code_project: true,
              }
              (
                with_notice(
                  sync_code_draft(next),
                  text(translator(model), "app.status.opened"),
                  false,
                ),
                @moui.Effect::none(),
              )
            }
            Err(message) =>
              (with_notice(model, message, true), @moui.Effect::none())
          }
        Failure(error) =>
          (with_notice(model, error.message, true), @moui.Effect::none())
        Cancelled => (model, @moui.Effect::none())
      }
    // === 工程工作台（M0）：导入 MoonBit 工程 ===
    // 与 Open 同构的三段链。walk 任务的域级失败（目录不是 MoonBit 模块、
    // 超限）在任务值里是 Err(...)，基础设施失败才是 Failure——两种都要
    // 说话，但文案口径不同：前者是「选错了目录」，后者是「扫描坏了」。
    ImportProjectRequested => {
      let options = @services.FileDialogOptions::new(
        title=text(translator(model), "app.dialog.import_project"),
      )
      (
        model,
        services
        .files()
        .pick_directory(options~)
        .effect(map=r => ProjectRootPicked(r)),
      )
    }
    ProjectRootPicked(result) =>
      match result {
        Success(root) =>
          (
            model,
            @project.walk_project_task(services.files(), root).effect(map=r => {
              ProjectWalkCompleted(r)
            }),
          )
        Failure(error) =>
          (with_notice(model, error.message, true), @moui.Effect::none())
        Cancelled => (model, @moui.Effect::none())
      }
    ProjectWalkCompleted(result) =>
      match result {
        Success(Ok(source)) =>
          match project_record_from_source(source) {
            Ok(record) => {
              // 同 root 原位替换（重复导入=刷新扫描），新工程成为当前选中
              let (projects, index) = upsert_project(model.projects, record)
              let notified = with_notice(
                { ..model, projects, active_project: index, },
                text_with(translator(model), "app.project.imported", [
                  ("name", record.module_name),
                ]),
                false,
              )
              // 预览 harness(M1):工程有逻辑入口就生成 .studio/preview
              // 并逐文件落盘(回执 PreviewFileWritten 推进游标)
              match preview_write_state_for(record) {
                None => (notified, @moui.Effect::none())
                Some(state) =>
                  match preview_write_current(state) {
                    None => (notified, @moui.Effect::none())
                    Some((path, content)) =>
                      (
                        { ..notified, preview_write: Some(state), },
                        services
                        .files()
                        .write_text(path, content)
                        .effect(map=r => PreviewFileWritten(r)),
                      )
                  }
              }
            }
            Err(msg) => (with_notice(model, msg, true), @moui.Effect::none())
          }
        Success(Err(msg)) =>
          (with_notice(model, msg, true), @moui.Effect::none())
        Failure(error) =>
          (with_notice(model, error.message, true), @moui.Effect::none())
        Cancelled => (model, @moui.Effect::none())
      }
    // 删除工程文件(确认流续行,M0-6b):磁盘删除 → 回执后重扫工程
    // (复用导入链,upsert 原位替换刷新文件树)。
    ProjectFileDeleteRun(rel) =>
      match active_project_of(model) {
        None => (model, @moui.Effect::none())
        Some(project) =>
          (
            model,
            services
            .files()
            .delete_file("\{project.root}/\{rel}")
            .effect(map=r => ProjectFileDeleted(rel, r)),
          )
      }
    ProjectFileDeleted(rel, result) =>
      match result {
        Success(_) =>
          match active_project_of(model) {
            None => (model, @moui.Effect::none())
            Some(project) =>
              (
                with_notice(
                  model,
                  text_with(translator(model), "app.project.file_deleted", [
                    ("a", rel),
                  ]),
                  false,
                ),
                @project.walk_project_task(services.files(), project.root).effect(map=r => {
                    ProjectWalkCompleted(r)
                  },
                ),
              )
          }
        Failure(error) =>
          (with_notice(model, error.message, true), @moui.Effect::none())
        Cancelled => (model, @moui.Effect::none())
      }
    // 构建服务(M0-7):kind 分发。StudioCompile 回路由既有编译轨
    // (CompileRun,五阶段管线),其余 kind 经注入的 build_submit 走
    // build_native 的单命令执行。门:工具链能力与编译轨同口径。
    ProjectBuildRun(kind) => {
      let gate = if !model.compile_track_available {
        Some(text(translator(model), "app.track.unavailable_web"))
      } else if model.build_busy {
        Some(text(translator(model), "app.project.build_busy"))
      } else {
        None
      }
      match gate {
        Some(message) =>
          (with_notice(model, message, true), @moui.Effect::none())
        None =>
          match active_project_of(model) {
            None =>
              (
                with_notice(
                  model,
                  text(translator(model), "app.project.no_project"),
                  true,
                ),
                @moui.Effect::none(),
              )
            Some(project) => {
              let entry_rel = build_entry_rel(kind, project)
              if entry_rel == "" {
                (
                  with_notice(
                    model,
                    text(translator(model), "app.project.no_entry"),
                    true,
                  ),
                  @moui.Effect::none(),
                )
              } else {
                (
                  {
                    ..model,
                    build_busy: true,
                    pending_build: Some(ProjectBuildRequest::{
                      kind,
                      root: project.root,
                      entry_rel,
                    }),
                  },
                  @moui.Effect::none(),
                )
              }
            }
          }
      }
    }
    ProjectBuildFinished(kind, result) =>
      match result {
        Ok(report) => {
          // 诊断落 last_build,由 Problems 汇流渲染;busy 复位
          let cleared = {
            ..model,
            last_build: Some(report),
            build_busy: false,
          }
          // FramePreview 成功(M1-2):解析哨兵协议 → 可重放帧
          let with_frame = if kind is BkFramePreview && report.ok {
            match parse_preview_frame(report.output) {
              Ok(frame) => { ..cleared, preview_frame: Some(frame), }
              Err(message) =>
                return (
                  with_notice(cleared, message, true),
                  @moui.Effect::none(),
                )
            }
          } else {
            cleared
          }
          // WebPreview 成功(M2-2):设静态服务目录 + 组预览 URL +
          // 存 build_seq(wrapper 据此派发 navigate/首次后 reload)
          let with_web = if kind is BkWebPreview && report.ok {
            (preview_web_controls().set_directory)(report.web_root)
            let url = "http://127.0.0.1:\{preview_web_controls().port}/\{report.web_index_rel}"
            {
              ..with_frame,
              preview_web_url: Some(url),
              preview_web_opened: true,
              preview_mode: PmWeb,
              workspace: WsPreview,
              build_seq: model.build_seq + 1,
            }
          } else {
            with_frame
          }
          // RunNative 成功(M3):产物落盘 → **自动脱离启动**(独立窗口,
          // Studio 退出不带走它——复用产物启动通道,零新执行路径)
          if kind is BkRunNative && report.ok && report.artifact_path != "" {
            (
              with_web,
              @moui.Effect::batch([
                @moui.Effect::dispatch(emit => {
                  emit(RunArtifact(report.artifact_path))
                }),
              ]),
            )
          } else {
            (
              with_notice(
                with_web,
                if report.ok {
                  text_with(translator(model), "app.project.build_ok", [
                    ("a", kind.tag()),
                  ])
                } else {
                  text_with(translator(model), "app.project.build_failed", [
                    ("a", kind.tag()),
                  ])
                },
                !report.ok,
              ),
              @moui.Effect::none(),
            )
          }
        }
        Err(message) =>
          (
            with_notice({ ..model, build_busy: false, }, message, true),
            @moui.Effect::none(),
          )
      }
    // 预览 harness 落盘回执(M1):成功推进游标;全部写完 = 预览就绪;
    // 失败(典型:web 端无写盘)显式声明并放弃本轮落盘。
    PreviewFileWritten(result) =>
      match (model.preview_write, result) {
        (None, _) => (model, @moui.Effect::none())
        (Some(_), Cancelled) =>
          ({ ..model, preview_write: None, }, @moui.Effect::none())
        (Some(_), Failure(error)) =>
          (
            with_notice(
              { ..model, preview_write: None, },
              text_with(translator(model), "app.project.preview_failed", [
                ("a", error.message),
              ]),
              true,
            ),
            @moui.Effect::none(),
          )
        (Some(state), Success(_)) => {
          let advanced = { ..state, done: state.done + 1, }
          match preview_write_current(advanced) {
            None =>
              (
                with_notice(
                  { ..model, preview_write: None, },
                  text(translator(model), "app.project.preview_ready"),
                  false,
                ),
                @moui.Effect::none(),
              )
            Some((path, content)) =>
              (
                { ..model, preview_write: Some(advanced), },
                services
                .files()
                .write_text(path, content)
                .effect(map=r => PreviewFileWritten(r)),
              )
          }
        }
      }
    // 字面量属性补丁(M1-3):读程序包源文件 → 定位字面量 → 转义回写 →
    // 成功后**自动走 BkFramePreview 重建**(点标题改文本 → 重建出新帧)。
    SemanticLabelCommit =>
      match semantic_commit_request(model) {
        None => (model, @moui.Effect::none())
        Some(Err(message)) =>
          (with_notice(model, message, true), @moui.Effect::none())
        Some(Ok(request)) =>
          (
            model,
            semantic_label_patch_task(services.files(), request).effect(map=r => {
              match r {
                @services.Success(result) => SemanticPatchFinished(result)
                @services.Failure(error) =>
                  SemanticPatchFinished(Err(error.message))
                @services.Cancelled => SemanticPatchFinished(Err("已取消"))
              }
            }),
          )
      }
    SemanticPatchFinished(result) =>
      match result {
        Ok(path) =>
          // 补丁成功:通知 + **自动重建预览**(点标题改文本 → 重建出新帧)
          (
            with_notice(
              model,
              text_with(translator(model), "app.project.label_patched", [
                ("a", path),
              ]),
              false,
            ),
            @moui.Effect::dispatch(emit => emit(ProjectBuildRun(BkFramePreview))),
          )
        Err(message) =>
          (with_notice(model, message, true), @moui.Effect::none())
      }
    // 表单设计器(M4-2):form.mbt 加载/编辑/保存链。
    FormDesignOpen =>
      match (active_project_of(model), form_design_rel_of(model)) {
        (Some(project), Some(form_rel)) =>
          (
            model,
            form_design_load_task(services.files(), project.root, form_rel).effect(map=r => {
                FormDesignLoaded(r)
              },
            ),
          )
        _ => (model, @moui.Effect::none())
      }
    FormDesignLoaded(result) =>
      match result {
        Success(source) =>
          match @form_designer.parse_form(source) {
            Err(message) =>
              (with_notice(model, message, true), @moui.Effect::none())
            Ok(parsed) => {
              let project = match active_project_of(model) {
                Some(project) => project
                None => return (model, @moui.Effect::none())
              }
              let form_rel = match form_design_rel_of(model) {
                Some(rel) => rel
                None => return (model, @moui.Effect::none())
              }
              (
                {
                  ..model,
                  form_designer: Some(FormDesignerSession::{
                    root: project.root,
                    form_rel,
                    source,
                    parsed,
                  }),
                },
                @moui.Effect::none(),
              )
            }
          }
        Failure(error) =>
          (with_notice(model, error.message, true), @moui.Effect::none())
        Cancelled => (model, @moui.Effect::none())
      }
    FormDesignDragEnd(index, dx, dy) =>
      match model.form_designer {
        None => (model, @moui.Effect::none())
        Some(session) => {
          let (next_session, changed) = form_design_apply_move(
            session, index, dx, dy,
          )
          if changed {
            form_design_write_effect(model, next_session, services.files())
          } else {
            (model, @moui.Effect::none())
          }
        }
      }
    FormDesignResizeEnd(index, dw, dh) =>
      match model.form_designer {
        None => (model, @moui.Effect::none())
        Some(session) => {
          let (next_session, changed) = form_design_apply_resize(
            session, index, dw, dh,
          )
          if changed {
            form_design_write_effect(model, next_session, services.files())
          } else {
            (model, @moui.Effect::none())
          }
        }
      }
    FormDesignSaved(result) =>
      match result {
        Success(_) =>
          // 三模式联动（M4）：拖拽/缩放保存 → span 补丁写回 form.mbt →
          // **自动重建预览**——模式一重放新帧；模式二经 build_seq 变化
          // 触发 webview reload（preview_web_effect 的 rebuilt 分支）。
          (
            with_notice(
              model,
              text(translator(model), "app.project.external_reloaded"),
              false,
            ),
            @moui.Effect::dispatch(emit => emit(ProjectBuildRun(BkFramePreview))),
          )
        Failure(error) =>
          (with_notice(model, error.message, true), @moui.Effect::none())
        Cancelled => (model, @moui.Effect::none())
      }
    // 外部改动重载（M8）：手动刷新入口 → 读 form.mbt → 回执比对。
    // 设计器会话未打开时静默（刷新芯片只在会话存在时显示）。
    FormDesignExternalCheck =>
      match model.form_designer {
        None => (model, @moui.Effect::none())
        Some(session) =>
          (
            model,
            services
            .files()
            .read_text("\{session.root}/\{session.form_rel}")
            .effect(map=r => FormDesignExternalChecked(r)),
          )
      }
    FormDesignExternalChecked(result) =>
      match (model.form_designer, result) {
        (Some(session), Success(new_source)) =>
          if new_source == session.source {
            (model, @moui.Effect::none())
          } else {
            match @form_designer.parse_form(new_source) {
              Err(message) =>
                (
                  with_notice(
                    model,
                    text_with(translator(model), "app.project.external_parse_error", [
                      ("a", message),
                    ]),
                    true,
                  ),
                  @moui.Effect::none(),
                )
              Ok(parsed) =>
                (
                  with_notice(
                    {
                      ..model,
                      form_designer: Some(
                        {
                          ..session,
                          source: new_source,
                          parsed,
                        },
                      ),
                    },
                    text(translator(model), "app.project.external_reloaded"),
                    false,
                  ),
                  @moui.Effect::none(),
                )
            }
          }
        // 无会话时静默忽略外部读取结果
        (None, Success(_)) => (model, @moui.Effect::none())
        (_, Failure(error)) =>
          (with_notice(model, error.message, true), @moui.Effect::none())
        (_, Cancelled) => (model, @moui.Effect::none())
      }
    // 代码工程骨架落盘回执（M6①）：两份文件各回一条，成功给一条
    // 静默 notice（重渲自动生效），失败如实说话。
    CodeProjectSaved(result) =>
      match result {
        Success(_) => (model, @moui.Effect::none())
        Failure(error) =>
          (with_notice(model, error.message, true), @moui.Effect::none())
        Cancelled => (model, @moui.Effect::none())
      }
    // 导出独立应用：native 有系统目录选择 + 逐文件写盘    // 导出独立应用：native 有系统目录选择 + 逐文件写盘    // 导出独立应用：native 有系统目录选择 + 逐文件写盘；Web 端的目录
    // 「选择」返回的是文件名列表而非可写路径，25 个文件全部写不进去——
    // 与编译轨同一口径：**不可达就显式声明**，不弹一个必然失败的目录框。
    ExportRequested =>
      if !model.export_available {
        (
          with_notice(
            model,
            text(translator(model), "app.export.unavailable_web"),
            true,
          ),
          @moui.Effect::none(),
        )
      } else {
        let options = @services.FileDialogOptions::new(
          title=text(translator(model), "app.dialog.export"),
          filters=[],
        )
        (
          model,
          services
          .files()
          .pick_directory(options~)
          .effect(map=r => ExportDirPicked(r)),
        )
      }
    ExportDirPicked(result) =>
      match result {
        Success(dir) => {
          let bundle = bundle_files(
            @codec.encode_program(model.program),
            sanitize_export_name(model),
          )
          let effects : Array[@moui.Effect[Msg]] = []
          for pair in bundle {
            let path = "\{dir}/\{pair.0}"
            effects.push(
              services
              .files()
              .write_text(path, pair.1)
              .effect(map=r => ExportFileWritten(r)),
            )
          }
          // 中间态直写字段（目录回显），**不走 with_notice**——每个文件
          // 完成时都会回到 ExportFileWritten，真正的「已导出/失败」在
          // 那里 toast 一次；这里再弹就是 25 条同样的 toast。
          (
            {
              ..model,
              notice: path_hint(dir, bundle),
              export_pending: bundle.length(),
            },
            @moui.Effect::batch(effects),
          )
        }
        Failure(error) =>
          (with_notice(model, error.message, true), @moui.Effect::none())
        Cancelled => (model, @moui.Effect::none())
      }
    ExportFileWritten(result) =>
      match result {
        Success(_) => {
          // bundle 有几十个文件，全部落盘才说「已导出」——逐文件报成功
          // 会把一次导出说成 25 次。
          let remaining = model.export_pending - 1
          if remaining <= 0 {
            (
              with_notice(
                { ..model, export_pending: 0, },
                text(translator(model), "app.status.exported"),
                false,
              ),
              @moui.Effect::none(),
            )
          } else {
            ({ ..model, export_pending: remaining, }, @moui.Effect::none())
          }
        }
        Failure(error) =>
          (
            with_notice({ ..model, export_pending: 0, }, error.message, true),
            @moui.Effect::none(),
          )
        Cancelled => (model, @moui.Effect::none())
      }
    // 草稿恢复：上次会话的自动保存内容。基线仍是初始样例，集中包装会把
    // dirty 置真，提示用户保存一份正式文件。
    DraftLoaded(result) =>
      match result {
        Success(Some(source)) =>
          match @codec.decode_program(source) {
            Ok(program) => {
              let next = {
                ..model,
                program,
                pending: None,
                run: None,
                drag: None,
                block_drag: None,
                selected_block: -1,
                block_draft: "",
                runtime_values: @studio_lang.initial_values(program),
                runtime_texts: @studio_lang.initial_texts(program),
                runtime_rows: @studio_lang.initial_rows(program),
                runtime_selections: Map([], capacity=4),
                selected_control: first_control_name(program.controls),
                selected_handler: first_handler_key(program.handlers),
              }
              (sync_code_draft(next), @moui.Effect::none())
            }
            Err(_) => (model, @moui.Effect::none())
          }
        _ => (model, @moui.Effect::none())
      }
    _ => update_pure(model, msg)
  }
}

///|
/// 导出目录名：窗口标题净化（小写 ASCII + 连字符，首尾去连字符）。
fn sanitize_export_name(model : Model) -> String {
  let chars : Array[Char] = []
  let mut last_was_dash = false
  for c in model.program.window.title {
    let code = c.to_int()
    if (code >= 0x61 && code <= 0x7A) || (code >= 0x30 && code <= 0x39) {
      chars.push(c)
      last_was_dash = false
    } else if code >= 0x41 && code <= 0x5A {
      chars.push((code + 0x20).unsafe_to_char())
      last_was_dash = false
    } else if chars.length() > 0 && !last_was_dash {
      chars.push('-')
      last_was_dash = true
    }
  }
  let mut begin = 0
  let mut finish = chars.length()
  while begin < finish && chars[begin] == '-' {
    begin = begin + 1
  }
  while finish > begin && chars[finish - 1] == '-' {
    finish = finish - 1
  }
  let buf = StringBuilder()
  let mut i = begin
  while i < finish {
    buf.write_char(chars[i])
    i = i + 1
  }
  let name = buf.to_string()
  if name == "" {
    "studio-app"
  } else {
    name
  }
}

///|
/// 导出 bundle 文件清单（services/export 的薄封装）。
pub fn bundle_files(
  program_json : String,
  name : String,
) -> Array[(String, String)] {
  @export.export_bundle(program_json, name)
}

///|
fn path_hint(dir : String, bundle : Array[(String, String)]) -> String {
  "\{dir}（\{bundle.length()} 个文件）"
}

///|
/// 产物路径 → 其**所在目录**的 `file://` URL（「在文件夹中打开」用）。
///
/// 传目录而不是文件：文件 URL 会被系统按关联程序「打开」，而目录 URL
/// 由文件管理器直接打开——用户点「在文件夹中打开」要的是定位，不是执行。
///
/// 路径按 URL 规则转义（空格 → `%20` 等）。不做转义的话，TMPDIR 里带
/// 空格的用户名会让 `NSURL` 解析失败，按钮点了没反应。
pub fn folder_url_of(path : String) -> String {
  let dir = match path.rev_find("/") {
    Some(index) => if index == 0 { "/" } else { path[:index].to_owned() }
    None => path
  }
  "file://" + percent_encode_path(dir)
}

///|
/// 文件路径 → URL 路径段转义：保留 `/` 与 URL 非保留字符，其余百分号编码。
///
/// 按 **UTF-8 字节**编码：直接对 `Char` 编码会把非 ASCII 字符的码点当字节
/// 写进 URL（`中` → `%4E2D` 而不是 `%E4%B8%AD`），`NSURL` 解析出来的路径
/// 与磁盘上的目录对不上——用户名或目录名带中文时「在文件夹中打开」会失败。
/// 这里手写 UTF-8 展开，避免为一个转义函数给 app 包引入新的依赖。
fn percent_encode_path(path : String) -> String {
  let buf = StringBuilder()
  let hex = "0123456789ABCDEF"
  for c in path {
    let value = c.to_int()
    // 非保留字符与 `/` 原样保留
    let unreserved = (value >= 0x41 && value <= 0x5A) ||
      (value >= 0x61 && value <= 0x7A) ||
      (value >= 0x30 && value <= 0x39) ||
      value == 0x2D ||
      value == 0x2E ||
      value == 0x5F ||
      value == 0x7E ||
      value == 0x2F
    if unreserved {
      buf.write_char(c)
    } else {
      for byte in utf8_bytes(value) {
        buf.write_char('%')
        buf.write_char(hex[(byte >> 4) & 0xF].unsafe_to_char())
        buf.write_char(hex[byte & 0xF].unsafe_to_char())
      }
    }
  }
  buf.to_string()
}

///|
/// 码点 → UTF-8 字节序列（1–4 字节），逐字节百分号编码用。
fn utf8_bytes(code : Int) -> Array[Int] {
  if code < 0x80 {
    [code]
  } else if code < 0x800 {
    [0xC0 | (code >> 6), 0x80 | (code & 0x3F)]
  } else if code < 0x10000 {
    [0xE0 | (code >> 12), 0x80 | ((code >> 6) & 0x3F), 0x80 | (code & 0x3F)]
  } else {
    [
      0xF0 | (code >> 18),
      0x80 | ((code >> 12) & 0x3F),
      0x80 | ((code >> 6) & 0x3F),
      0x80 | (code & 0x3F),
    ]
  }
}

///|
/// 设置读取结果 → 语言 tag（无值/失败 = 空串 → 回退中文）。
fn language_tag_of(result : @services.ServiceTaskResult[String?]) -> String {
  match result {
    Success(tag) =>
      match tag {
        Some(text) => text
        None => ""
      }
    _ => ""
  }
}

///|
/// 运行推进的计时器订阅：仅运行中激活。
fn run_subscription(
  model : Model,
  timer : @services.TimerSource?,
) -> @moui.Subscription[Msg] {
  // 虚拟时钟（切片 G）：窗体定时器开启且运行中时，用帧时间把每秒一帧
  // 标成 TimerTick——设计态订阅不活跃，时钟不走，这就是「虚拟」。
  let interpret_live = match model.run {
    Some(run) => run.state.status is @studio_lang.Running
    None => false
  }
  let compiled_live = model.compiled_run is Some(_) &&
    model.program.window.timer_interval > 0 &&
    app_running(model)
  // 定时器开着且编译轨活时，解释轨的 30ms 订阅也要标出秒帧——
  // 虚拟时钟在两轨上的步进口径一致。
  let timer_on = model.program.window.timer_interval > 0 && app_running(model)
  // toast 老化订阅：只要有 toast 在屏上，每秒发一次 ToastTick。
  // 与运行订阅 batch 合并——运行中 toast 也会照常过期。
  let toast_subscription = match (timer, model.toasts.length() > 0) {
    (Some(source), true) =>
      source.subscription(interval_ms=1000.0, map=_frame => ToastTick)
    _ => @moui.Subscription::none()
  }
  let run_subscription_plan = match timer {
    Some(source) =>
      if interpret_live {
        if timer_on {
          source.subscription(interval_ms=30.0, map=frame => {
            if frame.time_ms % 1000.0 < 30.0 {
              TimerTick
            } else {
              RunTick
            }
          })
        } else {
          source.subscription(interval_ms=30.0, map=_frame => RunTick)
        }
      } else if compiled_live {
        source.subscription(interval_ms=1000.0, map=_frame => TimerTick)
      } else {
        @moui.Subscription::none()
      }
    None => @moui.Subscription::none()
  }
  @moui.Subscription::batch([run_subscription_plan, toast_subscription])
}

///|
/// Program 组合根。provider_submit 由平台入口注入（macOS 真实 worker；
/// Web 入口注入 noop——浏览器只用离线假模型）。
pub fn program(
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
  provider_submit? : ProviderSubmit = noop_provider_submit,
  compile_submit? : CompileSubmit = noop_compile_submit,
  launch_submit? : LaunchSubmit = noop_launch_submit,
  runtime_snapshot? : RuntimeSnapshotFn = noop_runtime_snapshot,
  compile_cancel? : () -> Unit = noop_compile_cancel,
  build_submit? : BuildSubmit = noop_build_submit,
  build_cancel? : () -> Unit = noop_build_cancel,
  webview_controller? : @webview_host.WebViewController? = None,
  preview_web? : PreviewWebControls = noop_preview_web_controls(),
  provider_config? : ProviderConfig,
  compile_track_available? : Bool = false,
  export_available? : Bool = false,
  immersive? : Bool = false,
  apply_locale? : (String) -> Unit = _tag => (),
) -> @moui.Program[Model, Msg] {
  let services = environment.services()
  let timer = environment.timer()
  let submit = provider_submit
  let submit_compile = compile_submit
  let submit_launch = launch_submit
  let take_snapshot = runtime_snapshot
  let cancel_compile = compile_cancel
  let submit_build = build_submit
  let web_controls = preview_web
  let web_controller = webview_controller
  let on_locale = apply_locale
  // 预览 web 控制注入(M2-2):槽位供视图与处理器读取
  install_preview_web(webview_controller, Some(preview_web))
  @moui.Program::new_with_environment(
    init=() => {
      (
        initial_model(
          provider_config?,
          compile_track_available~,
          export_available~,
          immersive~,
        ),
        @moui.Effect::batch([
          services
          .settings()
          .read(LANGUAGE_SETTINGS_KEY)
          .effect(map=result => LanguageLoaded(language_tag_of(result))),
          services
          .settings()
          .read(DRAFT_SETTINGS_KEY)
          .effect(map=result => DraftLoaded(result)),
        ]),
      )
    },
    update=(model, msg) => {
      let (next0, effect0) = match msg {
        // 「停止编译」= 真终止：清 UI 状态之外还要杀掉正在跑的 moon
        // 子进程（旧实现只清状态，工具链继续后台跑完，进程表可见）。
        CompileStopped => {
          cancel_compile()
          update_pure(model, msg)
        }
        // 打开项目是覆盖性动作：有未保存修改时先要确认（破坏性操作
        // 确认纪律）。确认续行带 `open_confirmed` 一次性放行标记——
        // 放行即复位，标记不会泄漏到下一次打开。
        OpenRequested =>
          if model.dirty &&
            model.pending_confirm is None &&
            !model.open_confirmed {
            update_pure(model, RequestConfirm(CkOpen))
          } else {
            let (next, effect) = update_with_provider(
              model, msg, services, submit, submit_launch, on_locale,
            )
            ({ ..next, open_confirmed: false, }, effect)
          }
        SaveRequested
        | SavePathPicked(_)
        | SaveCompleted(_)
        | OpenPathPicked(_)
        | OpenReadCompleted(_)
        | ExportRequested
        | ExportDirPicked(_)
        | ExportFileWritten(_)
        | DraftLoaded(_)
        // 产物旁路动作（复制路径 / 在文件夹中打开 / **一键启动**）也必须走
        // **这一条**分支：它们要碰剪贴板、文件管理器与进程，属于服务流；
        // 纯转移链遇到它们返回 None（见 update_run_msgs），不在这里接住
        // 就会被静默丢弃——按钮点了没反应。
        | CopyArtifactPath(_)
        | RevealArtifact(_)
        | RunArtifact(_)
        | ArtifactActionDone(_)
        | GenerateProposal
        | RealGenerationFinished(_)
        | ExplainHandler
        | RealExplanationFinished(_)
        | SwitchLanguage
        | LanguageLoaded(_) =>
          update_with_provider(
            model, msg, services, submit, submit_launch, on_locale,
          )
        _ => {
          // 默认臂走 **update_with_services**（它的默认臂就是 update_pure，
          // 是严格超集）：导入工程/表单设计器/语义补丁等服务消息只有这
          // 一层接得住——此前默认臂直通 update_pure，导入按钮点了没反应
          //（服务消息被静默丢弃，实测缺陷）。
          let (next, effect) = update_with_services(
            model, msg, services, preview_web~,
          )
          // 运行时检查器挂载：只有「打开 Runtime 页签 / 显式刷新」两条
          // 路径会真正采样（O(节点数) 的全树遍历），其余消息零开销通过。
          // effect 必须与原 effect 合并——确认卡的打开续行（CkOpen 的
          // Effect::dispatch(OpenRequested)）就走在 update_pure 里。
          let (next2, refresh_effect) = runtime_refresh_attached(
            next, msg, take_snapshot,
          )
          (next2, @moui.Effect::batch([effect, refresh_effect]))
        }
      }
      // 真编译派发：只有「CompileRun 使 compile_busy 从假变真」这一次
      // 转移才入队——重复点击/其它消息不会重复排队。项目 JSON 在此编码，
      // 与导出 bundle 的输入是同一份（预览源码 = bundle 内实际编译源码）。
      // 预览 webview(M2-2):url 变化 → navigate;同 url 重建 → reload。
      // 控制器缺失(web 入口)时跳过——web 模式显式不可用。
      let preview_web_effect = if web_controls.port > 0 {
        match web_controller {
          Some(controller) => {
            let url_changed = match
              (model.preview_web_url, next0.preview_web_url) {
              (Some(old_url), Some(new_url)) => old_url != new_url
              (None, Some(_)) => true
              _ => false
            }
            let rebuilt = next0.build_seq != model.build_seq &&
              next0.preview_mode is PmWeb &&
              next0.preview_web_opened
            if url_changed {
              match next0.preview_web_url {
                Some(url) => controller.navigate(url).effect(map=_ => Msg::Noop)
                None => @moui.Effect::none()
              }
            } else if rebuilt && !url_changed {
              controller.reload().effect(map=_ => Msg::Noop)
            } else {
              @moui.Effect::none()
            }
          }
          None => @moui.Effect::none()
        }
      } else {
        @moui.Effect::none()
      }
      // 构建服务(M0-7):busy 上升 = 有新请求 → 派发注入的 build_submit
      // (回调 emit ProjectBuildFinished,回执落 last_build 并汇进 Problems)
      let build_effect = if next0.build_busy && !model.build_busy {
        match next0.pending_build {
          Some(request) =>
            @moui.Effect::dispatch(emit => {
              submit_build(request.kind, request.root, request.entry_rel, result => {
                emit(ProjectBuildFinished(request.kind, result))
              })
            })
          None => @moui.Effect::none()
        }
      } else {
        @moui.Effect::none()
      }
      let compile_effect = if compile_submit_needed(model, next0) {
        let json = @codec.encode_program(next0.program)
        let name = sanitize_export_name(next0)
        @moui.Effect::dispatch(emit => {
          submit_compile(
            json,
            name,
            progress => emit(CompileProgress(progress)),
            result => {
              match result {
                Ok(report) => emit(CompileRunFinished(report))
                Err(message) => emit(CompileRunFailed(message))
              }
            },
          )
        })
      } else {
        @moui.Effect::none()
      }
      // 集中脏标记 + 草稿自动保存：程序编码偏离基线即标脏（标题旁 ●）；
      // 内容相对上次草稿有变化才写 settings，运行期 30fps 的 RunTick
      // 不改程序，不会反复写。
      let encoding = @codec.encode_program(next0.program)
      let dirty = encoding != next0.saved_encoding
      let should_write = dirty && encoding != next0.draft_encoding
      // 代码工程骨架落盘（M6①/M6③）：SelectTemplate / 提案采纳 / 打开
      // 迁移交错的置位标记 → 写 form.mbt + handlers.mbt。写盘目录优先取
      // `pending_open_dir`（迁移器：旧 .studio.json 所在目录），否则打开
      // 工程的首个程序包；两者皆无时静默清位。
      let code_project_effect = if next0.pending_code_project {
        match next0.pending_open_dir {
          Some(dir) => {
            let files = code_project_files(next0.program)
            @moui.Effect::batch([
              services
              .files()
              .write_text("\{dir}/form.mbt", files.form_mbt)
              .effect(map=r => CodeProjectSaved(r)),
              services
              .files()
              .write_text("\{dir}/handlers.mbt", files.handlers_mbt)
              .effect(map=r => CodeProjectSaved(r)),
            ])
          }
          None =>
            match active_project_of(next0) {
              Some(project) =>
                match code_project_target(project) {
                  Some(pkg) => {
                    let files = code_project_files(next0.program)
                    let root = project.root
                    @moui.Effect::batch([
                      services
                      .files()
                      .write_text("\{root}/\{pkg}/form.mbt", files.form_mbt)
                      .effect(map=r => CodeProjectSaved(r)),
                      services
                      .files()
                      .write_text(
                        "\{root}/\{pkg}/handlers.mbt",
                        files.handlers_mbt,
                      )
                      .effect(map=r => CodeProjectSaved(r)),
                    ])
                  }
                  None => @moui.Effect::none()
                }
              None => @moui.Effect::none()
            }
        }
      } else {
        @moui.Effect::none()
      }
      let next = {
        ..next0,
        pending_code_project: false,
        pending_open_dir: if next0.pending_code_project {
          None
        } else {
          next0.pending_open_dir
        },
        dirty,
        draft_encoding: if should_write {
          encoding
        } else {
          next0.draft_encoding
        },
      }
      let effect = if should_write {
        @moui.Effect::batch([
          effect0,
          build_effect,
          preview_web_effect,
          compile_effect,
          code_project_effect,
          services
          .settings()
          .write(DRAFT_SETTINGS_KEY, encoding)
          .effect(map=_ => SetNotice("")),
        ])
      } else {
        @moui.Effect::batch([
          effect0,
          build_effect,
          preview_web_effect,
          compile_effect,
          code_project_effect,
        ])
      }
      (next, effect)
    },
    // 壳按真实视口自适应：ViewEnvironment 提供 viewport_size，
    // 顶栏/状态栏按窗口宽铺满、中心列吃剩余宽度、底栏按视口宽铺。
    view=(model, env) => {
      let viewport = env.viewport_size()
      // 沉浸式标题栏：把顶部那一条 `WINDOW_CHROME_HEIGHT` 声明成「按住可拖窗」
      // 的区域。无边框窗口没有系统标题栏，不声明这块就**完全没法移动窗口**。
      //
      // 这里是唯一同时拿得到 `services`（组合根闭包）与真实视口（`env`）的
      // 地方，所以声明放在视图构建期。声明是**状态**不是命令：同一矩形重复
      // 声明不推进 revision，宿主按 revision 去重，逐帧重发开销为零。
      //
      // **必须把右侧动作簇排除掉**：AppKit 的 presenter 命中拖拽区时直接
      // `performWindowDragWithEvent:`，事件不再进入运行时——若拖拽区覆盖了
      // 运行/单步/编译，点它们会变成拖窗口（按钮「点了没反应」）。所以拖拽
      // 矩形只覆盖到动作簇左缘为止，宽度由 `topbar_actions_width` 与**渲染**
      // 共用同一个计算源，两侧不会漂移。
      //
      // 非沉浸式（Web 入口）必须清空——浏览器没有原生拖窗，
      // 留下一个「看起来能拖但拖不动」的区域只会误导。
      if model.immersive {
        let __drag_w = topbar_drag_width(
          model,
          translator(model),
          viewport.width,
        )
        services
        .platform()
        .window_drag()
        .set_region(
          Some(
            @core.Rect::new(
              x=0.0,
              y=0.0,
              width=__drag_w,
              height=WINDOW_CHROME_HEIGHT,
            ),
          ),
        )
      } else {
        services.platform().window_drag().set_region(None)
      }
      view_with_viewport(model, viewport)
    },
    subscriptions=model => run_subscription(model, timer),
  ).with_commands(commands=studio_program_commands)
}

///|
/// 带真实 provider 的服务流（GenerateProposal 走网络）。
fn update_with_provider(
  model : Model,
  msg : Msg,
  services : @services.AppServices,
  submit : ProviderSubmit,
  submit_launch : LaunchSubmit,
  apply_locale : (String) -> Unit,
) -> (Model, @moui.Effect[Msg]) {
  match msg {
    // **一键启动产物**：脱离 Studio 生命周期起进程（见 services/launch_native）。
    //
    // 为什么走 effect 而不是直接调：`spawn` 是阻塞式系统调用 + 可能触发的
    // 首次执行校验，放在 UI 线程会让点击卡顿。effect 把它交给 worker，UI
    // 立刻拿到「正在启动」的反馈。
    RunArtifact(path) =>
      (
        push_toast(
          model,
          text(translator(model), "app.compile.launching"),
          false,
        ),
        @moui.Effect::dispatch(emit => {
          submit_launch(path, result => {
            // 启动执行器回的是裸 `Result`（它不起服务任务），在这里抬成
            // `ServiceTaskResult`——回执消息只认一种结果词汇，视图层因此
            // 不必为「哪条路来的」分叉。
            let outcome = match result {
              Ok(_) => @services.ServiceTaskResult::Success(())
              Err(message) =>
                @services.ServiceTaskResult::Failure(
                  @services.ServiceError::unavailable(message),
                )
            }
            emit(ArtifactActionDone(ArtifactLaunch, outcome))
          })
        }),
      )
    SwitchLanguage => {
      let (switched, effect) = update_pure(model, SwitchLanguage)
      let tag = switched.language.tag()
      apply_locale(tag)
      (
        switched,
        @moui.Effect::batch([
          effect,
          services
          .settings()
          .write(LANGUAGE_SETTINGS_KEY, tag)
          .effect(map=_ => SetNotice("")),
        ]),
      )
    }
    LanguageLoaded(tag) => {
      let wanted = ui_language_from_tag(tag)
      let next = sync_code_draft({ ..model, language: wanted, })
      apply_locale(next.language.tag())
      (next, @moui.Effect::none())
    }
    ExplainHandler =>
      if model.provider_mode is Fake || model.provider_key == "" {
        update_pure(model, ExplainHandler)
      } else {
        match current_handler(model) {
          None => (model, @moui.Effect::none())
          Some(handler) =>
            (
              { ..model, explanation: "", ai_busy: true, },
              @moui.Effect::dispatch(emit => {
                submit(
                  {
                    endpoint: model.provider_endpoint,
                    key: model.provider_key,
                    model: model.provider_model,
                    system: explanation_system_prompt(),
                    prompt: @studio_lang.render_handler(
                      handler,
                      model.language.dsl_language(),
                    ),
                  },
                  result => emit(RealExplanationFinished(result)),
                )
              }),
            )
        }
      }
    GenerateProposal =>
      if model.provider_mode is Fake {
        update_pure(model, GenerateProposal)
      } else if model.provider_key == "" {
        (
          { ..model, prompt_error: text(translator(model), "app.ai.key"), },
          @moui.Effect::none(),
        )
      } else {
        (
          { ..model, prompt_error: "", ai_busy: true, },
          @moui.Effect::dispatch(emit => {
            submit(
              {
                endpoint: model.provider_endpoint,
                key: model.provider_key,
                model: model.provider_model,
                system: @proposals.proposal_system_prompt(),
                prompt: model.prompt_draft,
              },
              result => emit(RealGenerationFinished(result)),
            )
          }),
        )
      }
    _ => update_with_services(model, msg, services)
  }
}
