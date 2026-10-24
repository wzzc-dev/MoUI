///|
/// A systemic guard for the other TEA invariant: `update` must not write
/// through the model it was handed.
///
/// `{ ..model, }` copies the record but shares every `Array`, so any branch that
/// appends or logs edits the *previous* model too. The existing test pinned two
/// messages by hand; this one sweeps every message that mutates containers, so a
/// new feature that forgets `fork()` fails here instead of corrupting a model
/// that some other code still holds.

///|
/// A fingerprint of everything a mutation could touch, including the mutable
/// containers that record update shares.
fn model_fingerprint(model : WorldModel) -> String {
  let parts : Array[String] = []
  parts.push(model.log().length().to_string())
  for line in model.log() {
    parts.push(line)
  }
  parts.push(model.selected().unwrap_or("-"))
  parts.push(model.say_draft())
  parts.push(model.do_draft())
  parts.push(model.story_draft())
  parts.push(model.scene_location().unwrap_or("-"))
  parts.push(
    match model.drawer() {
      Some(kind) => kind.to_repr().to_string()
      None => "-"
    },
  )
  parts.push(model.message_menu().unwrap_or(-1).to_string())
  parts.push(model.rail_open().to_string())
  parts.push(model.atmosphere().to_string())
  parts.push(model.backdrop().to_string())
  parts.push(model.creator_open().to_string())
  parts.push(model.creator_draft().name)
  parts.push(model.character_idea())
  parts.push(model.memory_drafts().length().to_string())
  parts.push(model.worlds().length().to_string())
  parts.push(model.current().unwrap_or("-"))
  parts.push(model.portraits().length().to_string())
  parts.push(
    match model.editing_line() {
      Some(index) => index.to_string()
      None => "-"
    },
  )
  parts.push(model.edit_buffer())
  parts.push(model.scenario().characters().length().to_string())
  parts.push(model.scenario().world_book().length().to_string())
  for conversation in model.conversations.entries {
    parts.push(conversation.character_id())
    parts.push(conversation.lines().length().to_string())
    parts.push(conversation.summary())
    parts.push(conversation.summarized_upto().to_string())
    parts.push(conversation.pending().to_string())
    parts.push(conversation.streaming())
    for line in conversation.lines() {
      parts.push(line.text())
      parts.push(line.selected().to_string())
      for alternative in line.alternatives() {
        parts.push(alternative)
      }
    }
  }
  parts.join("\u{1}")
}

///|
/// Assert `update(model, msg)` left `model` untouched.
fn assert_pure(label : String, model : WorldModel, msg : Msg) -> Unit raise {
  let before = model_fingerprint(model)
  ignore(update(model, msg, world_host=editing_host))
  let after = model_fingerprint(model)
  if before != after {
    fail("update mutated its input model: " + label)
  }
}

