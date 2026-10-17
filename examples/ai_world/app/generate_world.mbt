///|
/// AI world generation: one line of idea in, a world folder's content out.
///
/// With a provider configured the idea becomes a JSON-producing request on the
/// same `TurnRunner` the chat uses — no second transport contract. Without
/// one, `fallback_world` builds a deterministic starter world so the flow is
/// playable offline. Both paths converge in `update`, which parses, applies,
/// and commits the result to the folder database.

///|
/// The prompt pair for a world-generation request.
pub struct WorldIdeaPrompt {
  system : String
  user : String
} derive(Eq, Debug)

///|
pub extend WorldIdeaPrompt with Debug::{to_repr}

///|
pub extend WorldIdeaPrompt with Eq::{not_equal, equal}

///|
/// Compose the request that asks the provider to emit a whole scenario as
/// JSON. The schema mirrors the existing scenario codec, so the reply flows
/// through the same import path a hand-written JSON file would.
pub fn world_idea_prompt(idea : String) -> WorldIdeaPrompt {
  let system = [
    "你是一个AI世界引擎的世界设定师。根据用户的一句话设定，生成一个可玩的对话世界。",
    "只输出一个JSON对象，不要输出JSON以外的任何文字、解释或代码块标记。",
    "字段：id（世界英文名，小写字母）、name（世界中文短名）、background（约150字的背景叙述，给角色当记忆用）、",
    "locations（2-4个地点，每个含 id/name/description 和 rect{origin{x,y},size{width,height}}，坐标在 0,0 到 640,420 内）、",
    "characters（1-3个角色，每个含 id/name/persona（约100字人设）/appearance（可选）/voice（说话方式）/goal（目标）/secret（不主动说出的秘密）/point{x,y}）、",
    "world_book（2-4个条目，每个含 keys（触发关键词数组）和 content）。",
    "所有文本用中文；角色要能构成关系与张力；rect 高宽不超过 220。",
  ].join("\n")
  WorldIdeaPrompt::{ system, user: idea, }
}

///|
/// Pull the first JSON object out of a model reply. Providers like to wrap
/// JSON in ``` fences or prose; the scanner only trusts the braces.
pub fn extract_json_object(text : String) -> String? {
  let chars : Array[Char] = []
  for ch in text {
    chars.push(ch)
  }
  let mut first : Int? = None
  let mut cursor = 0
  while cursor < chars.length() {
    if chars[cursor] == '{' {
      first = Some(cursor)
      break
    }
    cursor += 1
  }
  match first {
    None => None
    Some(open) => {
      // Depth scan from the first `{`: nested objects (points, rects) are
      // expected, so the reply must close the outermost brace.
      let mut depth = 0
      let mut close : Int? = None
      let mut at = open
      while at < chars.length() {
        if chars[at] == '{' {
          depth += 1
        } else if chars[at] == '}' {
          depth -= 1
          if depth == 0 {
            close = Some(at)
            break
          }
        }
        at += 1
      }
      match close {
        None => None
        Some(close) =>
          Some(String::from_array(chars[open:close + 1]).to_string())
      }
    }
  }
}

///|
/// The offline world the idea gets when no provider is configured: keep the
/// player's words at the heart of it so the world still feels like theirs.
pub fn fallback_world(idea : String) -> Scenario {
  let trimmed : String = idea.trim().to_owned()
  let name = if trimmed == "" {
    "无名世界"
  } else if trimmed.length() > 12 {
    "\{trimmed[0:12]}……"
  } else {
    trimmed
  }
  let scenario = Scenario::new(
    id=name,
    name~,
    background="关于「\{idea}」的世界：这里的一切正等待被讲述。写下它的位置、气候与正在发生的事，每个角色都会记得。",
  )
  scenario
}

///|
/// Guide text the empty world shows until the player writes a background or
/// asks the provider for one.
pub fn world_nudge(scenario : Scenario) -> String {
  if scenario.background() == "" {
    "这个世界的背景还是空的。可以在右侧用一句话让AI生成，也可以直接编辑 world.md。"
  } else {
    ""
  }
}
