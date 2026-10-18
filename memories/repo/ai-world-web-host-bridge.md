# ai_world web host bridge (folder database + provider)

## Rule

For an app-private wasm-gc capability (network, folder/file IO), put the
MoonBit side in an app-only package with `extern "wasm"` declarations against
one page-provided module (ai_world: `ai_world_host`), strings crossed with the
`begin_create_string`/`string_append_char`/`finish_create_string` +
`begin_read_string`/`string_read_char` handshake (ids only), and completions
returned through exported callbacks (`ai_llm_complete`/`ai_fs_complete`) that
resolve request-id-keyed pending maps. The page module must queue completions
until `bootMouiWasmGcApp(...).then(instance)` resolves — the app's init effect
fires inside `_start`, before `booted` is set, so a bare
`booted?.exports?.ai_fs_complete(...)` silently drops the very first library
listing. **Queuing the call is not enough: the payload string must outlive the
queue too.** A completion that does `callExport(...)` and then
`stringStore.delete(textId)` hands the replayed export an empty payload, so the
app sees `ok = true` with `""` (observed as an empty first library listing).
Release through a helper that defers while unbooted and flushes after the
queue replays. Wrap every export call in try/catch that writes to the
diagnostics log: a wasm trap in a completion is otherwise invisible.

## Gotchas (all hit in practice)

- The JSON envelope between the page and MoonBit must match exactly on both
  sides (`{"names": [...]}` vs a bare array) — parse is defensive and a
  mismatch shows up as an empty library, not an error.
- `divider()` defaults to the horizontal axis; inside a `row` it stretches to
  the full card width and pushes the remaining columns out of view. Only use
  it inside `column`s, or pass the axis explicitly.
- Canvas `measure` sizes are logical px and must fit the parent row/card;
  overflow in a row shoves later children off-card instead of wrapping.
- MoUI's web semantics overlay is real DOM: Playwright `getByRole` on the
  app's buttons/textboxes works for black-box browser tests, and
  `domSnapshot()` is the text channel for canvas-only apps.
- **Canvas `draw` callbacks paint in canvas-global coordinates**: `frame` is
  the view's rect inside the whole app frame, not a (0,0)-anchored local
  space. Emitting content at local (0,0) draws it at the app's top-left, and
  a `Clear` command clears the entire surface (erasing views drawn earlier).
  The counter-example contract test lives in `examples/ai_world/render_check`.
- Do not perform host-bridge reads from a program's init effect: the bridge
  queues completions until `bootMouiWasmGcApp` resolves, which loses the
  first read. Ride follow-up IO on a later app message (ai_world reads
  `config.json` when `WorldListArrived` arrives) — after the boot settles.
- The IAB/webview kills in-flight `fetch` from hidden pages
  (`TypeError: Failed to fetch`): failed provider turns clear pending and are
  retryable; a page-direct fetch proves network/CORS are not at fault.
- **Host file filters are part of the storage contract.** A world folder is
  Markdown *plus* `conversations.json` / `events.json`. A host that returns
  only `*.md` looks fine (the world still opens) but every conversation resets
  on reopen. Both hosts now filter with the app's `is_world_file_name`
  (`.md` + `.json`; the page mirrors the rule because it cannot import
  MoonBit), pinned by `world_store_wbtest.mbt`.
- **A planned message list must reach the wire.** `LlmRequest` carries
  `messages : Array[(String, String)]`, not `system`/`user` fields: taking
  `plan.messages[0]` plus the last entry silently made every provider turn
  stateless (no history, no summary, no world-book hits) while the context
  layer's unit tests stayed green. Assert the transport, not just the planner.
- **`{ ..model, }` shares arrays.** In a TEA `update`, a branch that logs or
  appends must start from a copied record (`WorldModel::fork`), or it mutates
  the model it was handed; the runtime does no model diffing, so nothing
  surfaces this except an explicit purity test.
- **A multi-speaker history needs no new storage format.** A scene is a
  `Conversation` under `scene:<地点>` whose lines already carry
  `Speaker::Character(id)`; the pipeline (pending guard, journal commit,
  budgeted plan) is shared with private chat. What must NOT be shared is the
  reply's attribution: attribute the line to the *respondent*, not to the
  scene key, or every offline scene reply reads as if the room answered (this
  was a real bug caught by a test).
