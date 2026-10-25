///|
/// Read-only accessors for `WorldModel`; views read state through these.

///|
pub fn WorldModel::scenario(self : WorldModel) -> Scenario {
  self.scenario
}

///|

///|
pub fn WorldModel::config(self : WorldModel) -> ModelConfig {
  self.config
}

///|
/// The character the player is currently talking to, if any.
pub fn WorldModel::selected(self : WorldModel) -> String? {
  self.selected
}

///|
pub fn WorldModel::log(self : WorldModel) -> Array[String] {
  self.log
}

///|
/// World folder names discovered in the library.
pub fn WorldModel::worlds(self : WorldModel) -> Array[String] {
  self.worlds
}

///|
/// The world folder currently on stage.
pub fn WorldModel::current(self : WorldModel) -> String? {
  self.current
}

///|
/// Which generation of the world is on stage. Bumped every time the stage is
/// replaced (open, create, import, regenerate the whole world).
pub fn WorldModel::world_epoch(self : WorldModel) -> Int32 {
  self.world_epoch
}

///|
/// True when the host reports no library root at all.
pub fn WorldModel::library_missing(self : WorldModel) -> Bool {
  self.library_missing
}

///|
/// The world folder the world was opened from matches `id` on every save.
pub fn WorldModel::creator_open(self : WorldModel) -> Bool {
  self.creator_open
}

///|
pub fn WorldModel::creator_draft(self : WorldModel) -> CharacterDraft {
  self.creator_draft
}

///|
pub fn WorldModel::idea(self : WorldModel) -> String {
  self.idea
}

///|
pub fn WorldModel::generating(self : WorldModel) -> Bool {
  self.generating
}

///|
/// Memory entries proposed by the provider, pending a decision.
pub fn WorldModel::memory_drafts(self : WorldModel) -> Array[WorldEntry] {
  self.memory_drafts
}

///|
/// Whether the settings page renders the key in clear text.
pub fn WorldModel::api_key_revealed(self : WorldModel) -> Bool {
  self.api_key_revealed
}

///|
/// The location whose scene is on stage, if any.
pub fn WorldModel::scene_location(self : WorldModel) -> String? {
  self.scene_location
}

///|
/// Is the stage showing a multi-character scene?
pub fn WorldModel::in_scene(self : WorldModel) -> Bool {
  self.scene_location is Some(_)
}

///|
/// The cast of the current scene (empty when not in a scene).
pub fn WorldModel::scene_cast(self : WorldModel) -> Array[CharacterCard] {
  match self.scene_location {
    Some(location) => cast_at(self.scenario, location)
    None => []
  }
}

///|
/// The conversation the composer targets: the scene transcript in scene mode,
/// otherwise the selected character's private chat.
pub fn WorldModel::active_conversation_key(self : WorldModel) -> String? {
  match self.scene_location {
    Some(location) => Some(scene_key(location))
    None => self.selected
  }
}

///|
/// Portrait assets of the current world.
pub fn WorldModel::portraits(self : WorldModel) -> Array[(String, String)] {
  self.portraits
}

///|
/// The portrait `data:` URI for one card, or `""` when it has none.
pub fn WorldModel::portrait_for(
  self : WorldModel,
  card : CharacterCard,
) -> String {
  portrait_uri(card, self.portraits)
}

///|
/// The one-line character idea in the creation wizard.
pub fn WorldModel::character_idea(self : WorldModel) -> String {
  self.character_idea
}

///|
/// The composer's 说【】 field.
pub fn WorldModel::say_draft(self : WorldModel) -> String {
  self.say_draft
}

///|
/// The composer's 做【】 field.
pub fn WorldModel::do_draft(self : WorldModel) -> String {
  self.do_draft
}

///|
/// The composer's 旁白【】 field.
pub fn WorldModel::story_draft(self : WorldModel) -> String {
  self.story_draft
}

///|
/// The composer's beat field (the note of what happens next in the scene).
pub fn WorldModel::beat_draft(self : WorldModel) -> String {
  self.beat_draft
}

///|
/// How many transcript lines the stage shows at once.
pub fn WorldModel::transcript_window(self : WorldModel) -> Int32 {
  self.transcript_window
}

///|
/// Can the composer send right now? Any non-empty field counts as content.
pub fn WorldModel::composer_ready(self : WorldModel) -> Bool {
  composer_has_content(self.say_draft, self.do_draft, self.story_draft)
}

///|
/// The composer's active intent (the collapsed form's one field).
pub fn WorldModel::composer_mode(self : WorldModel) -> InputIntent {
  self.composer_mode
}

