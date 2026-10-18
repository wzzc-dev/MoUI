///|
/// The view: a product built around the conversation.
///
/// Three stages, left to right: the **library** (which world, who lives in
/// it), the **stage** (the world itself and the conversation — the main
/// surface), and the **controls** (model settings, AI world generation, and
/// the event log). Every empty state tells the player what to do next, and
/// every in-flight operation has a visible pending state. All state comes from
/// the model; the view only declares controls and maps their typed messages.
/// Panning is transient view state driven by a drag modifier, so scrolling
/// never enters the model and never gets persisted.

///|
/// Package-wide `using` for the shared view/paint vocabulary. `render.mbt`
/// and this file both draw and both compose controls, so the names are
/// introduced once here instead of duplicated per file.
using @views {
  type PaintContext,
  button,
  canvas,
  card,
  center,
  choice_item,
  chip,
  column,
  draw_text,
  expanded,
  flexible,
  padding_edges,
  fill_rounded_rect,
  image,
  pop_clip,
  push_clip,
  row,
  scroll_view,
  segmented_control,
  spacer,
  stroke_rounded_rect,
  text,
  text_area,
  text_field,
}

///|
/// Scenario map logical size.
pub let map_canvas_width : Double = 500.0

///|
pub let map_canvas_height : Double = 330.0

///|
/// Column widths of the three-stage layout.
pub let rail_width : Double = 310.0

///|
pub let stage_width : Double = 520.0

///|
pub let controls_width : Double = 330.0

///|
/// Total width of the centered content block: the three rails plus the two
/// 20px gutters between them. The header row is sized to the same total, so
/// both wrap into one visually centered column at any window width.
pub let content_width : Double = rail_width +
  stage_width +
  controls_width +
  40.0

///|
/// Pan offset kept out of the app model: it is transient view state driven by
/// the drag modifier, so it cannot leak into persistence or replay.
priv struct PanState {
  origin : @geometry.Point
}

///|
let pan_state : Ref[PanState] = Ref({
  origin: @geometry.Point::new(x=0.0, y=0.0),
})

///|
fn pan_origin() -> @geometry.Point {
  pan_state.val.origin
}

///|
/// Clamp panning so the map cannot be dragged entirely off-screen.
fn clamp_origin(point : @geometry.Point, model : WorldModel) -> @geometry.Point {
  let max_x = model.scenario.map_width() - map_canvas_width
  let max_y = model.scenario.map_height() - map_canvas_height
  let x = if max_x <= 0.0 { 0.0 } else { clamp(point.x, 0.0, max_x) }
  let y = if max_y <= 0.0 { 0.0 } else { clamp(point.y, 0.0, max_y) }
  @geometry.Point::new(x~, y~)
}

///|
fn clamp(value : Double, low : Double, high : Double) -> Double {
  if value < low {
    low
  } else if value > high {
    high
  } else {
    value
  }
}

///|
/// Paragraph-shaped content: the framework's `text(wrap=true)` owns breaking —
/// real text-system metrics, CJK/grapheme-safe points, `\n` hard breaks — so
/// the requested width is the line width and the box grows downward with the
/// line count, composing with the surrounding `scroll_view`s. The old
/// app-side `wrap_text` estimator is deleted.
fn wrapped_body(content : String, width~ : Double) -> @moui.View[Msg] {
  text(content, role=Body, width~, height=22.0, align=TextStart, wrap=true)
}

///|
fn wrapped_caption(content : String, width~ : Double) -> @moui.View[Msg] {
  text(content, role=Caption, width~, height=18.0, align=TextStart, wrap=true)
}

