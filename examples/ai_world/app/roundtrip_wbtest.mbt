///|
/// A systemic guard for the whole class of bugs found in rounds 7-10.
///
/// Every one of those was the same shape: `update` changed conversation state
/// but the change did not reach `commit_files`, or the reader dropped it on the
/// way back. Hunting them one at a time does not scale, so this file asserts the
/// *property* they all violate:
///
///   for any message sequence, reload(commit(model)) preserves the state the
///   user is meant to keep.
///
/// A new feature that forgets to persist now fails here, instead of shipping.

///|
/// Everything that must survive a save → reload.
///
/// Deliberately excludes session-only state (draft, selection, editing buffer,
/// transient notices, in-flight pending flags): those are *meant* to reset.
pub(all) struct PersistedShape {
  /// `(conversation key, [(speaker, text)])`, sorted by key.
  conversations : Array[(String, Array[(String, String)])]
  /// `(conversation key, summary)` for conversations with a non-empty summary.
  summaries : Array[(String, String)]
  /// `(conversation key, summarized_upto)`.
  coverage : Array[(String, Int)]
  /// World-book contents, in order.
  book : Array[String]
  /// Every event line that is world history (not session chatter).
  events : Array[String]
  /// Character ids, in order.
  characters : Array[String]
  /// `(character id, portrait file name)`.
  portraits : Array[(String, String)]
  /// Locations, in order.
  locations : Array[String]
} derive(Eq, Debug)

///|
pub extend PersistedShape with Debug::{to_repr}

///|
pub extend PersistedShape with Eq::{not_equal, equal}

///|
fn speaker_tag(speaker : Speaker) -> String {
  match speaker {
    Player => "player"
    Character(id) => "character:" + id
  }
}

///|
fn persisted_shape(model : WorldModel) -> PersistedShape {
  let keys : Array[String] = []
  for conversation in model.conversations.entries {
    keys.push(conversation.character_id())
  }
  keys.sort_by((left, right) => {
    let order = left.compare(right)
    order
  })
  let conversations : Array[(String, Array[(String, String)])] = []
  let summaries : Array[(String, String)] = []
  let coverage : Array[(String, Int)] = []
  for key in keys {
    let conversation = model.conversations.for_character(key)
    let lines : Array[(String, String)] = []
    for line in conversation.lines() {
      lines.push((speaker_tag(line.speaker()), line.text()))
    }
    conversations.push((key, lines))
    if conversation.summary() != "" {
      summaries.push((key, conversation.summary()))
    }
    coverage.push((key, conversation.summarized_upto()))
  }
  let book : Array[String] = []
  for entry in model.scenario.world_book() {
    book.push(entry.content())
  }
  let events : Array[String] = []
  for line in model.log() {
    if !is_transient_log_line(line) {
      events.push(line)
    }
  }
  let characters : Array[String] = []
  let portraits : Array[(String, String)] = []
  for card in model.scenario.characters() {
    characters.push(card.id())
    portraits.push((card.id(), card.portrait()))
  }
  let locations : Array[String] = []
  for place in model.scenario.locations() {
    locations.push(place.id())
  }
  {
    conversations,
    summaries,
    coverage,
    book,
    events,
    characters,
    portraits,
    locations,
  }
}

///|
/// Commit the world and load it back, exactly as a host would.
fn roundtrip(model : WorldModel) -> WorldModel {
  let files = commit_files(model, World)
  let folder = model.current().unwrap_or("世界")
  step(model, WorldFilesArrived(folder, true, files))
}

