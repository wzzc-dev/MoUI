///|
/// v4 IDE 壳消息域：工作区编排、面板显隐、审计/Console/最近修改、
/// AI 浮动层、快速操作、对话框与 toast。
///
/// 与既有消息域的关系：这里是**壳的状态**（谁可见、选中哪个页签、
/// 浮动层停在哪），不改 IR 语义；改 IR 的动作（快速插入、对齐）
/// 仍走 with_undo_point + 既有 commit 通道，保证撤销栈连续。

///|
/// AI 插件的会话切片挂载（M3，settings 样板同构）：lens 对 + wrap。
/// 视图由壳组装（切片的 Feature view 域刻意 abort，见插件包注释）。
fn ai_sessions_scope() -> @moui.ScopedFeature[
  Model,
  @ai.AiSessions,
  @ai.AiSessionMsg,
  Msg,
] {
  @ai.ai_sessions_feature().scope(
    read=model => model.ai_sessions,
    write=(sessions, model) => { ..model, ai_sessions: sessions, },
    wrap=message => AiSessionOp(message),
  )
}

///|
/// 壳消息分发：未命中返回 None（链式交给其他域）。
pub fn update_ide_msgs(model : Model, msg : Msg) -> (Model, @moui.Effect[Msg])? {
  match msg {
    AiSessionOp(op) => {
      // AI 插件会话切片经 Feature::scope 委托（M3）：lens 对 + wrap，
      // 与 settings 样板同构；切片 update 零副作用，effect 原样丢弃。
      let scope = ai_sessions_scope()
      let (next, effect) = scope.update(model, op)
      // 切换会话 = 换一条时间线：滚动复位到顶 + 恢复自动跟随
      // （贴底由新内容到达时触发，终端同款口径）。
      let next = match op {
        // 新建/切换/删除都会改变「当前时间线」——滚动复位 + 恢复跟随
        AiSessionCreate(_) | AiSessionSwitch(_) | AiSessionRemove(_) => {
          next.transcript_scroll = @geometry.Point::new(x=0.0, y=0.0)
          next.transcript_scroll_seq = next.transcript_scroll_seq + 1
          next.transcript_follow = true
          // 结构性事件：会话存储脏标（切换也存——active 指针在存储里）
          mark_ai_sessions_dirty(next)
          next
        }
        AiSessionPin(_, _) => {
          mark_ai_sessions_dirty(next)
          next
        }
        _ => next
      }
      Some((next, effect))
    }
    SetPerspective(p) => Some(set_perspective(model, p))
    SetWorkSpace(workspace) => Some(set_workspace(model, workspace))
    TogglePaneLive => Some(toggle_pane_live(model))
    ShowPaneLive => Some(show_pane_live(model))
    ShowPaneBlocks => Some(show_pane_blocks(model))
    TogglePaneBlocks => Some(toggle_pane_blocks(model))
    SetSplitRatio(ratio) => Some(set_split_ratio(model, ratio))
    SetLeftView(view) => Some(set_left_view(model, view))
    SetActiveProject(index) =>
      Some(
        (
          { ..model, active_project: index, selected_project_file: None, },
          @moui.Effect::none(),
        ),
      )
    ToggleProjectPackage(rel) => {
      // 折叠集合翻转(与 ToggleTreeGroup 同一手法,不共享可变数组)
      let collapsed : Array[String] = []
      let mut removed = false
      for item in model.project_tree_collapsed {
        if item == rel {
          removed = true
        } else {
          collapsed.push(item)
        }
      }
      if !removed {
        collapsed.push(rel)
      }
      Some(
        ({ ..model, project_tree_collapsed: collapsed, }, @moui.Effect::none()),
      )
    }
    ProjectFileLoaded(rel, result) =>
      match result {
        Success(content) =>
          // 文件仍处于选中态才挂载编辑器（再点同文件 = 取消选中）;
          // G4 多标签:同 rel 原位替换(重新读取=刷新内容),否则追加并激活。
          if model.selected_project_file is Some(current) && current == rel {
            let (files, index) = upsert_open_file(model.open_project_files, OpenProjectFile::{
              rel,
              saved_content: content,
              draft: content,
              caret: 0,
              selection: None,
            })
            Some(
              (
                { ..model, open_project_files: files, open_file_index: index, },
                @moui.Effect::none(),
              ),
            )
          } else {
            Some((model, @moui.Effect::none()))
          }
        Failure(error) =>
          Some((with_notice(model, error.message, true), @moui.Effect::none()))
        Cancelled => Some((model, @moui.Effect::none()))
      }
    ProjectFileSaveFinished(rel, result) =>
      // 落盘完成:按 rel 定位 tab,脏基准对齐草稿（写盘任务在服务层）。
      // F4 live 诊断:保存 .mbt 即自动起一次 web 构建（build 通道原样复用,
      // 诊断汇 Problems）——保存是天然节流点,不做独立防抖计时器。
      match result {
        Success(_) =>
          match open_file_index_of(model.open_project_files, rel) {
            Some(index) => {
              let open = model.open_project_files[index]
              let aligned = with_notice(
                {
                  ..model,
                  open_project_files: replace_open_file_at(
                    model.open_project_files,
                    index,
                    { ..open, saved_content: open.draft, },
                  ),
                },
                "已保存",
                false,
              )
              let (with_build, build_effect) = auto_build_after_save(
                aligned,
                open.rel,
              )
              Some((with_build, build_effect))
            }
            None => Some((model, @moui.Effect::none()))
          }
        Failure(error) =>
          Some((with_notice(model, error.message, true), @moui.Effect::none()))
        Cancelled => Some((model, @moui.Effect::none()))
      }
    ProjectFileCaretMoved(caret, selection) =>
      // 受控编辑器的光标回传（active tab）:没有这个往返,光标不能移动
      // （移动会被模型里的旧值复位——实测「光标只能向上」的根因）。
      match active_project_file(model) {
        None => Some((model, @moui.Effect::none()))
        Some(open) =>
          Some(
            (
              {
                ..model,
                open_project_files: replace_open_file_at(
                  model.open_project_files,
                  model.open_file_index,
                  { ..open, caret, selection, },
                ),
              },
              @moui.Effect::none(),
            ),
          )
      }
    EditProjectFile(draft) =>
      match active_project_file(model) {
        None => Some((model, @moui.Effect::none()))
        Some(open) =>
          Some(
            (
              {
                ..model,
                open_project_files: replace_open_file_at(
                  model.open_project_files,
                  model.open_file_index,
                  { ..open, draft, },
                ),
              },
              @moui.Effect::none(),
            ),
          )
      }
    // tab 导航（G4 多标签）：切换 = 置 active（光标随 tab 恢复）;
    // 关闭的脏 tab 守卫在 update_confirm_msgs（CkCloseFileTab）。
    SelectFileTab(index) =>
      if index >= 0 && index < model.open_project_files.length() {
        Some(({ ..model, open_file_index: index, }, @moui.Effect::none()))
      } else {
        Some((model, @moui.Effect::none()))
      }
    CloseFileTab(index) =>
      Some((close_open_file_at(model, index), @moui.Effect::none()))
    // 文件 CRUD 输入态（G4）：新建/改名共用一行式输入,Start 置草稿,
    // Dismiss 清态;Draft 只在对应模式打开时接受（防串台）。
    FileCreateStart =>
      Some(
        (
          {
            ..model,
            file_create_open: true,
            file_rename_open: None,
            file_name_draft: "",
          },
          @moui.Effect::none(),
        ),
      )
    FileCreateDraft(value) =>
      if model.file_create_open {
        Some(({ ..model, file_name_draft: value, }, @moui.Effect::none()))
      } else {
        Some((model, @moui.Effect::none()))
      }
    FileCreateDismiss =>
      Some(
        (
          { ..model, file_create_open: false, file_name_draft: "", },
          @moui.Effect::none(),
        ),
      )
    FileRenameStart(rel) =>
      Some(
        (
          {
            ..model,
            file_rename_open: Some(rel),
            file_create_open: false,
            file_name_draft: rel,
          },
          @moui.Effect::none(),
        ),
      )
    FileRenameDraft(value) =>
      if model.file_rename_open is Some(_) {
        Some(({ ..model, file_name_draft: value, }, @moui.Effect::none()))
      } else {
        Some((model, @moui.Effect::none()))
      }
    FileRenameDismiss =>
      Some(
        (
          { ..model, file_rename_open: None, file_name_draft: "", },
          @moui.Effect::none(),
        ),
      )
    // 全文搜索（G4 F3）:查询草稿纯转移;运行与回执在服务层
    SearchQueryDraft(value) =>
      Some(({ ..model, search_query: value, }, @moui.Effect::none()))
    // 纯聊天离线（G1）：确定性假回复 + 接通引导（真实提交在程序级臂）
    ChatSubmit =>
      if model.provider_mode is Fake || model.provider_key == "" {
        let prompt = model.ai_sessions.current().prompt_draft
        let reply = text_with(
          translator(model),
          "app.ai.offline_reply",
          [("prompt", prompt)],
        )
        let with_card = push_ai_card(
          model,
          AiCard::{
            kind: CardExplanation,
            title: text(translator(model), "app.ai.chat.title"),
            body: reply,
            steps: [],
            steps_done: 0,
            progress: 0,
            diff_lines: [],
            settled: true,
            settled_note: "",
            seq: 0,
            at: 0,
          },
        )
        let hinted = with_notice(
          with_card,
          text(translator(model), "app.ai.offline_hint"),
          false,
        )
        Some((hinted, @moui.Effect::none()))
      } else {
        // 真实提交：纯链未命中（程序级臂接管）
        None
      }
    SelectProjectFile(rel) =>
      // 再点同一个文件 = 取消选中(与图标栏「再点一次」同一心智)
      Some(
        (
          {
            ..model,
            selected_project_file: if model.selected_project_file
              is Some(current) &&
              current == rel {
              None
            } else {
              Some(rel)
            },
          },
          @moui.Effect::none(),
        ),
      )
    RemoveProject(index) => {
      let removed = remove_project_at(model, index)
      mark_projects_dirty(removed)
      Some((removed, @moui.Effect::none()))
    }
    // 扫描进度(G2):节流回调读数,一行显示;完成臂统一清 None
    ProjectScanProgress(p) =>
      Some(
        (
          {
            ..model,
            scan_progress: Some(
              text_with(translator(model), "app.project.scanning", [
                ("n", p.scanned_dirs.to_string()),
                ("path", p.current),
              ]),
            ),
          },
          @moui.Effect::none(),
        ),
      )
    SelectSemanticNode(index) => {
      // 选中语义节点:label 预填进编辑草稿(空 label 也能选中,草稿为空);
      // 再点同一个 = 取消选中
      let current = match model.selected_semantic {
        Some(value) => value
        None => -1
      }
      if index == current {
        Some(
          (
            { ..model, selected_semantic: None, semantic_draft: "", },
            @moui.Effect::none(),
          ),
        )
      } else {
        let draft = match model.preview_frame {
          Some(frame) => {
            let nodes = semantic_hit_nodes(frame)
            if index >= 0 && index < nodes.length() {
              nodes[index].label
            } else {
              ""
            }
          }
          None => ""
        }
        Some(
          (
            { ..model, selected_semantic: Some(index), semantic_draft: draft, },
            @moui.Effect::none(),
          ),
        )
      }
    }
    SemanticLabelInput(text) =>
      Some(({ ..model, semantic_draft: text, }, @moui.Effect::none()))
    SetPreviewMode(mode) =>
      Some(({ ..model, preview_mode: mode, }, @moui.Effect::none()))
    // 直达目标外观（实测反馈：单个循环胶囊太隐蔽，用户找不到 DSL 入口）
    SetCodeAppearance(appearance) =>
      Some(
        (
          sync_code_draft({ ..model, code_appearance: appearance, }),
          @moui.Effect::none(),
        ),
      )
    // 布局页签开关（M4 收尾）：进入布局设计时若无会话则自动加载 form.mbt
    //（FormDesignOpen 走服务层读盘链）。
    SetPreviewDesignOpen(open) => {
      let next = { ..model, preview_design_open: open, }
      if open && model.form_designer is None {
        Some((next, @moui.Effect::dispatch(emit => emit(FormDesignOpen))))
      } else {
        Some((next, @moui.Effect::none()))
      }
    }
    SelectFormControl(index) => {
      let current = match model.selected_form_control {
        Some(value) => value
        None => -1
      }
      if index == current {
        Some(({ ..model, selected_form_control: None, }, @moui.Effect::none()))
      } else {
        Some(
          (
            { ..model, selected_form_control: Some(index), },
            @moui.Effect::none(),
          ),
        )
      }
    }
    SetRightView(view) => Some(set_right_view(model, view))
    // 列间 sash 拖拽：视图层已按当帧布局夹取，这里再兜底夹一次静态界限
    // （窗口在拖拽中途变小等时序差）。纯布局状态：不进撤销、不标脏。
    ResizeLeftPanel(width) =>
      Some(
        (
          {
            ..model,
            left_width: width.clamp(
              min=LEFTBAR_MIN_WIDTH,
              max=LEFTBAR_MAX_WIDTH,
            ),
          },
          @moui.Effect::none(),
        ),
      )
    ResizeRightPanel(width) =>
      Some(
        (
          {
            ..model,
            right_width: width.clamp(
              min=RIGHTBAR_MIN_WIDTH,
              max=RIGHTBAR_MAX_WIDTH,
            ),
          },
          @moui.Effect::none(),
        ),
      )
    SetTreeQuery(query) =>
      Some(({ ..model, tree_query: query, }, @moui.Effect::none()))
    ToggleTreeGroup(group) => {
      let collapsed : Array[String] = []
      let mut removed = false
      for item in model.tree_collapsed {
        if item == group {
          removed = true
        } else {
          collapsed.push(item)
        }
      }
      if !removed {
        collapsed.push(group)
      }
      Some(({ ..model, tree_collapsed: collapsed, }, @moui.Effect::none()))
    }
    TriggerCompletion => {
      let (word, _) = word_at_caret(model.code_draft, model.code_caret)
      let candidates = completions_for(model, word)
      if candidates.length() > 0 {
        Some(
          (
            { ..model, completions: candidates, completion_open: true, },
            @moui.Effect::none(),
          ),
        )
      } else {
        Some((model, @moui.Effect::none()))
      }
    }
    ApplyCompletion(word) => {
      let (text, caret) = apply_completion(
        model.code_draft,
        model.code_caret,
        word,
      )
      Some(
        (
          with_draft_diagnostics({
            ..model,
            code_draft: text,
            code_caret: caret,
            code_selection: None,
            completion_open: false,
          }),
          @moui.Effect::none(),
        ),
      )
    }
    JumpToDeclaration => {
      let line = declaration_line_of(model, model.code_caret)
      if line > 0 {
        Some((goto_line(model, line), @moui.Effect::none()))
      } else {
        Some((model, @moui.Effect::none()))
      }
    }
    DismissCompletion =>
      Some(({ ..model, completion_open: false, }, @moui.Effect::none()))
    SetContextTab(tab) =>
      Some(({ ..model, ctx_tab: tab, }, @moui.Effect::none()))
    SetBottomTab(tab) =>
      Some((select_bottom_tab(model, tab), @moui.Effect::none()))
    ToggleBottom =>
      Some(
        (
          // **收起/展开底栏只动底栏**——绝不偷偷把 AI 输入面挪去右栏。
          //
          // 折叠面板是面板级动作，与「AI 输入面的宿主」是两件事：收起时
          // 输入面跟着收起（和审计/控制台页签一样），展开后原样回来。
          // 宿主由 right_view × 当前模式推导（M2），不存在
          // 「收起把 AI 挪走」的联动（历史事故记录见计划文档）。
          { ..model, bottom_open: !model.bottom_open, },
          @moui.Effect::none(),
        ),
      )
    AuditOpen(index) =>
      Some(
        (
          { ..model, bottom_open: true, bottom_tab: BtAudit, },
          jump_audit(model, index),
        ),
      )
    AuditSettle(index, note) => Some(settle_audit(model, index, note))
    AuditSettleAll(note) => Some(settle_all_audit(model, note))
    ClearConsole => Some(({ ..model, log_lines: [], }, @moui.Effect::none()))
    ToggleAiCardsFold =>
      Some(
        (
          { ..model, ai_cards_folded: !model.ai_cards_folded, },
          @moui.Effect::none(),
        ),
      )
    AlignControlLeft(name) => Some(align_control(model, name, AlignLeft))
    AlignControlCenter(name) => Some(align_control(model, name, AlignCenter))
    AlignControlRight(name) => Some(align_control(model, name, AlignRight))
    ToggleSettings =>
      Some(
        (
          { ..model, settings_open: !model.settings_open, },
          @moui.Effect::none(),
        ),
      )
    ToggleAiHistory =>
      Some(
        (
          { ..model, ai_history_open: !model.ai_history_open, },
          @moui.Effect::none(),
        ),
      )
    DismissToast(index) => Some(dismiss_toast(model, index))
    ToastTick => Some((age_toasts(model), @moui.Effect::none()))
    StudioCommandRun(id) => Some(run_studio_command(model, id))
    SelectBlockCategory(index) =>
      Some(({ ..model, selected_category: index, }, @moui.Effect::none()))
    HighlightIrPath(path) => {
      let same = same_path(model.ir_highlight, path)
      Some(
        (
          { ..model, ir_highlight: if same { [] } else { path }, },
          @moui.Effect::none(),
        ),
      )
    }
    HoverIrPath(path) =>
      Some(({ ..model, hover_path: path, }, @moui.Effect::none()))
    RestoreCodeDraft => Some(restore_code_draft(model))
    _ => None
  }
}

