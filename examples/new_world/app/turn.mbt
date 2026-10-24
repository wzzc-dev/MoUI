///|
/// One conversational turn: a private chat with one character, or a scene
/// where several characters share a transcript.
///
/// These live outside `update.mbt` because they are the only part of the loop
/// that is a *pipeline* (append the player's line, plan the prompt, dispatch a
/// provider request, commit the journal) rather than a state transition. Keeping
/// them here also keeps `update.mbt` a readable message switch.
///
/// Both paths share the same rules: one turn in flight per conversation, the
/// journal is committed whatever the reply turns out to be, and the request
/// carries the whole planned message list (never just the first and last).

///|
/// One scene turn: the player speaks to everyone present, and one named
/// character answers.
///
/// The scene shares the conversation book under `scene:<地点>`, so the
/// transcript keeps every speaker in order while a private chat with any of
/// them stays untouched. The respondent rotates (or answers to their name), so
/// a scene alternates voices without an extra "who speaks" model call.
fn send_scene_turn(
  model : WorldModel,
  location : String,
  text : String,
  runner : TurnRunner,
  host : WorldHost?,
) -> (WorldModel, @moui.Effect[Msg]) {
  let trimmed : String = text.trim().to_owned()
  if trimmed == "" {
    return (model, @moui.Effect::none())
  }
  let cast = cast_at(model.scenario, location)
  let key = scene_key(location)
  let conversation = model.conversations.for_character(key)
  if conversation.pending() {
    return (model, @moui.Effect::none())
  }
  // Rotation counts *scene turns*, not lines. A turn appends a player line and a
  // reply, so indexing by `lines().length()` advanced by 2 each time: with two
  // characters in the cast the same person answered every round. Counting the
  // player's lines gives one step per turn.
  let turn_index = match
    conversation.lines().filter(line => line.speaker() is Player) {
    players => players.length()
  }
  let responder = match responder_for(cast, trimmed, turn_index) {
    Some(card) => card
    None => return (model, @moui.Effect::none())
  }
  let next = { ..model.fork(), say_draft: "", do_draft: "", story_draft: "", }
  append_player(next, key, trimmed)
  next.push_log("you → 场景「\{location}」: \{trimmed}")
  if next.config.llm_enabled() {
    let conversation = next.conversations.for_character(key)
    next.conversations.set(conversation.with_pending(true))
    let system = build_scene_prompt(next.scenario, location, cast, responder)
    // Scene turns reuse the same budgeted history walk; only the system prompt
    // and the lore scope differ. The respondent's own memories ride along —
    // a scene is still a conversation with *someone*.
    let memories = select_memories(
      next.memories.for_character(responder.id()).entries(),
      trimmed,
    )
    let mood = conversation.mood().unwrap_or(next.scenario.mood())
    let plan = plan_messages(
      next.scenario,
      responder,
      conversation,
      trimmed,
      budget=next.config.context_budget(),
      memories~,
      mood=Some(mood),
    )
    let messages : Array[(String, String)] = [("system", system)]
    for index, message in plan.messages {
      // Replace the private persona prompt (index 0) with the scene prompt;
      // keep the summary, lore, and history that follow it.
      if index > 0 {
        messages.push(message)
      }
    }
    let request = LlmRequest::new(
      character_id=key,
      endpoint=next.config.endpoint(),
      api_key=next.config.api_key(),
      model=next.config.model(),
      temperature=next.config.temperature(),
      messages~,
    )
    let effects : Array[@moui.Effect[Msg]] = [
      @moui.Effect::run(
        key="new-world:scene-turn",
        kind="provider",
        label="Scene turn",
        run=dispatch => {
          runner(
            request,
            reply => {
              dispatch(SceneReply(key, responder.id(), reply))
            },
            delta => {
              dispatch(SceneReplyDelta(key, responder.id(), delta))
            },
          )
        },
      ),
      commit_effect(next, host, Conversation(key)),
    ]
    (next, pack_effects(effects))
  } else {
    // Offline: the respondent still answers, deterministically, so a scene is
    // playable without a key. The line must be attributed to the person who
    // spoke, not to the scene key — otherwise every offline scene reply reads
    // as if the room itself answered.
    append_scene_reply(
      next,
      key,
      responder.id(),
      scripted_reply(next.scenario, responder, trimmed),
    )
    next.push_log("（本地剧本）\{responder.name()} 在场景中回应")
    (next, commit_effect(next, host, Conversation(key)))
  }
}

