# 0077: Dev hot reload resets source-keyed host renderer caches on swap

- **Date**: 2026-11-25
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted)
- **Related**: ADR 0072, ADR 0074, ADR 0076; plan `dev-hot-reload-phase2c`

## Context

The native dev host keeps one renderer session across plugin generations. That
renderer caches by source identity for the process lifetime: decoded images by
path, failed image loads, retained and picture layers by `(key, revision)`,
shaped text by text plus font, paragraphs, paint memos, and loaded font-file
typefaces (including misses). ADR 0074 recorded the gap: a new generation may
rewrite an image or font at the same path, change shaping output for the same
text, or reuse a retained-layer key/revision with different pixels, and the host
still draws the previous generation's content.

## Decision

Reset the host renderer caches explicitly after every successful swap
(`docs/plans/active/dev-hot-reload-phase2c.md`). This is host-renderer work; ABI
v1 and the bridge payloads are unchanged.

1. `RendererSession` gains optional `reset_caches~ : (() -> Unit)?` and
   `RendererSession::reset_caches()`; it drops pending image requests, the
   remembered record generation and queued image events before invoking the
   renderer reset, so an in-flight completion from the old generation cannot
   repopulate a cleared cache.
2. `SkiaRasterRenderer::reset_host_caches()` clears the image and failed-image
   caches, the retained/picture layer caches and their admission/byte state, the
   shaping and paragraph caches, the paint memo, and the package-global font-file
   typeface cache. `ImageResourceLifecycle::reset()` clears records and bumps its
   generation so stale completions are ignored and loading/failed images retry.
   The GPU hybrid session resets both the GPU renderer and any inactive raster
   fallback.
3. The Skia font-file loader reads the file into owned bytes and builds the
   typeface with `Typeface::from_data` instead of keeping the platform manager's
   file mapping. The old mapping would fault (SIGBUS) when a generation
   truncates/rewrites the same path while the previous typeface is alive.
4. The generated host passes the bound session to
   `@devhost.install_renderer_cache_reset` via the provider
   `on_session_bound` hook; `clear_after_reload()` calls it on startup and after
   each successful plugin swap, and logs a `renderer caches reset after
   generation <n>` marker for smoke evidence.

## Options considered

- Reset on swap (chosen): one bounded re-decode/re-shape/replay on the first
  post-swap frame; no stale source identity can survive.
- mtime/key invalidation: font and layers have no reliable mtime and retained
  layers are not file-backed; content-revision keys were already insufficient.
- Recreate the renderer: needs an apphost/renderer lifecycle change and drops
  GPU resources for a cache-only problem.

## Consequences

- First post-swap frame costs a cache warm-up (images decode once, text shapes
  once, retained layers replay once); steady-state caching is unchanged.
- Font-file misses are retried each generation, so a newly added font appears.
  On the Linux prebuilt Skia stub the ordered font manager refuses caller-data
  typefaces; there the eviction path is covered and file content replacement is
  exercised on data-capable managers (local fontconfig build, macOS).
- `moui_devhost/host` owns the reset hook; a renderer without a reset path
  reports `false` and keeps the previous cache behaviour.