- **Portraits ride as base64, not as a second host contract.** `WorldFiles`
  carries `(file name, base64)` pairs and the app turns them into `data:`
  URIs; the card stores only the file name. Both hosts filter with the app's
  `is_portrait_file_name`, so a world's assets are part of the folder read.
- **Time advance is a button, never a tick.** A provider call costs money;
  drive it from an explicit `AdvanceTime` message. Offline it still writes a
  deterministic event so the control is never dead.
- **A lorebook needs one selector, used everywhere.** `app/lore.mbt`
  (`select_lore`) is the single source of priority / position / recursion /
  probability; the prompt builder, the offline scripted reply, and the UI's
  "what was injected" hint all call it. When two of those used different scans,
  the panel could disagree with what the model was actually given.
- **Probability must be deterministic per turn, not per request.** The roll is
  hashed from `(entry, turn)`; rerolling on every call would make a retry
  produce a different world. Recursion is capped (`lore_recursion_cap`) so a
  hand-edited `[recursion=99]` cannot become an unbounded prompt.
- **Lorebook modifiers live in the Markdown bullet, not a side file.** They go
  between the keys and the colon (`- 酒 [priority=8]: 内容`), only non-defaults
  are written back, and a bad modifier is ignored/clamped rather than dropping
  the entry. A player hand-editing `world_book.md` must never lose lore.
- **Input intent frames the wire, never the archive.** `frame_player_text`
  rewrites only the last message of `plan.messages`; the stored `ChatLine` keeps
  exactly what the player typed. Framing must *replace* that message — appending
  a framed copy sends the line twice (a test now counts occurrences).

- **Branches are sibling files, not a tree.** `BranchAt` writes
  `conversations/<角色>~N.json` (`branched_key` / `split_branch`), so a world
  stays a folder of readable files and any branch can be deleted alone. The
  roster must list them under the character or a branch becomes unreachable
  after the player selects something else.
- **`update.mbt` has a 1800-line budget.** `validate-maintenance-baseline`
  rejects oversized files that have no budget entry. Split by feature
  (`turn.mbt` = turn pipelines, `creation.mbt` = wizard + generation) rather
  than adding an exemption. MoonBit or-patterns cannot bind one name across
  variants with different payloads, so delegation arms are written one per
  variant.

- **Conversation keys are not all character ids.** `scene:<地点>` and
  `<角色>~N` (branches) are valid keys whose "anchor" is a place or a base
  character. Anything that resolves a conversation against the character list
  must special-case them — the orphan-conversation filter in
  `parse_world_files` silently deleted every scene and every branch on reload
  until it learned this.
- **`commit_files(model, World)` is the definition of "the world on disk".**
  Portrait bytes live in `model.portraits`, not in `scenario.world_files()`, so
  a world-scope commit must add them explicitly or an exported world loses every
  face while its Markdown still references the missing files.
- **Derived counters must be persisted or they re-derive wrong.** A summary's
  `summarized_upto` was not written, so the reader assumed "covers everything
  loaded". A half-compacted conversation then believed it needed no further
  compression and a stale summary stood in for real history. Persist the marker,
  clamp a hand-edited value to the line count, and keep the old
  "covers everything" fallback for files written before the field existed.
- **Effect completions that change conversation state must commit it.**
  `SummaryArrived` returned `Effect::none()`, so a successful compaction lived
  only in memory and the work was redone (or silently lost) on next launch.
- **A log that is both shown and persisted must filter UI chatter at write
  time.** "已载入「…」" and parse warnings describe opening the file, not the
  world; committing them made `events.json` grow by one identical line on every
  reload. `is_transient_log_line` filters them in `events_json_text`, and a
  re-read of the same folder drops the previous notice so memory does not
  accumulate either.
- **A field on the model is not a field on disk.** Four more losses of this
  shape: art map size (never written → every reload shrank a custom map),
  location description (the parser understood it, the writer never emitted it),
  the JSON codec's lorebook modifiers, and `portrait_prompt`. The guard is the
  "maximal world" test in `integrity_wbtest`: every field of every persistent
  type set to a distinguishable value, then asserted through the folder codec,
  the JSON codec, and a bundle.
