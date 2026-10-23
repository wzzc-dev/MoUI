///|
/// The views: the root, the shared primitives, and the pages that are not the
/// stage.
///
/// The product's center lives in `stage_view.mbt` (the character on stage),
/// `characters_rail.mbt` (who to talk to), `drawers.mbt` and
/// `message_menu.mbt` (the on-demand surfaces). This file owns what is left:
/// the view root — where the theme wraps the tree once and the app-level
/// overlays are declared — plus the small shared primitives (avatar, body
/// text, section headers) and the settings / onboarding pages.
///
/// All state comes from the model; the view only declares controls and maps
/// their typed messages. Panning is transient view state driven by a drag
/// modifier, so scrolling never enters the model and never gets persisted.
///
///| Package-wide `using` for the shared view/paint vocabulary. `render.mbt`,
/// `shell.mbt`, `stage_view.mbt`, `transcript_view.mbt`, `drawers.mbt`, and
/// this file all compose controls, so the names are introduced once here
/// instead of being duplicated per file.
using @views {
  type PaintContext,
  button,
  canvas,
  card,
  center,
  choice_item,
  chip,
  column,
  container,
  empty,
  divider,
  draw_text,
  expanded,
  flexible,
  overlay_host,
  padding_edges,
  fill_rounded_rect,
  image,
  pop_clip,
  popup_host,
  push_clip,
  row,
  scroll_view,
  segmented_control,
  spacer,
  stack,
  stroke_rounded_rect,
  text,
  text_area,
  text_field,
  wrap,
}

///|
/// Clamp a value into `[low, high]`.
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
/// The portrait prompt a generated world left for this character, phrased as
/// something the player can act on.
///
/// The app deliberately never calls an image API, so the value of generating
/// a prompt is entirely in making it *visible and copyable*. Empty for
/// hand-written cards and for characters that already have a portrait file.
fn portrait_prompt_hint(card : CharacterCard) -> String {
  if card.portrait() != "" || card.portrait_prompt() == "" {
    return ""
  }
  "立绘提示词（拿去生图后存为 characters/\{card.name()}.png）：\{card.portrait_prompt()}"
}

