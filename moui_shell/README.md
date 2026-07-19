# `wzzc-dev/moui_shell`

`moui_shell` is the independently released native-shell SDK for MoUI. It is
not a general windowing library and it does not import `wzzc-dev/moui`.

```text
moui_shell/embedding       shared lifecycle, frame, wire, and compatibility API
moui_shell/android         Android typed API, embedder, and runner
moui_shell/ios             iOS typed API, embedder, and runner
moui_shell/harmonyos       HarmonyOS typed API, embedder, and runner
```

MoUI's Android, iOS, and HarmonyOS backends import `embedding` plus exactly
their own platform package. `window` remains the desktop/web window and event
loop dependency. The C embedding provider, public ABI header, compatibility
metadata, native consumers, and managed/ejected runners are all owned by this
package. MoUI installs runtime callbacks through `embedding` and never exports
the ABI table itself.

## Package API

- `wzzc-dev/moui_shell/embedding` owns session generation and surface epochs,
  frame coalescing, request correlation, wire envelopes, capabilities, and ABI
  negotiation.
- `wzzc-dev/moui_shell/android` exposes Android native-surface metadata.
- `wzzc-dev/moui_shell/ios` exposes iOS view metadata.
- `wzzc-dev/moui_shell/harmonyos` exposes HarmonyOS XComponent metadata.

All three platform descriptors require shell API 1, embedding API 1, and the
sole supported profile, `handheld`.

## App and release boundary

Applications pin matching `wzzc-dev/moui` and `wzzc-dev/moui_shell` versions.
Their `shell.json` uses schema v1 with `shell.profile: "handheld"` and a
platform `runnerMode` of `managed` or `ejected`. `moui shell eject <platform>`
writes `.moui-shell.json` with both package versions, API versions, a capability
snapshot digest, template digest, and content digests.

Run focused checks with:

```sh
moon check moui_shell/embedding --target native
node --test moui_shell/scripts/shell-config-schema.test.mjs
sh moui_shell/tests/run-embedding-api-v1-tests.sh
```
