///|
/// The composer: one turn may contain several parts, each with its own intent.
///
/// Players routinely want to combine them — "我把伞收起来" (do) **and** "掌柜的，
/// 还有酒吗？" (say) in the same turn, or narrate a scene beat and then speak.
/// A single intent toggle could only ever send one of the three, so the composer
/// keeps one field per intent (说【】 / 做【】 / 旁白【】) and sends the non-empty
/// ones together.
///
/// Storage stays a plain `ChatLine`: the parts are written as canonical,
/// human-readable markers in the line's text, which is what keeps the journal
/// format unchanged (an old file loads as one `Say` part) and keeps a world a
/// folder of readable Markdown/JSON:
///
/// ```text
/// （动作）推开门
/// 掌柜的，还有酒吗？
/// （旁白）雨声更大了。
/// ```
///
/// The markers are the same ones the transcript shows, so what the player reads
/// and what the model is told never drift apart.

///|
/// One staged part of the next turn.
pub(all) struct ComposerPart {
  intent : InputIntent
  text : String
} derive(Eq, Debug)

///|
pub extend ComposerPart with Debug::{to_repr}

///|
pub extend ComposerPart with Eq::{not_equal, equal}

///|
pub fn ComposerPart::new(intent : InputIntent, text : String) -> ComposerPart {
  { intent, text, }
}

///|
pub fn ComposerPart::intent(self : ComposerPart) -> InputIntent {
  self.intent
}

///|
pub fn ComposerPart::text(self : ComposerPart) -> String {
  self.text
}

///|
/// The canonical marker a stored line uses for an action part.
pub let composer_do_marker : String = "（动作）"

///|
/// The canonical marker a stored line uses for a narration part.
pub let composer_story_marker : String = "（旁白）"

///|
/// The canonical marker a stored line uses for a scene beat.
pub let composer_beat_marker : String = "（这一幕）"

///|
/// How a part is written into the stored line (and shown in the transcript).
pub fn ComposerPart::to_line_text(self : ComposerPart) -> String {
  match self.intent {
    Say => self.text
    Do => composer_do_marker + self.text
    Story => composer_story_marker + self.text
    Beat => composer_beat_marker + self.text
  }
}

///|
/// A part's text is a single line: the storage format is line-based, so an
/// embedded newline inside an action would break the marker parse. Speech keeps
/// its newlines (every line stays a plain `Say` part and reads the same).
fn part_text_for(intent : InputIntent, text : String) -> String {
  match intent {
    Say => text
    _ => {
      let lines : Array[String] = []
      for line in text.split("\n") {
        let trimmed = line.trim().to_owned()
        if trimmed != "" {
          lines.push(trimmed)
        }
      }
      lines.join(" ")
    }
  }
}

///|
/// Render a whole turn (the staged parts plus the line being typed) as the text
/// stored in the journal. Empty parts are dropped, so a plain send produces
/// exactly the text the player typed.
pub fn composer_turn_text(parts : Array[ComposerPart]) -> String {
  let cleaned : Array[ComposerPart] = []
  for part in parts {
    let text = part_text_for(part.intent, part.text.trim().to_owned())
    if text != "" {
      cleaned.push(ComposerPart::new(part.intent, text))
    }
  }
  // A single spoken part is stored exactly as the player typed it, so a plain
  // send keeps the journal format it always had. An action or narration part
  // keeps its marker even alone: the marker is the only thing that tells the
  // file (and the transcript) that the line was not speech.
  if cleaned.length() == 1 && cleaned[0].intent is Say {
    cleaned[0].text
  } else {
    let lines : Array[String] = []
    for part in cleaned {
      lines.push(part.to_line_text())
    }
    lines.join("\n")
  }
}

