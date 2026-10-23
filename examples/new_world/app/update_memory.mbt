///|
/// The character memory manager: add, pin, and delete memories, and route the
/// model's proposals into the memory book.
///
/// Split out of `update.mbt` like the other feature dispatchers. The product
/// rule this module enforces: the *player* owns the memory. The model may
/// propose (every so often, from recent turns), but nothing is remembered
/// without an explicit accept, everything accepted is editable afterwards, and
/// `world_book` stays purely world lore — the shared history lives in the
/// per-character memory file, not in the world's settings.

///|
/// Dispatch the memory arms.
pub fn update_memory(
  model : WorldModel,
  msg : Msg,
  host : WorldHost?,
) -> (WorldModel, @moui.Effect[Msg]) {
  match msg {
    MemoryDraftChanged(text) =>
      ({ ..model, memory_input: text, }, @moui.Effect::none())
    AddMemory => add_memory(model, host)
    ToggleMemoryPin(index) =>
      edit_entry(model, index, host, entry => Some(entry.with_pinned(!entry.pinned())))
    DeleteMemory(index) =>
      edit_entry(model, index, host, _entry => None)
    // A proposal the player adopted: into the memory book of the character on
    // stage, never into the world book.
    AcceptMemory(index) =>
      match model.memory_drafts.get(index) {
        None => (model, @moui.Effect::none())
        Some(entry) =>
          match model.selected {
            None =>
              // Nowhere to put it: keep the draft and say so, rather than
              // silently dropping the model's suggestion.
              (
                log_line(model.fork(), "先在舞台上选一个角色，这段记忆才有归属"),
                @moui.Effect::none(),
              )
            Some(id) => {
              let entries : Array[MemoryEntry] = []
              for existing in model.memories.for_character(id).entries() {
                entries.push(existing)
              }
              entries.push(MemoryEntry::proposed(entry.content()))
              let memories = model.memories.clone()
              memories.set({ character_id: id, entries, })
              let next = {
                ..model.fork(),
                memories,
                memory_drafts: drop_draft(model.memory_drafts, index),
              }
              next.push_log("已记住：「\{entry.content()}」——见长久记忆")
              commit_memories(next, host, id)
            }
          }
      }
    DiscardMemory(index) => {
      let next = {
        ..model.fork(),
        memory_drafts: drop_draft(model.memory_drafts, index),
      }
      next.push_log("已忽略一条记忆提议")
      (next, @moui.Effect::none())
    }
    _ => (model, @moui.Effect::none())
  }
}

///|
/// Record what the player typed as an authored memory of the selected
/// character. An empty line is refused with a hint rather than stored.
fn add_memory(
  model : WorldModel,
  host : WorldHost?,
) -> (WorldModel, @moui.Effect[Msg]) {
  match model.selected {
    None =>
      (
        log_line(model.fork(), "先在舞台上选一个角色"),
        @moui.Effect::none(),
      )
    Some(id) => {
      let text : String = model.memory_input.trim().to_owned()
      if text == "" {
        (
          log_line(model.fork(), "先写下要记住的事"),
          @moui.Effect::none(),
        )
      } else {
        let entries : Array[MemoryEntry] = []
        for existing in model.memories.for_character(id).entries() {
          entries.push(existing)
        }
        entries.push(MemoryEntry::authored(text))
        let memories = model.memories.clone()
        memories.set({ character_id: id, entries, })
        let next = { ..model.fork(), memories, memory_input: "" }
        next.push_log("已记住：「\{text}」")
        commit_memories(next, host, id)
      }
    }
  }
}

///|
/// Apply an edit to one entry (pin flip, or delete via `None`) and persist.
fn edit_entry(
  model : WorldModel,
  index : Int32,
  host : WorldHost?,
  edit : (MemoryEntry) -> MemoryEntry?,
) -> (WorldModel, @moui.Effect[Msg]) {
  match model.selected {
    None => (model, @moui.Effect::none())
    Some(id) => {
      let record = model.memories.for_character(id)
      let entries = record.entries()
      if index < 0 || index >= entries.length() {
        return (model, @moui.Effect::none())
      }
      let kept : Array[MemoryEntry] = []
      for i, entry in entries {
        if i == index {
          match edit(entry) {
            Some(edited) => kept.push(edited)
            None => ()
          }
        } else {
          kept.push(entry)
        }
      }
      let memories = model.memories.clone()
      memories.set({ character_id: id, entries: kept, })
      let next = { ..model.fork(), memories }
      commit_memories(next, host, id)
    }
  }
}

///|
/// Drop one draft by index, keeping the rest in order.
fn drop_draft(
  drafts : Array[WorldEntry],
  index : Int32,
) -> Array[WorldEntry] {
  let kept : Array[WorldEntry] = []
  for i in 0..<drafts.length() {
    if i != index {
      kept.push(drafts[i])
    }
  }
  kept
}

///|
fn log_line(model : WorldModel, line : String) -> WorldModel {
  model.push_log(line)
  model
}

///|
/// Persist one character's memory file (plus the event log the notice rode
/// in on). Without a library the edit stays in memory, like every other
/// commit scope.
fn commit_memories(
  model : WorldModel,
  host : WorldHost?,
  id : String,
) -> (WorldModel, @moui.Effect[Msg]) {
  match (model.current, host) {
    (Some(folder), Some(h)) =>
      (model, commit_world_effect(h, folder, commit_files(model, Memories(id))))
    _ => (model, @moui.Effect::none())
  }
}
