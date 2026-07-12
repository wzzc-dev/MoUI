# ADR 0005: Mobile Host Channel Ownership

- Status: Accepted
- Date: 2026-07-11

## Context

Android JNI, iOS Obj-C++, and HarmonyOS NAPI need the same runtime-facing IME,
clipboard, semantics, and accessibility action behavior. Putting separate
state machines in each shell would make composition, async completion, and
dispose behavior diverge.

## Decision

`moui/backend/host` owns `MobileHostChannel` and the platform-neutral mobile
payloads. Runtime sessions synchronize IME state and revisioned flattened
semantics snapshots into the channel. Platform shells drain updates and return
typed responses through a stable C ABI.

IME requests carry text, UTF-16 selection/composition ranges, caret, and
candidate rectangle without changing desktop `window_core.ImeRequest`.
Clipboard requests are asynchronous and preserve request/session identity.
Semantics actions are validated and dispatched by `ElementId`; platform shells
must not re-hit-test screen coordinates.

## Consequences

- Platform shells own native API conversion and permission/user-interaction
  timing, while runtime semantics remain shared.
- Revisions suppress unchanged semantics traffic across JNI/Obj-C++/NAPI.
- Disposal invalidates outstanding responses so an old platform callback
  cannot mutate a new session.
- Matching-device evidence remains required before capabilities are declared
  available.