///|
/// A character's avatar: the portrait when the world ships one, otherwise the
/// deterministic colour block with the name's first character. Two shapes are
/// all the product needs (a list avatar and a stage portrait), so the helper
/// takes a size and a corner radius instead of a style enum.
fn avatar(
  model : WorldModel,
  card : CharacterCard,
  size~ : Double,
  radius? : Double = 0.0,
) -> @moui.View[Msg] {
  let uri = model.portrait_for(card)
  if uri != "" {
    // `fit=Cover` keeps a tall portrait from letterboxing inside a square.
    // A screen reader reaches the roster and the stage as a list of faces;
    // without a label the portrait is an unnameable image, so the character's
    // name is the only thing that survives.
    image(
      uri,
      width=size,
      height=size,
      fit=Cover,
      corner_radius=radius,
      accessibility_label=card.name() + " 的立绘",
    )
  } else {
    // No portrait: the colour is derived from the name, so a world without art
    // still reads as people rather than identical placeholders.
    column(
      [
        text(
          first_grapheme(card.name()),
          role=Title,
          width=size,
          height=size,
          align=TextCenter,
        ),
      ],
      justify=Center,
    )
    .frame(width=size, height=size)
    .background(card.color())
    .corner_radius(radius)
  }
}

///|
/// The first visible character of a name, for the no-portrait fallback.
fn first_grapheme(name : String) -> String {
  for ch in name {
    return ch.to_string()
  }
  "?"
}

///|
/// The draggable scenario map.
fn scenario_map(model : WorldModel) -> @moui.View[Msg] {
  let scenario = model.scenario
  let surface = canvas(
    measure=fn(_constraints : @geometry.Constraints) -> @geometry.Size {
      { width: map_canvas_width, height: map_canvas_height, }
    },
    draw=fn(ctx : PaintContext, frame : @geometry.Rect) -> Unit {
      draw_scenario(ctx, frame, scenario, pan_origin(), model.selected)
    },
    semantics_label="Scenario map",
  )
  let dragged = surface.on_drag(event => {
    let next = @geometry.Point::new(
      x=pan_state.val.origin.x - event.delta.x,
      y=pan_state.val.origin.y - event.delta.y,
    )
    pan_state.val = { origin: clamp_origin(next, model), }
    // Panning is a repaint, not a selection change: dispatching `Select` here
    // re-selected the same character on every drag frame (harmlessly after the
    // id guard, but the intent was wrong and it used to clear the draft).
    PanMap
  })
  dragged.on_tap_with_frame((position, frame) => {
    let point = @geometry.Point::new(
      x=position.x - frame.origin.x,
      y=position.y - frame.origin.y,
    )
    // A tap on a person opens their private chat; a tap on a place enters that
    // place's scene. That is what makes the map carry meaning instead of being
    // decoration next to the roster.
    match character_at(scenario, pan_origin(), point) {
      Some(id) => Select(Some(id))
      None =>
        match location_at(scenario, pan_origin(), point) {
          Some(location) => EnterScene(location)
          None => PanMap
        }
    }
  })
}

///|
/// App header: which world is on stage, and where replies come from.
fn header(model : WorldModel) -> @moui.View[Msg] {
  let source = if model.config.llm_enabled() {
    "模型回复已启用"
  } else {
    "本地剧本回复（未配置 key）"
  }
  let world = match model.current {
    Some(folder) => "「\{folder}」"
    None => "未选择世界"
  }
  column(
    [
      row(
        [
          text("AI 世界", role=Title, width=180.0, height=34.0),
          button("⚙ 设置", on_click=OpenSettings, width=92.0, height=30.0),
          text(
            "\{world} · \{source}",
            role=Caption,
            // Header tracks the centered content block exactly: 180 title +
            // 92 button + two 8px gutters leaves this width, so the right
            // edge of the caption lines up with the controls rail.
            width=content_width - 180.0 - 92.0 - 16.0,
            height=30.0,
            align=TextEnd,
          ),
        ],
        spacing=8.0,
        justify=Center,
      ),
    ],
    spacing=4.0,
  )
}