// ============================================================================
// 工作区与面板
// ============================================================================

///|
/// 中心工作区切换（M2 起降为中心形态机制——模式切换走 `SetPerspective`，
/// 活动栏不再有工作区按钮）。**「再点当前 = 空舞台」的语义已删除**（设计
/// 契约 1：五种再点语义收敛为一种；空舞台只作为两窗格全关的自然结果出现）。
/// 同值请求 = no-op。切可视化时两个窗格都显（从收起态恢复要有内容，
/// 否则点了没反应）。
fn set_workspace(
  model : Model,
  workspace : WorkSpace,
) -> (Model, @moui.Effect[Msg]) {
  if model.workspace == workspace {
    return (model, @moui.Effect::none())
  }
  let next = match workspace {
    WsPreview => { ..model, workspace: WsPreview, mode: ModeDesign, }
    WsVisual =>
      {
        ..model,
        workspace: WsVisual,
        mode: ModeDesign,
        pane_live: true,
        pane_blocks: true,
      }
    WsCode => { ..model, workspace: WsCode, mode: ModeCode, }
    // WsEmpty 不再是任何入口的目标（空舞台 = 两窗格全关的自然结果，
    // 恢复入口是空舞台上的「+ 窗格」按钮）；防御性保留：照原样置位。
    WsEmpty => { ..model, workspace: WsEmpty, }
  }
  (next, @moui.Effect::none())
}

