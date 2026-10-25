///|
/// Pure helpers for `update`: conversation appends, effect packing, and
/// provider-reply parsing.

///|
/// Append the player's line to a conversation, returning the updated state.
fn append_player(
  model : WorldModel,
  character_id : String,
  text : String,
) -> Unit {
  let conversation = model.conversations.for_character(character_id)
  model.conversations.set(conversation.append(ChatLine::player(text)))
}

///|
/// Append a character's line to a conversation.
fn append_reply(
  model : WorldModel,
  character_id : String,
  text : String,
) -> Unit {
  let conversation = model.conversations.for_character(character_id)
  model.conversations.set(
    conversation
    .append(ChatLine::character(character_id, text))
    .with_pending(false)
    // The finished line replaces the streamed text.
    .with_streaming(""),
  )
}

///|
/// Append a scene reply spoken by `respondent_id`.
///
/// The line's `Speaker::Character` carries the actual speaker, so a scene
/// transcript can mix voices while still being one conversation.
fn append_scene_reply(
  model : WorldModel,
  key : String,
  respondent_id : String,
  text : String,
) -> Unit {
  let conversation = model.conversations.for_character(key)
  model.conversations.set(
    conversation
    .append(ChatLine::character(respondent_id, text))
    .with_pending(false)
    .with_streaming(""),
  )
}

///|
/// Fold one streamed piece into a conversation that is still waiting for it.
///
/// Deltas are provider callbacks: by the time one lands the turn may have
/// finished (the full reply arrived first), the character may be gone, or the
/// world may have been replaced. None of those may create a conversation or
/// edit the model the caller still holds, so the guard runs before `fork()`.
fn append_reply_delta(
  model : WorldModel,
  key : String,
  delta : String,
  scene~ : Bool,
) -> (WorldModel, @moui.Effect[Msg]) {
  // The private and scene channels stay separate: a delta addressed to a
  // character id must not land in a scene transcript, or vice versa.
  if is_scene_key(key) != scene {
    return (model, @moui.Effect::none())
  }
  let waiting = match model.conversations.find(key) {
    Some(conversation) =>
      conversation.pending() && reply_target_exists(model, key)
    None => false
  }
  if !waiting {
    return (model, @moui.Effect::none())
  }
  let conversation = model.conversations.for_character(key)
  let next = model.fork()
  next.conversations.set(
    conversation.with_streaming(conversation.streaming() + delta),
  )
  (next, @moui.Effect::none())
}

///|
/// Parse a user-entered number, falling back to the current value when the
/// text is not a finite positive number. Configuration must never become NaN.
fn parse_double(text : String, fallback : Double) -> Double {
  let parsed = @string.parse_double(text) catch { _ => return fallback }
  if parsed.is_nan() || parsed <= 0.0 {
    fallback
  } else {
    parsed
  }
}

///|
/// Sort an incoming world-folder file set into the codec shape. Journal files
/// (`conversations.json` / `events.json`) ride beside the Markdown files and
/// degrade alone when missing.
fn world_files_from_paths(files : Array[(String, String)]) -> WorldFiles {
  let mut world_md = ""
  let mut book_md = ""
  let mut conversations_json = ""
  let mut events_json = ""
  let cards : Array[(String, String)] = []
  let memories : Array[(String, String)] = []
  let conversations : Array[(String, String)] = []
  let portraits : Array[(String, String)] = []
  for pair in files {
    let path = pair.0.trim().to_owned()
    if path == "world.md" || path.has_suffix("/world.md") {
      world_md = pair.1
    } else if path == "world_book.md" || path.has_suffix("/world_book.md") {
      book_md = pair.1
    } else if is_card_or_portrait_path(path) is Portrait {
      // Portraits live beside their cards (`characters/<名>.png`), so the prefix
      // alone cannot tell them apart. See `is_card_or_portrait_path`.
      portraits.push(pair)
    } else if is_card_or_portrait_path(path) is Memory {
      // `characters/<名>.memory.md`: the interaction memories, parsed into
      // the memory book by `parse_world_files`.
      memories.push(pair)
    } else if path.has_prefix("characters/") {
      cards.push(pair)
    } else if is_portrait_file_name(path) {
      // Portrait assets ride as base64 beside the cards. They are not parsed
      // by the world codec; the UI resolves them through `portrait_uri`.
      portraits.push(pair)
    } else if path.has_prefix(conversations_dir + "/") {
      // `conversations/<名>.json` per-character history, plus the index that
      // lists which of them belong to this world. The index is bookkeeping,
      // not a conversation.
      if path != conversation_index_file {
        conversations.push(pair)
      }
    } else if path == conversations_file ||
      path.has_suffix("/\{conversations_file}") {
      conversations_json = pair.1
    } else if path == events_file || path.has_suffix("/\{events_file}") {
      events_json = pair.1
    } else {
      // Unrelated files in the folder simply do not reach the model.
      ()
    }
  }
  WorldFiles::{
    world_md,
    book_md,
    character_files: cards,
    memory_files: memories,
    conversations_json,
    conversation_files: conversations,
    events_json,
    portraits,
  }
}