///|
/// Parse a stored player line back into parts.
///
/// A legacy line (no marker) is one `Say` part, so histories written before
/// multi-part turns keep loading and keep their exact text.
pub fn parse_player_parts(text : String) -> Array[ComposerPart] {
  let parts : Array[ComposerPart] = []
  for line in text.split("\n") {
    let trimmed = line.trim().to_owned()
    if trimmed == "" {
      continue
    }
    if trimmed.has_prefix(composer_do_marker) {
      parts.push(
        ComposerPart::new(Do, trimmed[composer_do_marker.length():].to_owned()),
      )
    } else if trimmed.has_prefix(composer_story_marker) {
      parts.push(
        ComposerPart::new(
          Story,
          trimmed[composer_story_marker.length():].to_owned(),
        ),
      )
    } else if trimmed.has_prefix(composer_beat_marker) {
      parts.push(
        ComposerPart::new(
          Beat,
          trimmed[composer_beat_marker.length():].to_owned(),
        ),
      )
    } else {
      parts.push(ComposerPart::new(Say, trimmed))
    }
  }
  parts
}

///|
/// The composer's three fields (说 / 做 / 旁白), ready for one send.
///
/// Each non-empty field becomes a part with its own intent, in that fixed
/// order, so "说一句话 + 做一个动作 + 旁白一句" is one turn typed in one place —
/// no staging step.
pub fn composer_field_parts(
  say : String,
  do_text : String,
  story : String,
  beat : String,
) -> Array[ComposerPart] {
  let parts : Array[ComposerPart] = []
  let said = say.trim().to_owned()
  if said != "" {
    parts.push(ComposerPart::new(Say, said))
  }
  let acted = do_text.trim().to_owned()
  if acted != "" {
    parts.push(ComposerPart::new(Do, acted))
  }
  let narrated = story.trim().to_owned()
  if narrated != "" {
    parts.push(ComposerPart::new(Story, narrated))
  }
  let staged = beat.trim().to_owned()
  if staged != "" {
    parts.push(ComposerPart::new(Beat, staged))
  }
  parts
}

///|
/// Can this composer state be sent?
pub fn composer_has_content(
  say : String,
  do_text : String,
  story : String,
) -> Bool {
  say.trim() != "" || do_text.trim() != "" || story.trim() != ""
}

///|
/// Frame one stored player line for the model.
///
/// - A line that is entirely speech is sent **verbatim**: a plain (or
///   multi-line) message must reach the model exactly as the player typed it,
///   which is also what keeps `Send` and every old journal byte-identical on the
///   wire.
/// - A single action/narration line is framed through `frame_player_text`, so
///   the model is told not to answer it as dialogue.
/// - A combined turn is framed part by part under a one-line header; without the
///   header, "action then speech" reads as one long quote.
pub fn frame_player_turn(text : String, fallback : InputIntent) -> String {
  let parts = parse_player_parts(text)
  if parts.is_empty() {
    return text
  }
  let marked = text.trim().has_prefix(composer_do_marker) ||
    text.trim().has_prefix(composer_story_marker)
  if parts.length() == 1 && marked {
    // One action/narration part: its marker is the intent.
    frame_player_text(parts[0].text, parts[0].intent)
  } else if parts.length() == 1 {
    // One unmarked part is either plain speech or a raw `Send` under the
    // composer's selected intent; either way the fallback decides, and `Say`
    // leaves the text untouched.
    frame_player_text(parts[0].text, fallback)
  } else if parts.all(part => part.intent is Say) {
    // Several lines of speech: the stored text *is* the message.
    text
  } else {
    let framed : Array[String] = []
    for part in parts {
      framed.push(frame_player_text(part.text, part.intent))
    }
    "（这一轮玩家按顺序做了几件事，请依次回应。）\n" +
    framed.join("\n")
  }
}

///|
/// The collapsed composer's one part: the active intent's line, if any.
///
/// The intent's marker rides along for 做 / 旁白, so a single action still
/// reaches the model as an action (and the journal as one marked line).
pub fn composer_active_parts(model : WorldModel) -> Array[ComposerPart] {
  let text = match model.composer_mode {
    Say => model.say_draft
    Do => model.do_draft
    Story => model.story_draft
    Beat => model.beat_draft
  }
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    []
  } else {
    [ComposerPart::new(model.composer_mode, trimmed)]
  }
}