- **Ids are references, so a derived id can break a pointer.** A world's id
  comes from its directory name and a *location's* id used to come from its
  display name — but character cards reference a place by `location`. A world
  authored from JSON (or generated by AI) has slug ids (`bar`), so after a
  reload the place became `吧台` while every card still said `bar`, and
  `cast_at` put nobody on stage (2 → 0). `world.md` now writes `id=bar` when the
  id differs from the name, and omits it otherwise so hand-written files stay
  clean. Assert names *and* ids where an id is referenced.
- **Session state must NOT round-trip.** `Conversation.pending` and `appended`
  are deliberately not persisted (`pending` would restore a stuck in-flight
  flag; `appended` re-derives from line count). Pin that with a test so nobody
  "fixes" the round trip by persisting them.
- **`rename_card` copies fields by hand — the classic silent-drop site.**
  Adding a field to `CharacterCard` without adding it there loses that field on
  *every* world load. `portrait_prompt` was lost this way. The guard is
  `integrity_wbtest`'s "every character field survives a world round trip",
  which sets each field to a distinct value.
- **Every card field that affects behaviour must also reach the Markdown.**
  `location` decides scene membership (`cast_at`) but was never written, so a
  character standing outside a place's rect vanished from their scene after a
  reload. It now round-trips as `## 所在`.
- **"Delete" must be written, not skipped.** Hosts never remove files, so a
  cleared conversation has to be committed as an *empty document*. Skipping
  empty conversations in `journal_files` made every clear silently undo itself
  on the next load — the old file was still on disk.
- **`ChatLine::with_text` edits the shown candidate in place.** `text` *is* the
  selected slot (`[text] + alternatives`), so an edit rewrites that slot and
  keeps the other candidates; the swipe history survives. Clearing
  `alternatives` on edit looks tidy but breaks "swipe back to the previous
  version", which is the whole point of keeping them.
- **Canvas `input`s have empty `placeholder` in the DOM.** The hint text is
  painted, so `find_element(By.XPATH, "...").get_attribute("placeholder")`
  returns `""` and a placeholder-based selector silently picks nothing. Select
  by position (the idea field is the input with `rect.x > 900` at 1500px width)
  or by index, never by placeholder.
- **`innerText` cannot see Markdown replies.** They are canvas-painted, so a
  browser check that greps `document.body.innerText` will report "the reply did
  not update" even when it did. Use a screenshot for anything Markdown-rendered.
  I burned a whole round re-"fixing" a working feature because of this.
- **`model.portraits` keys are already folder paths.** They look like
  `characters/<名>.png`; re-deriving through `world_folder_name` (which turns `/`
  into `_`) and prefixing `characters/` again produced
  `characters/characters_<名>.png`, so exports silently lost every portrait.
  `portrait_world_path` now normalises instead of re-deriving.
- **A codec test does not cover the caller.** `bundle_wbtest` proved the bundle
  *could* carry a portrait; it said nothing about `commit_files` putting one in.
  Test the payload the app actually builds.
- **A bare `if` chain after a match arrow does not parse.** `@core.DrawText(run)
  => if a { .. } if b { .. }` fails with a confusing "unexpected token id";
  wrap the arm body in `{ }`. Cost me two debugging rounds.
- **"UI 可见" needs a render assertion, not a string test.** `lore_summary`
  building the right text proves nothing about it being painted; the
  render_check probe asserts the hint and the matched key appear in `DrawText`.
- **`ScrollRequest` is applied verbatim, not clamped.** `scroll_view_layout.mbt`
  takes `request.offset` as the target offset whenever its `id` is newer. So
  `y=100000` does NOT mean "go to the bottom" — with content shorter than the
  viewport it scrolled a two-line conversation entirely out of sight and a fresh
  world looked empty. The app now sends `rows * row_height - viewport_allowance`
  clamped at 0.
