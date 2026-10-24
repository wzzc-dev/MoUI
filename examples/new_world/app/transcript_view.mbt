///|
/// The transcript: a visual-novel reading surface, not a chat log.
///
/// The product's core promise is that the *character* is the interface, so the
/// text follows novel conventions rather than messenger ones:
///
/// - a character's turn is continuous prose — actions, expressions, and
///   dialogue in one flowing block, no bubble, no card per sentence;
/// - the character's name appears once per run of consecutive lines, the way
///   a novel re-introduces a speaker only when the room changes;
/// - the player's own lines are the only bubbles, kept light and narrow;
/// - every line ends in a quiet `⋯` that opens its "more" menu
///   (`message_menu.mbt`) instead of wearing four buttons under each message;
/// - recent turns render Markdown (models emit *action* emphasis and lists),
///   older history degrades to plain wrapped text so a long session stays
///   cheap to build.
///
/// Scrolling follows the tail with a request whose id changes with the
/// content, so a new reply lands in view without fighting a manual drag.

///|
/// How many lines the transcript shows at once.
///
/// A long run is the point of this app, so the transcript must not cost more
/// the longer it gets: only the newest lines are built, and the older ones are
/// one click away. A three-hundred-line conversation therefore lays out the
/// same handful of rows a ten-line one does.
pub let transcript_window_default : Int32 = 40

///|
/// How many more lines one 「更早的对话」 click reveals.
pub let transcript_window_step : Int32 = 40

///|
/// Scroll the transcript to its newest line.
///
/// `scroll_view` keeps its own offset and never follows new content, while
/// the transcript grows *downward* from the top of its viewport, so with a long
/// history the newest reply paints below the clip rect. A request with an id
/// that changes with the content scrolls to the tail, and an unchanged id
/// leaves a manual drag alone.
///
/// The id is the newest line's own text, not the row count: revealing older
/// lines must not yank the reader back to the bottom.
fn follow_tail_request(newest : String) -> @moui.ScrollRequest {
  // Ask for "past the end" rather than estimating the content height:
  // `ScrollContainer` clamps the offset to `content - viewport` when it places
  // the child, so a large request lands exactly on the newest row.
  @moui.ScrollRequest::new(
    id=text_hash(newest),
    offset=@geometry.Point::new(x=0.0, y=1.0e6),
  )
}

///|
/// A small, stable hash of a text, for the scroll request's id.
fn text_hash(text : String) -> Int32 {
  let mut hash = 5381
  for ch in text {
    hash = (hash * 33 + ch.to_int()) % 1000003
  }
  hash
}

