# Web Wasm-GC Platform Notes

The Web path is the canonical browser target: `wasm-gc + window/web + browser
WebGPU host imports`. It requires browser WebGPU. Startup fails clearly if
`navigator.gpu`, an adapter, or a device is unavailable. There is no JS-target
fallback branch. Browser Canvas measurement and WebGPU glyph drawing share the
same CSS `system-ui` font stack generated from `FontSpec`; app-registered embedded fonts
can be surfaced through browser font APIs, but remote font loading is not part
of the backend contract.
WebGPU entrypoints may opt into `webgpu.textSelection.enabled` when a canvas
page needs browser-native selection/copy for drawn static text. That creates a
transparent DOM text layer from each presented frame's `DrawText` bounds while
leaving rendering, wheel scrolling, and app interaction on the canvas path.
The active Web runtime service bridge opens external URLs through the browser
host import, which calls `window.open(..., "_blank", "noopener,noreferrer")`
and reports failure when the browser blocks the popup or the API is unavailable.
Web copy/cut shortcuts are forwarded from the hidden text input to the runtime
and write selected text through a browser host import using the user-gesture
`document.execCommand("copy")` path. Focused browser text input can still paste
through normal input events; app-level async clipboard reads use
`navigator.clipboard.readText()` and complete through `HostServiceAsyncQueue`
when browser permissions allow it.
The Web host now advertises IME readiness because the local `window/web` bridge
supports browser composition lifecycle events and accepts MoUI
`TextInputSession` IME requests for enabling input, cursor-area updates, and
surrounding-text updates. This is browser text-input observation; it does not make
browser text shaping deterministic across browsers.
The active Web runtime now drains pending async service requests into browser
callbacks. Clipboard reads complete through exported wasm callback functions.
When `showOpenFilePicker` is available, open-file selection keeps the browser
file handle, reads the chosen `File.text()`, and caches the content under the
browser-exposed file name so app-owned handlers can follow the file-dialog
selection with the shared text-file read service. The hidden file input remains
the fallback open/directory path; fallback open can import text but does not
produce a writable handle, while directory selection still returns
browser-exposed relative names. Typed completions are delivered through
`HostAppServices::completion_subscription`. Save dialogs use the File System
Access API when `showSaveFilePicker` is available, keep the selected handle,
and route later Web text-file writes through `createWritable()`; without a
writable handle, the write completes as unavailable. Canceled file pickers
return an empty selection.
The browser host import reads `prefers-color-scheme` at startup and listens for
media-query changes through `window/web`; MoUI maps those events into runtime
environment color-scheme updates.
Browser file drag/drop events on the canvas are normalized through
`HostEvent::DragDrop` and dispatched to `View::on_file_drop` targets. The
Web platform receives browser-exposed file names or relative names rather than
native filesystem paths.
The Web backend intentionally does not implement `web_view` with an iframe
overlay. Browser wasm-gc hosts report native WebView unavailable, and examples
that share WebView app logic should render a fallback surface on Web.
The Web browser runtime normalizes the initial route from `?route=`,
`?section=`, or the hash, listens for `popstate`, and dispatches those route
events through the optional `HostRouteSource` passed in `WebAppOptions`.
Entrypoints can keep shared app logic platform-neutral by translating abstract
route commands into `web_history_push_route`, `web_history_replace_route`,
`web_history_back`, and `web_history_forward` at the Web edge.
See [Text system](text-system.md) for the shared runtime and renderer text
contract.

The reusable browser runtime assets live under `backend/web/*.js`. Each
`examples/*/web_wasm/` package is only the app-specific Web entrypoint and
supplies the example-specific wasm URL. The canvas host reports logical event
coordinates after DPR mapping and avoids CSS transforms, borders, and padding so
resize and input coordinates stay stable. The browser runtime treats native
pointer events as authoritative when the browser supports `PointerEvent` and
does not synthesize MoUI pointer activation from compatibility mouse/click
fallbacks in that mode. Older environments without pointer-event support still
use mouse/click fallback with transaction de-duplication, including delayed
fallback events whose rounded coordinates drift slightly. This keeps a slow app
rebuild after a button release from replaying the same browser click as a
second MoUI pointer activation.
Touch drags on the canvas synthesize wheel-style scroll deltas before browser
fallback panning, so `scroll_view` surfaces such as the website homepage can
scroll from mobile swipe gestures while still using the same app-owned
`on_scroll` path as desktop wheels and trackpads.
