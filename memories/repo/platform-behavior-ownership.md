# Platform behavior ownership

- Cross-platform duplication is resolved in code; there is no similarity
  score, threshold, budget, allowlist, or expiry mechanism.
- `moui/backend/common/desktop` uniquely owns desktop request routing
  while delegating shared filesystem behavior to `host_services_native`.
- `moui/backend/common/native` uniquely owns native `@fs`
  text/binary/directory handlers and raw filesystem image-source bytes for both
  desktop backends and `embedded_runtime`.
- `moui/backend/common/embedded/services` uniquely owns mobile pending
  request ids, FIFO drain, completion, duplicate rejection, and dispose/cancel;
  mobile platform packages reach it only through `embedded_runtime`.
- `moui/backend/common/WindowHostCoordinator` uniquely owns
  desktop/Web window requests, applied resize state, host-event bookkeeping,
  runtime slots, surfaces, and application exit intent.
- `moui/backend/common/WindowFrameCoordinator` uniquely owns
  native/Web and embedded redraw completion/pending state, image scheduling,
  IME timing, and follow-up redraw.
- Linux surface/content decoration conversion stays in its surface closures.
- `wzzc-dev/window/internal/embedded_dispatch` owns only the physical native
  FIFO, raw surface projection, and ordered `ApplicationHandler` callback
  dispatch. It has no logical generation, primary routing, or exit intent.
- `moui/backend/common/EmbeddedWindowHostCoordinator` uniquely
  owns Android/iOS/HarmonyOS logical lifecycle phase, surface generation,
  primary routing, detach, and application exit intent.
- Mobile platform packages retain public `HostCmd`, native payload decoding,
  nominal window/event-loop adaptation, effect application, and ABI FFI only.
- `moui/backend/common/embedded/HostedWindowBackend` uniquely owns
  post-callback session/renderer assembly, embedded services, and IME adapters;
  `EmbeddedRuntimeHostBridge` owns service-update mapping, semantics,
  platform-view, and native transport sequencing in the same package.
- Keep `window/core` neutral and never re-export the internal embedded dispatch.
