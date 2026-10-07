///|
/// AI 会话持久化编解码（moui.studio.ai-sessions v1）：native 入口落盘
/// `.studio/ai_sessions.json`，web 显式关闭（与导出/编译轨同口径）。
/// 纯函数、双目标。格式门卫与 `.studio.json` 同纪律：format/version 不匹配
/// 整单拒绝（未知版本 = 结构化错误，不猜、不迁移）。布尔字段以 0/1 数值
/// 编码——与 domain/codec 的数值字段同一套原语。
pub const AI_SESSIONS_FORMAT : String = "moui.studio.ai-sessions"

///|
pub const AI_SESSIONS_VERSION : Int = 1

///|
/// 存储解码错误（界面层本地化为 notice）。
pub(all) enum AiStoreError {
  StoreBadJson
  StoreBadFormat
  StoreBadVersion(Int)
  StoreBadPayload
}

///|
fn json_string_field(fields : Map[String, Json], key : String) -> String? {
  match fields.get(key) {
    Some(String(text)) => Some(text)
    _ => None
  }
}

///|
fn json_int_field(fields : Map[String, Json], key : String) -> Int? {
  match fields.get(key) {
    Some(Number(n, ..)) => Some(n.to_int())
    _ => None
  }
}

///|
fn json_items_field(fields : Map[String, Json], key : String) -> Array[String] {
  let items : Array[String] = []
  match fields.get(key) {
    Some(Array(values)) =>
      for value in values {
        match value {
          String(text) => items.push(text)
          _ => ()
        }
      }
    _ => ()
  }
  items
}

///|
fn json_pairs_field(
  fields : Map[String, Json],
  key : String,
) -> Array[(String, String)] {
  let pairs : Array[(String, String)] = []
  match fields.get(key) {
    Some(Array(values)) =>
      for value in values {
        match value {
          Object(pair_fields) => {
            let op = json_string_field(pair_fields, "op").unwrap_or("~")
            let text = json_string_field(pair_fields, "text").unwrap_or("")
            pairs.push((op, text))
          }
          _ => ()
        }
      }
    _ => ()
  }
  pairs
}

///|
fn encode_pairs(pairs : Array[(String, String)]) -> Json {
  Json::array(
    pairs.map(pair => {
      let fields : Map[String, Json] = Map([], capacity=2)
      fields["op"] = Json::string(pair.0)
      fields["text"] = Json::string(pair.1)
      Json::object(fields)
    }),
  )
}

///|
fn encode_kind(kind : AiCardKind) -> String {
  match kind {
    CardUserPrompt => "user_prompt"
    CardPlan => "plan"
    CardDiff => "diff"
    CardSideEffect => "side_effect"
    CardExplanation => "explanation"
    CardError => "error"
  }
}

///|
fn decode_kind(tag : String) -> AiCardKind? {
  match tag {
    "user_prompt" => Some(CardUserPrompt)
    "plan" => Some(CardPlan)
    "diff" => Some(CardDiff)
    "side_effect" => Some(CardSideEffect)
    "explanation" => Some(CardExplanation)
    "error" => Some(CardError)
    _ => None
  }
}

///|
fn encode_card(card : AiCard) -> Json {
  let fields : Map[String, Json] = Map([], capacity=11)
  fields["kind"] = Json::string(encode_kind(card.kind))
  fields["title"] = Json::string(card.title)
  fields["body"] = Json::string(card.body)
  fields["steps"] = Json::array(card.steps.map(Json::string))
  fields["steps_done"] = Json::number(card.steps_done.to_double())
  fields["progress"] = Json::number(card.progress.to_double())
  fields["diff_lines"] = encode_pairs(card.diff_lines)
  fields["settled"] = Json::number(if card.settled { 1.0 } else { 0.0 })
  fields["settled_note"] = Json::string(card.settled_note)
  fields["seq"] = Json::number(card.seq.to_double())
  fields["at"] = Json::number(card.at.to_double())
  Json::object(fields)
}

