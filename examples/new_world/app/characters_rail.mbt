///|
/// The character rail: who you have been talking to, and the way to someone
/// new.
///
/// The rail is the product's front door. 最近角色 lists the characters with a
/// live conversation (each with its branches underneath, so a divergent story
/// is one click away); 其他角色 lists the rest of the world's cast; 场景 lists
/// the places where several of them are present. The creator form lives here
/// too, because "+ 设定人物" is the rail's primary action.
///
/// On medium and compact layouts the rail is not beside the stage — it is a
/// toggleable column or a full-screen overlay, opened from the scene header's
/// 角色 button (`ToggleRail`).

///|
/// The rail: the roster (or the creator form while it is open).
fn characters_rail(model : WorldModel, width : Double) -> @moui.View[Msg] {
  if model.creator_open {
    creator_form(model, width)
  } else {
    roster_section(model, width)
  }
}

///|
/// Split the cast into "recent" (a live conversation) and "other", list the
/// branches under each recent character, and offer the scenes.
fn roster_section(model : WorldModel, width : Double) -> @moui.View[Msg] {
  let recent : Array[CharacterCard] = []
  let others : Array[CharacterCard] = []
  for card in model.scenario.characters() {
    let conversation = model.conversations.for_character(card.id())
    if !conversation.lines().is_empty() {
      recent.push(card)
    } else {
      others.push(card)
    }
  }
  let rows : Array[@moui.View[Msg]] = []
  rows.push(
    section_header(
      "最近角色",
      width~,
      action=button(
        "＋ 设定人物",
        on_click=ToggleCreator,
        variant=Tonal,
        width=120.0,
        height=button_md_height,
      ),
      action_width=120.0,
    ),
  )
  if recent.is_empty() {
    rows.push(
      wrapped_caption(
        "还没有开始的演绎。选一个角色，或从模板创建一位。",
        width~,
      ),
    )
  }
  for card in recent {
    let selected = model.selected is Some(id) && id == card.id()
    rows.push(
      row(
        [
          avatar(model, card, size=30.0, radius=15.0),
          chip(
            card.name(),
            selected~,
            on_click=Some(Select(Some(card.id()))),
            theme=app_theme_for(model.config.appearance()),
            width=chip_width(card.name()),
            height=34.0,
          ),
        ],
        spacing=8.0,
        align=Center,
      ),
    )
    // Branches of this character, indented under it. Without this list a
    // branch is a dead end: the conversation exists on disk but the player has
    // no way back to it after selecting something else.
    let branches : Array[(Int32, Int32)] = []
    for conversation in model.conversations.entries {
      match split_branch(conversation.character_id()) {
        Some((base, number)) =>
          if base == card.id() {
            branches.push((number, conversation.lines().length()))
          }
        None => ()
      }
    }
    // Numeric order, independent of insertion order.
    branches.sort_by((left, right) => left.0 - right.0)
    for pair in branches {
      let number = pair.0
      let count = pair.1
      let key = branched_key(card.id(), number)
      rows.push(
        chip(
          "↳ 分支 " +
          number.to_string() +
          "（" +
          count.to_string() +
          " 条）",
          selected=model.selected is Some(id) && id == key,
          on_click=Some(Select(Some(key))),
          theme=app_theme_for(model.config.appearance()),
          width=chip_width("↳ 分支 " + number.to_string()),
          height=30.0,
        ),
      )
    }
  }
  if !others.is_empty() {
    rows.push(section_header("其他角色", width~))
    for card in others {
      rows.push(
        row(
          [
            avatar(model, card, size=30.0, radius=15.0),
            chip(
              card.name(),
              selected=false,
              on_click=Some(Select(Some(card.id()))),
              theme=app_theme_for(model.config.appearance()),
              width=chip_width(card.name()),
              height=34.0,
            ),
          ],
          spacing=8.0,
          align=Center,
        ),
      )
    }
  }
  // Places with people in them become scenes: the map is the spatial view,
  // this is the list view of the same idea.
  let scenes : Array[@moui.View[Msg]] = []
  for place in model.scenario.locations() {
    let cast = cast_at(model.scenario, place.id())
    if cast.length() >= 2 {
      scenes.push(
        chip(
          "场景 · " +
          place.name() +
          "（" +
          cast.length().to_string() +
          "）",
          selected=match model.scene_location() {
            Some(current) => current == place.id()
            None => false
          },
          theme=app_theme_for(model.config.appearance()),
          on_click=Some(EnterScene(place.id())),
          width=width - 12.0,
          height=30.0,
        ),
      )
    }
  }
  if !scenes.is_empty() {
    rows.push(section_header("场景", width~))
    for scene in scenes {
      rows.push(scene)
    }
  }
  // The roster scrolls inside a capped box: a world with twenty characters
  // (and their branches) would otherwise grow the rail past the window and
  // squeeze the stage.
  scroll_view(
    column(rows, spacing=6.0),
    // The rows and the scroll share one width: a narrower scroll clipped the
    // row that carries the 「＋ 设定人物」 button.
    width~,
    height=(rows.length().to_double() * 42.0).min(420.0),
  )
}

