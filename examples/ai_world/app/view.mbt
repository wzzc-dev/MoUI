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
  password_field,
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
    Select(model.selected)
  })
  dragged.on_tap_with_frame((position, frame) => {
    let point = @geometry.Point::new(
      x=position.x - frame.origin.x,
      y=position.y - frame.origin.y,
    )
    Select(character_at(scenario, pan_origin(), point))
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
    rows.push(
      chip(
        card.name(),
        selected~,
        on_click=Some(Select(Some(card.id()))),
        width=rail_width - 12.0,
      ),
    )
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
      height=(rows.length().to_double() * 36.0).min(140.0),
    )
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
    ],
    spacing=6.0,
  )
}

///|
/// The character creator form. Only 人设 is required to make a card talk.
fn creator_form(model : WorldModel) -> @moui.View[Msg] {
  let draft = model.creator_draft()
  let wide = rail_width - 4.0
  column(
    [
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
      text(
        model.scenario.name(),
        role=Body,
        width=stage_width,
        height=26.0,
        align=TextStart,
      ),
      text(
        scenario_blurb(model),
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
fn scenario_blurb(model : WorldModel) -> String {
  let nudge = world_nudge(model.scenario)
  if nudge != "" {
    nudge
  } else {
    "拖动平移 · 点选角色 · \{model.scenario.characters().length()} 个角色，\{model.scenario.world_book().length()} 条世界设定"
  }
}

///|
/// The conversation with the selected character: scrollable transcript plus
/// composer.
fn conversation_panel(model : WorldModel) -> @moui.View[Msg] {
  match model.selected {
    None =>
      column(
        [
          text(
            "点选地图上的角色，或在左侧名单里选一个，开始对话。",
            role=Caption,
            width=stage_width,
            height=24.0,
            align=TextStart,
          ),
          // The spring keeps the composer pinned to the bottom edge even
          // while no conversation is on stage.
          spacer(weight=1.0),
          composer(model, enabled=false),
        ],
        spacing=6.0,
      )
    Some(id) =>
      match model.scenario.character(id) {
        None =>
          column(
            [
              text(
                "这个角色已不在当前世界里。重新选一个角色吧。",
                role=Caption,
                width=stage_width,
                height=24.0,
                align=TextStart,
              ),
              spacer(weight=1.0),
              composer(model, enabled=false),
            ],
            spacing=6.0,
          )
        Some(card) => {
          let conversation = model.conversations.for_character(id)
          let transcript : Array[@moui.View[Msg]] = []
          if conversation.lines().is_empty() {
            transcript.push(
              wrapped_caption(
                "和\{card.name()}说点什么吧。TA 记得这个世界的背景，也可能藏着秘密。",
                width=stage_width,
              ),
            )
          }
          for line in conversation.lines() {
            let prefix = match line.speaker() {
              Player => "你"
              Character(_) => card.name()
            }
            transcript.push(
              wrapped_body("\{prefix}：\{line.text()}", width=stage_width),
            )
          }
          if conversation.pending() {
            transcript.push(
              text(
                "\{card.name()} 正在斟酌…",
                role=Caption,
                width=stage_width,
                height=20.0,
                align=TextStart,
              ),
            )
          }
          column(
            [
              // The transcript absorbs all slack above the composer, so the
              // composer stays pinned to the bottom edge at every transcript
              // length instead of riding right under the last message.
              flexible(
                scroll_view(column(transcript, spacing=6.0), width=stage_width),
                weight=1.0,
              ),
              composer(model, enabled=true),
            ],
            spacing=6.0,
          )
        }
      }
  }
}

///|
fn composer(model : WorldModel, enabled? : Bool = true) -> @moui.View[Msg] {
  if enabled {
    column(
      [
        text_area(
          model.draft(),
          on_input=value => DraftChanged(value),
          placeholder="说点什么…（回车发送）",
          lines=2,
          width=stage_width,
          on_submit=Some(Send(model.draft())),
        ),
        row(
          [
            button("发送", on_click=Send(model.draft()), width=88.0),
            button(
              "换一个角色",
              on_click=Select(None),
              variant=Tonal,
              width=112.0,
            ),
          ],
          spacing=8.0,
        ),
      ],
      spacing=6.0,
    )
  } else {
    text_area(
      model.draft(),
      on_input=value => DraftChanged(value),
      placeholder="（先选择一个角色）",
      lines=2,
      width=stage_width,
    )
  }
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
        text(
          "事件",
          role=Body,
          width=controls_width,
          height=24.0,
          align=TextStart,
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
fn settings_view(model : WorldModel) -> @moui.View[Msg] {
  let config = model.config
  let wide = 520.0
  center(
    card(
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
          text("模型名", role=Body, width=wide, height=24.0, align=TextStart),
          text_field(
            config.model(),
            on_input=value => ModelChanged(value),
            placeholder="例如 glm-5.3-flash / gpt-4o-mini",
            width=wide,
            height=32.0,
          ),
          text("API key", role=Body, width=wide, height=24.0, align=TextStart),
          password_field(
            config.api_key(),
            on_input=value => ApiKeyChanged(value),
            revealed=false,
            on_toggle_reveal=ApiKeyChanged(config.api_key()),
            placeholder="sk-…",
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