///|
fn decode_card(fields : Map[String, Json]) -> AiCard? {
  let kind = match json_string_field(fields, "kind") {
    Some(tag) => decode_kind(tag)
    None => None
  }
  match kind {
    Some(kind) =>
      Some(AiCard::{
        kind,
        title: json_string_field(fields, "title").unwrap_or(""),
        body: json_string_field(fields, "body").unwrap_or(""),
        steps: json_items_field(fields, "steps"),
        steps_done: json_int_field(fields, "steps_done").unwrap_or(0),
        progress: json_int_field(fields, "progress").unwrap_or(0),
        diff_lines: json_pairs_field(fields, "diff_lines"),
        settled: json_int_field(fields, "settled").unwrap_or(0) != 0,
        settled_note: json_string_field(fields, "settled_note").unwrap_or(""),
        seq: json_int_field(fields, "seq").unwrap_or(0),
        at: json_int_field(fields, "at").unwrap_or(0),
      })
    None => None
  }
}

///|
fn encode_history_entry(entry : ProposalRecord) -> Json {
  let fields : Map[String, Json] = Map([], capacity=5)
  fields["summary"] = Json::string(entry.summary)
  fields["accepted"] = Json::number(if entry.accepted { 1.0 } else { 0.0 })
  fields["seq"] = Json::number(entry.seq.to_double())
  fields["diff"] = Json::array(
    entry.diff.map(item => {
      let op = match item.op {
        @proposals.Added => "+"
        @proposals.Removed => "-"
        @proposals.Changed => "~"
      }
      let fields : Map[String, Json] = Map([], capacity=4)
      fields["op"] = Json::string(op)
      fields["path"] = Json::string(item.path)
      fields["old_text"] = Json::string(item.old_text)
      fields["new_text"] = Json::string(item.new_text)
      Json::object(fields)
    }),
  )
  fields["code_diff"] = encode_pairs(entry.code_diff)
  Json::object(fields)
}

///|
fn decode_history_entry(fields : Map[String, Json]) -> ProposalRecord? {
  let summary = json_string_field(fields, "summary").unwrap_or("")
  let accepted = json_int_field(fields, "accepted").unwrap_or(0) != 0
  let seq = json_int_field(fields, "seq").unwrap_or(0)
  let diff : Array[@proposals.DiffEntry] = []
  match fields.get("diff") {
    Some(Array(values)) =>
      for value in values {
        match value {
          Object(item) => {
            let op = match json_string_field(item, "op").unwrap_or("~") {
              "+" => @proposals.Added
              "-" => @proposals.Removed
              _ => @proposals.Changed
            }
            diff.push(@proposals.DiffEntry::{
              op,
              path: json_string_field(item, "path").unwrap_or(""),
              old_text: json_string_field(item, "old_text").unwrap_or(""),
              new_text: json_string_field(item, "new_text").unwrap_or(""),
            })
          }
          _ => ()
        }
      }
    _ => ()
  }
  Some(ProposalRecord::{
    summary,
    diff,
    code_diff: json_pairs_field(fields, "code_diff"),
    accepted,
    seq,
  })
}

///|
fn encode_session(session : AiSession) -> Json {
  let fields : Map[String, Json] = Map([], capacity=8)
  fields["title"] = Json::string(session.title)
  fields["prompt_draft"] = Json::string(session.prompt_draft)
  fields["project"] = Json::string(session.project)
  fields["pinned"] = Json::number(if session.pinned { 1.0 } else { 0.0 })
  fields["updated"] = Json::number(session.updated.to_double())
  // created 是 v1 后追加的可选字段：解码缺省回退 updated（不 bump 版本）
  fields["created"] = Json::number(session.created.to_double())
  fields["card_seq"] = Json::number(session.card_seq.to_double())
  fields["cards"] = Json::array(session.cards.map(encode_card))
  fields["history"] = Json::array(
    session.proposal_history.map(encode_history_entry),
  )
  Json::object(fields)
}