///|
/// One line's body: Markdown for a character reply, verbatim text for the
/// player. Recent character turns keep the rich renderer; history past
/// `markdown_recent_lines` degrades to plain wrapped text.
fn player_or_reply(
  line : ChatLine,
  width~ : Double,
  recent~ : Bool,
) -> @moui.View[Msg] {
  match line.speaker() {
    Player => wrapped_body(line.text(), width~)
    Character(_) =>
      if recent {
        @moui_richtext.markdown_viewer(
          source=line.text(),
          size=@geometry.Size::new(width~, height=0.0),
          // Identity follows the text: a swipe rewrites the line in place,
          // and the framework reuses node state by identity.
          key=Some("msg|" + line.text()),
        )
      } else {
        wrapped_body(line.text(), width~)
      }
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
/// A one-line note about the world-book entries the player's last turn pulled
/// in, or `""` when nothing matched. This is the visible half of the injection
/// contract that `context.mbt` implements: the prompt already carries the lore,
/// so the transcript has to say so rather than letting a character "just know".
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
  // Same selector the prompt uses, so the note cannot disagree with what the
  // model was actually given.
  lore_summary(select_lore(scenario, player_text, "", lines.length()))
}

///|
/// The transcript for one conversation: the reading surface plus the quiet
/// per-line menus. `label_every` names every line's speaker (a scene, where
/// voices mix); a private chat names a speaker only when the run changes.
fn transcript_view(
  model : WorldModel,
  conversation : Conversation,
  width~ : Double,
  label_every~ : Bool = false,
) -> @moui.View[Msg] {
  let theme = app_theme_for(model.config.appearance())
  let lines = conversation.lines()
  let rows : Array[@moui.View[Msg]] = []
  // The window: only the newest lines are built, so a long run costs the
  // same as a short one. The older ones are one click away.
  let total = lines.length()
  let window = if model.transcript_window() <= 0 {
    transcript_window_default
  } else {
    model.transcript_window()
  }
  let start = if total > window { total - window } else { 0 }
  if lines.is_empty() {
    rows.push(
      wrapped_caption(
        if is_scene_key(conversation.character_id()) {
          "这里还没有人说话。试着叫住其中一位。"
        } else {
          match model.selected {
            Some(id) =>
              match model.scenario.character(id) {
                Some(card) =>
                  if card.opening() != "" {
                    ""
                  } else {
                    "和\{card.name()}说点什么吧。TA 记得这个世界的背景，也可能藏着秘密。"
                  }
                None =>
                  "这个角色已不在当前世界里。重新选一个角色吧。"
              }
            None =>
              "在左侧选一个角色，开始一段属于你们的演绎。"
          }
        },
        width~,
      ),
    )
  }
  if start > 0 {
    rows.push(
      button(
        "更早的对话（还有 \{start} 条）",
        on_click=ExtendTranscript(transcript_window_step),
        variant=Ghost,
        width=(width - 24.0).max(120.0),
        height=button_sm_height,
      ),
    )
  }
  for index in start..<total {
    let line = lines[index]
    let recent = index >= lines.length() - markdown_recent_lines
    let previous = if index == 0 {
      None
    } else {
      Some(lines[index - 1].speaker())
    }
    let label_run = label_every || previous != Some(line.speaker())
    if model.editing_line() == Some(index) {
      // Inline editor: the buffer is the line's text until committed.
      rows.push(
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
      match line.speaker() {
        Player => {
          // The player's line is the only bubble: light, narrow, right-aligned.
          // The bubble takes the room the words need (a two-word line should
          // not be a full-width bar) and never more than four fifths of the
          // column.
          let wanted = line.text().length().to_double() * 14.0 + 24.0
          let bubble = wanted.min(width * 0.8)
          rows.push(
            row(
              [
                spacer(weight=1.0),
                container(
                  wrapped_body(line.text(), width=bubble - 20.0),
                  width=bubble,
                  variant=Overlay,
                  corner_radius=theme.radius_scale.lg,
                  padding=10.0,
                ),
                more_button(model, index),
              ],
              spacing=6.0,
              align=Center,
            ),
          )
        }
        Character(speaker_id) =>
          rows.push(
            column(
              [
                if label_run {
                  row(
                    [
                      wrapped_caption(
                        character_label(model, speaker_id) + "：",
                        width=width * 0.6,
                      ),
                      spacer(weight=1.0),
                      more_button(model, index),
                    ],
                    spacing=6.0,
                    align=Center,
                  )
                } else {
                  row([more_button(model, index)], justify=End)
                },
                // The turn itself: continuous prose, full measure.
                player_or_reply(line, width~, recent~),
              ],
              spacing=2.0,
            ),
          )
      }
    }
  }
  if conversation.pending() {
    // The reply as it streams in: the words land on the stage while the
    // provider is still writing them.
    let streaming = conversation.streaming()
    if streaming != "" {
      rows.push(
        column(
          [
            wrapped_caption(
              if is_scene_key(conversation.character_id()) {
                "有人正在写…"
              } else {
                match model.selected {
                  Some(id) => "\{character_label(model, id)} 正在写…"
                  None => "有人正在写…"
                }
              },
              width~,
            ),
            player_or_reply(
              ChatLine::character(
                match model.selected {
                  Some(id) => id
                  None => ""
                },
                streaming,
              ),
              width~,
              recent=true,
            ),
          ],
          spacing=2.0,
        ),
      )
    } else {
      rows.push(
        text(
          if is_scene_key(conversation.character_id()) {
            "有人正在斟酌…"
          } else {
            match model.selected {
              Some(id) => "\{character_label(model, id)} 正在斟酌…"
              None => "有人正在斟酌…"
            }
          },
          role=Caption,
          width~,
          height=20.0,
          align=TextStart,
        ),
      )
    }
  }
  // Which lore the last player turn pulled in. Without this the injection is
  // invisible: the character "just knows" about the pawnshop and the player
  // cannot tell why.
  let lore_note = lore_hint(model.scenario, conversation)
  if lore_note != "" {
    rows.push(wrapped_caption(lore_note, width~))
  }
  let newest = if total > 0 { lines[total - 1].text } else { "" }
  flexible(
    scroll_view(
      column(rows, spacing=10.0),
      width~,
      request=follow_tail_request(newest),
    ),
    weight=1.0,
  )
}