- **The transcript must follow its tail.** `scroll_view` keeps its own offset
  and never chases new content, while the transcript grows downward from the top
  of its viewport — so the newest reply painted *below* the clip rect and the
  player saw only old messages. `follow_tail_request(line_count)` (an
  `@moui.ScrollRequest` whose id changes with the content) fixes it; the runtime
  clamps the oversized offset and an unchanged id leaves a manual drag alone.
  It was NOT a `markdown_viewer` height problem — that was a wrong guess.
- **`button` has no accessibility label; `image` does.** A button's text IS its
  label, so an icon-only control (`‹`, `›`) is unnameable for a screen reader.
  The fix is to make the glyph carry meaning ("‹ 上一版") rather than to hunt for
  a label hook that does not exist. Portraits take `accessibility_label=` and
  should always pass the character's name.
- **The compression trigger needs real pressure.** `needs_compression` requires
  `chat_history_limit - summary_keep_recent` (60 - 10 = 50) retained lines *or*
  an eviction, plus `summary_min_new_lines` (10) uncovered lines. A fixture with
  25 lines asserts nothing — it fails, and the failure is the fixture's fault.
- **The rolling summary must outlive its source lines.** Its whole purpose is
  continuity after the 60-line cap drops the originals, so `plan_messages` has to
  include it even when none of the summarised lines are still retained.
- **`rect_center` stacked co-located markers.** A card that names a location but
  carries no coordinates fell back to the location's exact centre, so every
  character in one place landed on the same pixel and only the last was visible
  — and that shape is what AI generation and hand-editing both produce.
  `ring_point` spreads them by cast order; a lone character still gets the centre
  and an explicit `x=`/`y=` still wins.
- **A commit failure must not undo the in-memory turn.** `WorldCommitted(folder,
  false)` only reports that the file did not update; the model keeps the turn so
  the player does not lose what they wrote as well. Its notice already states
  both cause and remedy.
- **A failed world load must not mix two worlds.** Opening world B and failing
  must leave either A untouched or the model reset — never A's cast under B's tab.
- **`ConversationBook::for_character` creates on miss.** It returns a fresh
  empty `Conversation` for an unknown id, so appending a late reply for a deleted
  character silently produced an orphan file that the loader then discarded.
  Both reply paths now check `reply_target_exists` first.
- **A test can encode a bug as a contract.** `update_wbtest.mbt` asserted that a
  reply for `jianghu` (absent from the world) produced a line — which was exactly
  the ghost-conversation defect. When a new guard makes an old test fail, read
  the old test before "fixing" the guard.
- **An empty provider reply must be treated as a failure.** `llm_clean_reply`
  strips whitespace and a leading name prefix, so a whitespace-only response
  cleans to `""`. Appending that unconditionally wrote a blank bubble the player
  could never edit away. Both the private and scene paths now check for `""`
  first and record a failed turn instead.
- **Failures must speak the UI's language.** The provider-failure notice was
  English (`no reply from provider for X`) inside an otherwise all-Chinese UI,
  which reads like a leaked internal error.
- **Documentation claims rot silently; pin them with tests.** The README still
  showed `conversations.json` as the storage format long after per-character
  files replaced it, and omitted portraits from the folder tree.
  `docclaim_wbtest.mbt` now feeds the README's own snippets through the real
  parser, so documented syntax cannot drift without a red test.
- **`is_world_file_name` does not include `.png`.** Portraits go through a
  separate `is_portrait_file_name` (`.png/.jpg/.jpeg/.webp`); a filter claim
  that lumps them together is wrong.
- **`uses<=1` does not mean dead.** `ai_fs_complete` / `ai_llm_complete` look
  uncalled from MoonBit because they are WASM export ABI driven by JS. Before
  deleting a "dead" function, check entrypoints, `pkg.generated.mbti`, and
  whether a host calls it by name. Bump-the-counter auditing also misses
  first-class references (`map(f)`, not `map(f())`).
- **The single unpublished API is `text(wrap=)`.** Verified by unzipping the
  registry cache: `moui@0.2.3`'s `views/text/text()` is
  `(text, role?, theme?, width?, height?, align?)` with no `wrap`, while
  `moui_richtext@0.2.1` *does* publish `markdown_viewer(..., key?)`. Footprint:
  `view.mbt`'s `wrapped_body`/`wrapped_caption` (3 sites, 19 callers). Removing
  it to unblock graduation would lose real CJK paragraph wrapping — publish
  `moui` instead.
