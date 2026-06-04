#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/verify-native-ownership.sh [options]

Checks native/ownership.json against the MoonBit handle declarations and C++
stub wrapper/finalizer implementation.

Options:
  --manifest PATH       Ownership manifest. Defaults to native/ownership.json.
  --header PATH         Native common header. Defaults to the manifest value.
  --source PATH         Native common C++ source. Defaults to the manifest value.
  --handles PATH        MoonBit handle declarations. Defaults to the manifest value.
  --types PATH          MoonBit public wrapper types. Defaults to the manifest value.
  -h, --help            Show this help.
EOF
}

manifest="native/ownership.json"
header=""
source=""
handles=""
types=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --manifest" >&2
        usage >&2
        exit 2
      fi
      manifest="$2"
      shift 2
      ;;
    --header)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --header" >&2
        usage >&2
        exit 2
      fi
      header="$2"
      shift 2
      ;;
    --source)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --source" >&2
        usage >&2
        exit 2
      fi
      source="$2"
      shift 2
      ;;
    --handles)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --handles" >&2
        usage >&2
        exit 2
      fi
      handles="$2"
      shift 2
      ;;
    --types)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --types" >&2
        usage >&2
        exit 2
      fi
      types="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

resolve_repo_path() {
  local path="$1"
  case "$path" in
    /*) printf '%s\n' "$path" ;;
    *) printf '%s\n' "$repo_root/$path" ;;
  esac
}

resolved_manifest="$(resolve_repo_path "$manifest")"
resolved_header="${header:+$(resolve_repo_path "$header")}"
resolved_source="${source:+$(resolve_repo_path "$source")}"
resolved_handles="${handles:+$(resolve_repo_path "$handles")}"
resolved_types="${types:+$(resolve_repo_path "$types")}"

python3 - "$repo_root" "$resolved_manifest" "$resolved_header" "$resolved_source" "$resolved_handles" "$resolved_types" <<'PY'
import json
import pathlib
import re
import sys

repo_root = pathlib.Path(sys.argv[1])
manifest_path = pathlib.Path(sys.argv[2])
header_override = sys.argv[3]
source_override = sys.argv[4]
handles_override = sys.argv[5]
types_override = sys.argv[6]


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def resolve(path: str) -> pathlib.Path:
    candidate = pathlib.Path(path)
    if candidate.is_absolute():
        return candidate
    return repo_root / candidate


def read_text(path: pathlib.Path, label: str) -> str:
    if not path.is_file():
        fail(f"{label} is missing: {path}")
    return path.read_text(encoding="utf-8")


try:
    manifest = json.loads(read_text(manifest_path, "native ownership manifest"))
except json.JSONDecodeError as error:
    fail(f"native ownership manifest JSON is invalid: {error}")

if manifest.get("schema_version") != 1:
    fail(f"unsupported native ownership schema_version: {manifest.get('schema_version')}")

header_path = pathlib.Path(header_override) if header_override else resolve(manifest.get("native_header", ""))
source_path = pathlib.Path(source_override) if source_override else resolve(manifest.get("native_source", ""))
if handles_override:
    handle_paths = [pathlib.Path(handles_override)]
else:
    handle_files = manifest.get("moonbit_handle_files")
    if handle_files is None:
        handle_files = [manifest.get("moonbit_handle_file", "")]
    if not isinstance(handle_files, list) or not handle_files:
        fail("native ownership manifest is missing moonbit_handle_files")
    handle_paths = [resolve(path) for path in handle_files]
types_path = pathlib.Path(types_override) if types_override else resolve(manifest.get("moonbit_type_file", ""))

header = read_text(header_path, "native ownership header")
source = read_text(source_path, "native ownership source")
types = read_text(types_path, "MoonBit native type file")

external_wrappers = manifest.get("external_wrappers")
regular_objects = manifest.get("regular_objects", [])
regular_runtime_objects = manifest.get("regular_runtime_objects", [])
if not isinstance(external_wrappers, list) or not external_wrappers:
    fail("native ownership manifest is missing external_wrappers")
if not isinstance(regular_objects, list):
    fail("native ownership manifest regular_objects must be a list")
if not isinstance(regular_runtime_objects, list):
    fail("native ownership manifest regular_runtime_objects must be a list")


def ensure_unique(entries, key: str, label: str) -> None:
    seen = set()
    for entry in entries:
        value = str(entry.get(key, "")).strip()
        if not value:
            fail(f"{label} entry is missing {key}")
        if value in seen:
            fail(f"duplicate {label} {key}: {value}")
        seen.add(value)


handle_entries = external_wrappers + regular_objects
regular_manifest_entries = regular_objects + regular_runtime_objects
all_manifest_entries = external_wrappers + regular_manifest_entries

for key in ("name", "wrapper_struct"):
    ensure_unique(all_manifest_entries, key, "native ownership")
for key in ("moonbit_handle", "moonbit_type"):
    ensure_unique(handle_entries, key, "native ownership")
ensure_unique(all_manifest_entries, "factory", "native ownership")
ensure_unique(external_wrappers, "finalizer", "external wrapper")

allowed_ownership = {"owned_delete", "sk_refcnt", "borrowed_with_refcnt_owner"}


def find_braced_body(text: str, pattern: str, label: str) -> str:
    match = re.search(pattern + r"\s*\{", text, re.S)
    if not match:
        fail(f"missing {label}")
    index = match.end()
    depth = 1
    while index < len(text):
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[match.end():index]
        index += 1
    fail(f"unterminated {label}")


def require_regex(text: str, pattern: str, message: str) -> None:
    if not re.search(pattern, text, re.S):
        fail(message)


def require_contains(text: str, needle: str, message: str) -> None:
    if needle not in text:
        fail(message)


def moonbit_type_body(type_name: str) -> str:
    return find_braced_body(
        types,
        rf"\bpub\(all\)\s+struct\s+{re.escape(type_name)}\s*",
        f"MoonBit wrapper type {type_name}",
    )


def c_struct_body(struct_name: str) -> str:
    return find_braced_body(
        header,
        rf"\bstruct\s+{re.escape(struct_name)}\s*",
        f"C++ wrapper struct {struct_name}",
    )


manifest_handles = {entry["moonbit_handle"] for entry in handle_entries}
for handles_path in handle_paths:
    handles = read_text(handles_path, "MoonBit native handle file")
    declared_handles = set(re.findall(r"\bpriv\s+type\s+([A-Za-z_][A-Za-z0-9_]*Handle)\b", handles))
    missing_handles = sorted(manifest_handles - declared_handles)
    if missing_handles:
        fail(f"ownership manifest references missing MoonBit handles in {handles_path}: " + ", ".join(missing_handles))
    extra_handles = sorted(declared_handles - manifest_handles)
    if extra_handles:
        fail(f"MoonBit handles in {handles_path} are missing from ownership manifest: " + ", ".join(extra_handles))

found_factory_pairs = {
    factory
    for _struct_name, factory in re.findall(
        r"\b(MoonbitSkia[A-Za-z0-9_]+)\s*\*\s*(moonbit_skia_make_[A-Za-z0-9_]+_wrapper)\s*\(",
        source,
    )
}
expected_factories = {entry["factory"] for entry in external_wrappers}
missing_factories = sorted(expected_factories - found_factory_pairs)
if missing_factories:
    fail("ownership manifest references missing external wrapper factories: " + ", ".join(missing_factories))
extra_factories = sorted(found_factory_pairs - expected_factories)
if extra_factories:
    fail("external wrapper factories are missing from ownership manifest: " + ", ".join(extra_factories))

expected_regular_factories = {entry["factory"] for entry in regular_manifest_entries}
found_regular_factories = set()
for match in re.finditer(
    r"\b(MoonbitSkia[A-Za-z0-9_]+)\s*\*\s*(moonbit_skia_make_[A-Za-z0-9_]+)\s*\([^{}]*\)\s*\{",
    source,
):
    factory = match.group(2)
    factory_body = find_braced_body(
        source,
        rf"\b{re.escape(factory)}\b[^{{}}]*",
        f"regular object factory {factory}",
    )
    if "moonbit_malloc" in factory_body:
        found_regular_factories.add(factory)
missing_regular_factories = sorted(expected_regular_factories - found_regular_factories)
if missing_regular_factories:
    fail("ownership manifest references missing regular object factories: " + ", ".join(missing_regular_factories))
extra_regular_factories = sorted(found_regular_factories - expected_regular_factories)
if extra_regular_factories:
    fail("moonbit_malloc regular object factories are missing from ownership manifest: " + ", ".join(extra_regular_factories))

found_finalizers = set(re.findall(r"\bstatic\s+void\s+(moonbit_skia_[A-Za-z0-9_]+_finalize)\s*\(", source))
expected_finalizers = {entry["finalizer"] for entry in external_wrappers}
missing_finalizers = sorted(expected_finalizers - found_finalizers)
if missing_finalizers:
    fail("ownership manifest references missing finalizers: " + ", ".join(missing_finalizers))
extra_finalizers = sorted(found_finalizers - expected_finalizers)
if extra_finalizers:
    fail("native finalizers are missing from ownership manifest: " + ", ".join(extra_finalizers))

for entry in external_wrappers:
    name = entry["name"]
    handle = entry["moonbit_handle"]
    type_name = entry["moonbit_type"]
    struct_name = entry["wrapper_struct"]
    field = entry["field"]
    factory = entry["factory"]
    finalizer = entry["finalizer"]
    ownership = entry["ownership"]
    if ownership not in allowed_ownership:
        fail(f"{name} has unsupported ownership kind: {ownership}")

    type_body = moonbit_type_body(type_name)
    require_regex(type_body, rf"\bpriv\s+handle\s*:\s*{re.escape(handle)}\b", f"{type_name} does not store {handle}")
    if ownership == "borrowed_with_refcnt_owner":
        owner_field = entry.get("moonbit_owner_field")
        owner_type = entry.get("owner_type")
        if not owner_field or not owner_type:
            fail(f"{name} borrowed owner contract is missing moonbit_owner_field/owner_type")
        require_regex(
            type_body,
            rf"\bpriv\s+{re.escape(owner_field)}\s*:\s*{re.escape(owner_type)}\?",
            f"{type_name} does not retain optional owner {owner_field}: {owner_type}?",
        )

    c_body = c_struct_body(struct_name)
    require_regex(c_body, rf"\b{re.escape(field)}\s*;", f"{struct_name} is missing field {field}")
    if ownership == "borrowed_with_refcnt_owner":
        owner_field = entry.get("owner_field")
        if not owner_field:
            fail(f"{name} borrowed owner contract is missing owner_field")
        require_regex(c_body, rf"\b{re.escape(owner_field)}\s*;", f"{struct_name} is missing owner field {owner_field}")

    factory_body = find_braced_body(source, rf"\b{re.escape(factory)}\b[^{{}}]*", f"factory {factory}")
    require_contains(factory_body, "moonbit_make_external_object", f"{factory} must allocate a MoonBit external object")
    require_contains(factory_body, finalizer, f"{factory} does not register finalizer {finalizer}")
    require_contains(factory_body, f"sizeof({struct_name})", f"{factory} does not allocate sizeof({struct_name})")
    require_regex(factory_body, rf"wrapper->{re.escape(field)}\s*=", f"{factory} does not initialize {field}")

    finalizer_body = find_braced_body(source, rf"\bstatic\s+void\s+{re.escape(finalizer)}\s*\([^)]*\)", f"finalizer {finalizer}")
    require_contains(finalizer_body, f"static_cast<{struct_name}*>", f"{finalizer} does not cast to {struct_name}")
    require_regex(finalizer_body, rf"wrapper->{re.escape(field)}\s*=\s*nullptr\s*;", f"{finalizer} does not clear {field}")

    if ownership == "owned_delete":
        require_contains(finalizer_body, f"delete wrapper->{field};", f"{finalizer} must delete owned {field}")
    elif ownership == "sk_refcnt":
        require_contains(finalizer_body, f"wrapper->{field}->unref();", f"{finalizer} must unref {field}")
    elif ownership == "borrowed_with_refcnt_owner":
        owner_field = entry["owner_field"]
        require_contains(factory_body, f"wrapper->{owner_field}->ref();", f"{factory} must ref owner field {owner_field}")
        require_contains(finalizer_body, f"wrapper->{owner_field}->unref();", f"{finalizer} must unref owner field {owner_field}")
        require_regex(finalizer_body, rf"wrapper->{re.escape(owner_field)}\s*=\s*nullptr\s*;", f"{finalizer} does not clear owner field {owner_field}")
        if re.search(rf"\bdelete\s+wrapper->{re.escape(field)}\s*;", finalizer_body):
            fail(f"{finalizer} must not delete borrowed field {field}")

def require_string_list(entry, key: str, name: str) -> list[str]:
    fields = entry.get(key)
    if not isinstance(fields, list) or any(not isinstance(field, str) or not field.strip() for field in fields):
        fail(f"{name} regular object is missing {key} list")
    return fields


def verify_regular_object(entry, require_moonbit_wrapper: bool) -> None:
    name = entry["name"]
    struct_name = entry["wrapper_struct"]
    factory = entry["factory"]
    allocation = entry.get("allocation")
    pointer_field_count = entry.get("pointer_field_count")
    pointer_fields = require_string_list(entry, "pointer_fields", name)
    value_fields = require_string_list(entry, "value_fields", name)
    if allocation != "moonbit_malloc":
        fail(f"{name} regular object uses unsupported allocation: {allocation}")
    if not isinstance(pointer_field_count, int) or pointer_field_count < 0:
        fail(f"{name} regular object is missing non-negative pointer_field_count")
    if len(pointer_fields) != pointer_field_count:
        fail(
            f"{name} regular object pointer_fields length does not match "
            f"pointer_field_count={pointer_field_count}"
        )

    if require_moonbit_wrapper:
        handle = entry["moonbit_handle"]
        type_name = entry["moonbit_type"]
        type_body = moonbit_type_body(type_name)
        require_regex(type_body, rf"\bpriv\s+handle\s*:\s*{re.escape(handle)}\b", f"{type_name} does not store {handle}")

    c_body = c_struct_body(struct_name)
    actual_pointer_fields = re.findall(r"\*\s+([A-Za-z_][A-Za-z0-9_]*)\s*;", c_body)
    actual_pointer_field_count = len(actual_pointer_fields)
    if actual_pointer_field_count != pointer_field_count:
        fail(
            f"{name} regular object pointer_field_count mismatch: "
            f"manifest={pointer_field_count} struct={actual_pointer_field_count}"
        )
    if actual_pointer_fields != pointer_fields:
        fail(
            f"{name} regular object pointer_fields mismatch: "
            f"manifest={pointer_fields} struct={actual_pointer_fields}"
        )
    for value_field in value_fields:
        require_regex(
            c_body,
            rf"\b{re.escape(value_field)}\s*;",
            f"{struct_name} is missing value field {value_field}",
        )
    factory_body = find_braced_body(source, rf"\b{re.escape(factory)}\b[^{{}}]*", f"regular object factory {factory}")
    require_contains(factory_body, "moonbit_malloc", f"{factory} must use moonbit_malloc")
    require_contains(
        factory_body,
        "moonbit_skia_regular_object_header",
        f"{factory} must initialize a regular object header",
    )
    require_regex(
        factory_body,
        rf"moonbit_skia_regular_object_header\s*\([^;]*,\s*{pointer_field_count}\s*,\s*0\s*\)",
        f"{factory} must encode pointer_field_count={pointer_field_count} in its object header",
    )
    if pointer_field_count > 0:
        first_pointer_field = pointer_fields[0]
        require_contains(
            factory_body,
            f"offsetof({struct_name}, {first_pointer_field})",
            f"{factory} must encode pointer-field offset with offsetof({struct_name}, {first_pointer_field})",
        )
    else:
        require_contains(
            factory_body,
            f"sizeof({struct_name}) >> 2",
            f"{factory} must encode scalar-only header size with sizeof({struct_name}) >> 2",
        )
    for field in pointer_fields + value_fields:
        require_regex(
            factory_body,
            rf"\b[A-Za-z_][A-Za-z0-9_]*->{re.escape(field)}\s*=",
            f"{factory} must initialize field {field}",
        )
    if "moonbit_make_external_object" in factory_body:
        fail(f"{factory} must not allocate a MoonBit external object")
    finalizer_name = factory.replace("make_", "").replace("_run", "_run_finalize")
    if finalizer_name in source:
        fail(f"{name} regular object unexpectedly has a finalizer: {finalizer_name}")


for entry in regular_objects:
    verify_regular_object(entry, require_moonbit_wrapper=True)
for entry in regular_runtime_objects:
    verify_regular_object(entry, require_moonbit_wrapper=False)

print(f"Verified native ownership manifest: {manifest_path}")
PY