///|
/// Left rail: the world library and the roster.
fn world_rail(model : WorldModel) -> @moui.View[Msg] {
  if model.creator_open {
    column(
      [
        text(
          "设定人物",
          role=Body,
          width=rail_width,
          height=26.0,
          align=TextStart,
        ),
        creator_form(model),
      ],
      spacing=8.0,
    )
  } else {
    column([world_library(model), roster_section(model)], spacing=18.0)
  }
}

///|
/// The world library: new-world composer plus the folder list.
fn world_library(model : WorldModel) -> @moui.View[Msg] {
  let entries : Array[@moui.View[Msg]] = []
  for name in model.worlds() {
    entries.push(
      chip(
        name,
        selected=match model.current {
          Some(current) => current == name
          None => false
        },
        on_click=Some(OpenWorld(name)),
        width=rail_width - 12.0,
      ),
    )
  }
  let list : @moui.View[Msg] = if entries.is_empty() {
    text(
      if model.library_missing() {
        "还没有世界库。点「选择世界库」选一个文件夹，世界会从子文件夹读取。"
      } else {
        "库里还没有世界——给它起个名字，然后点「新建」。"
      },
      role=Caption,
      width=rail_width,
      height=48.0,
      align=TextStart,
    )
  } else {
    scroll_view(
      column(entries, spacing=6.0),
      width=rail_width - 8.0,
      height=(entries.length().to_double() * 36.0).min(150.0),
    )
  }
  column(
    [
      row(
        [
          text("世界", role=Body, width=90.0, height=26.0, align=TextStart),
          button(
            "刷新",
            on_click=SyncLibrary,
            variant=Tonal,
            width=64.0,
            height=26.0,
          ),
          button(
            "选择世界库",
            on_click=PickWorldRoot,
            variant=Tonal,
            width=112.0,
            height=26.0,
          ),
        ],
        spacing=6.0,
      ),
      row(
        [
          text_field(
            model.world_name(),
            on_input=value => WorldNameChanged(value),
            placeholder="新世界的名字…",
            width=rail_width - 76.0,
            height=30.0,
          ),
          button("新建", on_click=NewWorld, width=64.0, height=30.0),
        ],
        spacing=6.0,
      ),
      list,
      // Portability lives next to the library, not buried in settings: a world
      // is a folder, so send/receive is a first-class action on the world.
      row(
        [
          button(
            "导出世界",
            on_click=ExportWorld,
            variant=Tonal,
            width=130.0,
            height=26.0,
          ),
          button(
            "导入",
            on_click=ImportWorld,
            variant=Tonal,
            width=130.0,
            height=26.0,
          ),
        ],
        spacing=6.0,
      ),
    ],
    spacing=6.0,
  )
}

///|
/// The roster and the creator entry.
fn roster_section(model : WorldModel) -> @moui.View[Msg] {
  let rows : Array[@moui.View[Msg]] = []
  for card in model.scenario.characters() {
    let selected = model.selected is Some(id) && id == card.id()
    // The avatar is the only place a portrait shows in the roster: a 32px
    // square reads at a glance and keeps the rail narrow.
    rows.push(
      row(
        [
          avatar(model, card, size=30.0, radius=15.0),
          chip(
            card.name(),
            selected~,
            on_click=Some(Select(Some(card.id()))),
            width=rail_width - 56.0,
          ),
        ],
        spacing=8.0,
      ),
    )
    // Branches of this character, indented under it. Without this list a
    // branch is a dead end: the conversation exists on disk but the player has
    // no way back to it after selecting something else.
    let branches : Array[(Int, Int)] = []
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
          width=rail_width - 32.0,
        ),
      )
    }
  }
  let roster : @moui.View[Msg] = if rows.is_empty() {
    wrapped_caption(
      "这个世界还没有人。点「+ 设定人物」，让第一个角色进入世界。",
      width=rail_width,
    )
  } else {
    scroll_view(
      column(rows, spacing=6.0),
      width=rail_width - 8.0,
      height=(rows.length().to_double() * 40.0).min(160.0),
    )
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
          on_click=Some(EnterScene(place.id())),
          width=rail_width - 12.0,
        ),
      )
    }
  }
  column(
    [
      row(
        [
          text("人物", role=Body, width=160.0, height=26.0, align=TextStart),
          button(
            "+ 设定人物",
            on_click=ToggleCreator,
            width=118.0,
            height=26.0,
          ),
        ],
        spacing=6.0,
      ),
      roster,
      if scenes.is_empty() {
        wrapped_caption(
          "同一个地点有 2 个以上角色时会在这里出现「场景」，点进去就能让多人同场对话。",
          width=rail_width,
        )
      } else {
        column(scenes, spacing=6.0)
      },
    ],
    spacing=6.0,
  )
}

