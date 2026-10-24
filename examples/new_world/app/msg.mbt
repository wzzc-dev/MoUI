///|
/// The message protocol and page enum.
///
/// Declared in their own file so the dead-UI gate can tell *construction*
/// sites from the message declaration: a variant constructed only inside
/// `update.mbt` (an effect completion) would otherwise look dead, because that
/// file is both the declaration file and the place the host callbacks are
/// wired. Splitting them makes the gate meaningful for this example too.
///
/// Every variant below has a real construction site somewhere else:
/// - player actions come from `view.mbt` (buttons, fields, the map);
/// - host/provider completions come from the typed effect callbacks in
///   `update.mbt`'s effect constructors (`sync_library_effect` and friends),
///   which live in `effect.mbt`.

///|
/// Top-level pages: the main three-stage layout and a full-width settings
/// page (the model configuration lives in `<世界库>/config.json`).
pub(all) enum Page {
  Main
  Settings
} derive(Eq, Debug)

///|
pub extend Page with Debug::{to_repr}

///|
pub extend Page with Eq::{not_equal, equal}

///|
/// Which side drawer is open (`None` = none).
///
/// The drawer is where everything the old permanent right rail used to show
/// now lives on demand: the character profile, the memory manager, the model
/// status, and the event log. The stage keeps its full width for reading.
pub(all) enum DrawerKind {
  Profile
  Memory
  Model
  Events
  /// The prompt as it is really sent: the system prompt, the world rules, the
  /// memories and the history, verbatim.
  Prompt
  /// The world book: the world's own keyword-triggered lore, editable here.
  WorldBook
} derive(Eq, Debug)

///|
pub extend DrawerKind with Debug::{to_repr}

///|
pub extend DrawerKind with Eq::{not_equal, equal}

