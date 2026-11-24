# Plan: Dev hot reload renderer cache reset

- **Status**: active
- **ADR**: [0077](../../decisions/0077-dev-hot-reload-renderer-cache-reset.md)
- **Goal**: After a generation swap, host-renderer caches no longer serve images,
  fonts/shaping or retained layers whose content changed at the same source
  identity.
- **Non-goals**: ABI changes, bridge payload changes, renderer recreation, or
  changing production (non-dev) cache lifetimes.

## Delivery

1. Add optional `reset_caches` to `RendererSession`; clear pending image work
   before the renderer callback so old completions cannot refill caches.
2. Clear image/failed image, layer/picture layer, shaping, paragraph, paint memo
   and font-file typeface caches in `reset_host_caches`; reset the image
   lifecycle generation; reset GPU fallback caches too.
3. Load font files from owned bytes (`from_data`) so rewriting a hot-reload path
   cannot invalidate a live file mapping.
4. Wire `on_session_bound` through the Skia provider factories into
   `install_renderer_cache_reset`; invoke it from `clear_after_reload()` and log
   the generation marker used by the Linux smoke.

## Acceptance

- [x] Same-path image changed in place renders new content after
  `reset_caches`; without it the stale frame is asserted (`moui_skia_renderer`).
- [x] Retained layer at the same key/revision replays new content after reset
  (`moui_skia_renderer`).
- [x] Font-file miss/shape caches are cleared; content replacement is asserted
  where the host font manager loads caller data, elsewhere the eviction path is
  covered (`moui_skia_renderer`).
- [x] Session pending/queued image state and the devhost cleanup hook are
  covered by unit tests (`moui/render`, `moui_devhost/host`).
- [x] `scripts/linux-hot-reload-smoke.sh --run` passes and observes
  `renderer caches reset after generation 2/3/4` after the matching frame.
- [ ] macOS hot smoke is matching-host evidence; not runnable here.

## Log

| Date | Decision / progress |
|------|---------------------|
| 2026-11-25 | Reset-on-swap chosen over mtime keys and renderer recreation; reset invoked after successful bridge swaps. |
| 2026-11-25 | Cache reset, font-byte loading, generated-host wiring and Linux smoke marker landed. |