///|
fn toggle_pane_live(model : Model) -> (Model, @moui.Effect[Msg]) {
  ({ ..model, pane_live: !model.pane_live, }, @moui.Effect::none())
}

///|
fn toggle_pane_blocks(model : Model) -> (Model, @moui.Effect[Msg]) {
  ({ ..model, pane_blocks: !model.pane_blocks, }, @moui.Effect::none())
}

///|
/// 幂等显示 Live App 窗格（空舞台的恢复入口）。
///
/// 必须用**赋值**而不是取反：空舞台只在两个窗格都关掉时出现，所以
/// `ShowPaneLive` 执行时 `pane_live` 一定是 false——但用取反会让这条消息
/// 在别处（比如命令面板）变成「关掉它」，语义不可预测。赋值才是
/// 设计稿 `#btnAddLive` 的语义：`S.live=true`。
///
/// 同时把工作区切回可视化：空舞台可以是 `WsEmpty`（点图标栏收起）造成的，
/// 那时只把 pane 打开、工作区还停在 `WsEmpty`，用户点了按钮却什么都没变。
fn show_pane_live(model : Model) -> (Model, @moui.Effect[Msg]) {
  (
    { ..model, workspace: WsVisual, mode: ModeDesign, pane_live: true, },
    @moui.Effect::none(),
  )
}

