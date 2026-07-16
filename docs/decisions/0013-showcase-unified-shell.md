# 0013: Showcase unified shell

- **Date**: 2026-07-16
- **Status**: Accepted
- **Related**: ADR 0012

## Context

After consolidating gallery/lab into four Showcase packages, the UI still felt
like four apps: root chrome plus each package's own header/nav, duplicate Mobile
Service Probe, and Diagnostics still exposing the old full catalog.

## Decision

1. **One chrome owner**: root shell only (workspace segment, catalog nav,
   history, list/detail on mobile).
2. Feature packages export **catalog metadata + `view_body`** only when hosted.
3. **Diagnostics catalog ≤ runtime labs** (inspector, runtime-renderer,
   advanced-rendering, text-diagnostics, interaction-lab).
4. **Mobile Service Probe** lives only under Platform.

## Consequences

- Clearer learning UX; package isolation retained for copy-paste.
- Dead dual-chrome code and non-diagnostic sections removed from the active
  navigation path.
