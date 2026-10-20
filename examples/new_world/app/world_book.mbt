///|
/// World book: keyword-triggered lore injection.
///
/// This is the SillyTavern "world info" mechanism. Without it, a scenario either
/// stuffs every fact into the system prompt (wasteful, and the model stops
/// noticing any single one) or reacts to nothing the player says. With it, the
/// prompt grows only around what the conversation is actually about.
///
/// Matching is deliberately simple and deterministic: case-insensitive
/// substring, no stemming, no regex. That keeps a trigger predictable to test
/// and explain, which matters more here than linguistic coverage.

///|
/// The world-book entries whose keys appear in `text`.
///
/// Returns the entries in scenario order, de-duplicated, so the injected block
/// is stable and reproducible across runs.
pub fn world_book_trigger(
  scenario : Scenario,
  text : String,
) -> Array[WorldEntry] {
  let matched : Array[WorldEntry] = []
  if text == "" {
    return matched
  }
  let haystack = text.to_lower()
  for entry in scenario.world_book() {
    if entry.keys.is_empty() {
      continue
    }
    let mut hit = false
    for key in entry.keys() {
      if key == "" {
        continue
      }
      if haystack.contains(key.to_lower()) {
        hit = true
        break
      }
    }
    if hit {
      matched.push(entry)
    }
  }
  matched
}

///|
/// The injected block for one turn, or `""` when nothing matched.
///
/// Empty means the caller can skip the section entirely, so an unrelated turn
/// costs nothing extra.
pub fn world_book_block(scenario : Scenario, text : String) -> String {
  let matched = world_book_trigger(scenario, text)
  if matched.is_empty() {
    return ""
  }
  let lines : Array[String] = []
  for entry in matched {
    lines.push("- " + entry.content())
  }
  lines.join("\n")
}

///|
/// Does any key in the book appear in `text`?
pub fn world_book_has_hit(scenario : Scenario, text : String) -> Bool {
  !world_book_trigger(scenario, text).is_empty()
}