///|
/// Paragraph-shaped content: the framework's `text(wrap=true)` owns breaking —
/// real text-system metrics, CJK/grapheme-safe points, `\n` hard breaks — so
/// the requested width is the line width and the box grows downward with the
/// line count, composing with the surrounding `scroll_view`s.
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
/// all the product needs (a rail avatar and a stage portrait), so the helper
/// takes a size and a corner radius instead of a style enum.
fn avatar(
  model : WorldModel,
  card : CharacterCard,
  size~ : Double,
  radius~ : Double = 0.0,
) -> @moui.View[Msg] {
  let uri = model.portrait_for(card)
  if uri != "" {
    // `fit=Cover` keeps a tall portrait from letterboxing inside a square.
    // A screen reader reaches the rail and the stage as a list of faces;
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
/// The width a chip needs for its label.
///
/// A chip's label is centred in the chip, so a chip that spans the whole rail
/// leaves the name floating in the middle of it. The chip takes the room its
/// name needs instead: a CJK glyph is about as wide as the control font is
/// tall, plus the chip's own padding on both sides.
pub fn chip_width(label : String) -> Double {
  label.length().to_double() * 13.0 + 30.0
}

///|
/// The portrait frame: a stable, clean surface for a portrait image.
///
/// A portrait PNG usually has a transparent background. Painted straight onto
/// the page it mixes with whatever sits behind it — the form's own text, the
/// next field, the stage under a translucent overlay — and the picture reads
/// as a hole rather than as a picture. The frame gives that transparency a
/// place to live: its own tint, a hairline edge, rounded corners.
///
/// The frame is the same in the editor (large) and in the profile drawer
/// (small), so the read-only view and the edit view show the character the
/// same way. The drawing keeps its own ratio (`Contain`) inside the frame, so
/// a tall portrait is letterboxed instead of cropped.
fn portrait_frame(
  model : WorldModel,
  card : CharacterCard,
  width : Double,
  height : Double,
  radius~ : Double = 12.0,
) -> @moui.View[Msg] {
  // The frame is the size the caller asked for and the picture *fills* it:
  // `Cover` crops the part that does not fit, and the framework crops from
  // the centre on both sides (a wide picture loses the same length on the
  // left and on the right), so a face never ends up off in one corner.
  let theme = app_theme_for(model.config.appearance())
  let uri = model.portrait_for(card)
  let content = if uri != "" {
    image(
      uri,
      width=width,
      height=height,
      fit=Cover,
      corner_radius=radius,
      accessibility_label=card.name() + " 的立绘",
    )
  } else {
    // No portrait file yet: the character's colour and first character, on the
    // same surface — an empty frame never looks broken.
    column(
      [
        text(
          first_grapheme(card.name()),
          role=Title,
          width=width,
          height=height,
          align=TextCenter,
        ),
      ],
      justify=Center,
    )
  }
  // The hairline is a one-pixel ring of the border colour under the surface,
  // which keeps the frame from needing the framework's border style.
  container(
    container(
      content,
      width=width,
      height=height,
      background=theme.palette.surface_variant,
      corner_radius=radius,
    ),
    width=width + 2.0,
    height=height + 2.0,
    background=theme.palette.outline_variant,
    corner_radius=radius + 1.0,
  )
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
/// The world library: current folder, refresh, picker, new-world composer, and
/// portability. Shown on the onboarding screen and on the settings page — never
/// on the stage, where a character is already talking.
fn library_panel(model : WorldModel, width : Double) -> @moui.View[Msg] {
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
        width=width - 12.0,
        height=34.0,
      ),
    )
  }
  let list : @moui.View[Msg] = if entries.is_empty() {
    wrapped_caption(
      if model.library_missing() {
        "还没有世界库。点「选择世界库」选一个文件夹，世界会从子文件夹读取。"
      } else {
        "库里还没有世界——给它起个名字，然后点「新建」。"
      },
      width=width - 4.0,
    )
  } else {
    scroll_view(
      column(entries, spacing=6.0),
      width=width - 8.0,
      height=(entries.length().to_double() * 38.0).min(180.0),
    )
  }
  column(
    [
      section_header(
        "世界库",
        width~,
        action=button(
          "刷新",
          on_click=SyncLibrary,
          variant=Tonal,
          width=72.0,
          height=button_sm_height,
        ),
      ),
      button(
        "选择世界库…",
        on_click=PickWorldRoot,
        variant=Outline,
        width=width - 4.0,
        height=button_md_height,
      ),
      list,
      row(
        [
          text_field(
            model.world_name(),
            on_input=value => WorldNameChanged(value),
            placeholder="新世界的名字…",
            width=width - 94.0,
            height=button_md_height,
          ),
          button(
            "新建",
            on_click=NewWorld,
            width=84.0,
            height=button_md_height,
          ),
        ],
        spacing=6.0,
      ),
      // Portability lives next to the library, not buried in settings: a world
      // is a folder, so send/receive is a first-class action on the world.
      row(
        [
          button(
            "导出世界",
            on_click=ExportWorld,
            variant=Tonal,
            width=(width - 10.0) / 2.0,
            height=button_md_height,
          ),
          button(
            "导入",
            on_click=ImportWorld,
            variant=Tonal,
            width=(width - 10.0) / 2.0,
            height=button_md_height,
          ),
        ],
        spacing=6.0,
      ),
    ],
    spacing=8.0,
  )
}

