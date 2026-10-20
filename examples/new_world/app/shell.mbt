///|
/// The responsive shell: header, tab strip, and where the panels go.
///
/// The panels themselves live in `view.mbt` and `conversation_view.mbt`; this
/// file decides *where* they go for the current `Screen` (see `layout.mbt`).
///
/// One product rule drives all three modes: **the conversation is the stage**.
/// In wide mode it sits between the roster and the event log; in medium mode the
/// stage stays put and the tab strip switches the side rail; in compact (a phone
/// in portrait) the stage is the default tab and the tabs take over the body.
///
/// The library picker and AI world generation are *onboarding* controls. Once a
/// world is open they move to the settings page, because a player with a world
/// open is talking to characters, not managing folders. With no world open they
/// own the main screen — otherwise there is nothing to do.

///|
/// Horizontal padding inside the onboarding card.
let onboarding_card_padding : Double = 26.0

///|
/// Header: which world is on stage, where replies come from, and the way into
/// settings. It carries no library controls any more.
fn shell_header(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  let source = if model.config.llm_enabled() {
    "模型回复"
  } else {
    "本地剧本"
  }
  let world = match model.current {
    Some(folder) => folder
    None => "未选择世界"
  }
  let caption = "\{world} · \{source}"
  let settings = button(
    "设置",
    on_click=OpenSettings,
    variant=Ghost,
    width=92.0,
    height=button_md_height,
  )
  match screen.mode {
    Compact => {
      let width = screen.width - screen.page_padding * 2.0
      column(
        [
          row(
            [
              text(
                "New World",
                role=Title,
                width=width - 104.0,
                height=32.0,
                align=TextStart,
              ),
              settings,
            ],
            spacing=action_gap,
            align=Center,
          ),
          text(caption, role=Caption, width~, height=18.0, align=TextStart),
        ],
        spacing=2.0,
      )
    }
    _ => {
      let header_width = if screen.mode is Wide {
        screen.layout.content_width()
      } else {
        screen.width - screen.page_padding * 2.0
      }
      row(
        [
          text(
            "New World",
            role=Title,
            width=180.0,
            height=34.0,
            align=TextStart,
          ),
          text(
            caption,
            role=Caption,
            width=header_width - 180.0 - 96.0 - action_gap * 2.0,
            height=30.0,
            align=TextStart,
          ),
          settings,
        ],
        spacing=action_gap,
        justify=Center,
        align=Center,
      )
    }
  }
}

///|
/// The tab strip for the narrow layouts. The wide workbench has every panel on
/// screen and needs no switcher.
///
/// Labels name what the tab *shows*: on a phone the conversation is the product,
/// "人物" is the roster plus the way into the library, and "事件" is the log.
fn shell_tabs(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  let width = match screen.mode {
    Compact => screen.width - screen.page_padding * 2.0
    _ => screen.rail
  }
  segmented_control(
    [
      choice_item("0", "对话"),
      choice_item("1", "人物"),
      choice_item("2", "事件"),
    ],
    selected=match model.shell_tab() {
      Chat => "0"
      Library => "1"
      Controls => "2"
    },
    on_select=value => {
      ShellTabChanged(
        match value {
          "1" => 1
          "2" => 2
          _ => 0
        },
      )
    },
    width~,
    size=Compact,
  )
}

///|
/// The way into the settings page from a narrow layout, where the library list
/// no longer has a permanent rail.
fn settings_link(model : WorldModel, width : Double) -> @moui.View[Msg] {
  ignore(model)
  button(
    "世界库与设置…",
    on_click=OpenSettings,
    variant=Outline,
    width=width - 4.0,
    height=button_md_height,
  )
}

///|
/// Wide: roster rail, stage, controls rail. The header and the columns share the
/// same total width, so the block reads as one centered workbench.
fn wide_body(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  row(
    [
      world_rail(model, screen.rail),
      conversation_stage(model, screen),
      controls_rail(model, screen.controls),
    ],
    spacing=20.0,
    justify=Center,
  )
}

