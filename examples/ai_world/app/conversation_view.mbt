///|
/// The conversation area: the private chat with one character, the multi-party
/// scene, and the composer they share.
///
/// Split from `view.mbt` to respect the repository's source-file limit; these
/// views are also the ones that change together whenever the transcript gains a
/// feature.

///|
/// The conversation with the selected character: scrollable transcript plus
/// composer.
fn conversation_panel(model : WorldModel) -> @moui.View[Msg] {
  // Scene mode has its own panel: the cast is the stage and every line names
  // its speaker, so it does not reuse the single-character transcript.
  match model.scene_location() {
    Some(location) => scene_panel(model, location)
    None => private_panel(model)
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
  // Every row is at least one body line plus the column's spacing; multi-line
  // rows only make the estimate smaller than reality, which leaves the tail a
  // little high rather than hiding it.
  // Content height minus roughly one viewport. A request is applied verbatim
  // (it is NOT clamped), so asking for the full content height scrolled a
  // two-line conversation completely out of sight and a fresh world looked
  // empty. Subtracting the allowance makes short histories request 0.
  let overflow = rows.length().to_double() * row_height_estimate -
    tail_allowance
  let offset = if overflow > 0.0 { overflow } else { 0.0 }
  @moui.ScrollRequest::new(
    id=rows.length(),
    offset=@geometry.Point::new(x=0.0, y=offset),
  )
}

///|
/// Conservative height of one transcript row, used only to aim the follow-tail
/// scroll. Slightly under-estimating is safe: the newest row stays near the
/// bottom instead of being pushed off the top.
let row_height_estimate : Double = 76.0

///|
/// Roughly one transcript viewport. Rows worth of height below this do not
/// overflow, so the follow-tail offset stays at zero.
let tail_allowance : Double = 420.0

///|
/// The multi-character scene: cast header, mixed transcript, shared composer.
fn scene_panel(model : WorldModel, location : String) -> @moui.View[Msg] {
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
  rows.push(row(people, spacing=10.0))
  rows.push(
    row(
      [
        wrapped_caption(
          "\{cast.length()} 人在场 · 说一句话，其中一位会回应",
          width=stage_width - 96.0,
        ),
        button(
          "离开场景",
          on_click=LeaveScene,
          variant=Tonal,
          width=88.0,
          height=24.0,
        ),
      ],
      spacing=8.0,
    ),
  )
  let transcript : Array[@moui.View[Msg]] = []
  if conversation.lines().is_empty() {
    transcript.push(
      wrapped_caption(
        "这里还没有人说话。试着叫住其中一位。",
        width=stage_width,
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
          wrapped_caption(name + "：", width=stage_width),
          @moui_richtext.markdown_viewer(
            source=line.text(),
            size=@geometry.Size::new(width=stage_width, height=0.0),
            // Identity follows the text: a swipe rewrites the line in place, and
            // the framework reuses node state by identity.
            key=Some("stage|" + line.text()),
          ),
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
        width=stage_width,
        height=20.0,
      ),
    )
  }
  rows.push(
    flexible(
      scroll_view(
        column(transcript, spacing=6.0),
        width=stage_width,
        request=follow_tail_request(transcript),
      ),
      weight=1.0,
    ),
  )
  rows.push(scene_composer(model, waiting))
  column(rows, spacing=8.0)
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
/// The scene composer: same box as a private chat, but the send target is the
/// scene key and the placeholder says the room is listening.
fn scene_composer(model : WorldModel, waiting : Bool) -> @moui.View[Msg] {
  let send_button = if waiting {
    button("等待回复…", width=88.0)
  } else {
    button("发送", on_click=Send(model.draft()), width=88.0)
  }
  column(
    [
      text_area(
        model.draft(),
        on_input=value => DraftChanged(value),
        placeholder=if waiting {
          "正在等待场景回应…"
        } else {
          "对在场的人说点什么…（回车发送）"
        },
        lines=2,
        width=stage_width,
        on_submit=if waiting { None } else { Some(Send(model.draft())) },
      ),
      row([send_button], spacing=8.0),
    ],
    spacing=6.0,
  )
}

///|
/// The private chat with one selected character.
fn private_panel(model : WorldModel) -> @moui.View[Msg] {
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
                      width=stage_width,
                      height=32.0,
                    ),
                    row(
                      [
                        button(
                          "保存",
                          on_click=EditLineCommit,
                          width=72.0,
                          height=26.0,
                        ),
                        button(
                          "取消",
                          on_click=EditLineCancel,
                          variant=Tonal,
                          width=72.0,
                          height=26.0,
                        ),
                      ],
                      spacing=6.0,
                    ),
                  ],
                  spacing=4.0,
                ),
              )
            } else {
              // Character replies are rendered as Markdown: models routinely
              // emit *action* emphasis and lists, which read as noise when
              // flattened into one plain paragraph. Player lines stay plain —
              // what the player typed is shown verbatim.
              transcript.push(
                match line.speaker() {
                  Character(_) =>
                    column(
                      [
                        wrapped_caption(prefix + "：", width=stage_width),
                        @moui_richtext.markdown_viewer(
                          source=line.text(),
                          size=@geometry.Size::new(
                            width=stage_width,
                            height=0.0,
                          ),
                          // The paint pass culls blocks outside the visible
                          // window, and this window defaults to height 0: only
                          // the first paragraph of a multi-paragraph reply was
                          // ever drawn. Telling it the real height renders the
                          // whole message.
                          // Regenerating rewrites this line in place, so the
                          // node identity has to follow the text; otherwise the
                          // old rendering stays on screen while the model and
                          // the file already hold the new one.
                          key=Some("line|" + line.text()),
                        ),
                      ],
                      spacing=2.0,
                    )
                  Player =>
                    wrapped_body(
                      "\{prefix}：\{line.text()}",
                      width=stage_width,
                    )
                },
              )
              // Every line is editable; a regenerated reply also gets swipes.
              let actions : Array[@moui.View[Msg]] = []
              if line.has_alternatives() {
                actions.push(
                  // "‹" alone is unreadable to a screen reader and cryptic to a
                  // first-time player; `button` has no accessibility-label hook,
                  // so the glyph carries the meaning itself.
                  button(
                    "‹ 上一版",
                    on_click=SwipeReply(index, -1),
                    variant=Tonal,
                    width=64.0,
                    height=22.0,
                  ),
                )
                actions.push(
                  text(
                    "\{line.selected() + 1}/\{line.candidate_count()}",
                    role=Caption,
                    width=34.0,
                    height=22.0,
                    align=TextCenter,
                  ),
                )
                actions.push(
                  button(
                    "下一版 ›",
                    on_click=SwipeReply(index, 1),
                    variant=Tonal,
                    width=64.0,
                    height=22.0,
                  ),
                )
              }
              actions.push(
                button(
                  "改",
                  on_click=EditLine(index),
                  variant=Tonal,
                  width=32.0,
                  height=22.0,
                ),
              )
              actions.push(
                button(
                  "删",
                  on_click=DeleteLine(index),
                  variant=Tonal,
                  width=32.0,
                  height=22.0,
                ),
              )
              // Branch from here: keep this line and everything before it in a
              // new sibling conversation, leaving the original intact.
              actions.push(
                button(
                  "分叉",
                  on_click=BranchAt(index),
                  variant=Tonal,
                  width=48.0,
                  height=22.0,
                ),
              )
              transcript.push(row(actions, spacing=6.0))
            }
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
          // Which lore the last player turn pulled in. Without this the
          // injection is invisible: the character "just knows" about the
          // pawnshop and the player cannot tell why.
          let lore_note = lore_hint(model.scenario, conversation)
          if lore_note != "" {
            transcript.push(wrapped_caption(lore_note, width=stage_width))
          }
          column(
            [
              // The transcript absorbs all slack above the composer, so the
              // composer stays pinned to the bottom edge at every transcript
              // length instead of riding right under the last message.
              flexible(
                scroll_view(
                  column(transcript, spacing=6.0),
                  width=stage_width,
                  request=follow_tail_request(transcript),
                ),
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
    // While a reply is in flight the composer is still editable (the player can
    // start the next line) but sending is withheld: `update` rejects a second
    // send for the same conversation, so the button must say so instead of
    // looking clickable and doing nothing.
    let waiting = match model.selected {
      Some(id) => model.conversations.for_character(id).pending()
      None => false
    }
    let send_label = if waiting { "等待回复…" } else { "发送" }
    let send_button = if waiting {
      // No handler while a turn is in flight: the label says why.
      button(send_label, width=88.0)
    } else {
      button(send_label, on_click=Send(model.draft()), width=88.0)
    }
    let submit = if waiting { None } else { Some(Send(model.draft())) }
    column(
      [
        text_area(
          model.draft(),
          on_input=value => DraftChanged(value),
          placeholder=if waiting {
            "正在等待回复…（可以先写下下一句）"
          } else {
            "说点什么…（回车发送）"
          },
          lines=2,
          width=stage_width,
          on_submit=submit,
        ),
        // Say / do / story: the same three intents AI Dungeon uses. The
        // composer stays one line; the segmented control says how the next
        // line will be read.
        segmented_control(
          [
            choice_item("0", "说"),
            choice_item("1", "做"),
            choice_item("2", "旁白"),
          ],
          selected=match model.intent() {
            Say => "0"
            Do => "1"
            Story => "2"
          },
          on_select=value => {
            IntentChanged(
              match value {
                "1" => 1
                "2" => 2
                _ => 0
              },
            )
          },
          width=208.0,
          size=Compact,
        ),
        row(
          [
            send_button,
            // Regenerate the last reply: the previous answer becomes a swipe
            // candidate instead of being lost.
            if waiting {
              button("重新生成", variant=Tonal, width=96.0)
            } else {
              button(
                "重新生成",
                on_click=RegenerateReply,
                variant=Tonal,
                width=96.0,
              )
            },
            button(
              "换一个角色",
              on_click=Select(None),
              variant=Tonal,
              width=112.0,
            ),
            button(
              "清空对话",
              on_click=ClearConversation,
              variant=Tonal,
              width=92.0,
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
