///|
/// The conversation area: the private chat with one character, the multi-party
/// scene, and the composer they share.
///
/// Split from `view.mbt` to respect the repository's source-file limit; these
/// views are also the ones that change together whenever the transcript gains a
/// feature. Every panel takes the width it is handed (see `Screen`), so a phone
/// gets a full-width transcript instead of a 520px column clipped at the edge.

///|
/// The conversation with the selected character: scrollable transcript plus
/// composer.
fn conversation_panel(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  // Scene mode has its own panel: the cast is the stage and every line names
  // its speaker, so it does not reuse the single-character transcript.
  match model.scene_location() {
    Some(location) => scene_panel(model, location, screen)
    None => private_panel(model, screen)
  }
}

///|
/// Scroll the transcript to its newest line.
///
/// `scroll_view` keeps its own offset and never follows new content, while the
/// transcript grows *downward* from the top of its viewport, so with a long
/// history the newest reply paints below the clip rect. A request with an id that
/// changes with the content scrolls to the tail, and an unchanged id leaves a
/// manual drag alone.
///
/// The offset is an estimate of the content height rather than a huge constant:
/// an oversized offset is not clamped when the content is *shorter* than the
/// viewport, which scrolled a two-line conversation completely out of sight and
/// made a fresh world look empty.
fn follow_tail_request(rows : Array[@moui.View[Msg]]) -> @moui.ScrollRequest {
  // Ask for "past the end" rather than estimating the content height:
  // `ScrollContainer` clamps the offset to `content - viewport` when it places
  // the child, so a large request lands exactly on the newest row. The estimate
  // this replaced had to be re-tuned every time a transcript row gained a
  // control row (the per-line action row is 36px on its own), and an
  // under-estimate left the newest reply half-clipped.
  @moui.ScrollRequest::new(
    id=rows.length(),
    offset=@geometry.Point::new(x=0.0, y=follow_tail_offset),
  )
}

///|
/// "Far enough that clamping puts us at the bottom." Any value larger than the
/// tallest realistic transcript works, because the scroll container clamps it
/// against the measured content.
let follow_tail_offset : Double = 1.0e6

///|
/// The multi-character scene: cast header, mixed transcript, shared composer.
fn scene_panel(
  model : WorldModel,
  location : String,
  screen : Screen,
) -> @moui.View[Msg] {
  let width = screen.stage
  let cast = model.scene_cast()
  let key = scene_key(location)
  let conversation = model.conversations.for_character(key)
  let waiting = conversation.pending()
  let rows : Array[@moui.View[Msg]] = []
  // The cast strip: who is in this room, with faces, so a scene reads as a
  // group rather than an anonymous chat.
  let people : Array[@moui.View[Msg]] = []
  for card in cast {
    people.push(
      column(
        [
          avatar(model, card, size=32.0, radius=16.0),
          wrapped_caption(card.name(), width=72.0),
        ],
        spacing=2.0,
        align=Center,
      ),
    )
  }
  rows.push(wrap(people, width~, spacing=10.0))
  rows.push(
    row(
      [
        wrapped_caption(
          "\{cast.length()} 人在场 · 说一句话，其中一位会回应",
          width=width - 104.0,
        ),
        // A standalone panel action, not a per-line row action: it keeps the
        // standard `button_sm` scale instead of the halved row-action theme.
        button(
          "离开场景",
          on_click=LeaveScene,
          variant=Outline,
          width=96.0,
          height=button_sm_height,
        ),
      ],
      spacing=action_gap,
      align=Center,
    ),
  )
  let transcript : Array[@moui.View[Msg]] = []
  if conversation.lines().is_empty() {
    transcript.push(
      wrapped_caption(
        "这里还没有人说话。试着叫住其中一位。",
        width~,
      ),
    )
  }
  for line in conversation.lines() {
    // A scene line names its speaker explicitly: with several characters in
    // one history, "你 / 林掌柜" alone would be ambiguous.
    let name = match line.speaker() {
      Player => "你"
      Character(id) => character_label(model, id)
    }
    transcript.push(
      column(
        [
          wrapped_caption(name + "：", width~),
          player_or_reply(model, line, width),
        ],
        spacing=2.0,
      ),
    )
  }
  if waiting {
    transcript.push(
      text(
        "有人正在斟酌…",
        role=Caption,
        width~,
        height=20.0,
        align=TextStart,
      ),
    )
  }
  rows.push(
    flexible(
      scroll_view(
        column(transcript, spacing=8.0),
        width~,
        request=follow_tail_request(transcript),
      ),
      weight=1.0,
    ),
  )
  rows.push(composer(model, screen, enabled=!waiting, waiting~))
  column(rows, spacing=8.0)
}

///|
/// One line's body: Markdown for a character reply, verbatim text for the
/// player. Shared by the private and scene transcripts so a fix to one (height,
/// identity, wrapping) applies to both.
fn player_or_reply(
  model : WorldModel,
  line : ChatLine,
  width : Double,
) -> @moui.View[Msg] {
  ignore(model)
  match line.speaker() {
    Player => wrapped_body(line.text(), width~)
    Character(_) =>
      @moui_richtext.markdown_viewer(
        source=line.text(),
        size=@geometry.Size::new(width~, height=0.0),
        // Identity follows the text: a swipe rewrites the line in place, and
        // the framework reuses node state by identity.
        key=Some("stage|" + line.text()),
      )
  }
}

///|
/// The name of a speaker id, resolving a character, a scene key, or nothing.
fn character_label(model : WorldModel, id : String) -> String {
  if is_scene_key(id) {
    return character_name(model.scenario, id)
  }
  match model.scenario.character(id) {
    Some(card) => card.name()
    None => id
  }
}

