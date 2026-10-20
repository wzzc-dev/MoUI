///|
/// Scenes: several characters talking in one place.
///
/// A scene is not a new storage format — it is a *view* over the folder
/// database. The transcript lives in the same `conversations/` folder under a
/// location-scoped key (`scene:吧台`), and its lines already carry
/// `Speaker::Character(id)`, so one history can hold several voices without
/// changing `ChatLine`.
///
/// Who answers? The provider is asked to reply *as one named character* while
/// knowing who else is present. The respondent rotates, which keeps a scene
/// from being a monologue and needs no extra model call to "pick a speaker".

///|
/// The conversation key for a scene at `location_id`.
///
/// Scenes and private chats share the conversation book, so the key must not
/// collide with a character id. `scene:` is reserved for this.
pub fn scene_key(location_id : String) -> String {
  "scene:" + location_id
}

///|
/// Is this conversation key a scene rather than a private chat?
pub fn is_scene_key(key : String) -> Bool {
  key.has_prefix("scene:")
}

///|
/// The characters who share a location with `origin`.
///
/// A card is "here" when its own `location` names the place, or when it stands
/// inside the place's rect. The second rule matters because AI-generated cards
/// often carry only a point, not a location id.
pub fn cast_at(
  scenario : Scenario,
  location_id : String,
) -> Array[CharacterCard] {
  let place = scenario.location(location_id)
  let cast : Array[CharacterCard] = []
  for card in scenario.characters() {
    let mut here = card.location() == location_id
    if !here {
      match place {
        Some(rect_place) =>
          match scenario.character_point(card.id()) {
            Some(point) => here = rect_contains(rect_place.rect(), point)
            None => ()
          }
        None => ()
      }
    }
    if here {
      cast.push(card)
    }
  }
  cast
}

///|
fn rect_contains(rect : @geometry.Rect, point : @geometry.Point) -> Bool {
  point.x >= rect.origin.x &&
  point.x <= rect.origin.x + rect.size.width &&
  point.y >= rect.origin.y &&
  point.y <= rect.origin.y + rect.size.height
}

///|
/// The system prompt for a scene turn.
///
/// Different from a private chat in three ways: the model is told who else is
/// in the room, it may let those characters react, and it must answer *as the
/// named respondent* — otherwise every reply collapses into one narrator voice
/// and the scene stops being multi-party.
pub fn build_scene_prompt(
  scenario : Scenario,
  location_id : String,
  cast : Array[CharacterCard],
  responder : CharacterCard,
) -> String {
  let sections : Array[String] = []
  sections.push(
    "你在一场多人场景中扮演" +
    responder.name() +
    "。用第一人称回应，始终留在角色中。",
  )
  sections.push("【世界】\n" + scenario.background())
  let place_name = match scenario.location(location_id) {
    Some(place) => place.name()
    None => location_id
  }
  sections.push("【场景】" + place_name)
  match scenario.location(location_id) {
    Some(place) =>
      if place.description() != "" {
        sections.push("【这里】" + place.description())
      }
    None => ()
  }
  // Everyone present, including the respondent, with the one field that
  // actually changes how they behave toward each other.
  let others : Array[String] = []
  for card in cast {
    if card.id() == responder.id() {
      others.push("- " + card.name() + "（你）")
    } else {
      others.push(
        "- " +
        card.name() +
        "：" +
        card.persona() +
        (if card.goal() != "" {
          "（想要的：" + card.goal() + "）"
        } else {
          ""
        }),
      )
    }
  }
  sections.push("【在场】\n" + others.join("\n"))
  if responder.persona() != "" {
    sections.push(
      "【你是" + responder.name() + "】\n" + responder.persona(),
    )
  }
  if responder.voice() != "" {
    sections.push("【说话方式】" + responder.voice())
  }
  if responder.secret() != "" {
    sections.push(
      "【秘密】" +
      responder.secret() +
      "（除非玩家明确问起或你信任对方，不要主动说出）",
    )
  }
  sections.push(
    "只输出" +
    responder.name() +
    "说的话或动作（可以用 *斜体* 写动作），不要替其他角色发言，不要写旁白标题。",
  )
  sections.join("\n\n")
}

///|
/// The character who answers this turn: the one whose name is mentioned in the
/// player's line, else a rotation over the cast keyed by how many lines exist.
///
/// Rotation is deliberate: asking the model "who speaks next" would cost an
/// extra call per turn, and a fixed order is predictable enough for a scene.
pub fn responder_for(
  cast : Array[CharacterCard],
  player_text : String,
  turn_index : Int,
) -> CharacterCard? {
  if cast.is_empty() {
    return None
  }
  for card in cast {
    if player_text.contains(card.name()) {
      return Some(card)
    }
  }
  Some(cast[turn_index % cast.length()])
}

///|
/// The prompt pair for "what happened while I was away".
///
/// The reply is one short paragraph the player reads in the event log; it is
/// deliberately not fed back into any character's context (that would let the
/// world rewrite its own history without the player noticing). The prompt names
/// the cast and the place, so the narration is about this world rather than
/// generic prose.
pub fn advance_time_prompt(
  scenario : Scenario,
  location : String?,
  present : Array[CharacterCard],
) -> (String, String) {
  let system = [
    "你是一个互动世界的时间线叙述者。", "根据世界设定和在场人物，用一段不超过120字的中文第三人称叙述，写玩家离开这段时间里发生了什么。",
    "只写具体的小事（谁做了什么、天气、一个决定），不要写总结，不要提问，不要用列表。",
  ].join("\n")
  let parts : Array[String] = []
  parts.push("【世界】" + scenario.background())
  match location {
    Some(place) =>
      match scenario.location(place) {
        Some(found) =>
          parts.push(
            "【地点】" + found.name() + "：" + found.description(),
          )
        None => parts.push("【地点】" + place)
      }
    None => parts.push("【地点】" + scenario.name())
  }
  if !present.is_empty() {
    let names : Array[String] = []
    for card in present {
      names.push(card.name() + "（" + card.persona() + "）")
    }
    parts.push("【在场】" + names.join("；"))
  }
  (system, parts.join("\n\n"))
}

///|
/// Turn a narration reply into one event-log line. Empty stays empty so a
/// failed generation adds nothing rather than a blank entry.
pub fn time_advanced_event(reply : String) -> String {
  let trimmed = reply.trim().to_owned()
  if trimmed == "" {
    return ""
  }
  "（这段时间）" + clip_chars(trimmed, 240)
}