///|
/// One private turn: append the player's line, then either ask the provider or
/// answer locally.
fn send_private_turn(
  model : WorldModel,
  text : String,
  runner : TurnRunner,
  host : WorldHost?,
) -> (WorldModel, @moui.Effect[Msg]) {
  let trimmed : String = text.trim().to_owned()
  if trimmed == "" {
    return (model, @moui.Effect::none())
  }
  // No selection means nothing to talk to; the view keeps Send unavailable
  // in that state, so this is a guard rather than a reachable branch.
  match model.selected {
    None => (model, @moui.Effect::none())
    Some(id) =>
      match model.scenario.character(id) {
        None => (model, @moui.Effect::none())
        Some(card) => {
          // One turn in flight per conversation: a second send while the
          // provider is still answering would stack requests and let the
          // first reply clear the pending flag under the second one.
          let in_flight = model.conversations.for_character(id)
          if in_flight.pending() {
            return (model, @moui.Effect::none())
          }
          let next = {
            ..model.fork(),
            say_draft: "",
            do_draft: "",
            story_draft: "",
          }
          append_player(next, id, trimmed)
          next.push_log(
            "you → \{character_name(next.scenario, id)}: \{trimmed}",
          )
          if next.config.llm_enabled() {
            // The provider turn is an effect, not a side effect here: the
            // runner is injected by the host, the reply arrives as a
            // typed message, and the pending flag keeps the UI honest.
            let conversation = next.conversations.for_character(id)
            next.conversations.set(conversation.with_pending(true))
            // What this character remembers about the player: pinned
            // entries always, then what this very line touches.
            let memories = select_memories(
              next.memories.for_character(id).entries(),
              trimmed,
            )
            let mood = conversation.mood().unwrap_or(next.scenario.mood())
            let plan = plan_messages(
              next.scenario,
              card,
              conversation,
              trimmed,
              budget=next.config.context_budget(),
              memories~,
              mood=Some(mood),
            )
            // The turn's parts frame the newest line for the model only; the
            // stored history keeps the raw text the player typed. The plan
            // already ends with that line, so the framed text replaces the
            // last message rather than being added as a second copy. A bare
            // `Send` line is plain speech (`Say`), so it reaches the model
            // verbatim; composed turns carry their own （动作）/（旁白） markers,
            // which the framer reads part by part.
            let wire : Array[(String, String)] = []
            for index, message in plan.messages {
              if index == plan.messages.length() - 1 {
                wire.push((message.0, frame_player_turn(message.1, Say)))
              } else {
                wire.push(message)
              }
            }
            // The whole plan is the request: system prompt, rolling
            // summary, world-book hits, and every history line that fits.
            // Sending only the first and last message would make each
            // turn stateless and silently discard the compression work.
            let request = LlmRequest::new(
              character_id=id,
              endpoint=next.config.endpoint(),
              api_key=next.config.api_key(),
              model=next.config.model(),
              temperature=next.config.temperature(),
              messages=wire,
            )
            let effects : Array[@moui.Effect[Msg]] = [
              @moui.Effect::run(
                key="new-world:turn",
                kind="provider",
                label="Provider turn",
                run=dispatch => {
                  runner(
                    request,
                    reply => dispatch(Reply(id, reply)),
                    delta => dispatch(ReplyDelta(id, delta)),
                  )
                },
              ),
            ]
            // The player's line is world state: commit the journal
            // alongside the turn, whatever the reply turns out to be. Only
            // this conversation and the event log changed, so the commit
            // rewrites exactly those two files.
            effects.push(commit_effect(next, host, Conversation(id)))
            // When history overflows its budget (or the cap), fold the
            // evicted tail into the rolling summary for next time.
            if needs_compression(conversation, plan.evicted.length()) {
              let marker = conversation.appended()
              let source = compression_source(conversation)
              let (summary_system, summary_user) = summarize_prompt(
                character_name=character_name(next.scenario, id),
                prior_summary=conversation.summary(),
                source_lines=source,
              )
              let summary_request = LlmRequest::single_shot(
                character_id=id,
                endpoint=next.config.endpoint(),
                api_key=next.config.api_key(),
                model=next.config.model(),
                temperature=next.config.temperature(),
                system=summary_system,
                user=summary_user,
              )
              effects.push(
                @moui.Effect::run(
                  key="new-world:compress",
                  kind="provider",
                  label="Compress memory",
                  run=dispatch => {
                    runner(
                      summary_request,
                      reply => {
                      dispatch(SummaryArrived(id, marker, reply))
                    },
                      _delta => (),
                    )
                  },
                ),
              )
            }
            (next, pack_effects(effects))
          } else {
            // No key: the world still answers, deterministically. The turn
            // completes inside this update, so nothing can dangle.
            append_reply(next, id, scripted_reply(next.scenario, card, trimmed))
            next.push_log(
              "（本地剧本）\{character_name(next.scenario, id)} 已回应",
            )
            (next, commit_effect(next, host, Conversation(id)))
          }
        }
      }
  }
}

///|
/// Can a reply addressed to this key still be stored?
///
/// The player can delete a character, or leave a scene, while a turn is in
/// flight. `ConversationBook::for_character` hands back a fresh `Conversation`
/// for an unknown id, so appending then would create a ghost conversation and
/// commit it as an orphan file that the loader later discards.
pub fn reply_target_exists(model : WorldModel, key : String) -> Bool {
  if is_scene_key(key) {
    return true
  }
  model.scenario.character(key) is Some(_)
}

///|
/// Drop a reply that arrived after its target disappeared, and say so.
pub fn drop_late_reply(
  model : WorldModel,
  notice : String,
) -> (WorldModel, @moui.Effect[Msg]) {
  let next = model.fork()
  next.push_log(notice)
  (next, @moui.Effect::none())
}
