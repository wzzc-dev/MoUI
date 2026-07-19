# Embedding API v1

Managed Android, iOS, and HarmonyOS shells use the same process-lifetime C
function table declared in `moui_shell/include/moui_embedding_api_v1.h`.
Platform code must call `moui_embedding_get_api_v1()` once, validate the
result with `moui_embedding_api_v1_is_compatible()`, and dispatch only
through that table. MoonBit objects and strings never cross the shell boundary.

## Negotiation And Ownership

- `abi_version` must be `1`.
- `struct_size` must be at least `MOUI_EMBEDDING_API_V1_REQUIRED_SIZE`.
- Every required capability and function pointer must be present. The scroll
  capability and pointer must either both be present or both be absent.
- Input text and byte views are borrowed for one call and use explicit lengths.
- Returned UTF-8 buffers include an explicit length and release callback. The
  shell invokes the callback exactly once with the original context, data, and
  length.

The adapter owns all MoonBit conversion references and releases each exactly
once. Shell code must not call `moonbit_incref`, `moonbit_decref`, or depend on
MoonBit string representation.

`moui_shell/embedding` owns the process-local callback state, every
`moui_embedding_*` MoonBit implementation used by the native adapter, and the
canonical `link.native.exports` declaration in its `moon.pkg`. A current
MoonBit native dependency package does not promote those declarations into the
final executable's C symbol table. Therefore each mobile executable root must
mirror the canonical list in its own `moon.pkg` and define an identical
`embedding_exports.mbt` whose functions do nothing except call the same-named
`@shell_embedding` function. This is a linker reachability shim, not ownership
of the ABI: app roots must not add callback state, conversion, branching,
adapter construction, or runtime behavior there.

## Lifecycle

`initialize` is process-wide and idempotent. A surface epoch begins with
`attach_surface` and ends with `detach_surface`. Detach disposes the presenter,
image coordinator, pending host requests, and epoch generation, but preserves
the `AppRuntime`. A later attach creates a new generation over the same app
state.

`destroy_application` is terminal and executes its MoonBit destroy hook once.
Every later session call returns
`MOUI_EMBEDDING_API_ERROR_APPLICATION_DESTROYED_V1`. Embedding API v1 supports
one application scene; a second concurrent scene must be rejected by the
canonical shell.

## Host Wire v1

`take_host_update_envelope_json` returns one UTF-8 envelope:

```json
{
  "schemaVersion": 1,
  "sessionGeneration": 42,
  "updates": []
}
```

The shell must retain `sessionGeneration` with every asynchronous request and
revisioned PlatformView snapshot. Generic control responses use
`dispatch_host_response_envelope`.

A PlatformView event has this shape:

```json
{
  "schemaVersion": 1,
  "sessionGeneration": 42,
  "response": {
    "kind": "platform-view",
    "revision": 7,
    "viewKind": "camera.preview",
    "id": "preview",
    "event": {
      "name": "ready",
      "value": "yes",
      "detail": "",
      "flag": true
    }
  }
}
```

The runtime rejects a PlatformView event when its generation, snapshot
revision, kind, or id is stale.

A plugin PlatformChannel completion has this shape:

```json
{
  "schemaVersion": 1,
  "sessionGeneration": 42,
  "response": {
    "kind": "platform-channel",
    "requestId": 19,
    "status": "ok",
    "payload": "{\"started\":true}"
  }
}
```

`status` is `ok`, `error`, or `unavailable`. The async queue accepts one
completion for a pending request and rejects duplicate, cancelled, unknown, or
late responses.

Clipboard image data remains a fixed C buffer rather than JSON. The
`complete_clipboard` function therefore takes `session_generation` before its
request id; a completion from a detached epoch is rejected before it can match
a new request.

All runners consume the v1 table, update envelope, and generation-aware
clipboard completion. The embedding table is the only supported shell ABI.