- **A heredoc guard that needs variables must not be quoted.** `<<'EOF'` blocks
  expansion, so `${wrap_sites}` printed literally; and reading those numbers in a
  later step fails because graduation has already `git rm`'d the example. Capture
  before removal, interpolate in an unquoted heredoc.
- **`git subtree split` only sees commits.** Twelve new source and test files
  sat untracked across rounds 2-26, so a graduation run would have produced a
  repository missing the entire app core while still reporting success. Commit
  before graduating; the script now names that consequence in its refusal.
- **`set -euo pipefail` + `grep` is a trap.** A `grep` that matches nothing
  exits 1, and `pipefail` turns that into an abort — the script died silently
  right after "checking the working tree". End such pipelines with `|| true`.
- **Hand-editing the world is the design, so orphan history is a normal
  state.** Deleting a character in `characters/` leaves its conversation file
  behind; the loader drops it **with a warning** rather than resurrecting a ghost
  character or silently keeping an unreachable file. Scenes survive because they
  are keyed by location, not by character — which is exactly why editing the cast
  must not delete multi-party transcripts.
- **Scrolling old content above the clip is correct, not a bug.** For a message
  taller than the viewport, rows with negative `y` are simply scrolled off. The
  real invariant under extreme input is *horizontal*: a wrapped paragraph must not
  spill out of its column. Asserting "nothing paints outside the clip" fails on
  perfectly correct tall content.
- **"Outermost clip" is not the window.** The first `PushClip` in the command
  stream belongs to whichever panel draws first, so a window-bounds check built
  on it measures the wrong rect. Select the clip by its known width instead.
- **A geometry guard can be vacuous.** The first version of the action-row fit
  test was wrapped in `if stage_right > 0.0` and therefore passed while measuring
  nothing. Assert the measured values are non-zero as well as within bounds.
- **Follow the chain to the draw commands, not to the model.** Every portrait
  test used to stop at "the card's URI string is right"; `portrait_probe.mbt`
  asserts a `DrawImage` with a `data:image/png;base64,` source actually appears,
  and that the no-portrait fallback emits *zero* images while still painting
  text. A correct model value that never becomes a draw command renders as
  nothing.
- **Clip escapes are invisible to unit tests.** `panels_probe.mbt` walks every
  draw command with a clip stack and asserts no text lands outside all active
  clips (51 runs, 0 escapes today). The detector itself has a synthetic in/out
  rect test so the guard cannot silently rot.
- **Measure layout with `render_check`, not by guessing.** `transcript_probe.mbt`
  builds the real view tree through `AppRuntime` and reads `PushClip` rects and
  `DrawText` frames. That turned "the reply looks clipped" into
  `clip=614..918` vs `text y=958` in one run after a whole round of failed
  guess-fixes.
- **A scene turn appends TWO lines, so rotation must count turns.** Indexing
  `responder_for` by `conversation.lines().length()` advanced by two per round;
  with a two-person cast `% 2` was always 0 and the same character answered every
  time — the scene looked multi-party but was a monologue. Unit tests passed
  because they pass the index directly. Count player lines instead.
- **The Web provider path was verified against a real HTTP server too.** Seed
  `localStorage['ai_world_config_v1']` with `{endpoint, model, api_key,
  temperature}` and `localStorage['ai_world_world_v1:<world>']` with the world
  files, then drive the page: the request arrives as
  `POST <base>/chat/completions` with a bearer header. This is the only way to
  confirm `[position=before]` actually orders the prompt — with lore matched,
  message 0 is `【世界规则】…` and message 1 is the persona.
- **The native transport was verified against a real socket once.** A local
  OpenAI-compatible stub confirmed URL resolution, the bearer header, the body,
  and `choices[0].message.content` parsing end to end. Because a test needing an
  external server cannot live in the suite, `llm_native/worker_wbtest.mbt` pins
  the socket-free half and is registered in the `pr` profile as
  "AI World native transport tests".
