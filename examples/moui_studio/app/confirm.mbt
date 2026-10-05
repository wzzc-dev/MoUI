///|
/// 破坏性操作确认：删除控件 / 删除变量 / 模板覆盖 / 新建覆盖 / 打开覆盖。
///
/// 背景（差距分析 §2.4）：这些动作此前**零确认**——删控件连子程序一起
/// 删、切模板直接覆盖整个程序，一次误点就丢工作。纪律：覆盖性动作先经
/// `RequestConfirm` 弹确认卡，`ConfirmAccepted` 才投递原消息续行。
///
/// 实现方式：`update_confirm_msgs` 挂在纯转移链**最前**，对被守卫的消息
/// 做拦截（原处理器不动）；`ConfirmAccepted` 把原消息经 Effect 重新投递
/// ——此时 `pending_confirm` 已清，守卫放行，消息走原有路径。

///|
/// 待确认的破坏性操作。
pub(all) enum ConfirmKind {
  CkDeleteControl(String)
  CkDeleteVariable(String)
  CkDeleteProjectFile(String)
  CkTemplate(Int)
  CkNewBlank
  CkOpen
}

///|
/// 确认卡的文案（标题 + 正文）：kind 是数据，措辞是渲染层的事。
pub fn confirm_copy(kind : ConfirmKind, t : @i18n.Translator) -> String {
  match kind {
    CkDeleteControl(name) =>
      text_with(t, "app.confirm.delete_control", [("a", name)])
    CkDeleteVariable(name) =>
      text_with(t, "app.confirm.delete_variable", [("a", name)])
    CkDeleteProjectFile(rel) =>
      text_with(t, "app.confirm.delete_project_file", [("a", rel)])
    CkTemplate(_) => text(t, "app.confirm.template")
    CkNewBlank => text(t, "app.confirm.new_blank")
    CkOpen => text(t, "app.confirm.open")
  }
}

///|
/// 守卫条件（模板/新建/打开）：**只看 dirty**——程序出厂自带的示例
/// handler 不算「用户的工作」（否则开箱第一次切模板就要确认，试用品
/// 变成路障）；用户一旦改动（dirty=true）就值得打扰。删除类动作
/// 无条件确认（见 update_confirm_msgs）。
fn program_has_work(model : Model) -> Bool {
  // 不看 dirty 标志——它只在 program 包装层每消息重算，纯转移上下文
  // （测试/服务分支）拿不到；直接比编码：当前程序偏离已存基线即算工作。
  @codec.encode_program(model.program) != model.saved_encoding
}

///|
/// 消息 → 确认种类的守卫表。
fn confirm_kind_of(msg : Msg) -> ConfirmKind {
  match msg {
    DeleteControl(name) => CkDeleteControl(name)
    DeleteVariable(name) => CkDeleteVariable(name)
    SelectTemplate(index) => CkTemplate(index)
    NewBlankProgram => CkNewBlank
    _ => CkOpen
  }
}

///|
/// 纯转移链第一环：确认状态机 + 破坏性守卫。返回 None = 放行后续链。
fn update_confirm_msgs(model : Model, msg : Msg) -> (Model, @moui.Effect[Msg])? {
  match msg {
    RequestConfirm(kind) =>
      Some(({ ..model, pending_confirm: Some(kind), }, @moui.Effect::none()))
    ConfirmDismissed =>
      Some(({ ..model, pending_confirm: None, }, @moui.Effect::none()))
    ConfirmAccepted =>
      match model.pending_confirm {
        None => Some((model, @moui.Effect::none()))
        Some(kind) => {
          let cleared = { ..model, pending_confirm: None, }
          match kind {
            // 打开项目走服务流（文件对话框），纯链接不住：置一次性
            // 放行标记后经 Effect 重投 OpenRequested（app.mbt 的
            // OpenRequested 臂看到标记即放行并复位）。
            CkOpen =>
              Some(
                (
                  { ..cleared, open_confirmed: true, },
                  @moui.Effect::dispatch(emit => emit(OpenRequested)),
                ),
              )
            // 删除工程文件走服务流(磁盘删除,纯链接不住):确认后派发
            // **独立续行消息** ProjectFileDeleteRun——它不是被守卫消息,
            // 无需放行标记,服务层直接执行删除并重扫工程。
            CkDeleteProjectFile(rel) =>
              Some(
                (
                  cleared,
                  @moui.Effect::dispatch(emit => emit(ProjectFileDeleteRun(rel))),
                ),
              )
            // 其余四种在纯链内同步续行：update_pure_inner 跳过守卫层，
            // 原处理器直接执行——测试的纯转移上下文也能走完整流程。
            _ => {
              let follow : Msg = match kind {
                CkDeleteControl(name) => DeleteControl(name)
                CkDeleteVariable(name) => DeleteVariable(name)
                // 删除工程文件在上方独立臂经 Effect 续行(服务流),此分支
                // 不可达;穷举要求给一个无害映射。
                CkDeleteProjectFile(_) => OpenRequested
                CkTemplate(index) => SelectTemplate(index)
                CkNewBlank => NewBlankProgram
                CkOpen => OpenRequested
              }
              Some(update_pure_inner(cleared, follow))
            }
          }
        }
      }
    // —— 被守卫的破坏性消息：**pending_confirm 已置位 = 确认续行中**，
    // 放行（None）让原处理器接手；否则转成确认请求。
    DeleteControl(_)
    | DeleteVariable(_)
    | SelectTemplate(_)
    | NewBlankProgram =>
      if model.pending_confirm is Some(_) {
        None
      } else {
        // 删除类无条件守卫；模板/新建只挡「有未保存工作」的程序。
        let guarded = match msg {
          DeleteControl(_) | DeleteVariable(_) => true
          _ => program_has_work(model)
        }
        if guarded {
          Some(
            (
              { ..model, pending_confirm: Some(confirm_kind_of(msg)), },
              @moui.Effect::none(),
            ),
          )
        } else {
          None
        }
      }
    _ => None
  }
}

///|
/// 确认卡（模态对话框）：标题 + 正文 + 取消/确认两键。
fn confirm_dialog(model : Model, t : @i18n.Translator) -> @moui.View[Msg] {
  let message = match model.pending_confirm {
    Some(kind) => confirm_copy(kind, t)
    None => ""
  }
  let ok_w = text_estimate_width(text(t, "app.confirm.ok")) + 34.0
  let cancel_w = text_estimate_width(text(t, "app.confirm.cancel")) + 34.0
  @views.container(
    @views.column(
      [
        @views.text(
          text(t, "app.confirm.title"),
          theme=studio_theme(),
          width=320.0,
          height=22.0,
          align=TextStart,
        ).foreground(ide_text()),
        @views.text(
          message,
          theme=studio_theme(),
          width=320.0,
          height=36.0,
          align=TextStart,
        ).foreground(ide_text_muted()),
        @views.row(
          [
            @views.spacer(min_length=0.0, weight=1.0),
            @views.button(
              text(t, "app.confirm.cancel"),
              on_click=ConfirmDismissed,
              variant=@style.Ghost,
              width=cancel_w,
              height=30.0,
            ),
            @views.button(
              text(t, "app.confirm.ok"),
              on_click=ConfirmAccepted,
              variant=@style.Primary,
              width=ok_w,
              height=30.0,
            ),
          ],
          spacing=8.0,
          align=Center,
        ).frame(width=320.0),
      ],
      spacing=10.0,
    ),
    background=ide_panel(),
    corner_radius=6.0,
    width=352.0,
    padding=16.0,
  )
}