///|
/// Whether the composer is in the three-field (combined) form.
pub fn WorldModel::composer_expanded(self : WorldModel) -> Bool {
  self.composer_expanded
}

///|
/// Whether the composer's intent menu is open.
pub fn WorldModel::composer_menu(self : WorldModel) -> Bool {
  self.composer_menu
}

///|
/// The history line being edited, if any.
pub fn WorldModel::editing_line(self : WorldModel) -> Int32? {
  self.editing_line
}

///|
/// The text currently in the inline editor.
pub fn WorldModel::edit_buffer(self : WorldModel) -> String {
  self.edit_buffer
}

///|
/// Replace the whole conversation for one character with a new line list.
///
/// Editing a history line re-derives the conversation from its line array; a
/// helper keeps that inside the app (the book is keyed by character id, and a
/// stale key must never create a second entry).
fn set_lines(
  model : WorldModel,
  character_id : String,
  lines : Array[ChatLine],
) -> Unit {
  let current = model.conversations.for_character(character_id)
  let mut rebuilt = Conversation::new(character_id~)
  for line in lines {
    rebuilt = rebuilt.append(line)
  }
  model.conversations.set({
    ..current,
    lines: rebuilt.lines(),
    // Editing history does not change the rolling-summary watermark; only
    // the line list (and its appended counter) is re-derived.
    appended: rebuilt.appended(),
    pending: false,
  })
}

///|
/// The generated reply for a turn: the line to regenerate, if the last line of
/// the conversation is a character line.
fn last_reply_index(conversation : Conversation) -> Int32? {
  let lines = conversation.lines()
  if lines.is_empty() {
    return None
  }
  let index = lines.length() - 1
  match lines[index].speaker() {
    Character(_) => Some(index)
    Player => None
  }
}

///|
pub fn WorldModel::world_name(self : WorldModel) -> String {
  self.world_name
}

///|
/// Which top-level page is on stage.
pub fn WorldModel::page(self : WorldModel) -> Page {
  self.page
}

///|
/// Which side drawer is open, if any.
pub fn WorldModel::drawer(self : WorldModel) -> DrawerKind? {
  self.drawer
}

///|
/// Which history line's "more" menu is open, if any.
pub fn WorldModel::message_menu(self : WorldModel) -> Int32? {
  self.message_menu
}

///|
/// Whether the character rail is visible (medium/compact only).
pub fn WorldModel::rail_open(self : WorldModel) -> Bool {
  self.rail_open
}

///|
/// Whether the full-screen atmosphere view is on stage.
pub fn WorldModel::atmosphere(self : WorldModel) -> Bool {
  self.atmosphere
}

///|
/// Whether the map backdrop paints behind the transcript.
pub fn WorldModel::backdrop(self : WorldModel) -> Bool {
  self.backdrop
}

///|
/// Whether the character editor is open.
pub fn WorldModel::editor_open(self : WorldModel) -> Bool {
  self.editor_open
}

///|
/// Which card the editor is working on (`None` = closed).
pub fn WorldModel::editor_target(self : WorldModel) -> String? {
  self.editor_target
}

///|
/// The editor's working draft.
pub fn WorldModel::editor_draft(self : WorldModel) -> CharacterDraft {
  self.editor_draft
}

///|
/// Which block of the editor is visible.
pub fn WorldModel::editor_tab(self : WorldModel) -> Int32 {
  self.editor_tab
}

///|
/// The example-lines buffer (one line per example).
pub fn WorldModel::editor_examples(self : WorldModel) -> String {
  self.editor_examples
}

///|
/// The memory drawer's input line.

///|
/// Does the editor's draft still differ from the card it was opened on?
pub fn WorldModel::editor_dirty(self : WorldModel) -> Bool {
  match self.editor_target {
    None => false
    Some(id) =>
      match self.scenario.character(id) {
        None => false
        Some(card) => self.editor_draft.differs_from(card)
      }
  }
}

///|
/// A Tavern character card the player pasted in, waiting to be read.
pub fn WorldModel::card_import_text(self : WorldModel) -> String {
  self.card_import_text
}

///|
/// The world book's working copy: the entries being edited.
pub fn WorldModel::world_book_draft(self : WorldModel) -> Array[WorldEntry] {
  self.world_book_draft
}

///|
/// Which world-book entry is open in the editor (-1 = none).
pub fn WorldModel::world_book_edit(self : WorldModel) -> Int32 {
  self.world_book_edit
}

///|
/// The progression topic of the memory being written ("" = a plain fact).
pub fn WorldModel::memory_topic_input(self : WorldModel) -> String {
  self.memory_topic_input
}

///|
pub fn WorldModel::memory_input(self : WorldModel) -> String {
  self.memory_input
}