///|
/// Dispatch the composer arms.
///
/// Split out of `update.mbt` because `update.mbt` is at the repository's
/// source-file hard limit and this is one cohesive feature: the three fields
/// (说 / 做 / 旁白) and sending the whole turn. It also keeps the "one turn may
/// carry several intents" rule next to the type that encodes it.
pub fn update_composer(
  model : WorldModel,
  msg : Msg,
  runner : TurnRunner,
  host : WorldHost?,
) -> (WorldModel, @moui.Effect[Msg]) {
  match msg {
    SayDraftChanged(value) =>
      ({ ..model, say_draft: value, }, @moui.Effect::none())
    DoDraftChanged(value) =>
      ({ ..model, do_draft: value, }, @moui.Effect::none())
    StoryDraftChanged(value) =>
      ({ ..model, story_draft: value, }, @moui.Effect::none())
    BeatDraftChanged(value) =>
      ({ ..model, beat_draft: value, }, @moui.Effect::none())
    // The intent switch: the collapsed composer writes into the matching
    // draft, and every intent keeps its own text, so switching 说 → 做 → 说
    // never loses a line.
    ComposerModeChanged(intent) =>
      (
        { ..model, composer_mode: intent, composer_menu: false, },
        @moui.Effect::none(),
      )
    ComposerMenuChanged(open) =>
      ({ ..model, composer_menu: open, }, @moui.Effect::none())
    ToggleComposerExpanded =>
      (
        {
          ..model,
          composer_expanded: !model.composer_expanded,
          composer_menu: false,
        },
        @moui.Effect::none(),
      )
    Send(text) =>
      // A scene turn and a private turn differ only in how the prompt is built
      // and which conversation key it lands in; everything after that (pending
      // guard, journal commit) is shared.
      match model.scene_location {
        Some(location) => send_scene_turn(model, location, text, runner, host)
        None => send_private_turn(model, text, runner, host)
      }
    SendComposer => {
      // The collapsed composer sends **one** intent — the active mode's line —
      // because only that line is on screen. The expanded composer sends the
      // non-empty fields in 说 → 做 → 旁白 order. Either way the turn reaches
      // the journal as one player line (see `composer_turn_text`), so the
      // conversation model is unchanged.
      let parts = if model.composer_expanded {
        composer_field_parts(
          model.say_draft,
          model.do_draft,
          model.story_draft,
          model.beat_draft,
        )
      } else {
        composer_active_parts(model)
      }
      let text = composer_turn_text(parts)
      if text == "" {
        (model, @moui.Effect::none())
      } else {
        // Only the sent parts are cleared: the other intents keep the text
        // the player wrote and switched away from.
        let kept_say = if model.composer_expanded || model.composer_mode is Say {
          ""
        } else {
          model.say_draft
        }
        let kept_do = if model.composer_expanded || model.composer_mode is Do {
          ""
        } else {
          model.do_draft
        }
        let kept_story = if model.composer_expanded ||
          model.composer_mode is Story {
          ""
        } else {
          model.story_draft
        }
        let kept_beat = if model.composer_expanded ||
          model.composer_mode is Beat {
          ""
        } else {
          model.beat_draft
        }
        let cleared = {
          ..model,
          say_draft: kept_say,
          do_draft: kept_do,
          story_draft: kept_story,
          beat_draft: kept_beat,
        }
        let (sent, effect) = match cleared.scene_location {
          Some(location) =>
            send_scene_turn(cleared, location, text, runner, host)
          None => send_private_turn(cleared, text, runner, host)
        }
        // The send helpers clear every draft; the intents that were not part
        // of this turn get their text back.
        let next = {
          ..sent,
          say_draft: kept_say,
          do_draft: kept_do,
          story_draft: kept_story,
          beat_draft: kept_beat,
        }
        (next, effect)
      }
    }
    _ => (model, @moui.Effect::none())
  }
}