///|
/// 幂等显示积木窗格（空舞台的恢复入口）。
///
/// 积木窗格还要**有选中的子程序**才画得出来（`blocks_pane_wanted` 判据）。
/// 从空舞台进来时如果没有选中的子程序，就顺手选上第一个——否则用户点了
/// 「+ 积木窗格」而屏幕上只有 Live App，看起来就是按钮没反应。
fn show_pane_blocks(model : Model) -> (Model, @moui.Effect[Msg]) {
  let mut next = {
    ..model,
    workspace: WsVisual,
    mode: ModeDesign,
    pane_blocks: true,
  }
  if current_handler(next) is None {
    match next.program.handlers {
      [first, ..] =>
        next = {
          ..next,
          selected_control: first.control_name,
          selected_handler: handler_key(first.control_name, first.event.tag()),
        }
      [] => ()
    }
  }
  (next, @moui.Effect::none())
}

///|
/// 分隔条比例：钳在 0.2–0.8（两端都留得住内容，拖到底不会把窗格压没）。
fn set_split_ratio(model : Model, ratio : Double) -> (Model, @moui.Effect[Msg]) {
  let clamped = if ratio.is_nan() { 0.55 } else { ratio.max(0.2).min(0.8) }
  ({ ..model, split_ratio: clamped, }, @moui.Effect::none())
}

