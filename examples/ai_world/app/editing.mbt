///|
/// History editing: regenerate, swipe between candidates, edit a line, delete a
/// line, branch the conversation, clear it.
///
/// Split out of `update.mbt` because it is one cohesive feature and because
/// that file has to stay under the repository's source-file hard limit. Every
/// arm here obeys the same two rules as the rest of `update`: start a mutating
/// branch from `model.fork()`, and commit whatever changed.

///|
/// Dispatch the history-editing arms.
pub fn update_editing(
  model : WorldModel,
  msg : Msg,
  runner : TurnRunner,
  host : WorldHost?,
) -> (WorldModel, @moui.Effect[Msg]) {
  match msg {
    RegenerateReply =>
      match model.selected {
        None => (model, @moui.Effect::none())
        Some(id) => {
          let conversation = model.conversations.for_character(id)
          match (last_reply_index(conversation), model.scenario.character(id)) {
            (None, _) => (model, @moui.Effect::none())
            (_, None) => (model, @moui.Effect::none())
            (Some(reply_index), Some(card)) => {
              if conversation.pending() {
                return (model, @moui.Effect::none())
              }
              // Regeneration requests the same prompt *without* the reply being
              // replaced: the model sees the turn it is about to answer again.
              let history = conversation.lines()
              let mut without_last = Conversation::new(character_id=id)
              for index in 0..<reply_index {
                without_last = without_last.append(history[index])
              }
              let plan = plan_messages(
                model.scenario,
                card,
                without_last,
                "",
                budget=model.config.context_budget(),
              )
              let next = model.fork()
              next.conversations.set(conversation.with_pending(true))
              next.push_log("重新生成 \{card.name()} 的回复…")
              if !model.config.llm_enabled() {
                // No provider: regenerate deterministically from the player's
                // last line, so the swipe affordance still works offline.
                let seed = match reply_index {
                  0 => ""
                  _ => history[reply_index - 1].text()
                }
                let lines : Array[ChatLine] = []
                for index in 0..<reply_index {
                  lines.push(history[index])
                }
                let regenerated = ChatLine::character(
                  id,
                  scripted_reply(model.scenario, card, seed),
                )
                let last = history[reply_index]
                lines.push(last.with_alternative(regenerated.text()))
                set_lines(next, id, lines)
                next.conversations.set(
                  next.conversations.for_character(id).with_pending(false),
                )
                next.push_log(
                  "（本地剧本）已换一版回复，可左右切换",
                )
                return (next, commit_effect(next, host, Conversation(id)))
              }
              let request = LlmRequest::new(
                character_id=id,
                endpoint=next.config.endpoint(),
                api_key=next.config.api_key(),
                model=next.config.model(),
                temperature=next.config.temperature(),
                messages=plan.messages,
              )
              (
                next,
                @moui.Effect::run(
                  key="ai-world:regenerate",
                  kind="provider",
                  label="Regenerate reply",
                  run=dispatch => {
                    runner(request, reply => dispatch(Regenerated(reply)))
                  },
                ),
              )
            }
          }
        }
      }
    Regenerated(reply) =>
      match model.selected {
        None => (model, @moui.Effect::none())
        Some(id) => {
          let conversation = model.conversations.for_character(id)
          let next = model.fork()
          match (reply, last_reply_index(conversation)) {
            (Some(text), Some(index)) => {
              let cleaned = llm_clean_reply(
                text,
                character_name(model.scenario, id),
              )
              let lines : Array[ChatLine] = []
              for line_index, line in conversation.lines() {
                if line_index == index {
                  lines.push(line.with_alternative(cleaned))
                } else {
                  lines.push(line)
                }
              }
              set_lines(next, id, lines)
              next.conversations.set(
                next.conversations.for_character(id).with_pending(false),
              )
              next.push_log(
                "已换一版回复（共 \{conversation.lines()[index].candidate_count() + 1} 版）",
              )
            }
            (None, Some(_)) => {
              next.conversations.set(conversation.with_pending(false))
              next.push_log("重新生成失败——保留原来的回复")
            }
            _ => ()
          }
          (next, commit_effect(next, host, Conversation(id)))
        }
      }
    SwipeReply(line_index, direction) =>
      match model.selected {
        None => (model, @moui.Effect::none())
        Some(id) => {
          let conversation = model.conversations.for_character(id)
          let lines = conversation.lines()
          if line_index < 0 || line_index >= lines.length() {
            return (model, @moui.Effect::none())
          }
          let line = lines[line_index]
          if !line.has_alternatives() {
            return (model, @moui.Effect::none())
          }
          let count = line.candidate_count()
          let target = (line.selected() + direction + count) % count
          let lines_next : Array[ChatLine] = []
          for index, existing in lines {
            if index == line_index {
              lines_next.push(existing.with_candidate(target))
            } else {
              lines_next.push(existing)
            }
          }
          let next = model.fork()
          set_lines(next, id, lines_next)
          (next, commit_effect(next, host, Conversation(id)))
        }
      }
    EditLine(line_index) =>
      match model.selected {
        None => (model, @moui.Effect::none())
        Some(id) => {
          let lines = model.conversations.for_character(id).lines()
          if line_index < 0 || line_index >= lines.length() {
            (model, @moui.Effect::none())
          } else {
            (
              {
                ..model,
                editing_line: Some(line_index),
                edit_buffer: lines[line_index].text(),
              },
              @moui.Effect::none(),
            )
          }
        }
      }
    EditLineChanged(value) =>
      ({ ..model, edit_buffer: value, }, @moui.Effect::none())
    EditLineCancel =>
      ({ ..model, editing_line: None, edit_buffer: "", }, @moui.Effect::none())
    EditLineCommit =>
      match (model.selected, model.editing_line) {
        (Some(id), Some(line_index)) => {
          let conversation = model.conversations.for_character(id)
          let lines = conversation.lines()
          if line_index < 0 || line_index >= lines.length() {
            (
              { ..model, editing_line: None, edit_buffer: "", },
              @moui.Effect::none(),
            )
          } else {
            let text = model.edit_buffer.trim().to_owned()
            if text == "" {
              (model, @moui.Effect::none())
            } else {
              let lines_next : Array[ChatLine] = []
              for index, existing in lines {
                if index == line_index {
                  lines_next.push(existing.with_text(text))
                } else {
                  lines_next.push(existing)
                }
              }
              let next = model.fork()
              set_lines(next, id, lines_next)
              let cleared = { ..next, editing_line: None, edit_buffer: "", }
              cleared.push_log("已修改第 \{line_index + 1} 条历史")
              (cleared, commit_effect(cleared, host, Conversation(id)))
            }
          }
        }
        _ =>
          (
            { ..model, editing_line: None, edit_buffer: "", },
            @moui.Effect::none(),
          )
      }
    DeleteLine(line_index) =>
      match model.selected {
        None => (model, @moui.Effect::none())
        Some(id) => {
          let lines = model.conversations.for_character(id).lines()
          if line_index < 0 || line_index >= lines.length() {
            (model, @moui.Effect::none())
          } else {
            let lines_next : Array[ChatLine] = []
            for index, existing in lines {
              if index != line_index {
                lines_next.push(existing)
              }
            }
            let next = model.fork()
            set_lines(next, id, lines_next)
            next.push_log("已删除第 \{line_index + 1} 条历史")
            (next, commit_effect(next, host, Conversation(id)))
          }
        }
      }
    BranchAt(line_index) =>
      match model.selected {
        None => (model, @moui.Effect::none())
        Some(id) => {
          let conversation = model.conversations.for_character(id)
          let lines = conversation.lines()
          if line_index < 0 || line_index >= lines.length() {
            return (model, @moui.Effect::none())
          }
          // Branches are siblings on disk (`林掌柜~2`), not a tree: the world
          // stays a folder of readable files.
          let mut branch = 2
          let mut key = branched_key(id, branch)
          while model.conversations.find(key) is Some(_) {
            branch += 1
            key = branched_key(id, branch)
          }
          let next = model.fork()
          // The new branch keeps everything up to and including the chosen
          // line; the original conversation is untouched.
          let mut fresh = Conversation::new(character_id=key)
          for index in 0..<=line_index {
            fresh = fresh.append(lines[index])
          }
          next.conversations.set(fresh)
          let settled = { ..next, selected: Some(key), }
          settled.push_log(
            "已在第 \{line_index + 1} 条分叉出「\{key}」（原对话保留）",
          )
          (settled, commit_effect(settled, host, Conversation(key)))
        }
      }
    ClearConversation =>
      match model.selected {
        None => (model, @moui.Effect::none())
        Some(id) => {
          let next = model.fork()
          next.conversations.set(Conversation::new(character_id=id))
          let cleared = { ..next, editing_line: None, edit_buffer: "", }
          cleared.push_log(
            "已清空与 \{character_name(cleared.scenario, id)} 的对话",
          )
          (cleared, commit_effect(cleared, host, Conversation(id)))
        }
      }
    _ => (model, @moui.Effect::none())
  }
}
