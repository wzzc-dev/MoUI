# Plan: AI World Engine

- **Status**: active
- **Goal**: Grow `examples/ai_world` into a complete, web-first AI world
  engine product centered on text dialogue: a local **folder database** (one
  subfolder per world, multiple Markdown files inside), create-new-world, in-UI
  character setup, real provider conversation, AI-generated world content, and
  good baseline UX. The shared app package stays a pure TEA package; platform
  entrypoints stay thin.
- **Non-goals**: Multiplayer, streaming replies, voice, or framework changes —
  everything stays inside the example's app + app-private transport/host
  packages until a pattern is proven reusable.

## Goal ladder

1. **Folder database**: the whole database is a folder the player points at;
   each world is a subfolder with `world.md` (name, background prose, map
   places), `characters/<角色名>.md` (one card per file), and `world_book.md`
   (keyword entries). Files are human-editable and reloaded on the next open;
   one damaged file degrades alone. New world = a new folder from a template.
2. **Create and talk**: character setup from the UI writes
   `characters/<角色名>.md` and starts the conversation. With a provider key
   the replies come from the model; without one a deterministic scripted reply
   keeps the world playable (the previous no-key path left the turn pending
   forever).
3. **Web-first composition root**: `web_wasm` runs the app in the browser
   (wasm-gc + WebGPU); an app-private host bridge (`ai_world_host` in the
   page, `llm_web` MoonBit side) performs the OpenAI-compatible request and the
   folder/file operations (directory handle where available; localStorage as a
   folder-shaped fallback). `macos_skia` remains with a `@async/fs` gateway.
4. **AI-generated world**: a one-line idea returns a full world folder's
   content (background prose, characters, world book, map locations) which is
   parsed, applied, and written to disk; failure is a visible message, never a
   world reset. AI edits that touch the world commit like any other change.
5. **Image backgrounds (later)**: scenario gets optional portrait/background
   image references; web loads them through the image-resource channel.

## Slice design (folder DB + create/talk + AI world + web root)

- `app/world_store.mbt`: defensive Markdown codec — `WorldFiles` in/out of
  `Scenario`; never raises; template for new worlds.
- `app`: `WorldHost` struct of injected closures (pick_root / list_worlds /
  read_world / write_world), same injection style as `TurnRunner`. All world
  mutations (new world, new character, AI generation) apply locally and are
  committed through `write_world`; the result comes back as a typed message.
- `app`: creator panel + scripted no-key replies + `GenerateWorld` flow
  (LLM when configured, deterministic local template otherwise).
- `llm_web` + `web_wasm`: wasm-gc bridge — strings cross with the
  `begin_create_string`/`begin_read_string` handshake; `llm_submit` →
  `llm_complete(request_id, ok, body_text_id)`; fs requests return through
  `fs_complete(request_id, ok, detail_text_id)`; settings ride localStorage.
-	real-provider testing: an OpenAI-compatible endpoint configured in the UI
  is exercised end-to-end in the browser (chat + world generation); keys stay
  in session memory and are never committed.

## Acceptance

- [ ] Folder round-trip: parse template worlds, write them back, tolerate
      damaged files (`moon test examples/ai_world/app --target native`).
- [ ] Player creates a world and a character from the UI; conversation starts
      with the card's persona in the system prompt.
- [ ] Without a key the conversation still progresses (scripted replies).
- [ ] `moon build examples/ai_world/web_wasm --target wasm-gc` succeeds; in the
      browser: pick library → new world → create character → chat → the .md
      files appear (real folder or fallback store).
- [ ] A real provider (user-supplied endpoint/key, not committed) answers both
      the chat and the world generation on web.
- [ ] README and `docs/examples.md` describe the product; static validators
      pass.

## Decision log

| Date | Decision |
|------|----------|
| 2026-10-16 | Web LLM transport is an app-private `llm_web` host bridge, not `moonbitlang/async/http` (wasm-gc has no TLS path there). |
| 2026-10-16 | No-key conversations use a deterministic scripted reply instead of leaving the turn pending, keeping the example credential-free. |
| 2026-10-16 | AI world generation reuses the existing `TurnRunner` and `ImportScenario` import path; no second transport contract. |

## Progress