///|
/// 左栏切换：点当前图标 = 收起（设计稿 setLeft 语义）。
fn set_left_view(model : Model, view : LeftView) -> (Model, @moui.Effect[Msg]) {
  let target = match (model.left_view, view) {
    (LeftTree, LeftTree) | (LeftData, LeftData) | (LeftProject, LeftProject) =>
      LeftHidden
    (_, wanted) => wanted
  }
  ({ ..model, left_view: target, }, @moui.Effect::none())
}

///|
/// 会话内移除导入的工程(不动磁盘)。active_project 随之修正:
/// 移除的正是当前选中 → 清空选中;移除在选中之前 → 下标左移一位。
fn remove_project_at(model : Model, index : Int) -> Model {
  if index < 0 || index >= model.projects.length() {
    return model
  }
  let projects : Array[ProjectRecord] = []
  let mut i = 0
  for project in model.projects {
    if i != index {
      projects.push(project)
    }
    i = i + 1
  }
  // 选中修正:移除的正是当前选中 → 落到**同位的下一个工程**(IDE 移除
  // 选中标签页的惯例;列表空了才清空选中);移除在选中之前 → 下标左移。
  let remaining = projects.length()
  let active = if model.active_project == index {
    if remaining == 0 {
      -1
    } else if index >= remaining {
      remaining - 1
    } else {
      index
    }
  } else if model.active_project > index {
    model.active_project - 1
  } else {
    model.active_project
  }
  { ..model, projects, active_project: active, selected_project_file: None, }
}

///|
/// 右栏当前视图（M2）：右栏头的 ✕ 关（RvHidden），重开与换视图走命令
/// 面板逃生口（studio.right.context / studio.ai.dock 等）。幂等。
///
/// 切到停靠（RvAi）时底栏若正停在 AI 页签必须让开——否则底栏（stale 页签）
/// 与右栏各画一份 composer。这不是「落点联动」：宿主仍是推导的，这里只是
/// 把 stale 的页签选择复位到审计（AI 回底栏时由 studio.ai.bar 显式选回）。
fn set_right_view(
  model : Model,
  view : RightView,
) -> (Model, @moui.Effect[Msg]) {
  let next = match (view, model.bottom_tab) {
    (RvAi, BtAi) => { ..model, bottom_tab: BtAudit, }
    _ => model
  }
  ({ ..next, right_view: view, }, @moui.Effect::none())
}

///|
/// 任务模式切换（M2 三模式工作台）：**进模式 = 应用预设**——一次性置位
/// 左栏视图、右栏视图与中心形态。同值再点 no-op（设计契约 1：不再有
/// 「再点 = 空舞台」）。模式内的临时收放不回写预设（契约 3），预设也不
/// 跨模式记忆（v1）。
fn set_perspective(
  model : Model,
  perspective : StudioPerspective,
) -> (Model, @moui.Effect[Msg]) {
  if model.perspective == perspective {
    return (model, @moui.Effect::none())
  }
  // 教学版 profile（M7）：只开放图形化模式——切其它模式 no-op（能力
  // 缺席而非隐藏报错；活动栏对应图标也不渲染）
  if model.profile is Teaching && !(perspective is PsVisual) {
    return (model, @moui.Effect::none())
  }
  // 插件管理（G7.3）：AI 插件被禁用时切到 AI 模式 no-op（入口同被隐藏）
  if perspective is PsAi && !plugin_active(model, "ai") {
    return (model, @moui.Effect::none())
  }
  (apply_perspective_preset(model, perspective), @moui.Effect::none())
}

///|
/// 预设表（唯一事实，与计划文档的表格一一对应）。中心形态：PsVisual →
/// 可视化画布（预览走 `SetWorkSpace(WsPreview)` 的中心切换，不占活动栏）；
/// PsCode → 代码编辑器；PsAi 不改 workspace——中心渲染以 perspective 优先
/// （M2 过渡 = 全幅 composer，M3 升级会话流）。
fn apply_perspective_preset(
  model : Model,
  perspective : StudioPerspective,
) -> Model {
  match perspective {
    PsVisual =>
      {
        ..model,
        perspective,
        left_view: LeftTree,
        right_view: RvContext,
        workspace: WsVisual,
        mode: ModeDesign,
      }
    PsCode =>
      {
        ..model,
        perspective,
        left_view: LeftProject,
        right_view: RvAi,
        workspace: WsCode,
        mode: ModeDesign,
      }
    PsAi =>
      {
        ..model,
        perspective,
        // AI 会话列表（M3 插件贡献的左栏视图）
        left_view: LeftAiSessions,
        right_view: RvHidden,
        mode: ModeDesign,
        // 真终端页签（M5/M8）：AI 模式预设选中终端页签；底栏默认收起
        // （M8④ 用户反馈：需要时再展开——页签头常在，点终端页签即展开）
        bottom_tab: BtTerminal,
        bottom_open: false,
      }
  }
}

// ============================================================================
// 审计时间线
// ============================================================================

