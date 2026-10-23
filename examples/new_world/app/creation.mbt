///|
/// Creation and generation: the character wizard and AI world generation.
///
/// Split out of `update.mbt` because these arms are one feature (compose or
/// generate something new) and because that file has a line budget it should
/// keep honouring rather than be exempted from.

///|
/// Dispatch the creation/generation arms.
pub fn update_creation(
  model : WorldModel,
  msg : Msg,
  runner : TurnRunner,
  host : WorldHost?,
) -> (WorldModel, @moui.Effect[Msg]) {
  match msg {
    ToggleCreator =>
      (
        {
          ..model,
          creator_open: !model.creator_open,
          creator_draft: CharacterDraft::new(),
        },
        @moui.Effect::none(),
      )
    CreatorChanged(draft) =>
      ({ ..model, creator_draft: draft, }, @moui.Effect::none())
    UseArchetype(index) => {
      let archetypes = creator_archetypes()
      if index < 0 || index >= archetypes.length() {
        (model, @moui.Effect::none())
      } else {
        (
          {
            ..model,
            creator_draft: model.creator_draft.with_archetype(archetypes[index]),
          },
          @moui.Effect::none(),
        )
      }
    }
    CharacterIdeaChanged(value) =>
      ({ ..model, character_idea: value, }, @moui.Effect::none())
    DraftCharacter => {
      let idea : String = model.character_idea.trim().to_owned()
      if idea == "" {
        let next = model.fork()
        next.push_log("先写一句话描述这个角色")
        return (next, @moui.Effect::none())
      }
      if !model.config.llm_enabled() {
        // Offline: seed from an archetype rather than pretending to generate,
        // so the button does something honest without a key.
        let archetypes = creator_archetypes()
        let next = {
          ..model.fork(),
          creator_draft: model.creator_draft.with_archetype(archetypes[0]),
        }
        next.push_log(
          "（无 key）先用「掌柜」模板填好，改成你想要的样子",
        )
        return (next, @moui.Effect::none())
      }
      let (system, user) = character_idea_prompt(idea, model.scenario.name())
      let request = LlmRequest::single_shot(
        character_id="!character",
        endpoint=model.config.endpoint(),
        api_key=model.config.api_key(),
        model=model.config.model(),
        temperature=model.config.temperature(),
        system~,
        user~,
      )
      let next = model.fork()
      next.push_log("正在起草角色…")
      (
        next,
        @moui.Effect::run(
          key="new-world:draft-character",
          kind="provider",
          label="Draft character",
          run=dispatch => {
            runner(request, reply => dispatch(CharacterDrafted(reply)))
          },
        ),
      )
    }
    CharacterDrafted(reply) => {
      let next = model.fork()
      match reply {
        None =>
          next.push_log(
            "起草失败——可以直接手填，或再试一次",
          )
        Some(text) =>
          match parse_generated_character(text) {
            Some(draft) => {
              // Keep anything the player already typed: generation fills gaps
              // rather than overwriting deliberate input.
              let merged = {
                name: if model.creator_draft.name.trim() == "" {
                  draft.name
                } else {
                  model.creator_draft.name
                },
                persona: draft.persona,
                appearance: draft.appearance,
                voice: draft.voice,
                goal: draft.goal,
                secret: draft.secret,
                principles: draft.principles,
                examples: draft.examples,
                portrait: draft.portrait,
                portrait_prompt: draft.portrait_prompt,
                user_identity: draft.user_identity,
                user_name: draft.user_name,
                boundary: draft.boundary,
                setting: draft.setting,
                opening: draft.opening,
                memory_rules: draft.memory_rules,
              }
              let settled = { ..next, creator_draft: merged, }
              settled.push_log(
                "已起草「\{draft.name}」——改完点「创建角色」",
              )
              return (settled, @moui.Effect::none())
            }
            None => next.push_log("模型返回的不是角色卡，已忽略")
          }
      }
      (next, @moui.Effect::none())
    }
    CharacterCreated => {
      let mut name : String = model.creator_draft.name.trim().to_owned()
      if name == "" {
        name = "无名旅人"
      }
      let mut count = 2
      let mut id = name
      while model.scenario.character(id) is Some(_) {
        id = "\{name} (\{count})"
        count += 1
      }
      let card = { ..model.creator_draft, name: id, }.to_card(
        point=first_free_spot(model.scenario),
      )
      let characters : Array[CharacterCard] = []
      for existing in model.scenario.characters() {
        characters.push(existing)
      }
      characters.push(card)
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
        selected: Some(id),
        say_draft: "",
        do_draft: "",
        story_draft: "",
        creator_open: false,
        creator_draft: CharacterDraft::new(),
      }
      next.push_log("\{id} 加入了这个世界")
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
    // ---- AI world generation ----
    WorldIdeaChanged(value) => ({ ..model, idea: value, }, @moui.Effect::none())
    GenerateWorld => {
      let idea : String = model.idea.trim().to_owned()
      if idea == "" {
        let next = model.fork()
        next.push_log(
          "先写一句话设定世界（例如：雨夜江南小镇的当铺）",
        )
        return (next, @moui.Effect::none())
      }
      if model.generating {
        (model, @moui.Effect::none())
      } else if model.config.llm_enabled() {
        let next = { ..model, generating: true, }
        let prompt = world_idea_prompt(idea)
        let request = LlmRequest::single_shot(
          character_id="!world",
          endpoint=next.config.endpoint(),
          api_key=next.config.api_key(),
          model=next.config.model(),
          temperature=next.config.temperature(),
          system=prompt.system,
          user=prompt.user,
        )
        (
          next,
          @moui.Effect::run(
            key="new-world:generate",
            kind="provider",
            label="Generate world",
            run=dispatch => {
              runner(request, reply => dispatch(WorldGenerated(reply)))
            },
          ),
        )
      } else {
        // Offline branch: the idea still becomes a world, deterministically.
        // The folder name is derived from the player's idea, so it is
        // sanitized here too (see `world_folder_name`).
        let world = fallback_world(idea)
        let folder = world_folder_name(world.name())
        let next = {
          ..model.fork(),
          scenario: world,
          current: Some(folder),
          idea: "",
          generating: false,
          worlds: with_world(model.worlds, folder),
          selected: None,
        }
        next.conversations.clear()
        next.push_log(
          "（无 key）本地生成了世界「\{folder}」；配置模型后可让AI重新生成",
        )
        match host {
          Some(h) =>
            (next, commit_world_effect(h, folder, commit_files(next, World)))
          None => (next, @moui.Effect::none())
        }
      }
    }
    WorldGenerated(reply) => {
      // `fork`, not a record update: every branch below pushes a log line, and
      // `{ ..model, }` shares the array, so the notice would be written into the
      // model the caller still holds.
      let next = { ..model.fork(), generating: false, }
      match reply {
        None => {
          next.push_log(
            "AI 生成失败——检查端点与 key，再试一次",
          )
          (next, @moui.Effect::none())
        }
        Some(text) =>
          match extract_json_object(text) {
            None => {
              next.push_log(
                "AI 返回的内容不是可解析的世界 JSON——再试一次或换个说法",
              )
              (next, @moui.Effect::none())
            }
            Some(json) =>
              match Scenario::try_from_json(json) {
                None => {
                  next.push_log(
                    "AI 返回的内容不是可解析的世界 JSON——再试一次或换个说法",
                  )
                  (next, @moui.Effect::none())
                }
                Some(world) => {
                  // The generation lands in the current folder when a world is
                  // open; otherwise it becomes its own new world folder.
                  let folder = match model.current {
                    Some(folder) => folder
                    None => world_folder_name(world.name())
                  }
                  // Keep the world's folder identity stable for future saves.
                  let named = Scenario::new(
                    id=folder,
                    name=world.name(),
                    background=world.background(),
                    map_width=world.map_width(),
                    map_height=world.map_height(),
                    locations=world.locations(),
                    characters=world.characters(),
                    world_book=world.world_book(),
                    mood=world.mood(),
                  )
                  let settled = {
                    ..next.fork(),
                    scenario: named,
                    current: Some(folder),
                    idea: "",
                    worlds: with_world(next.worlds, folder),
                    selected: None,
                  }
                  settled.conversations.clear()
                  settled.push_log(
                    "AI 生成了世界「\{world.name()}」（\{world.characters().length()} 角色）",
                  )
                  match host {
                    Some(h) =>
                      (
                        settled,
                        commit_world_effect(
                          h,
                          folder,
                          commit_files(settled, World),
                        ),
                      )
                    None => (settled, @moui.Effect::none())
                  }
                }
              }
          }
      }
    }
    _ => (model, @moui.Effect::none())
  }
}
