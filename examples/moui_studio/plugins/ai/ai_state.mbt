///|
/// AI 插件·会话状态切片（M3）。
///
/// 会话隔离范围 = **提示 / 回复 / 卡片**（契约 4）：每个会话独立持有
/// composer 草稿、线程卡、提案历史与单调序号；提案作用对象是程序 IR，
/// `pending` 提案与运行审计仍走全局通道（根模型持有）。
///
/// 剪切线：`AiCard` / `AiCardKind` / `ProposalRecord` 三个纯数据类型从
/// app 迁入本包（app 侧保留 `pub type` 别名，既有引用零改动）——它们是
/// 会话切片的组成单元，必须随切片走。

///|
/// AI 会话卡的种类：Agent 计划 / diff 待审计 / 副作用确认 / 讲解 / 错误。
/// 卡是「Agent 干了什么」的可审计投影，不承载执行语义——采纳仍走既有
/// AcceptProposal / AnswerGate 通道。
pub(all) enum AiCardKind {
  CardPlan
  CardDiff
  CardSideEffect
  CardExplanation
  CardError
}

///|
/// AI 会话卡：会话内的可见工作记录（设计稿 threadStack）。
/// steps 只在计划卡非空；diff 行只在 diff 卡非空。
pub(all) struct AiCard {
  kind : AiCardKind
  title : String
  body : String
  // 计划卡：步骤文本 + 已完成步数 + 进度百分比
  steps : Array[String]
  steps_done : Int
  progress : Int
  // diff 卡：逐行 ± 文本
  diff_lines : Array[(String, String)]
  // 卡是否已被用户处理（接受/拒绝/确认）：处理过的卡降透明度显示
  settled : Bool
  settled_note : String
  // 单调递增序号：用于稳定 key 与「最新一张」判定
  seq : Int
}

///|
/// 提案历史条目：会话内回放「AI 干了什么」（采纳/拒绝 + 摘要 + diff）。
pub(all) struct ProposalRecord {
  summary : String
  diff : Array[@proposals.DiffEntry]
  /// 采纳时的代码真源文本 diff（M6②：历史回放看代码改了哪几行）。
  code_diff : Array[(String, String)]
  accepted : Bool
  seq : Int
}

///|
/// 单个会话：独立的草稿 / 线程卡 / 提案历史。
pub(all) struct AiSession {
  /// 会话名（列表显示；新建时给默认名，可后续改名）
  title : String
  prompt_draft : String
  cards : Array[AiCard]
  card_seq : Int
  proposal_history : Array[ProposalRecord]
}

///|
/// 多会话容器：会话数组 + 当前会话指针。**列表永不为空**——composer
/// 任何时刻都要有落点，删掉最后一个会话时重建一个全新会话（与「删除
/// 当前选中 → 落到同位下一个」的 RemoveProject 惯例互补）。
///
/// 可变性与 audit_entries 同款：容器经 Model spread 共享（同一引用），
/// `create`/`switch`/`remove`/`amend` 原位生效，调用方不必重建容器。
pub(all) struct AiSessions {
  sessions : Array[AiSession]
  mut active : Int
  /// 历史开过的会话总数（默认命名单调递增，删除重建不重名）
  mut seq : Int
}

///|
/// 初始状态：一个全新默认会话。
pub fn AiSessions::new() -> AiSessions {
  AiSessions::fresh(1)
}

///|
/// 带 会话计数 的全新状态（第 n 个默认会话名随 n 递增，供删除重建续名）。
pub fn AiSessions::fresh(count : Int) -> AiSessions {
  { sessions: [AiSession::default(count)], active: 0, seq: count, }
}

///|
pub fn AiSession::default(count : Int) -> AiSession {
  {
    title: "会话 \{count}",
    prompt_draft: "",
    cards: [],
    card_seq: 0,
    proposal_history: [],
  }
}

///|
/// 当前会话（只读快照；数组与切片共享引用，与 audit_entries 同款语义）。
/// 注意：方法叫 `current` 而不是 `active`——后者与 `mut active` 字段撞名。
pub fn AiSessions::current(self : AiSessions) -> AiSession {
  let index = self.active.clamp(min=0, max=self.sessions.length() - 1)
  self.sessions[index]
}