///|
/// The character creator form. Only 人设 is required to make a card talk.
fn creator_form(model : WorldModel) -> @moui.View[Msg] {
  let draft = model.creator_draft()
  let wide = rail_width - 4.0
  // The wizard has two on-ramps, because there are two kinds of stuck:
  // "I don't know what to make" (archetypes) and "I know, but writing six
  // fields is tedious" (one-line idea → drafted card).
  let archetype_buttons : Array[@moui.View[Msg]] = []
  for index, archetype in creator_archetypes() {
    archetype_buttons.push(
      button(
        archetype.label,
        on_click=UseArchetype(index),
        variant=Tonal,
        width=70.0,
        height=24.0,
      ),
    )
  }
  column(
    [
      wrapped_caption("从模板开始：", width=wide),
      row(archetype_buttons, spacing=6.0),
      row(
        [
          text_field(
            model.character_idea(),
            on_input=value => CharacterIdeaChanged(value),
            placeholder="或一句话描述…",
            width=wide - 82.0,
            height=30.0,
          ),
          button(
            "起草",
            on_click=DraftCharacter,
            variant=Tonal,
            width=76.0,
            height=30.0,
          ),
        ],
        spacing=6.0,
      ),
      text_field(
        draft.name,
        on_input=value => CreatorChanged(draft.with_name(value)),
        placeholder="名字（例如：当铺掌柜）",
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
        draft.appearance,
        on_input=value => CreatorChanged(draft.with_appearance(value)),
        placeholder="外貌（可选）",
        width=wide,
      ),
      text_field(
        draft.goal,
        on_input=value => CreatorChanged(draft.with_goal(value)),
        placeholder="目标（可选）",
        width=wide,
      ),
      text_field(
        draft.secret,
        on_input=value => CreatorChanged(draft.with_secret(value)),
        placeholder="秘密（可选，模型不会主动说出）",
        width=wide,
      ),
      row(
        [
          button("创建角色", on_click=CharacterCreated, width=120.0),
          button("取消", on_click=ToggleCreator, variant=Tonal, width=80.0),
        ],
        spacing=8.0,
      ),
    ],
    spacing=8.0,
  )
}

///|
/// The stage: world description, map, and the conversation. The map and the
/// transcript are flexible so a short window shrinks them instead of clipping
/// the composer off the bottom edge.
fn conversation_stage(model : WorldModel) -> @moui.View[Msg] {
  column(
    [
      row(
        [
          text(
            model.scenario.name(),
            role=Body,
            width=stage_width - 92.0,
            height=26.0,
            align=TextStart,
          ),
          // The selected character's portrait on stage: the conversation is
          // with *someone*, and a face makes that concrete.
          match model.selected {
            Some(id) =>
              match model.scenario.character(id) {
                Some(card) => avatar(model, card, size=40.0, radius=20.0)
                None => text("", width=40.0, height=26.0)
              }
            None => text("", width=40.0, height=26.0)
          },
        ],
        spacing=8.0,
        align=Center,
      ),
      text(
        // The portrait prompt of the character on stage rides here: it is
        // only useful if the player can see and copy it.
        {
          let hint = match model.selected {
            Some(id) =>
              match model.scenario.character(id) {
                Some(card) => portrait_prompt_hint(card)
                None => ""
              }
            None => ""
          }
          if hint != "" {
            hint
          } else {
            scenario_blurb(model)
          }
        },
        role=Caption,
        width=stage_width,
        height=34.0,
        align=TextStart,
      ),
      flexible(scenario_map(model), weight=1.0),
      flexible(conversation_panel(model), weight=1.0),
    ],
    spacing=8.0,
  )
}