///|
/// The private chat with one selected character.
fn private_panel(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  let width = screen.stage
  match model.selected {
    None =>
      column(
        [
          text(
            "点选地图上的角色，或在左侧名单里选一个，开始对话。",
            role=Caption,
            width~,
            height=24.0,
            align=TextStart,
          ),
          // The spring keeps the composer pinned to the bottom edge even
          // while no conversation is on stage.
          spacer(weight=1.0),
          composer(model, screen, enabled=false),
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
                width~,
                height=24.0,
                align=TextStart,
              ),
              spacer(weight=1.0),
              composer(model, screen, enabled=false),
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
                width~,
              ),
            )
          }
          for index, line in conversation.lines() {
            let prefix = match line.speaker() {
              Player => "你"
              Character(_) => card.name()
            }
            if model.editing_line() == Some(index) {
              // Inline editor: the buffer is the line's text until committed.
              transcript.push(
                column(
                  [
                    text_field(
                      model.edit_buffer(),
                      on_input=value => EditLineChanged(value),
                      on_submit=Some(EditLineCommit),
                      width~,
                      height=button_md_height,
                    ),
                    row(
                      [
                        button(
                          "保存",
                          on_click=EditLineCommit,
                          width=76.0,
                          height=button_sm_height,
                        ),
                        button(
                          "取消",
                          on_click=EditLineCancel,
                          variant=Tonal,
                          width=76.0,
                          height=button_sm_height,
                        ),
                      ],
                      spacing=action_gap,
                    ),
                  ],
                  spacing=6.0,
                ),
              )
            } else {
              transcript.push(
                column(
                  [
                    wrapped_caption(prefix + "：", width~),
                    // Character replies are rendered as Markdown: models
                    // routinely emit *action* emphasis and lists, which read as
                    // noise when flattened into one paragraph. Player lines stay
                    // plain — what the player typed is shown verbatim.
                    player_or_reply(model, line, width),
                  ],
                  spacing=2.0,
                ),
              )
              transcript.push(line_actions(index, line, width))
            }
          }
          if conversation.pending() {
            transcript.push(
              text(
                "\{card.name()} 正在斟酌…",
                role=Caption,
                width~,
                height=20.0,
                align=TextStart,
              ),
            )
          }
          // Which lore the last player turn pulled in. Without this the
          // injection is invisible: the character "just knows" about the
          // pawnshop and the player cannot tell why.
          let lore_note = lore_hint(model.scenario, conversation)
          if lore_note != "" {
            transcript.push(wrapped_caption(lore_note, width~))
          }
          column(
            [
              // The transcript absorbs all slack above the composer, so the
              // composer stays pinned to the bottom edge at every transcript
              // length instead of riding right under the last message.
              flexible(
                scroll_view(
                  column(transcript, spacing=8.0),
                  width~,
                  request=follow_tail_request(transcript),
                ),
                weight=1.0,
              ),
              composer(
                model,
                screen,
                enabled=true,
                waiting=conversation.pending(),
              ),
            ],
            spacing=6.0,
          )
        }
      }
  }
}

///|
/// The per-line action row: swipes, edit, delete, branch.
///
/// These used to be 32×22 labels in the default filled variant, which read as
/// four competing primary buttons under every message. They are now one scale
/// (`row_action_height`, half of the old row), ghost by default, with the
/// destructive one in the danger colour and the swipe pair reduced to its
/// glyphs around the counter.
fn line_actions(
  index : Int32,
  line : ChatLine,
  width : Double,
) -> @moui.View[Msg] {
  let actions : Array[@moui.View[Msg]] = []
  if line.has_alternatives() {
    actions.push(action_button("‹", SwipeReply(index, -1), width=30.0))
    actions.push(
      text(
        "\{line.selected() + 1}/\{line.candidate_count()}",
        role=Caption,
        width=36.0,
        height=row_action_height(),
        align=TextCenter,
      ),
    )
    actions.push(action_button("›", SwipeReply(index, 1), width=30.0))
  }
  actions.push(action_button("改", EditLine(index), width=36.0))
  actions.push(destructive_button("删", DeleteLine(index), width=36.0))
  // Branch from here: keep this line and everything before it in a new sibling
  // conversation, leaving the original intact.
  actions.push(action_button("分叉", BranchAt(index), width=52.0))
  // Wrap rather than overflow: on a phone the swipe pair plus three actions is
  // wider than the stage, and a clipped "分叉" is a missing feature.
  wrap(actions, width~, spacing=6.0, row_spacing=4.0)
}

///|
/// The composer: one 说【】 field, one 做【】 field, one 旁白【】 field, then the
/// action row led by 发送.
///
/// Each field frames its line with its own intent, and one send composes the
/// non-empty ones in order, so an action and a spoken line ride the same turn
/// with no staging step in between. Enter in any field sends the whole turn.
fn composer(
  model : WorldModel,
  screen : Screen,
  enabled~ : Bool = true,
  waiting~ : Bool = false,
) -> @moui.View[Msg] {
  let width = screen.stage
  let can_send = enabled && !waiting && model.composer_ready()
  let rows : Array[@moui.View[Msg]] = []
  // The 说 field carries the state hints the old single input box held: why the
  // composer is inert, and that a reply can be pre-written while waiting.
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
  rows.push(composer_actions(screen, can_send, enabled, waiting))
  column(rows, spacing=6.0)
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

///|
/// A one-third-width ghost action for the phone composer. `enabled=false`
/// renders it without a handler, which is the same "looks inert because it is"
/// rule the send button follows.
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