///|
/// 当前会话下标（状态栏/列表高亮读数）。
pub fn AiSessions::active_index(self : AiSessions) -> Int {
  self.active
}

///|
/// 会话数（列表读数）。
pub fn AiSessions::count(self : AiSessions) -> Int {
  self.sessions.length()
}

///|
/// 按下标读会话（越界返回 None；列表渲染用）。
pub fn AiSessions::session_at(
  self : AiSessions,
  index : Int,
) -> AiSession? {
  if index >= 0 && index < self.sessions.length() {
    Some(self.sessions[index])
  } else {
    None
  }
}

///|
/// 原位替换当前会话（amend 惯例：模型里的数组是共享可变引用，与
/// audit_entries 的 push 同一写法；调用方不必重建整个容器）。
pub fn AiSessions::amend(self : AiSessions, session : AiSession) -> Unit {
  let index = self.active.clamp(min=0, max=self.sessions.length() - 1)
  self.sessions[index] = session
}

///|
/// 新建会话并切换过去（返回新活跃下标）。默认名取「会话 N」，N = 历史
/// 开过的最大序号 + 1（删除重建不重名）。
pub fn AiSessions::create(self : AiSessions) -> Int {
  self.seq = self.seq + 1
  self.sessions.push(AiSession::default(self.seq))
  self.active = self.sessions.length() - 1
  self.active
}

///|
/// 切换会话（越界 no-op，返回是否生效）。
pub fn AiSessions::switch(self : AiSessions, index : Int) -> Bool {
  if index >= 0 && index < self.sessions.length() {
    self.active = index
    true
  } else {
    false
  }
}

///|
/// 删除会话（RemoveProject 惯例）：删当前 → 落到同位下一个；删前面的 →
/// 指针左移；**删最后一个 → 重建一个全新会话**（列表永不为空）。
pub fn AiSessions::remove(self : AiSessions, index : Int) -> Unit {
  if index < 0 || index >= self.sessions.length() {
    return
  }
  ignore(self.sessions.remove(index))
  if self.sessions.length() == 0 {
    self.seq = self.seq + 1
    self.sessions.push(AiSession::default(self.seq))
    self.active = 0
    return
  }
  if self.active >= self.sessions.length() {
    self.active = self.sessions.length() - 1
  }
}

///|
/// 流式追加（M4）：把增量文本**追加到最后一张卡的 body**——流式卡由调用方
/// （fake/真实 provider 路径）先推入，之后每个分片经本操作追加。追加语义
/// 稳定：只动最后一张卡，既有卡零改动（重渲染不闪不重排）。
pub fn AiSessions::append_to_last_card(self : AiSessions, text : String) -> Unit {
  let session = self.current()
  if session.cards.length() == 0 {
    return
  }
  let total = session.cards.length()
  let cards : Array[AiCard] = []
  let mut index = 0
  for card in session.cards {
    if index == total - 1 {
      // 只动最后一张卡（流式卡），既有卡零改动
      cards.push({ ..card, body: card.body + text })
    } else {
      cards.push(card)
    }
    index = index + 1
  }
  self.amend({ ..session, cards })
}

///|
/// 确定性分块（fake provider 流式）：把完整回复按固定字符数切块，末块可短。
/// 纯函数、顺序稳定——同一文本永远产生同一分块序列。
pub fn fake_stream_chunks(text : String, chunk_size : Int) -> Array[String] {
  let size = if chunk_size <= 0 { 1 } else { chunk_size }
  let chars : Array[Char] = []
  for c in text {
    chars.push(c)
  }
  let chunks : Array[String] = []
  let buf = StringBuilder()
  let mut used = 0
  for c in chars {
    buf.write_char(c)
    used = used + 1
    if used == size {
      chunks.push(buf.to_string())
      buf.reset()
      used = 0
    }
  }
  if used > 0 {
    chunks.push(buf.to_string())
  }
  chunks
}
