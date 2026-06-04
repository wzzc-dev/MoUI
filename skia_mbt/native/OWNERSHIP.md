# Native Ownership Contract

`ownership.json` is the machine-readable contract between the MoonBit handle
types and the C++ Skia stub wrappers. It keeps the fallback build, real Skia
smoke jobs, and code review aligned on who releases every native pointer.

Validate it after changing `native/skia_stub_common.*`, `native/handles_*`, or
the public wrapper structs. Both native and unavailable handle declarations must
match the manifest:

```bash
bash scripts/verify-native-ownership.sh
```

```powershell
.\scripts\verify-native-ownership.ps1
```

MoonBit `extern "C"` declarations have a second gate:

```bash
bash scripts/verify-native-ffi-borrows.sh
```

```powershell
.\scripts\verify-native-ffi-borrows.ps1
```

That verifier rejects any non-primitive extern parameter that is missing
`#borrow(...)` or `#owned(...)`, plus stale annotations that name a primitive or
unknown parameter.

The release-facing capability gate ties these lower-level checks to runtime
evidence:

```bash
bash scripts/verify-native-capability-contract.sh
```

```powershell
.\scripts\verify-native-capability-contract.ps1
```

When adding a new native Canvas, Path, Text, Shader, Filter, GPU, or resource
handle capability, update `native/capabilities.json` in the same patch. Each
capability must name its native and unavailable MoonBit files, list any owned
handles from `ownership.json`, and either point to native-smoke markers or
record why runtime smoke evidence is not applicable.

## Capability Addition Checklist

Use this checklist for every new public native Canvas, Path, Text, Shader,
Filter, GPU, surface, or resource-cache API:

- Add the MoonBit native implementation and the unavailable fallback
  implementation in the same change. Their public API sets must match, and
  `native/moon.pkg` must keep native files on `native`/`llvm` and unavailable
  files on `wasm`/`wasm-gc`/`js`.
- Annotate every non-primitive `extern "C"` parameter with `#borrow(...)` or
  `#owned(...)`. If the API does not add externs or C++ stubs, say so in review
  notes so the borrow gate result is easy to interpret.
- If a new MoonBit handle or C++ wrapper is introduced, add the handle files,
  wrapper struct, factory, finalizer, and ownership kind to `ownership.json` in
  the same patch. Value-only MoonBit structs that hold existing handles do not
  need a new ownership entry.
- Add targeted MoonBit tests for the native path and the unavailable/fallback
  behavior. For public API changes, run `moon info` and check that
  `pkg.generated.mbti` changes only expose the intended API.
- Add a native-smoke marker for the runtime behavior, or add an explicit
  `non_smoke_rationale` in `native/capabilities.json` when runtime smoke
  evidence is not meaningful. New conditional behavior, such as optional
  SkShaper or future GPU backends, belongs in
  `native_smoke_conditional_capabilities` with a stable availability marker.
- Add the marker to `skia-platform-status.json`, synchronize
  `verify-native-smoke-log.sh` and `verify-native-smoke-log.ps1`, and update
  `verify-platform-status.*` when the marker becomes a required capability or
  expected value.
- Keep release status honest: platform acceptance can only be changed through
  `accept-platform-status.*` after downloaded Linux, macOS, or Windows real
  Skia artifacts pass the native smoke log verifier, acceptance log verifier,
  and real artifact verifier.
- Before committing, run the local gate set for the touched stage:
  `moon check`, `moon test`, `moon check --target all`,
  `moon -C scripts/native_smoke check`,
  `moon -C scripts/native_smoke build --target native`, ownership, borrow,
  fallback parity, smoke capability sync, platform status, capability contract,
  and ASan smoke dry-run when FFI or native-stub behavior changed.

## Ownership Kinds

- `owned_delete`: the MoonBit external object owns a heap allocation and its
  finalizer must call `delete wrapper->field` before clearing the field.
- `sk_refcnt`: the wrapper owns one Skia `SkRefCnt` reference and its finalizer
  must call `wrapper->field->unref()` before clearing the field.
- `borrowed_with_refcnt_owner`: the wrapper borrows a child pointer and keeps an
  owning Skia object alive by calling `owner_field->ref()` in the factory and
  `owner_field->unref()` in the finalizer. Canvas currently uses this pattern to
  borrow `SkCanvas*` from `SkSurface`.
- `regular_objects`: GC-allocated MoonBit runtime objects made with
  `moonbit_malloc`, not `moonbit_make_external_object`. They do not have C++
  finalizers. Their `pointer_field_count` and ordered `pointer_fields` list must
  match the C struct exactly, and the factory must encode the first pointer
  field offset in `moonbit_skia_regular_object_header(...)` before assigning
  every listed pointer field. Their `value_fields` list records non-pointer
  fields that must also exist in the struct and be initialized by the factory.
- `regular_runtime_objects`: regular MoonBit runtime objects that cross the C++
  ABI as values, arrays, or helper records rather than public MoonBit handle
  wrappers. These follow the same `moonbit_malloc`, `pointer_fields`, and
  `value_fields` checks as `regular_objects`; the verifier also rejects any
  `moonbit_malloc` factory in `native/skia_stub_common.cpp` that is not listed
  in one of these regular-object manifest sections.

When adding a new native handle, update `ownership.json` in the same patch as
the C++ wrapper. The verifier rejects undeclared external factories, undeclared
finalizers, missing MoonBit handle types, and release code that no longer
matches the declared ownership kind.