///|
fn decode_session(fields : Map[String, Json]) -> AiSession? {
  let title = json_string_field(fields, "title")
  match title {
    Some(title) => {
      let cards : Array[AiCard] = []
      match fields.get("cards") {
        Some(Array(values)) =>
          for value in values {
            match value {
              Object(card_fields) =>
                match decode_card(card_fields) {
                  Some(card) => cards.push(card)
                  None => ()
                }
              _ => ()
            }
          }
        _ => ()
      }
      let history : Array[ProposalRecord] = []
      match fields.get("history") {
        Some(Array(values)) =>
          for value in values {
            match value {
              Object(entry_fields) =>
                match decode_history_entry(entry_fields) {
                  Some(entry) => history.push(entry)
                  None => ()
                }
              _ => ()
            }
          }
        _ => ()
      }
      Some(AiSession::{
        title,
        prompt_draft: json_string_field(fields, "prompt_draft").unwrap_or(""),
        project: json_string_field(fields, "project").unwrap_or(""),
        pinned: json_int_field(fields, "pinned").unwrap_or(0) != 0,
        updated: json_int_field(fields, "updated").unwrap_or(0),
        created: json_int_field(fields, "created").unwrap_or(
          json_int_field(fields, "updated").unwrap_or(0),
        ),
        card_seq: json_int_field(fields, "card_seq").unwrap_or(cards.length()),
        cards,
        proposal_history: history,
      })
    }
    None => None
  }
}

///|
/// 编码会话容器（时间线、提案历史全量）。
pub fn encode_ai_sessions(sessions : AiSessions) -> String {
  let root : Map[String, Json] = Map([], capacity=5)
  root["format"] = Json::string(AI_SESSIONS_FORMAT)
  root["version"] = Json::number(AI_SESSIONS_VERSION.to_double())
  root["active"] = Json::number(sessions.active_index().to_double())
  root["seq"] = Json::number(sessions.seq.to_double())
  root["sessions"] = Json::array(sessions.sessions.map(encode_session))
  Json::object(root).stringify()
}

///|
/// 解码会话容器。空 sessions 数组按「无存储」处理，重建一个全新会话
/// （列表永不为空的切片纪律在解码后依然成立）。
pub fn decode_ai_sessions(source : String) -> Result[AiSessions, AiStoreError] {
  let payload = @json.parse(source) catch { _ => return Err(StoreBadJson) }
  let fields = match payload {
    Object(fields) => fields
    _ => return Err(StoreBadFormat)
  }
  match json_string_field(fields, "format") {
    Some(text) => if text != AI_SESSIONS_FORMAT { return Err(StoreBadFormat) }
    None => return Err(StoreBadFormat)
  }
  let version = match json_int_field(fields, "version") {
    Some(value) => value
    None => return Err(StoreBadVersion(-1))
  }
  if version != AI_SESSIONS_VERSION {
    return Err(StoreBadVersion(version))
  }
  let sessions : Array[AiSession] = []
  match fields.get("sessions") {
    Some(Array(values)) =>
      for value in values {
        match value {
          Object(session_fields) =>
            match decode_session(session_fields) {
              Some(session) => sessions.push(session)
              None => return Err(StoreBadPayload)
            }
          _ => return Err(StoreBadPayload)
        }
      }
    _ => return Err(StoreBadPayload)
  }
  if sessions.length() == 0 {
    return Ok(AiSessions::new())
  }
  let active = json_int_field(fields, "active").unwrap_or(0)
  let container : AiSessions = {
    sessions,
    active: active.clamp(min=0, max=sessions.length() - 1),
    seq: json_int_field(fields, "seq").unwrap_or(sessions.length()),
  }
  Ok(container)
}