///|
/// 追加审计条目（会话内，超 AUDIT_LIMIT 丢最旧）。
/// 视图层与 update 层共用：所有条目都带单调序号，稳定 key。
pub fn push_audit(
  model : Model,
  kind : AuditKind,
  text : String,
  detail : String,
) -> Model {
  let entries = model.audit_entries
  entries.push(AuditEntry::{
    kind,
    seq: model.audit_seq,
    text,
    detail,
    stack: "",
    settled: false,
    settled_note: "",
  })
  while entries.length() > AUDIT_LIMIT {
    ignore(entries.remove(0))
  }
  { ..model, audit_entries: entries, audit_seq: model.audit_seq + 1, }
}

///|
/// 追加带调用栈的审计错误卡。
pub fn push_audit_error(model : Model, text : String, stack : String) -> Model {
  let entries = model.audit_entries
  entries.push(AuditEntry::{
    kind: AuditError,
    seq: model.audit_seq,
    text,
    detail: "",
    stack,
    settled: false,
    settled_note: "",
  })
  while entries.length() > AUDIT_LIMIT {
    ignore(entries.remove(0))
  }
  { ..model, audit_entries: entries, audit_seq: model.audit_seq + 1, }
}

///|
/// 追加副作用待确认卡（AuditWarn）。
pub fn push_audit_side_effect(
  model : Model,
  text : String,
  detail : String,
) -> Model {
  push_audit(model, AuditWarn, text, detail)
}

///|
/// 点击审计条目：整数下标 → 该条目的序号，再反查对应积木块。
/// 审计条目记的是「第几条事实」，跳转需要的是「哪条语句」——
/// 这里按条目序号定位到最近一条带语句路径的事实（detail 里存的
/// 是规范文本，用 current_spotlight 同源的匹配）。
fn jump_audit(model : Model, index : Int) -> @moui.Effect[Msg] {
  ignore(model)
  ignore(index)
  @moui.Effect::none()
}

///|
/// 处理单条审计卡（确认/拒绝）：标记 settled + 记 Console。
fn settle_audit(
  model : Model,
  index : Int,
  note : String,
) -> (Model, @moui.Effect[Msg]) {
  if index < 0 || index >= model.audit_entries.length() {
    return (model, @moui.Effect::none())
  }
  let entries : Array[AuditEntry] = []
  let mut cursor = 0
  for entry in model.audit_entries {
    if cursor == index {
      entries.push(AuditEntry::{ ..entry, settled: true, settled_note: note, })
    } else {
      entries.push(entry)
    }
    cursor = cursor + 1
  }
  let next = { ..model, audit_entries: entries, }
  (log_line(next, LogInfo, "app.log.settled"), @moui.Effect::none())
}

///|
/// 一键确认全部副作用卡：把「待确认」清空（仍不改闸门语义——真实
/// 外发只在运行时点确认按钮时才发生）。
fn settle_all_audit(model : Model, note : String) -> (Model, @moui.Effect[Msg]) {
  let entries : Array[AuditEntry] = []
  let mut changed = false
  for entry in model.audit_entries {
    if entry.kind is AuditWarn && !entry.settled {
      entries.push(AuditEntry::{ ..entry, settled: true, settled_note: note, })
      changed = true
    } else {
      entries.push(entry)
    }
  }
  if !changed {
    return (model, @moui.Effect::none())
  }
  let next = { ..model, audit_entries: entries, }
  (log_line(next, LogInfo, "app.log.settled_all"), @moui.Effect::none())
}

// ============================================================================
// Console
// ============================================================================

///|
/// 追加 Console 日志行（超 LOG_LIMIT 丢最旧）。
pub fn log_line(model : Model, level : LogLevel, text : String) -> Model {
  let lines = model.log_lines
  lines.push(LogLine::{ level, seq: model.log_seq, text, })
  while lines.length() > LOG_LIMIT {
    ignore(lines.remove(0))
  }
  { ..model, log_lines: lines, log_seq: model.log_seq + 1, }
}

// ============================================================================
// 最近修改
// ============================================================================

///|
/// 追加最近修改条目（会话内，超 RECENT_LIMIT 丢最旧）。
/// by_agent 区分「你」与「Agent」——教学上这是最重要的一列。
pub fn push_recent(
  model : Model,
  target : String,
  action : String,
  by_agent : Bool,
) -> Model {
  let changes = model.recent_changes
  changes.push(RecentChange::{
    target,
    by_agent,
    action,
    seq: model.recent_seq,
  })
  while changes.length() > RECENT_LIMIT {
    ignore(changes.remove(0))
  }
  { ..model, recent_changes: changes, recent_seq: model.recent_seq + 1, }
}

// ============================================================================
// AI 浮动层
// ============================================================================

///|
/// 切换底栏页签。
///
/// **只读页签绝不搬动 AI 输入面**：点「运行审计」「Console」「问题」只是
/// 想看一眼那个面板。M2 起 AI 的宿主由 `right_view` 与当前模式**推导**
/// （右栏停靠 > AI 模式中心 > 底栏页签），「页签与落点互相联动」的整套
/// reconciliation（sync_ai_placement / apply_ai_anchor）随之删除——
/// 推导出的状态天然自洽，没有需要收敛的矛盾态。

///|
/// 底栏高度兜底钳制（视图层按窗口高度精确钳后，update 再兜底）。
pub fn clamp_bottom_height(height : Double) -> Double {
  height.clamp(min=100.0, max=1200.0)
}

