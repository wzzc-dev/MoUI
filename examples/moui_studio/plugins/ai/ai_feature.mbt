///|
/// AI 插件·会话操作的 TEA 单元（M3）。
///
/// 组合根用 `Feature::scope(read, write, wrap)` 把本切片挂进根模型：会话
/// 建切删经 scope 委托（包装变体臂，漏臂 = 编译错误）；线程卡渲染等视图
/// 需要 app 的主题与消息类型——按 non-render-component-cookbook 的既定
/// 口径「视图由父组装，scope 只管 update 与 effect 提升」，本 Feature 的
/// view 域刻意 abort（mo_workbench 先例）。

///|
/// 会话操作消息：新建 / 切换 / 删除。
pub(all) enum AiSessionMsg {
  AiSessionCreate
  AiSessionSwitch(Int)
  AiSessionRemove(Int)
}

///|
/// 会话操作 update：纯状态转移，零副作用。
pub fn AiSessions::update(
  self : AiSessions,
  message : AiSessionMsg,
) -> (AiSessions, @moui.Effect[AiSessionMsg]) {
  match message {
    AiSessionCreate => {
      ignore(self.create())
      (self, @moui.Effect::none())
    }
    AiSessionSwitch(index) => {
      let _ = self.switch(index)
      (self, @moui.Effect::none())
    }
    AiSessionRemove(index) => {
      self.remove(index)
      (self, @moui.Effect::none())
    }
  }
}

///|
/// 插件的 Feature（契约第 1 件：状态切片 + 五元组；view 由父组装）。
pub fn ai_sessions_feature() -> @moui.Feature[AiSessions, AiSessionMsg] {
  @moui.Feature::new(
    init=() => (AiSessions::new(), @moui.Effect::none()),
    update=fn(state, message) { state.update(message) },
    view=_state => abort("ai session views are composed by the parent shell"),
  )
}

///|
/// 会话列表的读数投影：[(下标, 会话名, 是否当前)]，供壳渲染列表。
pub fn AiSessions::list_entries(
  self : AiSessions,
) -> Array[(Int, String, Bool)] {
  let entries : Array[(Int, String, Bool)] = []
  let mut index = 0
  for session in self.sessions {
    entries.push((index, session.title, index == self.active))
    index = index + 1
  }
  entries
}