///|
/// One-line idea → a whole world folder's content. Onboarding and settings only.
fn generation_panel(model : WorldModel, width : Double) -> @moui.View[Msg] {
  column(
    [
      section_header("AI 生成世界", width~),
      // One row when the field has room; stacked when it does not, because a
      // 108px button next to a shrunken field wraps the placeholder into noise.
      if width > 480.0 {
        row(
          [
            text_field(
              model.idea(),
              on_input=value => WorldIdeaChanged(value),
              placeholder="一句话设定，例如：雨夜江南小镇的当铺",
              width=width - 118.0,
              height=button_md_height,
            ),
            button(
              "生成世界",
              on_click=GenerateWorld,
              width=108.0,
              height=button_md_height,
            ),
          ],
          spacing=8.0,
        )
      } else {
        column(
          [
            text_field(
              model.idea(),
              on_input=value => WorldIdeaChanged(value),
              placeholder="一句话设定，例如：雨夜江南小镇的当铺",
              width=width - 4.0,
              height=button_md_height,
            ),
            button(
              "生成世界",
              on_click=GenerateWorld,
              width=108.0,
              height=button_md_height,
            ),
          ],
          spacing=6.0,
        )
      },
      wrapped_caption(
        if model.generating() {
          "正在生成…请稍候"
        } else {
          "生成会写入当前世界文件夹；没有打开世界时会新建一个。"
        },
        width=width - 4.0,
      ),
    ],
    spacing=6.0,
  )
}

///|
/// The entrypoint the runtime calls: view plus the viewport it was given.
pub fn view(
  model : WorldModel,
  environment : @moui.ViewEnvironment,
) -> @moui.View[Msg] {
  let viewport = environment.viewport_size()
  let screen = Screen::for_viewport(viewport.width, viewport.height)
  view_for(model, screen)
}

///|
/// The view for an explicit screen. Exposed for tests and the plugin frame: both
/// hand over a rectangle rather than a runtime environment.
///
/// Three things happen here, in this order:
///
/// 1. **the window background** — the runtime clears to white, so the
///    appearance's surface is painted by the app itself; otherwise 墨蓝 would
///    show a white window;
/// 2. **the theme** — one `View::theme` re-skins the whole product (panels,
///    drawers, sheets) the frame the appearance field changes. A theme
///    modifier changes colours only; it must not resize the tree, so the
///    framework keeps the subtree's constraints intact;
/// 3. **the app-level overlays** — the side drawer, the full-screen
///    atmosphere view and the character editor are declared as presentations
///    over the app.
///
/// The presentations live in a *sibling* overlay host rather than wrapping
/// the app: an overlay host relaxes its base child's constraints, and the app
/// shell needs those minimums — the shell column hands the rest of the window
/// to its weighted body (the stage), and without a minimum that body
/// measures to zero height and the whole stage collapses.
pub fn view_for(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  let theme = app_theme_for(model.config.appearance())
  let body : @moui.View[Msg] = match model.page() {
    Settings => settings_view(model, screen)
    Main =>
      if model.current is None && !model.creator_open() {
        // No world open: the library manager and AI generation are the page.
        padding_edges(
          column(
            [
              shell_header(model, screen),
              expanded(onboarding_view(model, screen), weight=1.0),
            ],
            spacing=14.0,
          ),
          top=screen.page_padding,
          right=screen.page_padding,
          bottom=screen.page_padding,
          left=screen.page_padding,
        )
      } else {
        main_view(model, screen)
      }
  }
  // The background covers the window: it is a stack sibling painted first,
  // sized to the viewport the app was given. (A container would have been the
  // obvious choice, but a container relaxes its child's minimums — and the
  // shell column needs them to hand its height to the stage.)
  let background = container(
    text("", width=screen.width, height=screen.height),
    width=screen.width,
    height=screen.height,
    background=theme.palette.background,
  )
  let specs : Array[@views.PresentationSpec[Msg]] = []
  for spec in drawer_specs(model, screen) {
    specs.push(spec)
  }
  if model.atmosphere() {
    specs.push(atmosphere_spec(model, screen))
  }
  if model.editor_open() {
    specs.push(character_editor_spec(model, screen))
  }
  // The overlay host's base child is a zero-size placeholder: the host itself
  // fills the viewport and hosts the presentations on top of it.
  let hosted = overlay_host(empty(), specs)
  stack([background, body.theme(theme), hosted])
}

///|
/// A default 1560×1080 screen. Kept so a caller with no viewport (a probe, a
/// printout) still gets a sensible desktop frame; the runtime always uses
/// `view(model, environment)`.
pub fn view_default(model : WorldModel) -> @moui.View[Msg] {
  view_for(model, Screen::for_viewport(1560.0, 1080.0))
}