///|
test "no branch writes through the model it was given" {
  let base = crowded_world()
  let talking_model = step(
    step(base, Select(Some("林掌柜"))),
    Send("温一壶酒"),
  )
  let in_scene = step(base, EnterScene("吧台"))
  let scene_turn = step(in_scene, Send("掌柜的"))
  let branched = step(talking_model, BranchAt(0))
  let drafting = step(base, ToggleCreator)
  let with_idea = step(drafting, CharacterIdeaChanged("一个卖伞的"))
  // Every message that touches a container, run against a model where that
  // branch actually does something.
  let cases : Array[(String, WorldModel, Msg)] = [
    ("Select", base, Select(Some("赶考书生"))),
    ("SayDraftChanged", base, SayDraftChanged("写了一半")),
    ("DoDraftChanged", base, DoDraftChanged("推开门")),
    ("StoryDraftChanged", base, StoryDraftChanged("雨声更大了。")),
    ("SendComposer", base, SendComposer),
    ("OpenDrawer", base, OpenDrawer(Profile)),
    ("CloseDrawer", step(base, OpenDrawer(Profile)), CloseDrawer),
    ("OpenMessageMenu", talking_model, OpenMessageMenu(0)),
    ("CloseMessageMenu", talking_model, CloseMessageMenu),
    ("ToggleRail", base, ToggleRail),
    ("ToggleAtmosphere", base, ToggleAtmosphere),
    ("SetBackdrop", base, SetBackdrop(true)),
    ("SetAppearance", base, SetAppearance("ink")),
    ("PanMap", base, PanMap),
    ("Send", step(base, Select(Some("林掌柜"))), Send("温一壶酒")),
    ("Reply", talking_model, Reply("林掌柜", Some("回一句。"))),
    ("ReplyDelta", talking_model, ReplyDelta("林掌柜", "回")),
    (
      "InWorld",
      talking_model,
      InWorld(
        talking_model.world_epoch(),
        ReplyDelta("林掌柜", "回"),
      ),
    ),
    (
      "SceneReply",
      scene_turn,
      SceneReply(scene_key("吧台"), "林掌柜", Some("嗯。")),
    ),
    (
      "SceneReplyDelta",
      scene_turn,
      SceneReplyDelta(scene_key("吧台"), "林掌柜", "嗯"),
    ),
    ("EnterScene", base, EnterScene("吧台")),
    ("LeaveScene", in_scene, LeaveScene),
    ("AdvanceTime", base, AdvanceTime),
    ("TimeAdvanced", base, TimeAdvanced(Some("发生了一件事。"))),
    ("RegenerateReply", talking_model, RegenerateReply),
    (
      "Regenerated",
      talking_model,
      Regenerated("林掌柜", Some("另一个版本。")),
    ),
    ("SwipeReply", branched, SwipeReply(0, 1)),
    ("EditLine", talking_model, EditLine(0)),
    (
      "EditLineChanged",
      step(talking_model, EditLine(0)),
      EditLineChanged("改"),
    ),
    (
      "EditLineCommit",
      step(step(talking_model, EditLine(0)), EditLineChanged("改")),
      EditLineCommit,
    ),
    ("EditLineCancel", step(talking_model, EditLine(0)), EditLineCancel),
    ("DeleteLine", talking_model, DeleteLine(0)),
    ("ClearConversation", talking_model, ClearConversation),
    ("BranchAt", talking_model, BranchAt(0)),
    ("ToggleCreator", base, ToggleCreator),
    ("UseArchetype", drafting, UseArchetype(0)),
    ("CharacterIdeaChanged", drafting, CharacterIdeaChanged("想法")),
    (
      "CharacterDrafted",
      with_idea,
      CharacterDrafted(Some("{\"name\":\"甲\",\"persona\":\"乙。\"}")),
    ),
    (
      "CreatorChanged",
      drafting,
      CreatorChanged(CharacterDraft::new().with_name("阿七")),
    ),
    (
      "CharacterCreated",
      step(
        drafting,
        CreatorChanged(drafting.creator_draft().with_name("阿七")),
      ),
      CharacterCreated,
    ),
    (
      "SummaryArrived",
      talking_model,
      SummaryArrived("林掌柜", 1, Some("摘要。")),
    ),
    (
      "MemoryProposalsArrived",
      base,
      MemoryProposalsArrived(
        Some("{\"entries\":[{\"keys\":[\"酒\"],\"content\":\"记住。\"}]}"),
      ),
    ),
    (
      "AcceptMemory",
      step(
        base,
        MemoryProposalsArrived(
          Some("{\"entries\":[{\"keys\":[\"酒\"],\"content\":\"记住。\"}]}"),
        ),
      ),
      AcceptMemory(0),
    ),
  ]
  for pair in cases {
    assert_pure(pair.0, pair.1, pair.2)
  }
}

///|
test "bookkeeping completions are pure too" {
  let base = crowded_world()
  let talking_model = step(
    step(base, Select(Some("林掌柜"))),
    Send("温一壶酒"),
  )
  let cases : Array[(String, WorldModel, Msg)] = [
    ("ApiKeyChanged", base, ApiKeyChanged("sk-x")),
    ("EndpointChanged", base, EndpointChanged("https://x")),
    ("ModelChanged", base, ModelChanged("gpt")),
    ("TemperatureChanged", base, TemperatureChanged("0.5")),
    ("ContextChanged", base, ContextChanged("2000")),
    ("ToggleApiKeyReveal", base, ToggleApiKeyReveal),
    ("OpenSettings", base, OpenSettings),
    ("CloseSettings", base, CloseSettings),
    ("ConfigFileLoaded", base, ConfigFileLoaded(Some("api_key=sk\n"))),
    ("SyncLibrary", base, SyncLibrary),
    ("PickWorldRoot", base, PickWorldRoot),
    ("WorldListArrived", base, WorldListArrived(["甲", "乙"])),
    ("WorldNameChanged", base, WorldNameChanged("新世界")),
    ("WorldIdeaChanged", base, WorldIdeaChanged("想法")),
    (
      "WorldGenerated",
      base,
      WorldGenerated(Some("{\"name\":\"甲\",\"background\":\"乙\"}")),
    ),
    (
      "WorldFilesArrived",
      talking_model,
      WorldFilesArrived("x", true, commit_files(talking_model, World)),
    ),
    ("WorldCommitted", base, WorldCommitted("甲", true)),
    ("SettingsSaved", base, SettingsSaved(true)),
    ("SaveConfig", base, SaveConfig),
    ("ExportWorld", base, ExportWorld),
    ("WorldExported", base, WorldExported(true)),
    ("ImportWorld", base, ImportWorld),
    ("WorldImported", base, WorldImported(false, "", [])),
    ("OpenWorld", base, OpenWorld("甲")),
    ("Unused-Page", base, Select(None)),
    (
      "DiscardMemory",
      step(
        base,
        MemoryProposalsArrived(
          Some("{\"entries\":[{\"keys\":[\"酒\"],\"content\":\"记住。\"}]}"),
        ),
      ),
      DiscardMemory(0),
    ),
  ]
  for pair in cases {
    assert_pure(pair.0, pair.1, pair.2)
  }
}