///|
/// Medium: the stage stays, the tab strip switches the side rail. The strip sits
/// *above the rail*, not above the whole page: a page-wide strip looks like it
/// switches the stage and makes the rail's own content read as unrelated.
fn medium_body(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  // Two tabs, because the stage never leaves in medium mode: the strip picks
  // which *side rail* is visible, and labelling it "对话" would promise a
  // switch that does not happen.
  let on_controls = model.shell_tab() is Controls
  let tabs = segmented_control(
    [choice_item("1", "人物"), choice_item("2", "事件")],
    selected=if on_controls { "2" } else { "1" },
    on_select=value => ShellTabChanged(if value == "2" { 2 } else { 1 }),
    width=screen.rail,
    size=Compact,
  )
  let rail : @moui.View[Msg] = if on_controls {
    scroll_view(controls_rail(model, screen.rail), width=screen.rail)
  } else {
    scroll_view(
      column(
        [world_rail(model, screen.rail), settings_link(model, screen.rail)],
        spacing=12.0,
      ),
      width=screen.rail,
    )
  }
  row(
    [column([tabs, rail], spacing=10.0), conversation_stage(model, screen)],
    spacing=20.0,
    justify=Center,
  )
}

///|
/// Compact: one full-width panel per tab.
fn compact_body(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  match model.shell_tab() {
    Chat => conversation_stage(model, screen)
    Library =>
      scroll_view(
        column(
          [world_rail(model, screen.stage), settings_link(model, screen.stage)],
          spacing=12.0,
        ),
        width=screen.stage,
      )
    Controls =>
      scroll_view(controls_rail(model, screen.stage), width=screen.stage)
  }
}

///|
/// The onboarding screen: no world is open yet, so the two things a player can
/// actually do are choose a library and generate a world.
///
/// This is the only place the library manager and the generation box appear on
/// the main screen. Once a world is open they move to settings, which is what
/// "选择之后可以放到设置中" asks for.
fn onboarding_view(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  let available = screen.width - screen.page_padding * 2.0
  // The card's own padding is part of the budget: sizing the inner column to
  // `available` and then adding padding painted the card 52px past the right
  // edge on a 390px phone, clipping 刷新 / 新建 / 生成世界.
  let width = (available - onboarding_card_padding * 2.0).min(560.0).max(240.0)
  center(
    card(
      scroll_view(
        column(
          [
            text(
              "从一句话开始",
              role=Headline,
              width~,
              height=40.0,
              align=TextStart,
            ),
            wrapped_caption(
              "世界就是一个文件夹：选一个世界库，新建或让 AI 生成一个世界，角色、对话与事件都保存在那个子文件夹里。",
              width~,
            ),
            library_panel(model, width),
            generation_panel(model, width),
          ],
          spacing=16.0,
        ),
        width~,
      ),
      width=width + onboarding_card_padding * 2.0,
      padding=onboarding_card_padding,
    ),
    width=screen.width,
    height=screen.height,
  )
}

///|
/// The main page. The header is fixed; the body takes the remaining height so a
/// short window shrinks the flexible map/transcript instead of clipping the
/// composer off the bottom edge.
fn main_view(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  let body : @moui.View[Msg] = match screen.mode {
    Wide => wide_body(model, screen)
    Medium => medium_body(model, screen)
    Compact => compact_body(model, screen)
  }
  let content : Array[@moui.View[Msg]] = [shell_header(model, screen)]
  // Compact has one column, so the strip belongs under the header. Medium puts
  // it above the rail (inside `medium_body`) and Wide has every panel visible.
  if screen.mode is Compact {
    content.push(shell_tabs(model, screen))
  }
  content.push(expanded(body, weight=1.0))
  padding_edges(
    column(content, spacing=12.0),
    top=screen.page_padding,
    right=screen.page_padding,
    bottom=screen.page_padding,
    left=screen.page_padding,
  )
}
