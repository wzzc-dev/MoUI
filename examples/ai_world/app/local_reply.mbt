///|
/// The no-key conversation path: a deterministic, character-flavoured reply.
///
/// When no provider is configured the world must still respond — a stuck
/// pendulum reads as a broken product. The reply is composed from what the
/// model already knows (persona, voice, goal, background, any world-book hit)
/// with a pure function, so it is testable and identical on every platform.
/// A key swap to the provider path changes nothing about history handling.

///|
/// Compose a deterministic reply for one player line.
pub fn scripted_reply(
  scenario : Scenario,
  card : CharacterCard,
  player_text : String,
) -> String {
  let lore = world_book_block(scenario, player_text)
  let variant = player_text.length() % 3
  let name = card.name()
  let voice_hint = if card.voice() != "" {
    card.voice()
  } else {
    "语气随和"
  }
  let goal_hint = if card.goal() != "" {
    "现在的想法：\{card.goal()}"
  } else {
    ""
  }
  let body = match variant {
    0 =>
      "（\{name}注意到你的来意。眼下这里——\{snippet(scenario.background())}）得看时机，先坐下来喝一口。"
    1 =>
      "你这话说得有意思。（\{name}沉吟片刻——\{voice_hint}。）\{world_nod(scenario)}"
    _ =>
      "（\{name}朝你这边看了一眼。）此事说来话长。\{goal_part(goal_hint)}"
  }
  if lore != "" {
    // A world-book hit means the player asked about something the world has
    // an answer for; lead with the lore like the provider path would.
    "\{body}\n（世界记忆泛起：\{first_line(lore)}）"
  } else {
    body
  }
}

///|
fn snippet(text : String) -> String {
  let first = first_line(text)
  if first == "" {
    "这片天地的底色还没有写下"
  } else if first.length() > 60 {
    "\{first[0:60]}……"
  } else {
    first
  }
}

///|
fn world_nod(scenario : Scenario) -> String {
  let first = first_line(scenario.background())
  if first == "" {
    "这里的一切都还等名字。"
  } else {
    "这里的事，先从「\{first[0:24]}」说起。"
  }
}

///|
fn goal_part(goal : String) -> String {
  if goal == "" {
    ""
  } else {
    "（\{goal}）"
  }
}

///|
fn first_line(text : String) -> String {
  let lines = text.split("\n").to_array().map(line => line.trim().to_owned())
  let mut picked = ""
  for line in lines {
    if line != "" {
      picked = line
      break
    }
  }
  picked
}
