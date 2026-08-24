# ADR 0030: Overlay presentation host and neutral modal transport

- **Status**: Accepted
- **Date**: 2026-08-25

## Context

The former overlay helpers mixed layout, dismissal, semantics, and host
behavior. That made nested popovers and modal barriers inconsistent and left
native presentation paths with a second ownership model.

## Decision

Applications declare an ordered TEA-owned `PresentationSpec` list and compose
it only through `moui/views::overlay_host`. Runtime owns placement from stable
anchor snapshots, top-most input/focus ordering, modal semantics isolation, and
Escape/Back dispatch. A modal barrier's input blocking is independent from its
dismiss message.

Native presentation is negotiated through the neutral `moui/backend` host-modal
contract and the stateful `backend/common/host_modal::HostModalSession`.
Pending, rejected, unavailable, or stale requests retain the view-level
surface. Only an accepted request may become native-only, and host lifecycle
events return to the TEA boundary as typed events. The host renders the same
MoUI surface and never owns application state.

## Consequences

Stable anchor placement and modal semantics are consistent across hosts, while
platform presenters can be added independently. Native readiness remains
evidence-gated per platform; transparent view-level fallback is the default.
Exit visual-state retention and matching-host presenter implementations remain
follow-up work rather than hidden compatibility behavior.