- **Provider `content` is not always a string.** Anthropic-shaped gateways and
  some OpenAI-compatible proxies return `[{"type":"text","text":…}]`. The
  parser must join the text blocks and skip non-text ones; a block array with no
  text (pure tool_use) must still be `None` so the retry path stays honest rather
  than appending an empty line.
- **`--profile daily` has a pre-existing failure unrelated to this example.**
  `scripts/test-moui-prebuild.mjs` throws "Skia binding prebuild must leave link
  ownership to moon.pkg". It reproduces with every ai_world change stashed, so
  do not chase it from this workstream. The objective's gate is the `pr` profile
  (green); `daily` additionally covers Skia native prebuild plumbing.
- **Run `sh scripts/check.sh --profile pr`, not just the validators you know.**
  Seven individual validators can all be green while the profile is red:
  generated docs go stale when a workspace member or catalog row is added, and
  `validate_source_file_policy` enforces a 1200 *logic-line* hard limit on files
  that were previously under it. Ratchets exist only for files that were
  already oversized; a file you pushed over must be split.
- **Release-mode `moon fmt` elides package aliases that equal the default.**
  `"x/app" @app` and `"x/llm_web" @llm_web` get stripped in the
  `wasm-gc/release/format` copy, so `moon fmt --check` never converges. Give them
  distinct aliases (`@world_app`, `@llm_web_gateway`).
- **A hand-written purity test does not stay true.** The original test pinned
  two messages; by round 12 there were 58 variants and three of them wrote
  through the input model (`WorldGenerated`, `DiscardMemory`, `AcceptMemory` —
  all `{ ..model, }` followed by `push_log`). `app/purity_wbtest.mbt` sweeps
  every variant against a fingerprint, so a new branch that forgets `fork()`
  fails immediately.
- **`{ ..model, }` followed by any push is always a bug.** Record update shares
  every `Array`; `fork()` is the only correct start for a mutating arm. When
  auditing, grep for `{ ..model,` and check the next ~16 lines for
  `push_log|push|set|clear|insert|pop` on the new binding.
- **Guard the property, not the instances.** Seven separate bugs were the same
  shape: state changed in `update` but never reached `commit_files`, or was
  dropped on read-back. `app/roundtrip_wbtest.mbt` now asserts
  `reload(commit(model)) == persisted_shape(model)` across user actions,
  excluding session-only state (draft, selection, editing buffer, notices,
  pending). A new feature that forgets to persist fails there instead of
  shipping. Verified by injecting three regressions — all three were caught.
- **Test the seams, not just the features.** Each feature passed its own tests
  while three of them were broken in combination (portraits never written,
  scenes dropped, branches dropped). `app/integrity_wbtest.mbt` exists to catch
  regressions at those crossings.
- **Folder names need a byte budget, not just character sanitising.**
  `world_folder_name` clips at `folder_name_max_bytes = 120` measured with
  `utf8_width`, because most file systems cap one path component at 255 bytes
  and CJK costs 3 each. Truncating by characters is not enough (a cut can land
  mid-character and produce invalid UTF-8), and assuming 3 bytes for every
  character over-truncates ASCII.
- **The workspace runs an unreleased `moui`.** `moui/moon.mod` says `0.2.3`,
  which is also the newest registry version — but the committed local tree has
  `text(wrap? : Bool = false)` while published `0.2.3`'s `text()` has no `wrap`
  parameter. Anything that must build *outside* this workspace (graduation to a
  standalone repo, a consumer app) cannot use such API until `moui` is
  republished under a new version.

## Where

`examples/ai_world/llm_web/bridge.mbt` (wasm-gc side),
`examples/ai_world/web_wasm/index.html` (`ai_world_host` + boot queue),
`examples/ai_world/macos_skia/main.mbt` (`@async/fs` worker twin),
`examples/ai_world/app/msg.mbt` + `effect.mbt` + `turn.mbt` + `creation.mbt`
(protocol / host effects / turn pipelines / wizard+generation),
`examples/ai_world/app/lore.mbt` (lorebook selection),
`docs/plans/active/ai-world-engine.md` (product state).
