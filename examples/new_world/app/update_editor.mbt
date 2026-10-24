///|
/// The character editor: open on an existing card, edit a working copy of the
/// six blocks, save it back whole.
///
/// Split out of `update.mbt` like `library.mbt` and `editing.mbt`: one cohesive
/// feature, and a source-file budget that must keep meaning something.
///
/// The editor's invariants:
///
/// - **identity never drifts.** A card's `id` is its folder file name and its
///   conversation key; renaming would orphan both. The editor therefore keeps
///   the card's id/name/location/point/colour and edits only the six blocks
///   (plus the portrait file name, which is data, not identity).
/// - **nothing reaches the card without an explicit save.** The draft and the
///   example-lines buffer are the editor's own working copy; closing discards.
/// - **the example buffer is prose.** One example per line, split on save —
///   the same rule the Markdown card uses.

///|
/// Dispatch the editor arms.
pub fn update_editor(
  model : WorldModel,
  msg : Msg,
  host : WorldHost?,
) -> (WorldModel, @moui.Effect[Msg]) {
  match msg {
    EditCharacter(id) =>
      match model.scenario.character(id) {
        None => (model, @moui.Effect::none())
        Some(card) => {
          let next = {
            ..model.fork(),
            editor_open: true,
            editor_target: Some(id),
            editor_draft: CharacterDraft::from_card(card),
            editor_examples: card.examples().join("\n"),
            editor_tab: 0,
            // The editor covers the drawer it was opened from.
            drawer: None,
            message_menu: None,
          }
          (next, @moui.Effect::none())
        }
      }
    CloseEditor =>
      (
        { ..model, editor_open: false, editor_target: None, },
        @moui.Effect::none(),
      )
    EditorTabChanged(code) =>
      // An out-of-range code snaps to the first block rather than showing an
      // empty page.
      ({ ..model, editor_tab: clamp_int(code, 0, 6), }, @moui.Effect::none())
    EditorChanged(draft) =>
      ({ ..model, editor_draft: draft, }, @moui.Effect::none())
    EditorExamplesChanged(text) =>
      ({ ..model, editor_examples: text, }, @moui.Effect::none())
    // Copy the character as a Tavern v2 card: the format the rest of the
    // roleplay world reads, so a character is not locked inside this app.
    CopyCharacterCard =>
      match model.editor_target {
        None => (model, @moui.Effect::none())
        Some(id) =>
          match model.scenario.character(id) {
            None => (model, @moui.Effect::none())
            Some(card) =>
              match host {
                Some(h) => (model, copy_prompt_effect(h, tavern_v2_json(card)))
                None => (model, @moui.Effect::none())
              }
          }
      }
    // Read a pasted Tavern card into the editor's draft.
    ImportCharacterCard =>
      match tavern_card_from_json(model.card_import_text()) {
        None => {
          let next = model.fork()
          next.push_log("这段不是一张能读的角色卡")
          (next, @moui.Effect::none())
        }
        Some(card) => {
          let next = {
            ..model.fork(),
            editor_draft: CharacterDraft::from_card(card),
            card_import_text: "",
          }
          next.push_log("已读入角色卡：" + card.name())
          (next, @moui.Effect::none())
        }
      }
    SaveCharacter => save_character(model, host)
    _ => (model, @moui.Effect::none())
  }
}

///|
fn clamp_int(value : Int32, low : Int32, high : Int32) -> Int32 {
  if value < low {
    low
  } else if value > high {
    high
  } else {
    value
  }
}

///|
/// Write the editor's draft back into the card it came from, close, and
/// commit the world scope (six blocks live in the card's Markdown file).
fn save_character(
  model : WorldModel,
  host : WorldHost?,
) -> (WorldModel, @moui.Effect[Msg]) {
  let id = match model.editor_target {
    Some(id) => id
    None => return (model, @moui.Effect::none())
  }
  let existing = match model.scenario.character(id) {
    Some(card) => card
    None => return (model, @moui.Effect::none())
  }
  let draft = model.editor_draft
  // The persona is the one field a card cannot live without; an emptied one
  // is refused rather than written, so a stray select-all + delete cannot
  // cost the player their character.
  if draft.persona.trim() == "" {
    let next = model.fork()
    next.push_log("人设不能为空——先把「TA是谁」写回来")
    return (next, @moui.Effect::none())
  }
  let saved = CharacterCard::new(
    id=existing.id(),
    name=existing.name(),
    persona=draft.persona,
    appearance=draft.appearance,
    portrait=draft.portrait,
    portrait_prompt=draft.portrait_prompt,
    principles=draft.principles,
    voice=draft.voice,
    examples=parse_examples_section(model.editor_examples),
    relationship={
      user_identity: draft.user_identity,
      user_name: draft.user_name,
      boundary: draft.boundary,
    },
    setting=draft.setting,
    opening=draft.opening,
    secret=draft.secret,
    goal=draft.goal,
    memory_rules=draft.memory_rules,
    location=existing.location(),
    point=existing.point(),
    color=existing.color(),
  )
  let characters : Array[CharacterCard] = []
  for card in model.scenario.characters() {
    if card.id() == id {
      characters.push(saved)
    } else {
      characters.push(card)
    }
  }
  let scenario = Scenario::new(
    id=model.scenario.id(),
    name=model.scenario.name(),
    background=model.scenario.background(),
    map_width=model.scenario.map_width(),
    map_height=model.scenario.map_height(),
    locations=model.scenario.locations(),
    characters~,
    world_book=model.scenario.world_book(),
    mood=model.scenario.mood(),
  )
  let next = {
    ..model.fork(),
    scenario,
    editor_open: false,
    editor_target: None,
  }
  next.push_log("「\{existing.name()}」的档案已更新")
  match model.current {
    Some(folder) =>
      match host {
        Some(h) =>
          (next, commit_world_effect(h, folder, commit_files(next, World)))
        None => (next, @moui.Effect::none())
      }
    None => (next, @moui.Effect::none())
  }
}