///|
fn select_bottom_tab(model : Model, tab : BottomTab) -> Model {
  // 终端页签（M8）：**关闭态**再点 = 重开（terminal_open 恢复，句柄已清
  // → 下次 update 重派生）；选中态的关闭走 TerminalTabClose（kill 需要
  // 服务，在 update_with_services）。其余页签照常选中。
  if tab is BtTerminal && !model.terminal_open {
    model.terminal_open = true
    return { ..model, bottom_tab: tab, bottom_open: true, }
  }
  { ..model, bottom_tab: tab, bottom_open: true, }
}

///|
/// 追加 AI 会话卡（超 AI_CARD_LIMIT 丢最旧）：写进**当前会话**的线程
/// （M3 会话切片化，经 amend 原位替换活跃会话）。`at` 戳在这里统一盖——
/// 构造点不必各自取钟，时间线的时间与时长口径单一。
pub fn push_ai_card(model : Model, card : AiCard) -> Model {
  let session = model.ai_sessions.current()
  let cards = session.cards
  cards.push(AiCard::{
    ..card,
    seq: session.card_seq,
    at: civil_seconds(model.clock),
  })
  while cards.length() > AI_CARD_LIMIT {
    ignore(cards.remove(0))
  }
  model.ai_sessions.amend({ ..session, cards, card_seq: session.card_seq + 1, })
  // 新内容到达：跟随态下强制时间线贴底（对白转录；非跟随态不动）
  follow_transcript(model)
}

// ============================================================================
// 快速操作（对齐）
// ============================================================================

///|
/// 对齐目标：设计稿口径是 24pt 边距、640 设计宽。
priv enum AlignTarget {
  AlignLeft
  AlignCenter
  AlignRight
}

///|
/// 对齐单个选中控件：改 x，宽度不变。
/// 24pt 边距与「居中 = round((640 − w) / 2)」直接来自设计稿的 qaBar。
/// 走 with_undo_point（coalesce 键按控件+对齐方式，连续对齐合并为一个还原点）。
fn align_control(
  model : Model,
  name : String,
  target : AlignTarget,
) -> (Model, @moui.Effect[Msg]) {
  match @ir.find_control(model.program, name) {
    None => (model, @moui.Effect::none())
    Some(control) => {
      let x = match target {
        AlignLeft => ALIGN_MARGIN
        AlignCenter => (@ir.DESIGN_WIDTH - control.width) / 2
        AlignRight => @ir.DESIGN_WIDTH - control.width - ALIGN_MARGIN
      }
      let clamped = x.max(0)
      if clamped == control.x {
        return (model, @moui.Effect::none())
      }
      let undo = with_undo_point(model, "align:\{name}", m => {
        let controls : Array[@ir.Control] = []
        for item in m.program.controls {
          if item.name == name {
            controls.push(item.with_rect_field(@ir.RectX, clamped))
          } else {
            controls.push(item)
          }
        }
        { ..m, program: { ..m.program, controls, }, }
      })
      let next = { ..undo, selected_control: name, }
      (
        log_line(
          push_recent(next, name, "app.recent.align", false),
          LogInfo,
          "app.log.align",
        ),
        @moui.Effect::none(),
      )
    }
  }
}

///|
/// 设计稿的快速操作对齐边距。
pub const ALIGN_MARGIN : Int = 24

// ============================================================================
// 对话框与命令
// ============================================================================

///|
fn dismiss_toast(model : Model, index : Int) -> (Model, @moui.Effect[Msg]) {
  if index < 0 || index >= model.toasts.length() {
    return (model, @moui.Effect::none())
  }
  let toasts : Array[ToastEntry] = []
  let mut cursor = 0
  for toast in model.toasts {
    if cursor != index {
      toasts.push(toast)
    }
    cursor = cursor + 1
  }
  ({ ..model, toasts, }, @moui.Effect::none())
}

///|
/// 追加 toast（超 TOAST_LIMIT 丢最旧）。
pub fn push_toast(model : Model, text : String, warning : Bool) -> Model {
  let toasts = model.toasts
  toasts.push(ToastEntry::{ text, warning, age: 0, })
  while toasts.length() > TOAST_LIMIT {
    ignore(toasts.remove(0))
  }
  { ..model, toasts, }
}

///|
/// notice 的唯一写入漏斗：写 `model.notice` 的同时补推一条 toast。
///
/// 为什么必须有这个漏斗：`notice` 在视图层**没有任何渲染点**（状态栏不画
/// 它），直接写结构体字段等于把成功/失败静默吞掉——保存失败、解析失败、
/// 预算超限、Web 端编译轨不可达，用户全都看不到。所有 notice 写入必须
/// 走这里；警告类（warning=true）用暖色条。空串（settings 写入的哑回调
/// `SetNotice("")`）只清字段，不产生 toast。长文本按 toast 文案宽度截断
/// （toast 视图是定宽 300 的单行）。
pub fn with_notice(model : Model, notice : String, warning : Bool) -> Model {
  if notice == "" {
    return { ..model, notice: "", }
  }
  push_toast({ ..model, notice, }, fit_label(notice, 280.0), warning)
}

