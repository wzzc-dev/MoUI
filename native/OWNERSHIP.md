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