///|

///|
/// The portrait prompt a generated world left for this character, phrased as
/// something the player can act on.
///
/// The app deliberately never calls an image API, so the value of generating a
/// prompt is entirely in making it *visible and copyable*. Empty for
/// hand-written cards and for characters that already have a portrait file.
fn portrait_prompt_hint(card : CharacterCard) -> String {
  if card.portrait() != "" || card.portrait_prompt() == "" {
    return ""
  }
  "立绘提示词（拿去生图后存为 characters/\{card.name()}.png）：\{card.portrait_prompt()}"
}

///|
fn scenario_blurb(model : WorldModel) -> String {
  let nudge = world_nudge(model.scenario)
  if nudge != "" {
    nudge
  } else {
    "拖动平移 · 点选角色 · \{model.scenario.characters().length()} 个角色，\{model.scenario.world_book().length()} 条世界设定"
  }
}

///|
/// A one-line note about the world-book entries the player's last turn pulled
/// in, or `""` when nothing matched. This is the visible half of the injection
/// contract that `context.mbt` implements: the prompt already carries the lore,
/// so the UI has to say so rather than letting a character "just know".
fn lore_hint(scenario : Scenario, conversation : Conversation) -> String {
  let lines = conversation.lines()
  if lines.is_empty() {
    return ""
  }
  // The freshest player line is the one whose lore is still relevant.
  let mut player_text = ""
  let mut index = lines.length()
  while index > 0 {
    index -= 1
    match lines[index].speaker() {
      Player => {
        player_text = lines[index].text()
        break
      }
      Character(_) => ()
    }
  }
  if player_text == "" {
    return ""
  }
  // Same selector the prompt uses, so the panel cannot disagree with what the
  // model was actually given.
  lore_summary(select_lore(scenario, player_text, "", lines.length()))
}

///|
/// Right rail: AI world generation and the event log. Model configuration
/// lives on the settings page (⚙ 设置) alone.
fn controls_rail(model : WorldModel) -> @moui.View[Msg] {
  let sections : Array[@moui.View[Msg]] = [generation_panel(model)]
  if !model.memory_drafts().is_empty() {
    sections.push(memory_panel(model))
  }
  sections.push(
    column(
      [
        row(
          [
            text("事件", role=Body, width=120.0, height=24.0, align=TextStart),
            // Explicit time advance: a provider call costs money, so the world
            // never moves on its own — the player decides when to skip ahead.
            button(
              "推进时间",
              on_click=AdvanceTime,
              variant=Tonal,
              width=92.0,
              height=24.0,
            ),
          ],
          spacing=6.0,
        ),
        log_panel(model),
      ],
      spacing=6.0,
    ),
  )
  column(sections, spacing=16.0)
}

///|
/// Provider-proposed long-term memories, awaiting the player's decision.
/// Nothing reaches the world book without an explicit accept.
fn memory_panel(model : WorldModel) -> @moui.View[Msg] {
  let rows : Array[@moui.View[Msg]] = []
  for index, entry in model.memory_drafts() {
    rows.push(
      row(
        [
          wrapped_caption(
            "- \{entry.keys().join(" | ")}: \{entry.content()}",
            width=controls_width - 152.0,
          ),
          button(
            "采纳",
            on_click=AcceptMemory(index),
            width=64.0,
            height=26.0,
          ),
          button(
            "忽略",
            on_click=DiscardMemory(index),
            variant=Tonal,
            width=64.0,
            height=26.0,
          ),
        ],
        spacing=6.0,
      ),
    )
  }
  column(
    [
      text(
        "记忆草稿",
        role=Body,
        width=controls_width,
        height=24.0,
        align=TextStart,
      ),
    ] +
    rows,
    spacing=6.0,
  )
}