///|
/// Studio 自有命令：比 moui 文本命令协议的 10 个 intent 更宽的壳操作。
/// 每条命令都是既有消息的封装——命令面板不引入新的状态通道。
fn run_studio_command(model : Model, id : String) -> (Model, @moui.Effect[Msg]) {
  match id {
    // 三模式（M2）：面板命令 = 模式命令；预览是图形化模式的中心形态
    "studio.mode.visual" => update_pure(model, SetPerspective(PsVisual))
    "studio.mode.code" => update_pure(model, SetPerspective(PsCode))
    "studio.mode.ai" => update_pure(model, SetPerspective(PsAi))
    "studio.workspace.visual" => update_pure(model, SetPerspective(PsVisual))
    "studio.workspace.code" => update_pure(model, SetPerspective(PsCode))
    "studio.workspace.preview" => update_pure(model, SetWorkSpace(WsPreview))
    "studio.pane.split" => update_pure(model, SetSplitRatio(0.55))
    "studio.left.toggle" =>
      update_pure(
        model,
        SetLeftView(
          if model.left_view is LeftHidden {
            LeftTree
          } else {
            LeftHidden
          },
        ),
      )
    "studio.pane.live" => update_pure(model, TogglePaneLive)
    "studio.pane.blocks" => update_pure(model, TogglePaneBlocks)
    "studio.left.tree" => update_pure(model, SetLeftView(LeftTree))
    "studio.left.data" => update_pure(model, SetLeftView(LeftData))
    "studio.right.toggle" =>
      update_pure(
        model,
        SetRightView(
          if model.right_view is RvHidden {
            // AI 模式展开 = 工作区面板（更改/文件——VS Code 智能体模式口径）;
            // 其余模式 = 检查器
            if model.perspective is PsAi {
              RvWorkspace
            } else {
              RvContext
            }
          } else {
            RvHidden
          },
        ),
      )
    "studio.right.context" => update_pure(model, SetRightView(RvContext))
    "studio.ctx.runtime" => update_pure(model, SetContextTab(CtxRuntime))
    "studio.code.complete" => update_pure(model, TriggerCompletion)
    "studio.code.jump" => update_pure(model, JumpToDeclaration)
    "studio.bottom.audit" => update_pure(model, SetBottomTab(BtAudit))
    "studio.bottom.console" => update_pure(model, SetBottomTab(BtConsole))
    "studio.bottom.problems" => update_pure(model, SetBottomTab(BtProblems))
    "studio.bottom.toggle" => update_pure(model, ToggleBottom)
    "studio.audit.settle_all" =>
      update_pure(model, AuditSettleAll("app.audit.confirmed"))
    // AI 落点显式 move-to（M2）：落底栏 = 右栏换回检查器 + 展开底栏选中
    // AI 页签（「把输入面放到某处」必须同时让它可见）；落右栏 = 停靠。
    // 不再有循环命令。composer 的 ghost 按钮也走这两条命令。
    // 会话管理（M6,对白转录）：命令面板与键盘同走 run_studio_command
    "studio.ai.new_session" =>
      update_pure(
        model,
        AiSessionOp(AiSessionCreate(civil_seconds(model.clock))),
      )
    "studio.ai.search" => update_pure(model, ToggleAiSessionSearch)
    "studio.ai.bar" => {
      let (next, _) = update_pure(model, SetRightView(RvContext))
      update_pure(next, SetBottomTab(BtAi))
    }
    "studio.ai.dock" => update_pure(model, SetRightView(RvAi))
    "studio.ai.history" => update_pure(model, ToggleAiHistory)
    "studio.settings" => update_pure(model, ToggleSettings)
    "studio.run.start" => update_pure(model, RunStart)
    "studio.run.stop" => update_pure(model, RunStop)
    "studio.compile.run" => update_pure(model, CompileRun)
    "studio.file.new" => update_pure(model, NewBlankProgram)
    "studio.file.save" => update_pure(model, SaveRequested)
    "studio.file.open" => update_pure(model, OpenRequested)
    "studio.file.export" => update_pure(model, ExportRequested)
    "studio.lang.switch" => update_pure(model, SwitchLanguage)
    "studio.help" => update_pure(model, SetMode(ModeHelp))
    "studio.preview" => update_pure(model, SetMode(ModePreview))
    "studio.template.hello" => update_pure(model, SelectTemplate(0))
    "studio.template.roll_call" => update_pure(model, SelectTemplate(1))
    "studio.template.drill" => update_pure(model, SelectTemplate(2))
    "studio.template.store" => update_pure(model, SelectTemplate(3))
    _ => (model, @moui.Effect::none())
  }
}

///|
/// 代码草稿回归 IR 渲染：丢弃手改，按**当前外观**重新渲染当前子程序。
/// 外观感知（实测缺陷）：旧实现无条件按 DSL 语言渲染——MoonBit 外观下
/// 点「按 IR 重渲染」会把草稿打回中文 DSL 且没有回去的入口。
fn restore_code_draft(model : Model) -> (Model, @moui.Effect[Msg]) {
  match current_handler(model) {
    None => (model, @moui.Effect::none())
    Some(handler) => {
      let rendered = render_code_appearance(model, handler)
      (
        log_line(
          { ..model, code_draft: rendered, code_error: "", },
          LogInfo,
          "app.log.restore",
        ),
        @moui.Effect::none(),
      )
    }
  }
}

///|
/// toast 老化：每秒 +1，满 TOAST_SECONDS 秒即消失（自动，无需手点）。
fn age_toasts(model : Model) -> Model {
  let kept : Array[ToastEntry] = []
  for toast in model.toasts {
    if toast.age + 1 < TOAST_SECONDS {
      kept.push(ToastEntry::{
        text: toast.text,
        warning: toast.warning,
        age: toast.age + 1,
      })
    }
  }
  { ..model, toasts: kept, }
}