| Date | Note |
|------|------|
| 2026-10-16 | Plan drafted; native app (scenario/world book/context/LLM worker, macOS Skia root) already in place. |
| 2026-10-17 | Folder database shipped (`app/world_store.mbt`, 67 native tests green), character creation, scripted no-key replies, AI world generation, `web_wasm` + `llm_web` composition root, native `@async/fs` gateway. Browser-verified end-to-end with a real provider: new world, character, AI generation (3 characters / 4 lore entries from one line), and an in-character provider reply; reload re-reads the world from the library. |
| 2026-10-17 | Fixed the map draw-space bug: canvas `draw` callbacks paint in canvas-global coordinates (`frame` is the view's global rect), so the map content must offset by `frame.origin` and must not emit a surface-wide `Clear` (it erased every view drawn before it). Pinned by a `render_check` probe package that asserts the emitted `DrawCommand`s. |
| 2026-10-17 | Long replies wrap: MoUI's `text` view clips a single line, so the app wraps paragraphs via a pure `wrap_text` estimator (CJK ≈ 1em, ASCII ≈ 0.55em) into the existing transcript `scroll_view`; event log and captions use it too. Main-page model panel removed — the settings page is the single configuration surface. |
| 2026-10-17 | Settings moved to a dedicated page and persisted as `config.json` at the library root (`read_config`/`write_config` on `WorldHost`; page host + native gateway implementations). Config load rides on `WorldListArrived` — never on the boot-time init effect, which races the page's host-bridge queue. Browser-verified: save → reload → settings auto-restore → real provider chat with the restored key. Hidden-tab fetches are killed by the browser (`Failed to fetch`); the failure path clears pending and is retryable. |
| 2026-10-17 | Text wrapping moved into the framework: `text` gained opt-in `wrap` (real `TextSystem` paragraph metrics; CJK/grapheme-safe, `\n` hard breaks), so the app-side `wrap_text` estimator (CJK ≈ 1em, ASCII ≈ 0.55em) is deleted; `wrapped_body`/`wrapped_caption` are now one-line adapters. The event log no longer truncates entries — its fixed-height `scroll_view` already bounds it. `examples/ai_world` joined `moon.work` members so it builds against the workspace framework (previously pinned `wzzc-dev/moui@0.2.3`, which cannot carry app-invented features); `moon test examples/ai_world/app --target native` now works from the repo root, and the native run is `moon run examples/ai_world/macos_skia --target native`. |
| 2026-10-17 | Layout and journal persistence: the three-column workbench centers horizontally (`row(justify=Center)`, header totals the same `content_width`), and the composer is pinned to the bottom edge — the transcript `scroll_view` is flexible above it and a spring holds the empty selection state down as well. Conversations and the event log persist as `conversations.json` / `events.json` inside the world folder (`app/journal.mbt`, hand-owned JSON shape, defensive parse): every send/reply commits the journal beside the Markdown world files, a fresh open restores them (load replaces the in-memory journal; same-folder re-reads keep it), conversations for removed characters drop with a warning, and damaged files degrade alone. README + test counts updated (app 71, render_check 3). |
| 2026-10-17 | Native folder picking reaches parity: `macos_skia`'s `pick_root` now dispatches the macOS backend's FileDialog service (`HostFileDialogKind::PickDirectory`, NSOpenPanel `canChooseDirectories`) on the main thread, re-roots `library_root` (now a `Ref`) on selection, and re-lists via the fs worker; a cancel keeps the current library instead of losing the player's worlds. |
| 2026-10-17 | Context management upgraded per the analysis triage: (1) **rolling memory compression** — `plan_messages` now exposes the evicted tail, and an overflowing send (cap or budget) fires a second provider request that folds it into a per-character 120-char summary, injected as a 【此前】 system message and persisted in conversations.json; (3) **context presets** — the settings page exposes 紧凑/标准/宽裕 tiers mapping to 3000/6000/12000-char budgets via ModelConfig (hand-written tolerant from_json so old config.json files keep every field); (2) **semi-automatic long-term memory** — every 10 appends the provider proposes 0-2 world-book entries (deduped against the curated book and open drafts), shown as a 记忆草稿 panel where an explicit 采纳 writes them into world_book.md and commits the folder. App tests 71→78. |