///|
pub(all) enum Msg {
  /// Select the character the player is talking to. Selecting the already
  /// selected character keeps the composer draft; switching characters does
  /// not carry a half-written line into a different conversation.
  Select(String?)
  /// Enter the scene at a location: several characters present there talk in
  /// one transcript instead of one-on-one.
  EnterScene(String)
  /// Leave the scene and go back to the character list.
  LeaveScene
  /// Advance the world clock: ask the model what happened while the player was
  /// away, and fold the answer into the event log. An explicit action, never a
  /// background tick: a provider call costs money and should not be driven by
  /// a timer.
  AdvanceTime
  /// The advanced-time narration arrived (`None` = failure).
  TimeAdvanced(String?)
  /// The map was panned. Transient (view-owned) state changed, but the message
  /// still travels through `update` so a drag cannot silently become a
  /// character switch that discards the draft.
  PanMap
  /// Player typed into the composer's 说【】 field.
  SayDraftChanged(String)
  /// Player typed into the composer's 做【】 field.
  DoDraftChanged(String)
  /// Player typed into the composer's 旁白【】 field.
  StoryDraftChanged(String)
  /// Player typed into the composer's 这一幕【】 field: the note of what
  /// happens next in the scene.
  BeatDraftChanged(String)
  /// The Tavern card the player pasted in, waiting to be read.
  CardImportTextChanged(String)
  /// Copy the edited character as a Tavern v2 card.
  CopyCharacterCard
  /// Read the pasted Tavern card into the editor's draft.
  ImportCharacterCard
  /// The world book was opened for editing: the working copy is loaded.
  WorldBookOpened
  /// Open one world-book entry in the editor.
  WorldBookEdit(Int32)
  /// The edited entry's trigger keywords (comma separated).
  WorldBookKeysChanged(String)
  /// The edited entry's content.
  WorldBookContentChanged(String)
  /// Add an empty entry to the world book.
  WorldBookAdd
  /// Remove one entry from the world book.
  WorldBookDelete(Int32)
  /// Write the world book back into the world.
  WorldBookSave
  /// Reveal `step` more lines of the transcript.
  ExtendTranscript(Int32)
  /// Player typed a line and submitted it.
  Send(String)
  /// Send the three composer fields (说 / 做 / 旁白) as one turn.
  SendComposer
  /// A piece of a reply arrived while the provider is still writing.
  ReplyDelta(String, String)
  /// A piece of a scene reply arrived.
  SceneReplyDelta(String, String, String)
  /// A provider reply arrived; `None` text means the call failed.
  ///
  /// The key is the conversation the turn belonged to: a character id for a
  /// private chat, `scene:<地点>` for a scene. A scene reply also carries the
  /// respondent so its line is attributed to the right speaker.
  Reply(String, String?)
  /// A scene reply arrived: `(scene key, respondent id, reply)`.
  SceneReply(String, String, String?)
  /// Open a side drawer: the character profile, the memory manager, the model
  /// status, or the event log — everything the old permanent right rail used
  /// to show, now on demand.
  OpenDrawer(DrawerKind)
  /// Close the open drawer (button, outside tap, or Escape).
  CloseDrawer
  /// Open one history line's "more" menu (`⋯`): regenerate, swipe candidates,
  /// edit, delete, branch. Replaces the always-visible per-line action row.
  OpenMessageMenu(Int32)
  /// Close the message menu (item chosen, outside tap, or Escape).
  CloseMessageMenu
  /// Show / hide the character rail on medium and compact layouts, where it
  /// cannot sit beside the stage permanently.
  ToggleRail
  /// Enter / leave the full-screen atmosphere view: the scenario map as an
  /// immersive backdrop, with the mood switcher.
  ToggleAtmosphere
  /// Show / hide the low-interference map backdrop behind the transcript.
  SetBackdrop(Bool)
  /// Switch the world's scene mood (the atmosphere view's palette chips).
  /// The accent colour and the map tint follow; the text never does.
  SetMood(MoodVariant)
  // ---- character editor ----
  /// Open the six-block editor on an existing character (the profile
  /// drawer's 编辑角色 button).
  EditCharacter(String)
  /// Close the editor without saving.
  CloseEditor
  /// Switch the editor's visible block.
  EditorTabChanged(Int32)
  /// A field in the editor changed; the draft is the whole buffer.
  EditorChanged(CharacterDraft)
  /// The example-lines buffer changed (one line per example).
  EditorExamplesChanged(String)
  /// Write the editor's draft back into the card and close.
  SaveCharacter
  /// The world's portrait assets, re-read from the folder after a commit.
  ///
  /// The model caches the portraits so rendering never does IO. A commit can
  /// bring a new picture into the folder (the editor's 立绘 field points at a
  /// file the player just dropped in), and the cache has to learn about it —
  /// otherwise the picture only appears after a restart.
  WorldPortraitsRefreshed(Array[(String, String)])
  // ---- composer ----
  /// Switch the composer's active intent (说 / 做 / 旁白). The single field
  /// writes into the matching draft, and each intent keeps its own text.
  ComposerModeChanged(InputIntent)
  /// Open or close the composer's intent menu.
  ComposerMenuChanged(Bool)
  /// Expand the composer into the three-field (combined) form, or collapse it
  /// back to the single field.
  ToggleComposerExpanded
  // ---- character memory ----
  /// The "要记住的事" input in the memory drawer changed.
  MemoryDraftChanged(String)
  /// The progression topic of the memory being written ("" = a plain fact).
  MemoryTopicDraftChanged(String)
  /// Keep a memory out of the prompt (or let it back in).
  ToggleMemoryHidden(Int32)
  /// Copy the prompt preview to the clipboard.
  CopyPromptPreview
  /// Record what the player typed as an authored memory of the selected
  /// character.
  AddMemory
  /// Pin / unpin a memory (pinned entries always ride in the prompt).
  ToggleMemoryPin(Int32)
  /// Delete a memory the player no longer wants kept.
  DeleteMemory(Int32)
  /// Open the settings page (re-reads `config.json` from the library).
  OpenSettings
  /// Back to the main layout.
  CloseSettings
  /// The library's `config.json` arrived; `None` = missing or unreadable.
  ConfigFileLoaded(String?)
  /// A settings-file write finished.
  SettingsSaved(Bool)
  /// Configuration field edits.
  EndpointChanged(String)
  ModelChanged(String)
  ApiKeyChanged(String)
  TemperatureChanged(String)
  /// Persist the current configuration through host settings.
  SaveConfig
  // ---- world management (folder database) ----
  /// Re-list the library without interaction.
  SyncLibrary
  /// Ask the host to pick/point at the library root (a user gesture).
  PickWorldRoot
  /// The library listing arrived.
  WorldListArrived(Array[String])
  /// Open (or re-read) one world folder.
  OpenWorld(String)
  /// One world folder's files arrived.
  WorldFilesArrived(String, Bool, Array[(String, String)])
  /// The new-world name being typed.
  WorldNameChanged(String)
  /// Create the folder for a new world.
  NewWorld
  /// A world folder write finished.
  WorldCommitted(String, Bool)
  // ---- character creation ----
  ToggleCreator
  CreatorChanged(CharacterDraft)
  CharacterCreated
  /// Fill the creator from a built-in archetype (index into
  /// `creator_archetypes`).
  UseArchetype(Int32)
  /// The one-line character idea being typed.
  CharacterIdeaChanged(String)
  /// Ask the provider to draft the card from that idea.
  DraftCharacter
  /// The drafted card arrived (`None` = failure, keep what was typed).
  CharacterDrafted(String?)
  // ---- AI world generation ----
  WorldIdeaChanged(String)
  GenerateWorld
  /// The provider answered a generation request (`None` = failure).
  WorldGenerated(String?)
  // ---- context & memory ----
  /// The context-budget preset changed from the settings page.
  ContextChanged(String)
  /// The appearance changed ("paper" / "ink"): the whole product re-skins
  /// through the root theme wrap, and the choice persists with the config.
  SetAppearance(String)
  /// A memory-compression reply arrived; `None` = failure (retry later).
  SummaryArrived(String, Int32, String?)
  /// A memory-extraction reply arrived; `None` = failure.
  MemoryProposalsArrived(String?)
  /// Adopt a proposed memory entry into the world book.
  AcceptMemory(Int32)
  /// Drop a proposed memory entry.
  DiscardMemory(Int32)
  /// Show / hide the API key on the settings page.
  ToggleApiKeyReveal
  // ---- conversation editing ----
  /// Regenerate the last reply of the selected conversation (the previous one
  /// becomes a swipe candidate).
  RegenerateReply
  /// A regeneration request settled; `None` = failure (keep the old reply).
  Regenerated(String?)
  /// Move within a reply's candidates. `(line index, direction)`.
  SwipeReply(Int32, Int32)
  /// Start editing one history line.
  EditLine(Int32)
  /// The edit buffer changed.
  EditLineChanged(String)
  /// Commit the edited text back into the history.
  EditLineCommit
  /// Abandon the edit.
  EditLineCancel
  /// Delete one history line.
  DeleteLine(Int32)
  /// Clear the selected character's conversation.
  ClearConversation
  /// Branch the conversation at a line: keep everything up to it and start a
  /// new history from there, leaving the original intact on disk.
  BranchAt(Int32)
  // ---- portability ----
  /// Write the current world out as a shareable bundle.
  ExportWorld
  /// A bundle export finished; `false` = cancelled or failed.
  WorldExported(Bool)
  /// Pick a bundle and add it to the library as a new world.
  ImportWorld
  /// A bundle import finished: `(ok, folder, files)`.
  WorldImported(Bool, String, Array[(String, String)])
}
