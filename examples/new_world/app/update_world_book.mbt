///|
/// The world book editor: the world's own lore, editable in the app.
///
/// The world book (`world_book.md`) is the SillyTavern "world info"
/// mechanism: entries whose keywords appear in the conversation are injected
/// into the prompt. It is how a world stays small and still reacts to what
/// the player says — and until now it could only be edited by hand in a text
/// file, which put the world's most expressive tool out of reach of most
/// players.
///
/// The rule is the same as everywhere else in this app: the player owns the
/// world. Edits live in a working copy until 保存, and only 保存 writes the
/// file.

///|
/// Dispatch the world-book arms.
pub fn update_world_book(
  model : WorldModel,
  msg : Msg,
  host : WorldHost?,
) -> (WorldModel, @moui.Effect[Msg]) {
  match msg {
    // Opening the panel loads the working copy from the world.
    WorldBookOpened => ({
      ..model,
      world_book_draft: model.scenario.world_book(),
      world_book_edit: -1,
    }, @moui.Effect::none())
    WorldBookEdit(index) =>
      ({ ..model, world_book_edit: index, }, @moui.Effect::none())
    WorldBookKeysChanged(text) =>
      ({
        ..model,
        world_book_draft: replace_entry(
          model.world_book_draft,
          model.world_book_edit,
          entry => Some(entry.with_keys(split_keys(text))),
        ),
      }, @moui.Effect::none())
    WorldBookContentChanged(text) =>
      ({
        ..model,
        world_book_draft: replace_entry(
          model.world_book_draft,
          model.world_book_edit,
          entry => Some(entry.with_content(text)),
        ),
      }, @moui.Effect::none())
    WorldBookAdd => {
      let draft : Array[WorldEntry] = []
      for entry in model.world_book_draft {
        draft.push(entry)
      }
      draft.push(
        WorldEntry::new(
          keys=["新关键词"],
          content="",
        ),
      )
      ({
        ..model,
        world_book_draft: draft,
        world_book_edit: draft.length() - 1,
      }, @moui.Effect::none())
    }
    WorldBookDelete(index) => {
      let draft : Array[WorldEntry] = []
      let mut at = 0
      for entry in model.world_book_draft {
        if at != index {
          draft.push(entry)
        }
        at += 1
      }
      ({
        ..model,
        world_book_draft: draft,
        world_book_edit: -1,
      }, @moui.Effect::none())
    }
    // Saving writes the book into the world and commits the world folder.
    WorldBookSave => {
      let next = {
        ..model.fork(),
        scenario: model.scenario.with_world_book(model.world_book_draft),
        world_book_edit: -1,
      }
      next.push_log("世界书已保存")
      let effect = match host {
        Some(h) =>
          match next.current {
            Some(folder) =>
              commit_world_effect(h, folder, commit_files(next, World))
            None => @moui.Effect::none()
          }
        None => @moui.Effect::none()
      }
      (next, effect)
    }
    _ => (model, @moui.Effect::none())
  }
}

///|
/// Replace one entry of the working copy.
fn replace_entry(
  entries : Array[WorldEntry],
  index : Int32,
  edit : (WorldEntry) -> WorldEntry?,
) -> Array[WorldEntry] {
  let out : Array[WorldEntry] = []
  let mut at = 0
  for entry in entries {
    if at == index {
      match edit(entry) {
        Some(edited) => out.push(edited)
        None => ()
      }
    } else {
      out.push(entry)
    }
    at += 1
  }
  out
}

///|
/// The trigger keywords of an entry, as the editor writes them: a comma (or a
/// Chinese comma) separated line.
fn split_keys(text : String) -> Array[String] {
  let keys : Array[String] = []
  let mut current = ""
  for ch in text {
    if ch == ',' || ch == '，' || ch == '、' {
      let trimmed = current.trim().to_owned()
      if trimmed != "" {
        keys.push(trimmed)
      }
      current = ""
    } else {
      current += ch.to_string()
    }
  }
  let trimmed = current.trim().to_owned()
  if trimmed != "" {
    keys.push(trimmed)
  }
  keys
}

///|
/// The trigger keywords of an entry, as the editor shows them.
fn join_keys(entry : WorldEntry) -> String {
  entry.keys().join("，")
}