///|
/// The character creator form, with two on-ramps: archetypes for "I don't know
/// what to make", and a one-line idea for "I know, but writing every field is
/// tedious". The full six-block editor (`character_editor.mbt`) takes over for
/// editing an existing card; this form creates one.
fn creator_form(model : WorldModel, width : Double) -> @moui.View[Msg] {
  let draft = model.creator_draft()
  let wide = width - 4.0
  let archetype_buttons : Array[@moui.View[Msg]] = []
  for index, archetype in creator_archetypes() {
    archetype_buttons.push(
      button(
        archetype.label,
        on_click=UseArchetype(index),
        variant=Tonal,
        width=64.0,
        height=button_sm_height,
      ),
    )
  }
  column(
    [
      section_header(
        "设定人物",
        width~,
        action=button(
          "关闭",
          on_click=ToggleCreator,
          variant=Ghost,
          width=64.0,
          height=button_sm_height,
        ),
        action_width=64.0,
      ),
      wrapped_caption("从模板开始：", width=wide),
      wrap(archetype_buttons, width~, spacing=6.0, row_spacing=4.0),
      row(
        [
          text_field(
            model.character_idea(),
            on_input=value => CharacterIdeaChanged(value),
            placeholder="或一句话描述…",
            width=wide - 88.0,
            height=button_md_height,
          ),
          button(
            "起草",
            on_click=DraftCharacter,
            variant=Tonal,
            width=80.0,
            height=button_md_height,
          ),
        ],
        spacing=6.0,
      ),
      text_field(
        draft.name,
        on_input=value => CreatorChanged(draft.with_name(value)),
        placeholder="名字（例如：温衍）",
        width=wide,
      ),
      text_area(
        draft.persona,
        on_input=value => CreatorChanged(draft.with_persona(value)),
        placeholder="人设：TA是谁？（必填）",
        lines=3,
        width=wide,
      ),
      text_field(
        draft.voice,
        on_input=value => CreatorChanged(draft.with_voice(value)),
        placeholder="说话方式（例如：简短、爱用反问）",
        width=wide,
      ),
      text_field(
        draft.opening,
        on_input=value => CreatorChanged(draft.with_opening(value)),
        placeholder="开场白（可选）：第一句话，或第一段演绎",
        width=wide,
      ),
      row(
        [
          button(
            "创建角色",
            on_click=CharacterCreated,
            width=120.0,
            height=button_md_height,
          ),
          button(
            "取消",
            on_click=ToggleCreator,
            variant=Tonal,
            width=80.0,
            height=button_md_height,
          ),
        ],
        spacing=8.0,
      ),
    ],
    spacing=8.0,
  )
}
