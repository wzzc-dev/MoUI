///|
/// MoUI Studio 应用装配：Program 组合根 + 文件服务流（保存/打开/导出）
/// + 真实 provider 派发。平台入口只负责把 provider_submit 与 timer 接上。

///|
/// 测试辅助：置 MoonBit 代码草稿（M6① 着色分派验证用；生产路径由
/// sync_code_draft 按 IR 播种，不手置草稿）。
pub fn update_moonbit_draft_for_test(model : Model, draft : String) -> Model {
  { ..model, code_draft: draft, }
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
/// 服务闭包与请求规格的类型定义已收编进内核服务注册表
/// （`kernel/services.mbt`，M1 插件化）；这里保留公开别名，既有引用零改动。
pub type ProviderRequestSpec = @kernel.ProviderRequestSpec

///|
pub type ProviderSubmit = @kernel.ProviderSubmit

///|
pub type CompileSubmit = @kernel.CompileSubmit

///|
pub type LaunchSubmit = @kernel.LaunchSubmit

///|
/// 产物旁路动作 → 成功 toast 的 i18n 键（三种动作各说各的事实）。
pub fn artifact_done_key(what : ArtifactAction) -> String {
  match what {
    ArtifactCopy => "app.compile.path_copied"
    ArtifactReveal => "app.compile.revealed"
    ArtifactLaunch => "app.compile.launched"
    ArtifactAiCopy => "app.ai.copied"
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
    @kernel.noop_provider_submit,
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
  pty? : @kernel.PtyService[Msg] = @kernel.PtyService::unavailable(),
) -> (Model, @moui.Effect[Msg]) {
  match msg {
    // 终端（M5）：PTY 输出增量喂屏；派生回执挂句柄；输入行经服务写出；
    // 关闭 = kill + 句柄清空（屏保留回看）
    TerminalOutput(text) => {
      model.terminal.feed_output(text)
      // 新输出 → 终端屏滚动跟随到底部（用户反馈②）：offset = 内容底部
      //（行数×行高，容器 clamp 到精确底部）——**不用 1e9 巨值**（收起/
      // 重开重挂载时的巨值 offset 处理是卡死嫌疑，M9-fix 排查中）
      model.terminal_scroll = @geometry.Point::new(
        x=0.0,
        y=(model.terminal.screen.length().to_double() + 1.0) * 16.0,
      )
      model.terminal_scroll_seq = model.terminal_scroll_seq + 1
      (model, @moui.Effect::none())
    }
    TerminalSpawned(handle) => {
      model.terminal.handle = handle
      (model, @moui.Effect::none())
    }
    TerminalInput =>
      match (model.terminal.take_input(), model.terminal.handle) {
        (Some(line), Some(handle)) =>
          if pty.available {
            (model, @moui.Effect::dispatch(_emit => (pty.write)(handle, line)))
          } else {
            (model, @moui.Effect::none())
          }
        _ => (model, @moui.Effect::none())
      }
    TerminalType(text) => {
      model.terminal.type_text(text)
      (model, @moui.Effect::none())
    }
    // 终端页签关闭（M8）：kill PTY + 开关复位 + 页签退选到 Console +
    // 底栏收起（屏保留回看；重开 = 再点页签，重派生条件自动成立）
    TerminalTabClose =>
      match model.terminal.handle {
        Some(handle) => {
          model.terminal.session_closed()
          model.terminal_open = false
          (
            { ..model, bottom_tab: BtConsole, bottom_open: false, },
            @moui.Effect::dispatch(_emit => (pty.kill)(handle)),
          )
        }
        None => {
          model.terminal_open = false
          (
            { ..model, bottom_tab: BtConsole, bottom_open: false, },
            @moui.Effect::none(),
          )
        }
      }
    // 终端直连键入（M8 交互式）：键盘/输入法透传，字节序列直接写 PTY
    //（回显由 PTY 输出流返回——真终端语义，不本地回显）
    TerminalWrite(seq) =>
      match model.terminal.handle {
        Some(handle) =>
          if pty.available {
            (model, @moui.Effect::dispatch(_emit => (pty.write)(handle, seq)))
          } else {
            (model, @moui.Effect::none())
          }
        None => (model, @moui.Effect::none())
      }
    TerminalClose =>
      match model.terminal.handle {
        Some(handle) => {
          model.terminal.session_closed()
          if pty.available {
            (model, @moui.Effect::dispatch(_emit => (pty.kill)(handle)))
          } else {
            (model, @moui.Effect::none())
          }
        }
        None => (model, @moui.Effect::none())
      }
    // 流式分片（M4）：追加进当前会话的流式卡。已停止（ai_streaming=false）
    // 后的残余分片直接忽略（干净截断）。放导出层而非包装闭包——测试与
    // 生产默认臂都经这里，消息流可断言。
    StreamChunk(chunk) =>
      if model.ai_streaming {
        model.ai_sessions.append_to_last_card(chunk)
        // 流式追加也是新内容：跟随态下时间线贴底
        (follow_transcript(model), @moui.Effect::none())
      } else {
        (model, @moui.Effect::none())
      }
    StreamFinished => {
      // 一轮流式收尾 = 结构性事件：会话存储脏标
      let finished = { ..model, ai_streaming: false, }
      mark_ai_sessions_dirty(finished)
      (finished, @moui.Effect::none())
    }
    StopGeneration => {
      // 截断：停止标志复位 + 流式卡标记已停止（「已停止」回执）
      let session = model.ai_sessions.current()
      let total = session.cards.length()
      let cards : Array[AiCard] = []
      let mut index = 0
      for card in session.cards {
        if index == total - 1 && !card.settled {
          cards.push(AiCard::{
            ..card,
            settled: true,
            settled_note: "app.ai.stopped",
          })
        } else {
          cards.push(card)
        }
        index = index + 1
      }
      model.ai_sessions.amend({ ..session, cards, })
      ({ ..model, ai_streaming: false, }, @moui.Effect::none())
    }
    // 复制产物路径：走系统剪贴板（native 是 NSPasteboard，Web 是可用的
    // navigator.clipboard 垫片）。成功/失败都回一条 ArtifactActionDone，
    // 让 notice 如实说话——静默失败会让用户以为「复制了」。
    // 工程树点文件（M8 反馈）：读文件内容 → 只读查看器。读取在服务层，
    // 选中/取消的纯转移照走 update_pure。
    SelectProjectFile(rel) => {
      let (next, effect) = update_pure(model, msg)
      let read_effect = match active_project_of(model) {
        Some(project) =>
          services
          .files()
          .read_text("\{project.root}/\{rel}")
          .effect(map=r => ProjectFileLoaded(rel, r))
        None => @moui.Effect::none()
      }
      (next, @moui.Effect::batch([effect, read_effect]))
    }
    // 保存工程文件（试用反馈：点开的文件可编辑,保存写回磁盘）。
    SaveProjectFile =>
      match (active_project_file(model), active_project_of(model)) {
        (Some(open), Some(project)) =>
          (
            model,
            services
            .files()
            .write_text("\{project.root}/\{open.rel}", open.draft)
            .effect(map=r => ProjectFileSaveFinished(open.rel, r)),
          )
        _ => (model, @moui.Effect::none())
      }
    // 插件管理（G7.3）：禁用 = 过滤贡献项入口（状态保留,非运行时卸载）。
    TogglePlugin(id) => {
      let next : Array[String] = if plugin_active(model, id) {
        let added = model.plugin_disabled + [id]
        added
      } else {
        let removed : Array[String] = []
        for existing in model.plugin_disabled {
          if existing != id {
            removed.push(existing)
          }
        }
        removed
      }
      let toggled = { ..model, plugin_disabled: next }
      // 归一化:禁用终端/AI 时若正停在其入口,先退回无害页签/模式
      let normalized = if id == "terminal" &&
        !plugin_active(toggled, "terminal") &&
        toggled.bottom_tab is BtTerminal {
        { ..toggled, bottom_tab: BtAudit }
      } else if id == "ai" &&
        !plugin_active(toggled, "ai") &&
        toggled.perspective is PsAi {
        apply_perspective_preset(toggled, PsVisual)
      } else {
        toggled
      }
      (
        normalized,
        services
        .settings()
        .write(PLUGINS_SETTINGS_KEY, encode_plugin_disabled(normalized))
        .effect(map=_ => Msg::Noop),
      )
    }
    PluginsLoaded(result) =>
      match result {
        Success(payload) => {
          let restored = {
            ..model,
            plugin_disabled: decode_plugin_disabled(payload.unwrap_or("")),
          }
      // 与 Toggle 同款归一化（boot 恢复也可能带来禁用态）
          let normalized = if !plugin_active(restored, "terminal") &&
            restored.bottom_tab is BtTerminal {
            { ..restored, bottom_tab: BtAudit }
          } else if !plugin_active(restored, "ai") &&
            restored.perspective is PsAi {
            apply_perspective_preset(restored, PsVisual)
          } else {
            restored
          }
          (normalized, @moui.Effect::none())
        }
        Failure(_) | Cancelled => (model, @moui.Effect::none())
      }
    // === 全文搜索（G4 F3）:树缓存按需读文件扫描,双护栏防失控 ===
    SearchRun =>
      match active_project_of(model) {
        None => (model, @moui.Effect::none())
        Some(project) => {
          let query = model.search_query.trim(chars=" \t").to_owned()
          if query == "" {
            (model, @moui.Effect::none())
          } else {
            // 目标 = 扫描树里的文本文件（.mbt/.md）,来自扫描缓存不重走树
            let targets : Array[String] = []
            for pkg in project.scanned.packages {
              for name in pkg.files {
                let rel = if pkg.rel_path == "" {
                  name
                } else {
                  "\{pkg.rel_path}/\{name}"
                }
                if rel.has_suffix(".mbt") || rel.has_suffix(".md") {
                  targets.push(rel)
                }
              }
            }
            if targets.is_empty() {
              (model, @moui.Effect::none())
            } else {
              (
                { ..model, search_busy: true, },
                @moui.Effect::dispatch(emit => {
                  let _ = project_search_task(
                    services.files(),
                    project.root,
                    targets,
                    query~,
                  ).start(r => emit(SearchFinished(r)))
                }),
              )
            }
          }
        }
      }
    SearchFinished(result) =>
      match result {
        Success(hits) =>
          (
            { ..model, search_hits: hits, search_busy: false, },
            @moui.Effect::none(),
          )
        Failure(_) | Cancelled =>
          ({ ..model, search_busy: false, }, @moui.Effect::none())
      }
    SearchHitClicked(rel) => {
      // 跳转 = 切到代码工作区 + 打开该文件（选中态相同则免重复读——
      // ProjectFileLoaded 的挂载守卫依赖选中态）
      let (next, _) = update_pure(model, SetWorkSpace(WsCode))
      if next.selected_project_file == Some(rel) {
        (next, @moui.Effect::none())
      } else {
        let (selected, effect) = update_pure(next, SelectProjectFile(rel))
        let read_effect = match active_project_of(selected) {
          Some(project) =>
            services
            .files()
            .read_text("\{project.root}/\{rel}")
            .effect(map=r => ProjectFileLoaded(rel, r))
          None => @moui.Effect::none()
        }
        (selected, @moui.Effect::batch([effect, read_effect]))
      }
    }
    // === 文件 CRUD（G4）：新建 = write;改名 = read→write→delete 三步链 ===
    FileCreateCommit =>
      match active_project_of(model) {
        None => (model, @moui.Effect::none())
        Some(project) => {
          let rel = model.file_name_draft.trim(chars=" \t").to_owned()
          if !valid_new_file_rel(rel) {
            (
              with_notice(
                model,
                text(translator(model), "app.project.file_name_invalid"),
                true,
              ),
              @moui.Effect::none(),
            )
          } else if project_has_file(model, rel) {
            (
              with_notice(
                model,
                text_with(translator(model), "app.project.file_exists", [
                  ("a", rel),
                ]),
                true,
              ),
              @moui.Effect::none(),
            )
          } else {
            (
              model,
              services
              .files()
              .write_text("\{project.root}/\{rel}", "")
              .effect(map=r => ProjectFileCreated(rel, r)),
            )
          }
        }
      }
    ProjectFileCreated(rel, result) =>
      match result {
        Success(_) =>
          match active_project_of(model) {
            None => (model, @moui.Effect::none())
            Some(project) => {
              // 开空 tab + 重扫刷新文件树
              let (files, index) = upsert_open_file(model.open_project_files, OpenProjectFile::{
                rel,
                saved_content: "",
                draft: "",
                caret: 0,
                selection: None,
              })
              let created = with_notice(
                {
                  ..model,
                  open_project_files: files,
                  open_file_index: index,
                  file_create_open: false,
                  file_name_draft: "",
                },
                text_with(translator(model), "app.project.file_created", [
                  ("a", rel),
                ]),
                false,
              )
              (
                created,
                @project.walk_root_task(services.files(), project.root).effect(map=r => {
                  ProjectScanCompleted(r)
                }),
              )
            }
          }
        Failure(error) =>
          (
            with_notice(
              { ..model, file_create_open: false, },
              error.message,
              true,
            ),
            @moui.Effect::none(),
          )
        Cancelled => (model, @moui.Effect::none())
      }
    FileRenameCommit =>
      match (model.file_rename_open, active_project_of(model)) {
        (Some(old), Some(project)) => {
          let new = model.file_name_draft.trim(chars=" \t").to_owned()
          if !valid_new_file_rel(new) {
            (
              with_notice(
                model,
                text(translator(model), "app.project.file_name_invalid"),
                true,
              ),
              @moui.Effect::none(),
            )
          } else if new == old {
            ({ ..model, file_rename_open: None, }, @moui.Effect::none())
          } else {
            (
              model,
              services
              .files()
              .read_text("\{project.root}/\{old}")
              .effect(map=r => ProjectRenameRead(old, new, r)),
            )
          }
        }
        _ => (model, @moui.Effect::none())
      }
    ProjectRenameRead(old, new, result) =>
      match result {
        Success(content) =>
          match active_project_of(model) {
            None => (model, @moui.Effect::none())
            Some(project) =>
              (
                model,
                services
                .files()
                .write_text("\{project.root}/\{new}", content)
                .effect(map=r => ProjectRenameWritten(old, new, r)),
              )
          }
        Failure(error) =>
          (
            with_notice(
              { ..model, file_rename_open: None, },
              error.message,
              true,
            ),
            @moui.Effect::none(),
          )
        Cancelled => (model, @moui.Effect::none())
      }
    ProjectRenameWritten(old, new, result) =>
      match result {
        Success(_) =>
          match active_project_of(model) {
            None => (model, @moui.Effect::none())
            Some(project) =>
              (
                model,
                services
                .files()
                .delete_file("\{project.root}/\{old}")
                .effect(map=r => ProjectRenameDeleted(old, new, r)),
              )
          }
        Failure(error) =>
          // 新文件已写、旧文件残留——半完成如实说话,不静默
          (
            with_notice(
              { ..model, file_rename_open: None, },
              text_with(translator(model), "app.project.rename_partial", [
                ("a", error.message),
              ]),
              true,
            ),
            @moui.Effect::none(),
          )
        Cancelled => (model, @moui.Effect::none())
      }
    ProjectRenameDeleted(old, new, result) =>
      match result {
        Success(_) => {
          let renamed = {
            ..model,
            open_project_files: rename_open_file(
              model.open_project_files,
              old,
              new,
            ),
            file_rename_open: None,
            file_name_draft: "",
          }
          let noticed = with_notice(
            renamed,
            text_with(translator(model), "app.project.file_renamed", [
              ("a", new),
            ]),
            false,
          )
          match active_project_of(noticed) {
            None => (noticed, @moui.Effect::none())
            Some(project) =>
              (
                noticed,
                @project.walk_root_task(services.files(), project.root).effect(map=r => {
                  ProjectScanCompleted(r)
                }),
              )
          }
        }
        Failure(error) =>
          (
            with_notice(
              { ..model, file_rename_open: None, },
              text_with(translator(model), "app.project.rename_partial", [
                ("a", error.message),
              ]),
              true,
            ),
            @moui.Effect::none(),
          )
        Cancelled => (model, @moui.Effect::none())
      }
    // 保存全部（G4 多标签）：逐脏 tab 写盘,回执各按 rel 定位落账。
    SaveAllFiles =>
      match active_project_of(model) {
        None => (model, @moui.Effect::none())
        Some(project) => {
          let writes : Array[@moui.Effect[Msg]] = []
          for open in model.open_project_files {
            if open.draft != open.saved_content {
              writes.push(
                services
                .files()
                .write_text("\{project.root}/\{open.rel}", open.draft)
                .effect(map=r => ProjectFileSaveFinished(open.rel, r)),
              )
            }
          }
          if writes.is_empty() {
            (model, @moui.Effect::none())
          } else {
            (model, @moui.Effect::batch(writes))
          }
        }
      }
    CopyArtifactPath(path) =>
      (
        model,
        services
        .clipboard()
        .write_text(path)
        .effect(map=r => ArtifactActionDone(ArtifactCopy, r)),
      )
    // 时间线消息复制（对白转录）：同一条剪贴板通道，回执文案区分来源。
    CopyAiMessage(seq) =>
      match card_text_by_seq(model, seq) {
        Some(body) =>
          (
            model,
            services
            .clipboard()
            .write_text(body)
            .effect(map=r => ArtifactActionDone(ArtifactAiCopy, r)),
          )
        None => (model, @moui.Effect::none())
      }
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
          match
            migrate_studio_source(model.pending_open_dir.unwrap_or("."), source) {
            Ok(outcome) => {
              let program = outcome.program
              let next = {
                ..model,
                program,
                pending: None,
                // 新程序 = 新 AI 上下文：会话切片重置（旧语义即清草稿/历史）
                ai_sessions: @ai.AiSessions::new(),
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
                // 打开成功：基线对齐新程序（脏标记随之清除）
                saved_encoding: @codec.encode_program(program),
                selected_control: first_control_name(program.controls),
                selected_handler: first_handler_key(program.handlers),
              }
              // 迁移器落盘（M1 事件化）：发出代码工程写盘事件，目录取
              // pending_open_dir（旧 .studio.json 所在目录，发出点消费清位）
              let next = emit_code_project_write(next)
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
          // 扫描在服务回调链上推进;进度经 dispatch 的 emit 直发 Msg
          // (provider/compile 的 worker 回调同款线程纪律),完成走同一条 emit。
          (
            model,
            @moui.Effect::dispatch(emit => {
              let _ = @project.walk_root_task(services.files(), root, on_progress=p => {
                emit(ProjectScanProgress(p))
              }).start(r => emit(ProjectScanCompleted(r)))
            }),
          )
        Failure(error) =>
          (with_notice(model, error.message, true), @moui.Effect::none())
        Cancelled => (model, @moui.Effect::none())
      }
    ProjectScanCompleted(result) =>
      match result {
        Success(Ok(output)) =>
          match output {
            Single(source) =>
              import_single_source(model, services.files(), source)
            Workspace(scan) => import_workspace_scan(model, scan)
          }
        Success(Err(msg)) =>
          (with_notice(model, msg, true), @moui.Effect::none())
        Failure(error) =>
          (with_notice(model, error.message, true), @moui.Effect::none())
        Cancelled => (model, @moui.Effect::none())
      }
    // 工程记录存储(G2 W3):boot 读取 → 静默重扫 → 静默合并;坏文件才说话。
    ProjectsStoreLoaded(result) =>
      match result {
        Success(payload) =>
          match decode_project_store(payload) {
            Ok((active_root, records)) =>
              if records.is_empty() {
                (model, @moui.Effect::none())
              } else {
                // 逐 root 起静默重扫;回执走 ProjectRestoreScanCompleted
                (
                  {
                    ..model,
                    projects_restore_pending: records.length(),
                    restore_active_root: active_root,
                  },
                  @moui.Effect::dispatch(emit => {
                    for entry in records {
                      let (root, _name) = entry
                      let _ = @project.walk_root_task(services.files(), root).start(r => {
                          emit(ProjectRestoreScanCompleted(r))
                        },
                      )
                    }
                  }),
                )
              }
            Err(message) =>
              (with_notice(model, message, true), @moui.Effect::none())
          }
        // 文件不存在(首跑常态)= 不声不响
        Failure(_) | Cancelled => (model, @moui.Effect::none())
      }
    ProjectRestoreScanCompleted(result) =>
      // 静默合并:成功即 upsert(无通知无 harness——通知噪音与写盘都省);
      // 失败成员丢弃(工程在盘上,重新导入即可)。pending 在所有臂递减,
      // 归零时按存储的 active_root 落位选中。
      match result {
        Success(Ok(Single(source))) => {
          let pending = model.projects_restore_pending - 1
          match project_record_from_source(source) {
            Ok(record) => {
              let (projects, _index) = upsert_project(model.projects, record)
              let next = {
                ..model,
                projects,
                projects_restore_pending: pending,
              }
              if pending == 0 {
                (finish_restore_active(next), @moui.Effect::none())
              } else {
                (next, @moui.Effect::none())
              }
            }
            Err(_) =>
              (
                { ..model, projects_restore_pending: pending, },
                @moui.Effect::none(),
              )
          }
        }
        Success(Ok(Workspace(_))) | Success(Err(_)) | Failure(_) | Cancelled =>
          // 恢复只存单模块 root;其余回执一律静默递减
          (
            {
              ..model,
              projects_restore_pending: model.projects_restore_pending - 1,
            },
            @moui.Effect::none(),
          )
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
            Some(project) => {
              // 打开中的 tab 一并关闭（文件已不存在;删除本身走确认流,
              // 这里不再对脏 tab 二次打扰）
              let model = match
                open_file_index_of(model.open_project_files, rel) {
                Some(index) => close_open_file_at(model, index)
                None => model
              }
              (
                with_notice(
                  model,
                  text_with(translator(model), "app.project.file_deleted", [
                    ("a", rel),
                  ]),
                  false,
                ),
                @project.walk_root_task(services.files(), project.root).effect(map=r => {
                  ProjectScanCompleted(r)
                }),
              )
            }
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
                // 过门即发构建事件（M1 事件化）：busy 置位防重复排队，
                // 派发给注入的 build_submit 由组合根监听器承担
                model.outbox.push(EvBuildSubmit(kind, project.root, entry_rel))
                ({ ..model, build_busy: true, }, @moui.Effect::none())
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
          // WebPreview 成功(M2-2):设静态服务目录 + 组预览 URL。
          // webview 命令改事件驱动(M1):URL 变化(含首次)发 navigate,
          // 同 URL 重建发 reload——由组合根监听器经 PreviewNavigate/
          // PreviewReload 消息派发,不再 diff build_seq。
          let with_web = if kind is BkWebPreview && report.ok {
            (preview_web_controls().set_directory)(report.web_root)
            let url = "http://127.0.0.1:\{preview_web_controls().port}/\{report.web_index_rel}"
            let next = {
              ..with_frame,
              preview_web_url: Some(url),
              preview_web_opened: true,
              preview_mode: PmWeb,
              workspace: WsPreview,
            }
            match model.preview_web_url {
              Some(old) if old == url => next.outbox.push(EvPreviewWebReload)
              _ => next.outbox.push(EvPreviewWebNavigate(url))
            }
            next
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
                    text_with(
                      translator(model),
                      "app.project.external_parse_error",
                      [("a", message)],
                    ),
                    true,
                  ),
                  @moui.Effect::none(),
                )
              Ok(parsed) =>
                (
                  with_notice(
                    {
                      ..model,
                      form_designer: Some({
                        ..session,
                        source: new_source,
                        parsed,
                      }),
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
  wall_clock : (() -> StudioClock)?,
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
  // 墙钟订阅（对白转录）：组合根注入了 wall_clock 且在 AI 模式时每秒重取
  // 一次——时间线 HH:MM、相对时间、「已工作 N 秒」随之走动。其他模式没有
  // 时间显示，订阅不活跃（省一档每秒全树重渲）。
  let clock_subscription = match (timer, wall_clock, model.perspective) {
    (Some(source), Some(f), PsAi) =>
      source.subscription(interval_ms=1000.0, map=_frame => ClockUpdated(f()))
    _ => @moui.Subscription::none()
  }
  @moui.Subscription::batch([
    run_subscription_plan, toast_subscription, clock_subscription,
  ])
}

///|
/// Program 组合根。provider_submit 由平台入口注入（macOS 真实 worker；
/// Web 入口注入 noop——浏览器只用离线假模型）。
pub fn program(
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
  provider_submit? : ProviderSubmit = @kernel.noop_provider_submit,
  compile_submit? : CompileSubmit = @kernel.noop_compile_submit,
  launch_submit? : LaunchSubmit = @kernel.noop_launch_submit,
  runtime_snapshot? : RuntimeSnapshotFn = noop_runtime_snapshot,
  compile_cancel? : () -> Unit = @kernel.noop_compile_cancel,
  build_submit? : BuildSubmit = @kernel.noop_build_submit,
  build_cancel? : () -> Unit = @kernel.noop_build_cancel,
  webview_controller? : @webview_host.WebViewController? = None,
  preview_web? : PreviewWebControls = @kernel.noop_preview_web_controls(),
  provider_config? : ProviderConfig,
  compile_track_available? : Bool = false,
  export_available? : Bool = false,
  immersive? : Bool = false,
  pty? : @kernel.PtyService[Msg] = @kernel.PtyService::unavailable(),
  focus_terminal? : () -> Unit = fn() { () },
  profile? : StudioProfile = Full,
  apply_locale? : (String) -> Unit = _tag => (),
  /// 墙钟闭包（组合根映射平台 FFI 注入；缺省 = 常数钟）。时间戳/时长/
  /// 相对时间的唯一来源；订阅只在 AI 模式活跃（run_subscription）。
  wall_clock? : (() -> StudioClock)? = None,
  /// AI 会话存储路径（M5）：非空 = native 持久化开启（init 读取 +
  /// 结构性事件写盘）；空 = 关闭（web 入口），UI 无持久化入口。
  sessions_store_path? : String = "",
  /// 工程记录存储路径（G2）：`.studio/projects.json`（只存 root/module_name
  /// 摘要,启动重扫拿新鲜树）；空 = 关闭（web 入口）。
  projects_store_path? : String = "",
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
  let on_locale = apply_locale
  let wall = wall_clock

  // 预览 web 控制注入(M2-2):槽位供视图与处理器读取
  install_preview_web(webview_controller, Some(preview_web))
  // 类型化服务容器（M1 内核化）：平台能力集中一处，事件监听器与消息臂
  // 经它取能力；provider 的选择已经由上面注入的闭包决定。
  // 高亮服务（M6）：moonbit 词法器随内核注册；DSL 词法走既有直连扫描
  // （关键字表依赖会话内 UI 语言，provider 注册表供未来消费者按 id 分派）
  let highlight = @kernel.HighlightService::new()
  highlight.register({ language: "moonbit", run: @kernel.moonbit_highlight, })
  let svc : @kernel.StudioServices[Msg] = {
    provider_submit: submit,
    compile_submit: submit_compile,
    compile_cancel: cancel_compile,
    build_submit: submit_build,
    build_cancel,
    launch_submit: submit_launch,
    files: services.files(),
    preview_web: web_controls,
    highlight,
  }
  // 事件总线（M1 内核化）：组合根是唯一注册点。监听器是纯函数——把事件
  // 翻译成后续消息，副作用由那些消息的 update 臂经 svc 执行。
  let bus : @kernel.EventBus[StudioEvent, Msg] = @kernel.EventBus::new()
  // 代码工程写盘（SelectTemplate / 提案采纳 / 迁移器的汇合点）
  bus.on("studio.code_project", fn(event) {
    match event {
      EvCodeProjectWrite(dir, form_mbt, handlers_mbt) =>
        [CodeProjectWriteRequested(dir, form_mbt, handlers_mbt)]
      _ => []
    }
  })
  // 构建派发（ProjectBuildRun 过门后的执行通道）
  bus.on("studio.build", fn(event) {
    match event {
      EvBuildSubmit(kind, root, entry_rel) =>
        [
          BuildDispatchRequested(ProjectBuildRequest::{ kind, root, entry_rel, }),
        ]
      _ => []
    }
  })
  // AI 会话存储（M5）：只有组合根配置了路径才注册——web/裸测试组合根
  // 不注册，EvAiSessionsDirty 排空零开销。
  if sessions_store_path != "" {
    bus.on("studio.ai_sessions", fn(event) {
      match event {
        EvAiSessionsDirty => [AiSessionsStoreWriteRequested]
        _ => []
      }
    })
  }
  // 工程记录存储（G2）：同款纪律,EvProjectsDirty → 写盘请求。
  if projects_store_path != "" {
    bus.on("studio.projects", fn(event) {
      match event {
        EvProjectsDirty => [ProjectsStoreWriteRequested]
        _ => []
      }
    })
  }
  // webview 命令（Web 预览重建回执）
  bus.on("studio.preview_web", fn(event) {
    match event {
      EvPreviewWebNavigate(url) => [PreviewNavigate(url)]
      EvPreviewWebReload => [PreviewReload]
      _ => []
    }
  })
  @moui.Program::new_with_environment(
    init=() => {
      let base = initial_model(
        provider_config?,
        compile_track_available~,
        export_available~,
        immersive~,
        pty_available=pty.available && !(profile is Teaching),
        profile~,
      )
      // 组合根注入了墙钟就用真实时刻播种 Model.clock（常数钟只兜底）
      let model = match wall {
        Some(f) => { ..base, clock: f(), }
        None => base
      }
      // 会话存储（M5）：配置了路径才读；文件不存在（首跑）= Failure，
      // 处理臂保持默认会话不声不响（坏文件才 with_notice）。
      let load_effect = if sessions_store_path != "" {
        services
        .files()
        .read_text(sessions_store_path)
        .effect(map=result => AiSessionsStoreLoaded(result))
      } else {
        @moui.Effect::none()
      }
      // 工程记录存储（G2）：同款;Loaded 臂解码后逐 root 静默重扫。
      let projects_load_effect = if projects_store_path != "" {
        services
        .files()
        .read_text(projects_store_path)
        .effect(map=result => ProjectsStoreLoaded(result))
      } else {
        @moui.Effect::none()
      }
      (
        model,
        @moui.Effect::batch([
          services
          .settings()
          .read(LANGUAGE_SETTINGS_KEY)
          .effect(map=result => LanguageLoaded(language_tag_of(result))),
          services
          .settings()
          .read(DRAFT_SETTINGS_KEY)
          .effect(map=result => DraftLoaded(result)),
          services
          .settings()
          .read(PLUGINS_SETTINGS_KEY)
          .effect(map=result => PluginsLoaded(result)),
          load_effect,
          projects_load_effect,
        ]),
      )
    },
    update=(model, msg) => {
      let (next0, effect0) = match msg {
        // 事件驱动消息（M1 内核化）：由事件总线从 outbox 翻译而来，副作用
        // 经服务容器执行——监听器保持纯函数，这里才是副作用的家。
        CodeProjectWriteRequested(dir, form_mbt, handlers_mbt) =>
          (
            model,
            @moui.Effect::batch([
              services
              .files()
              .write_text("\{dir}/form.mbt", form_mbt)
              .effect(map=r => CodeProjectSaved(r)),
              services
              .files()
              .write_text("\{dir}/handlers.mbt", handlers_mbt)
              .effect(map=r => CodeProjectSaved(r)),
            ]),
          )
        BuildDispatchRequested(request) =>
          (
            model,
            @moui.Effect::dispatch(emit => {
              submit_build(request.kind, request.root, request.entry_rel, result => {
                emit(ProjectBuildFinished(request.kind, result))
              })
            }),
          )
        PreviewNavigate(url) => (model, (svc.preview_web.navigate)(url))
        PreviewReload => (model, (svc.preview_web.reload)())
        SetBottomHeight(h) =>
          (
            { ..model, bottom_height: h.clamp(min=100.0, max=1200.0), },
            @moui.Effect::none(),
          )
        // 终端聚焦请求（M8）：经组合根注入的回调把键盘焦点交给终端节点
        // （runtime.focus_key("terminal-input")——app 不接触 runtime）
        FocusTerminalRequest => {
          focus_terminal()
          (model, @moui.Effect::none())
        }
        // 「停止编译」= 真终止：清 UI 状态之外还要杀掉正在跑的 moon
        // 子进程（旧实现只清状态，工具链继续后台跑完，进程表可见）。
        CompileStopped => {
          cancel_compile()
          update_pure(model, msg)
        }
        // AI 会话存储写盘（M5）：事件总线从 EvAiSessionsDirty 翻译而来；
        // 只有配置了路径的组合根会发出这条消息（监听器按路径注册）。
        AiSessionsStoreWriteRequested =>
          if sessions_store_path != "" {
            (
              model,
              services
              .files()
              .write_text(
                sessions_store_path,
                @ai.encode_ai_sessions(model.ai_sessions),
              )
              .effect(map=result => AiSessionsStoreSaved(result)),
            )
          } else {
            (model, @moui.Effect::none())
          }
        // 工程记录存储写盘（G2）：EvProjectsDirty 翻译而来,同款纪律。
        ProjectsStoreWriteRequested =>
          if projects_store_path != "" {
            (
              model,
              services
              .files()
              .write_text(projects_store_path, encode_project_store(model))
              .effect(map=result => ProjectsStoreSaved(result)),
            )
          } else {
            (model, @moui.Effect::none())
          }
        ProjectsStoreSaved(result) =>
          match result {
            Success(_) | Cancelled => (model, @moui.Effect::none())
            Failure(error) =>
              (push_toast(model, error.message, true), @moui.Effect::none())
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
        | CopyAiMessage(_)
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
          let (next, effect) = update_with_services(model, msg, services, pty~)
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
      // 终端派生触发（M5）：AI 模式 + 终端页签在位 + 未派生 + 本端有
      // PTY 能力 → 派生一次（句柄经 TerminalSpawned 回执挂上；非 flag——
      // 读的是动作后的界面状态）。别处不再有派生入口。
      // 终端聚焦请求（M8）：进 AI 模式或选终端页签时，请宿主把键盘焦点
      // 交给终端节点（Effect::send 下一趟 update 到达——届时面板已渲染）
      let terminal_focus_effect = match msg {
        SetBottomTab(BtTerminal) | SetPerspective(PsAi) =>
          @moui.Effect::send(FocusTerminalRequest)
        _ => @moui.Effect::none()
      }
      // 终端全模式可用（M8 用户反馈①②）：触发不限模式——页签在哪个
      // 模式被选中，PTY 就在那里派生
      let terminal_spawn_effect = if next0.bottom_tab is BtTerminal &&
        next0.terminal_open &&
        next0.terminal.handle is None &&
        pty.available {
        @moui.Effect::dispatch(emit => {
          let handle = (pty.spawn)(
            80,
            24,
            text => TerminalOutput(text),
            () => TerminalClose,
            emit,
          )
          emit(TerminalSpawned(handle))
        })
      } else {
        @moui.Effect::none()
      }
      // 事件出口排空（M1 内核化）：本趟 update 发出的全部事实经事件总线
      // 翻译为后续消息（副作用在那些消息的臂里经 svc 执行）。取代旧的
      // preview_web diff / build busy 上升 / code_project flag 三个消费点。
      let events_effect = @kernel.fire_events(next0.outbox, bus)
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
      let next = {
        ..next0,
        // 事件已排空：outbox 归零（与旧 flag 的「消费即清位」同语义）
        outbox: [],
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
          events_effect,
          compile_effect,
          terminal_spawn_effect,
          terminal_focus_effect,
          services
          .settings()
          .write(DRAFT_SETTINGS_KEY, encoding)
          .effect(map=_ => SetNotice("")),
        ])
      } else {
        @moui.Effect::batch([
          effect0, events_effect, compile_effect, terminal_spawn_effect, terminal_focus_effect,
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
              x=topbar_drag_x(model),
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
    subscriptions=model => run_subscription(model, timer, wall),
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
        // M4 流式：fake 路径 = 确定性分块流（本地讲解文本按固定字符数
        // 切块，逐片经 StreamChunk 追加进当前会话的流式卡；真实 provider
        // 未来把回调换成 SSE 分片即可复用同一消息流）
        let (with_explanation, _) = update_pure(model, msg)
        let streamed = push_ai_card(with_explanation, AiCard::{
          kind: CardExplanation,
          title: text(translator(model), "app.ai.card.explain"),
          body: "",
          steps: [],
          steps_done: 0,
          progress: 0,
          diff_lines: [],
          settled: false,
          settled_note: "",
          seq: 0,
          at: 0,
        })
        let streamed = { ..streamed, ai_streaming: true, explanation: "", }
        let chunks = @ai.fake_stream_chunks(with_explanation.explanation, 12)
        (
          streamed,
          @moui.Effect::dispatch(emit => {
            for chunk in chunks {
              emit(StreamChunk(chunk))
            }
            emit(StreamFinished)
          }),
        )
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
                prompt: model.ai_sessions.current().prompt_draft,
              },
              result => emit(RealGenerationFinished(result)),
            )
          }),
        )
      }
    _ => update_with_services(model, msg, services)
  }
}

///|
/// 生成源逆解析门面：测试与未来「粘贴代码 → 积木」入口共用的唯一通道
/// （app 不直接散用 @blocks_code,导入面收敛于此）。
pub fn parse_generated_source(
  source : String,
  stmt_lines : Array[@export.StmtLine],
) -> @blocks_code.ParsedHandlerSource {
  @blocks_code.parse_generated_source(source, stmt_lines)
}
