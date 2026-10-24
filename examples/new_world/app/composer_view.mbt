///|
/// The composer: one field, one intent — and a combined form on demand.
///
/// The product's stage used to carry three permanent fields (说【】 / 做【】 /
/// 旁白【】). The capability is worth keeping — one turn may carry a spoken
/// line *and* an action — but three live fields made the foot of the stage
/// busy and asked the player to think about three boxes before saying
/// anything.
///
/// So the composer has two forms:
///
/// - **collapsed (default)** — one field with a mode switcher on its left
///   (`说 ▾`): the field writes into that intent's draft, and sending sends
///   that intent alone. Each intent keeps its own text, so switching back and
///   forth never loses a line.
/// - **expanded (组合)** — the three fields, for the turn that really needs
///   several parts at once. Sending composes the non-empty ones in
///   说 → 做 → 旁白 order, exactly as before.
///
/// Enter sends in both forms. The action row (发送 / 重新生成 / 换一个角色 /
/// 清空对话) is unchanged.

///|
fn composer(
  model : WorldModel,
  screen : Screen,
  enabled~ : Bool = true,
  waiting~ : Bool = false,
) -> @moui.View[Msg] {
  let width = screen.stage
  let can_send = enabled && !waiting && model.composer_ready()
  let rows : Array[@moui.View[Msg]] = []
  if model.composer_expanded() {
    // The combined form: a header that says what this is and how to leave it,
    // then all three fields. The header is the way back — without it the
    // player is stuck in the combined form.
    rows.push(composer_expanded_header(screen))
    rows.push(
      intent_field(
        "说",
        model.say_draft(),
        value => SayDraftChanged(value),
        placeholder=if !enabled {
          "（先选择一个角色）"
        } else if waiting {
          "（正在等待回复…可以先写下下一句）"
        } else {
          ""
        },
        width~,
        can_send~,
      ),
    )
    rows.push(
      intent_field(
        "做",
        model.do_draft(),
        value => DoDraftChanged(value),
        width~,
        can_send~,
      ),
    )
    rows.push(
      intent_field(
        "旁白",
        model.story_draft(),
        value => StoryDraftChanged(value),
        width~,
        can_send~,
      ),
    )
    rows.push(
      intent_field(
        "这一幕",
        model.beat_draft(),
        value => BeatDraftChanged(value),
        width~,
        can_send~,
      ),
    )
  } else {
    // The default form: one field, one intent.
    rows.push(collapsed_row(model, screen, enabled, waiting, can_send))
  }
  rows.push(composer_actions(screen, can_send, enabled, waiting))
  column(rows, spacing=6.0)
}

///|
/// The collapsed row: the mode switcher, the one field, and the way into the
/// combined form.
///
/// The switcher reads `说 ▾` — the current intent plus the affordance — so the
/// player sees what a line will *be* before typing it, and the menu that
/// opens lists the three intents in the order they are used.
fn collapsed_row(
  model : WorldModel,
  screen : Screen,
  enabled : Bool,
  waiting : Bool,
  can_send : Bool,
) -> @moui.View[Msg] {
  let width = screen.stage
  let mode_label = composer_mode_label(model.composer_mode())
  let placeholder = if !enabled {
    "（先选择一个角色）"
  } else if waiting {
    "（正在等待回复…可以先写下下一句）"
  } else {
    match model.composer_mode() {
      Say => "说点什么…"
      Do => "写下你的动作…"
      Story => "写一段旁白…"
      Beat => "写下这一幕要发生什么…"
    }
  }
  let value = match model.composer_mode() {
    Say => model.say_draft()
    Do => model.do_draft()
    Story => model.story_draft()
    Beat => model.beat_draft()
  }
  let on_input = match model.composer_mode() {
    Say => (text : String) => SayDraftChanged(text)
    Do => (text : String) => DoDraftChanged(text)
    Story => (text : String) => StoryDraftChanged(text)
    Beat => (text : String) => BeatDraftChanged(text)
  }
  // The switcher and the combined-form button are the fixed ends of the row;
  // the field takes the rest.
  let switcher_width = 88.0
  let expand_width = 72.0
  let field_width = (width - switcher_width - expand_width - action_gap * 2.0).max(
    120.0,
  )
  row(
    [
      composer_mode_button(model, mode_label, switcher_width),
      text_field(
        value,
        on_input~,
        on_submit=if can_send { Some(SendComposer) } else { None },
        placeholder~,
        width=field_width,
        height=button_md_height,
      ),
      button(
        "组合",
        on_click=ToggleComposerExpanded,
        variant=Ghost,
        width=expand_width,
        height=button_md_height,
      ),
    ],
    spacing=action_gap,
    align=Center,
  )
}