///|
fn with_world(worlds : Array[String], name : String) -> Array[String] {
  let next : Array[String] = []
  for world in worlds {
    next.push(world)
  }
  if !next.contains(name) {
    next.push(name)
  }
  next
}

///|
/// Effects fly as one batch; a single effect skips the wrapper so tests can
/// observe a plain run.
fn pack_effects(effects : Array[@moui.Effect[Msg]]) -> @moui.Effect[Msg] {
  if effects.length() == 1 {
    effects[0]
  } else if effects.length() == 0 {
    @moui.Effect::none()
  } else {
    @moui.Effect::batch(effects)
  }
}

///|
/// Parse `{"memories":[…],"content":"…"}` replies into entries. Duplicates of
/// the curated book, of drafts already on the table, or of the selected
/// character's memory book are dropped; a malformed reply simply proposes
/// nothing.
fn parse_memory_proposals(
  text : String,
  book : Array[WorldEntry],
  drafts : Array[WorldEntry],
  memories : Array[String],
) -> Array[WorldEntry] {
  let result : Array[WorldEntry] = []
  let payload = match extract_json_object(text) {
    Some(json) => json
    None => return result
  }
  let parsed = @json.parse(payload) catch { _ => return result }
  let fields = match parsed {
    Object(values) => values
    _ => return result
  }
  let items = match fields.get("memories") {
    Some(Array(values)) => values
    _ => return result
  }
  for item in items {
    let obj = match item {
      Object(values) => values
      _ => continue
    }
    let content = match obj.get("content") {
      Some(String(value)) => value
      _ => continue
    }
    if content.trim() == "" {
      continue
    }
    let keys : Array[String] = []
    match obj.get("keys") {
      Some(Array(values)) =>
        for value in values {
          match value {
            String(key) => if key != "" { keys.push(key) }
            _ => ()
          }
        }
      _ => ()
    }
    let mut duplicate = false
    for existing in book {
      if existing.content() == content {
        duplicate = true
      }
    }
    for existing in drafts {
      if existing.content() == content {
        duplicate = true
      }
    }
    for known_content in memories {
      if known_content == content {
        duplicate = true
      }
    }
    for existing in result {
      if existing.content() == content {
        duplicate = true
      }
    }
    if !duplicate {
      result.push(WorldEntry::new(keys~, content~))
    }
  }
  result
}

///|
fn character_name(scenario : Scenario, id : String) -> String {
  // A scene transcript is keyed by location, so its "speaker" in the log is the
  // place rather than a person.
  if is_scene_key(id) {
    let location : String = id[6:].to_owned()
    return match scenario.location(location) {
      Some(place) => "场景「" + place.name() + "」"
      None => "场景「" + location + "」"
    }
  }
  // A branch is a sibling key (`林掌柜~2`); it is still that character, so the
  // log and prompt say their name with the branch number appended.
  match split_branch(id) {
    Some((base, number)) => {
      let name = match scenario.character(base) {
        Some(card) => card.name()
        None => base
      }
      return name + " · 分支 " + number.to_string()
    }
    None => ()
  }
  match scenario.character(id) {
    Some(card) => card.name()
    None => id
  }
}
