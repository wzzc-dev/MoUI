///|
/// The responsive shell: the product header, and where the two panels go.
///
/// One product rule drives all three modes: **the conversation is the
/// stage**. In wide mode it sits beside the character rail; in medium mode the
/// stage takes the width and the rail is a toggleable column; in compact (a
/// phone in portrait) the stage is a full-screen chat and the rail is a
/// full-screen overlay. What used to be a permanent third column is now a
/// drawer (`drawers.mbt`), so no mode has to budget for it.
///
/// The library picker and AI world generation are *onboarding* controls. Once
/// a world is open they move to the settings page, because a player with a
/// world open is talking to characters, not managing folders. With no world
/// open they own the main screen — otherwise there is nothing to do.

///|
/// Horizontal padding inside the onboarding card.
let onboarding_card_padding : Double = 26.0

///|
/// Header: the product name, which world is on stage, where replies come
/// from, and the way into settings. It carries no library controls.
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
                "New World · 角色演绎",
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
            "New World · 角色演绎",
            role=Title,
            width=220.0,
            height=34.0,
            align=TextStart,
          ),
          text(
            caption,
            role=Caption,
            width=header_width - 220.0 - 96.0 - action_gap * 2.0,
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
/// Wide: character rail | stage, centered as one block.
fn wide_body(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  row(
    [
      characters_rail(model, screen.rail),
      stage_view(model, screen),
    ],
    spacing=screen.layout.gutter,
    justify=Center,
  )
}

///|
/// Medium: the stage takes the width; the rail is a toggleable 300px column
/// opened from the scene header. Opening it narrows the stage rather than
/// overlapping it — a reading surface should not be half-covered while the
/// player is mid-sentence.
fn medium_body(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  if model.rail_open() {
    // The stage keeps its reading measure by shrinking, not by scrolling
    // under the rail.
    let narrowed = {
      ..screen,
      stage: (screen.stage - screen.rail - screen.layout.gutter).max(320.0),
    }
    row(
      [
        characters_rail(model, screen.rail),
        stage_view(model, narrowed),
      ],
      spacing=screen.layout.gutter,
      justify=Center,
    )
  } else {
    stage_view(model, screen)
  }
}

///|
/// Compact: the stage is a full-screen chat. The rail is a full-screen
/// overlay (a non-modal Dialog centered in the viewport), so a phone gets the
/// whole screen for reading and the whole screen for choosing.
fn compact_body(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  if model.rail_open() {
    overlay_host(
      stage_view(model, screen),
      [
        @views.PresentationSpec::new(
          id="new-world:roster",
          kind=Dialog,
          content=card(
            column(
              [
                row(
                  [
                    text(
                      "角色",
                      role=Subtitle,
                      width=screen.stage - 96.0,
                      height=28.0,
                      align=TextStart,
                    ),
                    button(
                      "关闭",
                      on_click=ToggleRail,
                      variant=Ghost,
                      width=64.0,
                      height=button_sm_height,
                    ),
                  ],
                  spacing=action_gap,
                  align=Center,
                ),
                divider(),
                scroll_view(
                  characters_rail(model, screen.stage),
                  width=screen.stage - 24.0,
                  height=(screen.height - 160.0).max(200.0),
                ),
              ],
              spacing=8.0,
            ),
            width=screen.stage,
            padding=12.0,
          ),
          modality=NonModal,
          dismiss=@views.PresentationDismissPolicy::new(
            outside_tap=true,
            escape=true,
            message=Some(ToggleRail),
          ),
          presented=true,
        ),
      ],
    )
  } else {
    stage_view(model, screen)
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
              "从一位角色开始",
              role=Headline,
              width~,
              height=40.0,
              align=TextStart,
            ),
            wrapped_caption(
              "世界就是一个文件夹：选一个世界库，新建或让 AI 生成一个世界，角色、对话与记忆都保存在那个子文件夹里。",
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
/// short window shrinks the transcript instead of clipping the composer off
/// the bottom edge.
fn main_view(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  let body : @moui.View[Msg] = match screen.mode {
    Wide => wide_body(model, screen)
    Medium => medium_body(model, screen)
    Compact => compact_body(model, screen)
  }
  padding_edges(
    column([shell_header(model, screen), expanded(body, weight=1.0)], spacing=12.0),
    top=screen.page_padding,
    right=screen.page_padding,
    bottom=screen.page_padding,
    left=screen.page_padding,
  )
}