///|
/// The combined form's header: what the three fields are, and the way back to
/// the single field.
fn composer_expanded_header(screen : Screen) -> @moui.View[Msg] {
  row(
    [
      text(
        "多段合成 · 一次发送",
        role=Caption,
        width=screen.stage - 88.0,
        height=button_sm_height,
        align=TextStart,
      ),
      button(
        "收起",
        on_click=ToggleComposerExpanded,
        variant=Ghost,
        width=72.0,
        height=button_sm_height,
      ),
    ],
    spacing=action_gap,
    align=Center,
  )
}

///|
/// The label of an intent, as the switcher shows it.
fn composer_mode_label(intent : InputIntent) -> String {
  match intent {
    Say => "说 ▾"
    Do => "做 ▾"
    Story => "旁白 ▾"
    Beat => "这一幕 ▾"
  }
}

///|
/// The mode switcher: the current intent, and a popup menu with the three
/// intents. The menu is the framework's context menu, anchored to the button
/// and dismissed by any tap elsewhere — the same contract as the per-line
/// `⋯` menu.
fn composer_mode_button(
  model : WorldModel,
  label : String,
  width : Double,
) -> @moui.View[Msg] {
  let trigger = button(
    label,
    on_click=ComposerMenuChanged(!model.composer_menu()),
    variant=Tonal,
    width=width,
    height=button_md_height,
  )
  if model.composer_menu() {
    popup_host(trigger, [composer_mode_spec(model)])
  } else {
    trigger
  }
}

///|
/// The intent menu's presentation declaration.
fn composer_mode_spec(
  model : WorldModel,
) -> @views.PresentationSpec[Msg] {
  @views.PresentationSpec::new(
    id="new-world:composer-mode",
    kind=ContextMenu,
    content=composer_mode_content(model).theme(
      app_theme_for(model.config.appearance()),
    ),
    anchor=HostBase,
    placement=Some(
      @views.PresentationPlacement::new(
        candidates=[BelowEnd, AboveEnd],
        viewport_insets=@geometry.Insets::all(6.0),
      ),
    ),
    modality=NonModal,
    dismiss=@views.PresentationDismissPolicy::new(
      outside_tap=true,
      escape=true,
      message=Some(ComposerMenuChanged(false)),
    ),
    presented=model.composer_menu(),
  )
}

///|
/// The intent menu: one row per intent, the active one marked.
fn composer_mode_content(model : WorldModel) -> @moui.View[Msg] {
  let theme = app_theme_for(model.config.appearance())
  let rows : Array[@moui.View[Msg]] = []
  let intents : Array[(String, InputIntent)] = [
    ("说", Say),
    ("做", Do),
    ("旁白", Story),
    ("这一幕", Beat),
  ]
  for entry in intents {
    let name = entry.0
    let intent = entry.1
    let active = model.composer_mode() == intent
    rows.push(
      button(
        (if active { "· " } else { "" }) + name,
        on_click=ComposerModeChanged(intent),
        variant=Ghost,
        theme=compact_action_theme(theme),
        width=104.0,
        height=button_sm_height,
      ),
    )
  }
  card(column(rows, spacing=2.0), padding=6.0)
}

