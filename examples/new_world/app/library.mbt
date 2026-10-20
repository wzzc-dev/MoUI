///|
/// The world library: list the folders, open one, create a new one, and record
/// a commit.
///
/// Split from `update.mbt` for the same reason as `editing.mbt` and
/// `creation.mbt`: one cohesive feature, and a hard line limit to respect.

///|
/// Dispatch the world-library arms.
pub fn update_library(
  model : WorldModel,
  msg : Msg,
  host : WorldHost?,
) -> (WorldModel, @moui.Effect[Msg]) {
  // No `runner`: the library never talks to a provider. Opening, creating and
  // committing are local bookkeeping, which is why this module needs no turns.
  ignore(model)
  match msg {
    SyncLibrary =>
      match host {
        Some(h) => (model, sync_library_effect(h))
        None => (model, @moui.Effect::none())
      }
    PickWorldRoot =>
      match host {
        Some(h) =>
          (
            model,
            @moui.Effect::run(
              key="new-world:pick-root",
              kind="filesystem",
              label="Pick world library",
              run=dispatch => {
                (h.pick_root)(names => dispatch(WorldListArrived(names)))
              },
            ),
          )
        None => (model, @moui.Effect::none())
      }
    WorldListArrived(names) => {
      let next = { ..model, worlds: names, library_missing: false, }
      // The config load rides on the first listing: this message can only be
      // dispatched once the host bridge is fully past the boot race.
      let config_effect = match host {
        Some(h) =>
          if next.config_file_loaded {
            @moui.Effect::none()
          } else {
            read_config_effect(h)
          }
        None => @moui.Effect::none()
      }
      // First sync after launch opens the newest-known world so the product
      // boots straight into a conversation instead of an empty catalogue.
      let next = if next.config_file_loaded {
        next
      } else {
        { ..next, config_file_loaded: true, }
      }
      if next.current is None && names.length() > 0 {
        match host {
          Some(h) =>
            (
              next,
              @moui.Effect::batch([
                open_world_effect(h, names[0]),
                config_effect,
              ]),
            )
          None => (next, @moui.Effect::none())
        }
      } else {
        (next, config_effect)
      }
    }
    OpenWorld(folder) =>
      // Only a plain child-folder name can reach the host. The list comes from
      // the host itself, so this is a guard against a malformed listing rather
      // than a user path.
      if folder != world_folder_name(folder) || folder == "" {
        let next = model.fork()
        next.push_log(
          "「\{folder}」不是合法的世界文件夹名，已忽略",
        )
        (next, @moui.Effect::none())
      } else {
        match host {
          Some(h) => (model, open_world_effect(h, folder))
          None => (model, @moui.Effect::none())
        }
      }
    WorldFilesArrived(folder, ok, files) =>
      if !ok {
        let next = model.fork()
        next.push_log(
          "无法读取世界库「\{folder}」——先选择一个文件夹作为世界库",
        )
        ({ ..next, library_missing: true, }, @moui.Effect::none())
      } else {
        match parse_world_files(world_files_from_paths(files)) {
          Some(parsed) => {
            // A different folder means a different world: conversations are
            // keyed by character id and must not leak across worlds. Re-reading
            // the same folder keeps the current history.
            let fresh = match model.current {
              Some(opened) => opened != folder
              None => true
            }
            let next = {
              ..model.fork(),
              scenario: parsed.scenario,
              current: Some(folder),
              portraits: files.filter(pair => is_portrait_file_name(pair.0)),
            }
            if fresh {
              next.conversations.clear()
              // The folder is the source of truth at open time: the world's
              // own journal replaces whatever is in memory.
              next.log.clear()
              for event in parsed.events {
                next.log.push(event)
              }
              for conversation in parsed.conversations {
                next.conversations.set(conversation)
              }
            }
            // Load notices describe the act of opening the file, not something
            // that happened in the world. They are written into the log for the
            // player to see, but `events_json_text` filters them out so they
            // never accumulate in the world's own file.
            for warning in parsed.warnings {
              next.push_log("世界书提示：\{warning}")
            }
            // Re-reading the same folder must not pile up identical notices, so
            // the previous ones are dropped first.
            let kept : Array[String] = []
            for line in next.log {
              if !is_transient_log_line(line) {
                kept.push(line)
              }
            }
            next.log.clear()
            for line in kept {
              next.log.push(line)
            }
            next.push_log(
              "已载入「\{folder}」：\{parsed.scenario.characters().length()} 个角色，\{parsed.scenario.world_book().length()} 条世界书",
            )
            (next, @moui.Effect::none())
          }
          None => {
            let next = model.fork()
            next.push_log(
              "「\{folder}」不是世界文件夹（缺 world.md 或名字行）",
            )
            (next, @moui.Effect::none())
          }
        }
      }
    WorldNameChanged(value) =>
      ({ ..model, world_name: value, }, @moui.Effect::none())
    NewWorld => {
      let typed : String = model.world_name.trim().to_owned()
      if typed == "" {
        let next = model.fork()
        next.push_log("先给新世界起个名字")
        return (next, @moui.Effect::none())
      }
      // The name becomes a directory on the player's disk, so it is sanitized
      // before it is compared or handed to the host: a typed `../x` must not be
      // able to create a folder outside the library.
      let name = world_folder_name(typed)
      // The sanitising warning has to ride on the model actually returned, so
      // it is collected here and pushed onto `next` below. (It used to be
      // pushed onto a throwaway copy, which made the notice vanish.)
      let mut warned_about_name = false
      if name != typed {
        warned_about_name = true
      }
      if model.worlds.contains(name) {
        let next = model.fork()
        next.push_log("「\{name}」已存在——直接打开它即可")
        return (next, @moui.Effect::none())
      }
      let next = {
        ..model.fork(),
        scenario: blank_world(name),
        current: Some(name),
        worlds: with_world(model.worlds, name),
        world_name: "",
        selected: None,
      }
      next.conversations.clear()
      if warned_about_name {
        next.push_log(
          "名字里的路径符号已替换：「\{typed}」→「\{name}」",
        )
      }
      next.push_log("新世界「\{name}」已建立")
      match host {
        Some(h) =>
          (next, commit_world_effect(h, name, commit_files(next, World)))
        None => (next, @moui.Effect::none())
      }
    }
    WorldCommitted(folder, ok) => {
      let next = model.fork()
      if ok {
        next.push_log("已保存到世界库：\{folder}")
      } else {
        next.push_log(
          "写入失败：\{folder}（世界仍在内存中，可重试或检查文件夹权限）",
        )
      }
      (next, @moui.Effect::none())
    }
    _ => (model, @moui.Effect::none())
  }
}