///|
/// One-line idea → a whole world folder's content.
fn generation_panel(model : WorldModel) -> @moui.View[Msg] {
  column(
    [
      text(
        "AI 生成世界",
        role=Body,
        width=controls_width,
        height=24.0,
        align=TextStart,
      ),
      text_field(
        model.idea(),
        on_input=value => WorldIdeaChanged(value),
        placeholder="一句话设定，例如：雨夜江南小镇的当铺",
        width=controls_width - 4.0,
        height=30.0,
      ),
      row(
        [
          button(
            "生成世界",
            on_click=GenerateWorld,
            width=104.0,
            height=28.0,
          ),
          text(
            if model.generating() {
              "正在生成…请稍候"
            } else {
              ""
            },
            role=Caption,
            width=controls_width - 120.0,
            height=24.0,
            align=TextStart,
          ),
        ],
        spacing=6.0,
      ),
      wrapped_caption(
        "生成会写入当前世界文件夹；没有打开世界时会新建一个。",
        width=controls_width - 4.0,
      ),
    ],
    spacing=6.0,
  )
}

///|
/// The event log, newest first.
fn log_panel(model : WorldModel) -> @moui.View[Msg] {
  let lines : Array[@moui.View[Msg]] = []
  if model.log().is_empty() {
    lines.push(
      text(
        "还没有事件。",
        role=Caption,
        width=controls_width - 8.0,
        height=20.0,
        align=TextStart,
      ),
    )
  }
  for entry in model.log() {
    // Full wrap: the log already lives in a fixed-height scroll_view, so a
    // long entry scrolls instead of needing a truncated estimate.
    lines.push(wrapped_caption(entry, width=controls_width - 8.0))
  }
  scroll_view(
    column(lines, spacing=2.0),
    width=controls_width - 8.0,
    height=168.0,
  )
}

///|
pub fn view(model : WorldModel) -> @moui.View[Msg] {
  match model.page() {
    Settings => settings_view(model)
    Main => main_view(model)
  }
}

