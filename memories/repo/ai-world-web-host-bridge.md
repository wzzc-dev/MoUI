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

## Where

`examples/ai_world/llm_web/bridge.mbt` (wasm-gc side),
`examples/ai_world/web_wasm/index.html` (`ai_world_host` + boot queue),
`examples/ai_world/macos_skia/main.mbt` (`@async/fs` worker twin),
`examples/ai_world/app/msg.mbt` + `effect.mbt` (protocol / host effects, split
so the dead-message gate can scan this example),
`docs/plans/active/ai-world-engine.md` (product state).