///|
/// Horizontal padding inside the settings card.
let settings_card_padding : Double = 26.0

///|
/// The settings page: model configuration plus the world-library manager and AI
/// generation, which moved here once a world is open.
///
/// The card is taller than a short window, so it scrolls rather than clipping
/// the save / back buttons off the bottom edge (the stage handles the same
/// problem by making the transcript flexible).
fn settings_view(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  let config = model.config
  // The card's padding is part of the width budget: sizing the inner column to
  // the screen and then adding padding painted the card past the right edge on
  // a phone, which cut off 返回世界 and 填写.
  let available = screen.width - screen.page_padding * 2.0
  let wide = clamp(available - settings_card_padding * 2.0, 280.0, 520.0)
  center(
    card(
      scroll_view(
        column(
          [
            row(
              [
                text(
                  "设置",
                  role=Title,
                  width=wide - 104.0,
                  height=38.0,
                  align=TextStart,
                ),
                button(
                  "返回世界",
                  on_click=CloseSettings,
                  variant=Tonal,
                  width=104.0,
                  height=button_md_height,
                ),
              ],
              spacing=action_gap,
              align=Center,
            ),
            wrapped_caption(
              "设置保存在世界库根目录的 config.json 里；世界本身是同级的子文件夹，导出或分享一个世界不会带上这个文件。",
              width=wide,
            ),
            divider(),
            // ---- world library (moved here from the main screen) ----
            library_panel(model, wide),
            generation_panel(model, wide),
            divider(),
            section_header("模型", width=wide),
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
              height=button_md_height,
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
              height=button_md_height,
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
                    width=wide - 84.0,
                    height=button_md_height,
                  ),
                  button(
                    "隐藏",
                    on_click=ToggleApiKeyReveal,
                    variant=Tonal,
                    width=76.0,
                    height=button_md_height,
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
                      "••••••••（已保存到世界库 config.json）"
                    },
                    role=Body,
                    width=wide - 84.0,
                    height=button_md_height,
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
                    width=76.0,
                    height=button_md_height,
                  ),
                ],
                spacing=8.0,
              )
            },
            wrapped_caption(
              "key 保存在世界库根目录的 config.json（与各世界子文件夹同级），随本次使用的世界库走；世界文件夹里没有它，所以导出、分享单个世界不会泄露 key。",
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
              height=button_md_height,
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
              "紧凑≈3000字 · 标准≈6000字 · 宽裕≈12000字；影响历史保留量与记忆压缩频率。",
              width=wide,
            ),
            divider(),
            section_header("外观", width=wide),
            // The two hand-tuned appearances: 宣纸 (light) and 墨蓝 (dark).
            // The choice persists with the rest of the configuration, so the
            // product reopens on the surface the player left it on.
            segmented_control(
              [
                choice_item("paper", "宣纸"),
                choice_item("ink", "墨蓝"),
              ],
              selected=config.appearance(),
              on_select=value => SetAppearance(value),
              width=wide,
              size=Compact,
            ),
            wrapped_caption(
              "宣纸：月白底、墨灰字，白天长读不刺眼。墨蓝：夜深式的墨蓝底，适合长时间演绎。",
              width=wide,
            ),
            row(
              [
                button(
                  "保存设置",
                  on_click=SaveConfig,
                  width=120.0,
                  height=button_md_height,
                ),
                button(
                  "返回世界",
                  on_click=CloseSettings,
                  variant=Tonal,
                  width=120.0,
                  height=button_md_height,
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
        // The card is taller than any window: give the scroll view a viewport
        // that fits inside the screen minus the page padding and the card's own
        // padding, or the top of the form is painted above the window and
        // cannot be scrolled to.
        height=(screen.height -
        screen.page_padding * 2.0 -
        settings_card_padding * 2.0).max(240.0),
      ),
      width=wide + settings_card_padding * 2.0,
      padding=settings_card_padding,
    ),
  )
}
