///|
/// Lorebook matching: priority, position, recursion, and probability.
///
/// The plain substring scan lives in `world_book.mbt`; this file is the layer
/// that turns its matches into what actually enters a prompt. It exists
/// separately because the *rules* are worth reading on their own:
///
/// - **priority** decides injection order and who survives a budget cut;
/// - **position** decides whether an entry reads as a world rule (before the
///   persona) or as a scene fact (just before the history);
/// - **recursion** re-scans injected text so a chain of triggers can fire
///   ("当铺" → "周掌柜" → "官文") instead of needing every keyword up front;
/// - **probability** makes an entry occasional without deleting it.
///
/// Everything here is a pure function of (entries, text, turn) so a retry at
/// the same turn reproduces the same injection — a lorebook that rerolls on
/// every request makes a world feel arbitrary.

///|
/// One entry selected for injection, with the reason it fired.
pub(all) struct LoreHit {
  entry : WorldEntry
  /// How many recursion rounds it took to reach this entry (0 = direct match).
  depth : Int32
} derive(Eq, Debug)

///|
pub extend LoreHit with Debug::{to_repr}

///|
pub extend LoreHit with Eq::{not_equal, equal}

///|
/// The maximum recursion depth a single turn will walk, no matter what a file
/// asks for. A hand-edited `[recursion=99]` must not turn into an unbounded
/// scan (or an unbounded prompt).
pub let lore_recursion_cap : Int32 = 4

///|
/// A stable, cheap hash used to make the probability roll reproducible.
fn lore_roll(entry : WorldEntry, turn : Int32) -> Int32 {
  let mut hash = 5381
  for key in entry.keys() {
    for ch in key {
      hash = (hash * 33 + ch.to_int()) % 1000003
    }
  }
  for ch in entry.content() {
    hash = (hash * 33 + ch.to_int()) % 1000003
  }
  (hash + turn * 7919) % 100
}

///|
/// Does this entry pass its probability gate on this turn?
pub fn lore_passes_probability(entry : WorldEntry, turn : Int32) -> Bool {
  let chance = entry.probability()
  if chance >= 100 {
    true
  } else if chance <= 0 {
    false
  } else {
    lore_roll(entry, turn) < chance
  }
}

///|
/// Select the entries to inject for one turn.
///
/// Direct matches are taken first; each round then rescans the text of the
/// entries already selected, up to the deepest `recursion` any of them asked
/// for (capped by `lore_recursion_cap`). The result is ordered by descending
/// priority, then by scenario order, so the prompt is stable.
pub fn select_lore(
  scenario : Scenario,
  player_text : String,
  recursion_text : String,
  turn : Int32,
) -> Array[LoreHit] {
  let hits : Array[LoreHit] = []
  let seen : Array[String] = []
  // Round 0: the player's own words.
  let mut frontier = player_text
  if frontier == "" && recursion_text != "" {
    frontier = recursion_text
  }
  let mut depth = 0
  let mut max_depth = 0
  for entry in scenario.world_book() {
    if entry.recursion() > max_depth {
      max_depth = entry.recursion()
    }
  }
  if max_depth > lore_recursion_cap {
    max_depth = lore_recursion_cap
  }
  while frontier != "" && depth <= max_depth {
    let mut added_here = false
    for entry in scenario.world_book() {
      if seen.contains(entry.content()) {
        continue
      }
      if !matches_any(entry, frontier) {
        continue
      }
      if !lore_passes_probability(entry, turn) {
        continue
      }
      seen.push(entry.content())
      hits.push(LoreHit::{ entry, depth, })
      added_here = true
    }
    if !added_here {
      break
    }
    // Re-scan with the newly injected text, which is what chains a trigger.
    let next : Array[String] = []
    for hit in hits {
      if hit.depth == depth {
        next.push(hit.entry.content())
      }
    }
    frontier = next.join("\n")
    depth += 1
  }
  sort_lore_hits(hits)
  hits
}

///|
fn matches_any(entry : WorldEntry, text : String) -> Bool {
  let haystack = text.to_lower()
  for key in entry.keys() {
    if key != "" && haystack.contains(key.to_lower()) {
      return true
    }
  }
  false
}

///|
fn sort_lore_hits(hits : Array[LoreHit]) -> Unit {
  // Descending priority; ties keep insertion (scenario) order, which is what
  // makes the output stable across runs.
  let sorted : Array[LoreHit] = []
  while !hits.is_empty() {
    let mut best = 0
    for index in 1..<hits.length() {
      if hits[index].entry.priority() > hits[best].entry.priority() {
        best = index
      }
    }
    sorted.push(hits[best])
    ignore(hits.remove(best))
  }
  for hit in sorted {
    hits.push(hit)
  }
}

///|
/// The injected text for one position, highest priority first.
///
/// Entries of the requested position only; `""` means the caller skips that
/// prompt section entirely.
pub fn lore_block_at(hits : Array[LoreHit], position : LorePosition) -> String {
  let lines : Array[String] = []
  for hit in hits {
    if hit.entry.position() == position {
      lines.push("- " + hit.entry.content())
    }
  }
  lines.join("\n")
}

///|
/// A one-line summary of what was injected, for the UI (the player should see
/// the lore working, not just its effect on the character).
pub fn lore_summary(hits : Array[LoreHit]) -> String {
  if hits.is_empty() {
    return ""
  }
  let keys : Array[String] = []
  let mut injected = 0
  for hit in hits {
    keys.push(hit.entry.keys().join("/"))
    // The size matters as much as the names: lore competes with history for
    // the context budget, so the player should see what this turn cost.
    injected += hit.entry.content().length()
  }
  "本轮注入世界书：" +
  keys.join(" · ") +
  "（" +
  hits.length().to_string() +
  " 条，" +
  injected.to_string() +
  " 字）"
}