///|
/// Assert the property for one model, with a label naming the scenario.
///
/// Field-by-field so the failure says *which* piece drifted; a single "shapes
/// differ" assertion would leave the next reader re-deriving it.
fn assert_roundtrip(label : String, model : WorldModel) -> Unit raise {
  let before = persisted_shape(model)
  let after = persisted_shape(roundtrip(model))
  if before.conversations != after.conversations {
    fail("conversations changed — " + label)
  }
  if before.summaries != after.summaries {
    fail("summaries changed — " + label)
  }
  if before.coverage != after.coverage {
    fail("summary coverage changed — " + label)
  }
  if before.book != after.book {
    fail("world book changed — " + label)
  }
  if before.events != after.events {
    fail("event log changed — " + label)
  }
  if before.characters != after.characters {
    fail("characters changed — " + label)
  }
  if before.portraits != after.portraits {
    fail("portraits changed — " + label)
  }
  if before.locations != after.locations {
    fail("locations changed — " + label)
  }
}

///|
test "property: every single-user action survives a round trip" {
  let base = crowded_world()
  let selected = step(base, Select(Some("林掌柜")))
  let talking_model = step(selected, Send("温一壶酒"))
  // Each entry is a model reached by a distinct user action.
  let cases : Array[(String, WorldModel)] = [
    ("fresh", base),
    ("selected", selected),
    ("one turn", talking_model),
    ("two turns", step(talking_model, Send("再来一壶"))),
    ("regenerated", step(talking_model, RegenerateReply)),
    ("edited", step(step(talking_model, EditLine(0)), EditLineCommit)),
    ("deleted", step(talking_model, DeleteLine(0))),
    ("cleared", step(talking_model, ClearConversation)),
    ("branched", step(talking_model, BranchAt(0))),
    ("time advanced", step(base, AdvanceTime)),
  ]
  for pair in cases {
    assert_roundtrip(pair.0, pair.1)
  }
}

///|
test "property: scene and branch state survives a round trip" {
  let base = crowded_world()
  let in_scene = step(base, EnterScene("吧台"))
  let scene_turn = step(in_scene, Send("掌柜的"))
  assert_roundtrip("scene entered", in_scene)
  assert_roundtrip("scene turn", scene_turn)
  let left = step(scene_turn, LeaveScene)
  assert_roundtrip("left scene", left)
  let selected = step(left, Select(Some("林掌柜")))
  let branched = step(step(selected, Send("温一壶酒")), BranchAt(0))
  assert_roundtrip("branch", branched)
}

///|
test "property: world edits survive a round trip" {
  let base = crowded_world()
  let created = step(
    step(base, ToggleCreator),
    CreatorChanged(
      CharacterDraft::new().with_name("新角色").with_persona("刚来的。"),
    ),
  )
  assert_roundtrip("character created", step(created, CharacterCreated))
  // Accepting a memory rewrites the world book.
  let with_draft = step(
    base,
    MemoryProposalsArrived(
      Some(
        "{\"entries\":[{\"keys\":[\"酒\"],\"content\":\"新记下的一条。\"}]}",
      ),
    ),
  )
  if !with_draft.memory_drafts().is_empty() {
    assert_roundtrip("memory accepted", step(with_draft, AcceptMemory(0)))
  }
  // A lorebook entry with every modifier set.
  let lore = step(
    WorldModel::new(),
    WorldFilesArrived("x", true, [
      ("world.md", "# 测试\n\n背景。\n"),
      (
        "world_book.md", "# 世界书\n\n- 甲 [priority=7] [position=before] [recursion=2] [probability=30]: 内容。\n",
      ),
    ]),
  )
  assert_roundtrip("lorebook modifiers", lore)
}

///|
test "property: alternatives and their selection survive a round trip" {
  let base = step(crowded_world(), Select(Some("林掌柜")))
  let talking_model = step(base, Send("温一壶酒"))
  let never : TurnRunner = (_request, _on_reply) => ()
  let (asked, _e) = update(talking_model, RegenerateReply, turn_runner=never)
  let (two, _e2) = update(
    asked,
    Regenerated(Some("第二个版本。")),
    turn_runner=never,
  )
  assert_roundtrip("two candidates", two)
  // Swiping to the other candidate is a persisted choice.
  let (swiped, _e3) = update(two, SwipeReply(1, -1), turn_runner=never)
  assert_roundtrip("swiped back", swiped)
}