///|
/// One 说【…】-style composer row: the intent label opens the bracket, the field
/// carries the text, and the closing bracket sits right after the field. The
/// label width follows the full-width glyph count at the control font instead
/// of a per-row constant, so 旁白【 and 说【 hug their fields the same way.
fn intent_field(
  label : String,
  value : String,
  on_input : (String) -> Msg,
  placeholder~ : String = "",
  width~ : Double,
  can_send~ : Bool = false,
) -> @moui.View[Msg] {
  let label_width = label.length().to_double() * 16.0 + 6.0
  let bracket_width = 20.0
  let field_width = (width - label_width - bracket_width - action_gap).max(80.0)
  row(
    [
      text(
        label + "【",
        role=Control,
        width=label_width,
        height=button_md_height,
        align=TextEnd,
      ),
      text_field(
        value,
        on_input~,
        on_submit=if can_send { Some(SendComposer) } else { None },
        placeholder~,
        width=field_width,
        height=button_md_height,
      ),
      text(
        "】",
        role=Control,
        width=bracket_width,
        height=button_md_height,
        align=TextStart,
      ),
    ],
    spacing=action_gap / 2.0,
    align=Center,
  )
}

///|
/// A ghost action in the phone layout: one third of the row. Without a handler
/// the button is inert, which is how the row reads "not now" without a
/// separate disabled style.
fn ghost_third(
  label : String,
  on_click : Msg,
  width : Double,
  enabled : Bool,
) -> @moui.View[Msg] {
  if enabled {
    button(label, on_click~, variant=Ghost, width~, height=button_md_height)
  } else {
    button(label, variant=Ghost, width~, height=button_md_height)
  }
}

///|
/// Send / regenerate / switch / clear.
///
/// On a roomy stage these are one wrapped row with a single primary action. On a
/// phone the same four controls would wrap into three ragged rows and push the
/// bottom-most one off screen, so the primary action takes a row of its own and
/// the three secondaries share the next one as equal thirds.
fn composer_actions(
  screen : Screen,
  can_send : Bool,
  enabled : Bool,
  waiting : Bool,
) -> @moui.View[Msg] {
  let width = screen.stage
  let send : @moui.View[Msg] = if !enabled || waiting {
    // No handler while a turn is in flight: the label says why.
    button(
      if waiting {
        "等待回复…"
      } else {
        "发送"
      },
      width=96.0,
      height=button_md_height,
    )
  } else if !can_send {
    button("发送", width=96.0, height=button_md_height)
  } else {
    button("发送", on_click=SendComposer, width=96.0, height=button_md_height)
  }
  // Regenerate the last reply: the previous answer becomes a swipe candidate
  // instead of being lost.
  let regenerate : @moui.View[Msg] = if !enabled || waiting {
    button("重新生成", variant=Tonal, width=104.0, height=button_md_height)
  } else {
    button(
      "重新生成",
      on_click=RegenerateReply,
      variant=Tonal,
      width=104.0,
      height=button_md_height,
    )
  }
  let switch_character : @moui.View[Msg] = button(
    if screen.tight_controls {
      "换人"
    } else {
      "换一个角色"
    },
    on_click=Select(None),
    variant=Ghost,
    width=if screen.tight_controls { 72.0 } else { 112.0 },
    height=button_md_height,
  )
  let clear : @moui.View[Msg] = button(
    if screen.tight_controls {
      "清空"
    } else {
      "清空对话"
    },
    on_click=ClearConversation,
    variant=Ghost,
    width=if screen.tight_controls { 72.0 } else { 96.0 },
    height=button_md_height,
  )
  if screen.tight_controls {
    let third = (width - action_gap * 2.0) / 3.0
    column(
      [
        if can_send {
          button(
            "发送",
            on_click=SendComposer,
            width~,
            height=button_hero_height,
          )
        } else {
          button(
            if waiting {
              "等待回复…"
            } else {
              "发送"
            },
            width~,
            height=button_hero_height,
          )
        },
        row(
          [
            ghost_third(
              "重新生成",
              RegenerateReply,
              third,
              enabled && !waiting,
            ),
            ghost_third("换人", Select(None), third, enabled),
            ghost_third("清空", ClearConversation, third, enabled),
          ],
          spacing=action_gap,
        ),
      ],
      spacing=6.0,
    )
  } else {
    wrap(
      [send, regenerate, switch_character, clear],
      width~,
      spacing=action_gap,
      row_spacing=6.0,
    )
  }
}