///|
/// The settings page: model configuration, persisted as `config.json` at the
/// library root next to the world folders.
///
/// The card is taller than a short window, so it scrolls rather than clipping
/// the save / back buttons off the bottom edge (the main view handles the same
/// problem by making the map and transcript flexible).
fn settings_view(model : WorldModel) -> @moui.View[Msg] {
  let config = model.config
  let wide = 520.0
  center(
    card(
      scroll_view(
        column(
          [
            text(
              "模型与设置",
              role=Title,
              width=wide,
              height=36.0,
              align=TextStart,
            ),
            wrapped_caption(
              "设置保存在世界库根目录的 config.json 里，随你的世界一起走；API key 存在你自己选择的数据文件夹中。",
              width=wide,
            ),
            text(
              "OpenAI 兼容端点",
              role=Body,
              width=wide,
              height=24.0,
              align=TextStart,
            ),
            text_field(
              config.endpoint(),
              on_input=value => EndpointChanged(value),
              placeholder="https://api.openai.com/v1",
              width=wide,
              height=32.0,
            ),
            text(
              "模型名",
              role=Body,
              width=wide,
              height=24.0,
              align=TextStart,
            ),
            text_field(
              config.model(),
              on_input=value => ModelChanged(value),
              placeholder="例如 glm-5.3-flash / gpt-4o-mini",
              width=wide,
              height=32.0,
            ),
            text("API key", role=Body, width=wide, height=24.0, align=TextStart),
            // While hidden the key is a *read-only* mask: an editable masked
            // field would feed `••••` back through `on_input` and store it as the
            // key. `@views.password_field` has the same shape (it masks the value
            // it passes to `on_input`), so a plain field plus an explicit reveal
            // is both correct and simpler. Editing is only possible when shown.
            if model.api_key_revealed() {
              row(
                [
                  text_field(
                    config.api_key(),
                    on_input=value => ApiKeyChanged(value),
                    placeholder="sk-…",
                    width=wide - 76.0,
                    height=32.0,
                  ),
                  button(
                    "隐藏",
                    on_click=ToggleApiKeyReveal,
                    variant=Tonal,
                    width=68.0,
                    height=32.0,
                  ),
                ],
                spacing=8.0,
              )
            } else {
              row(
                [
                  text(
                    if config.api_key() == "" {
                      "（未填写）"
                    } else {
                      "••••••••（已保存到本次会话）"
                    },
                    role=Body,
                    width=wide - 76.0,
                    height=32.0,
                    align=TextStart,
                  ),
                  button(
                    if config.api_key() == "" {
                      "填写"
                    } else {
                      "显示/修改"
                    },
                    on_click=ToggleApiKeyReveal,
                    variant=Tonal,
                    width=68.0,
                    height=32.0,
                  ),
                ],
                spacing=8.0,
              )
            },
            wrapped_caption(
              "key 只存在本次会话的内存里，不会写进 config.json（那个文件会随世界库被备份或分享）。重新打开应用后需要再填一次。",
              width=wide,
            ),
            text(
              "温度（创造性，0.1 – 1.0）",
              role=Body,
              width=wide,
              height=24.0,
              align=TextStart,
            ),
            text_field(
              config.temperature().to_string(),
              on_input=value => TemperatureChanged(value),
              placeholder="0.7",
              width=wide,
              height=32.0,
            ),
            text(
              "上下文规模",
              role=Body,
              width=wide,
              height=24.0,
              align=TextStart,
            ),
            segmented_control(
              [
                choice_item("compact", "紧凑"),
                choice_item("standard", "标准"),
                choice_item("roomy", "宽裕"),
              ],
              selected=config.context_preset(),
              on_select=value => ContextChanged(value),
              width=wide,
              size=Compact,
            ),
            wrapped_caption(
              "紧凑≈3000字 · 标准≈6000字 · 宽裕≈12000字;影响历史保留量与记忆压缩频率。",
              width=wide,
            ),
            row(
              [
                button(
                  "保存设置",
                  on_click=SaveConfig,
                  width=120.0,
                  height=34.0,
                ),
                button(
                  "返回世界",
                  on_click=CloseSettings,
                  variant=Tonal,
                  width=120.0,
                  height=34.0,
                ),
              ],
              spacing=12.0,
            ),
            text(
              if config.llm_enabled() {
                "当前：回复与 AI 生成来自模型（改动保存后生效）"
              } else {
                "当前：未配置完整（缺 key/端点/模型），对话走本地剧本"
              },
              role=Caption,
              width=wide,
              height=24.0,
              align=TextStart,
            ),
          ],
          spacing=10.0,
        ),
        width=wide,
      ),
      width=620.0,
      padding=26.0,
    ),
  )
}

///|
/// Full-viewport workbench layout: the header is fixed and the three-column
/// row takes the remaining height (`expanded`), so short windows shrink the
/// flexible map/transcript instead of clipping the composer off the bottom.
/// The row centers its fixed-width columns horizontally, and the header row
/// totals the same `content_width`, so the whole product reads as one
/// centered block.
fn main_view(model : WorldModel) -> @moui.View[Msg] {
  padding_edges(
    column(
      [
        header(model),
        expanded(
          row(
            [world_rail(model), conversation_stage(model), controls_rail(model)],
            spacing=20.0,
            justify=Center,
          ),
          weight=1.0,
        ),
      ],
      spacing=14.0,
    ),
    top=16.0,
    right=22.0,
    bottom=16.0,
    left=22.0,
  )
}
