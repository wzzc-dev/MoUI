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
  /// Player edited the composer without sending yet.
  DraftChanged(String)
  /// The composer's input intent changed (say / do / story).
  IntentChanged(Int)
  /// Player typed a line and submitted it.
  Send(String)
  /// A provider reply arrived; `None` text means the call failed.
  ///
  /// The key is the conversation the turn belonged to: a character id for a
  /// private chat, `scene:<地点>` for a scene. A scene reply also carries the
  /// respondent so its line is attributed to the right speaker.
  Reply(String, String?)
  /// A scene reply arrived: `(scene key, respondent id, reply)`.
  SceneReply(String, String, String?)
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
  UseArchetype(Int)
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
  /// A memory-compression reply arrived; `None` = failure (retry later).
  SummaryArrived(String, Int, String?)
  /// A memory-extraction reply arrived; `None` = failure.
  MemoryProposalsArrived(String?)
  /// Adopt a proposed memory entry into the world book.
  AcceptMemory(Int)
  /// Drop a proposed memory entry.
  DiscardMemory(Int)
  /// Show / hide the API key on the settings page.
  ToggleApiKeyReveal
  // ---- conversation editing ----
  /// Regenerate the last reply of the selected conversation (the previous one
  /// becomes a swipe candidate).
  RegenerateReply
  /// A regeneration request settled; `None` = failure (keep the old reply).
  Regenerated(String?)
  /// Move within a reply's candidates. `(line index, direction)`.
  SwipeReply(Int, Int)
  /// Start editing one history line.
  EditLine(Int)
  /// The edit buffer changed.
  EditLineChanged(String)
  /// Commit the edited text back into the history.
  EditLineCommit
  /// Abandon the edit.
  EditLineCancel
  /// Delete one history line.
  DeleteLine(Int)
  /// Clear the selected character's conversation.
  ClearConversation
  /// Branch the conversation at a line: keep everything up to it and start a
  /// new history from there, leaving the original intact on disk.
  BranchAt(Int)
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
