#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/verify-native-ffi-borrows.sh [options]

Checks native MoonBit extern "C" declarations so every non-primitive parameter
is explicitly listed in #borrow(...) or #owned(...).

Options:
  --native-dir PATH     Native package directory. Defaults to native.
  -h, --help            Show this help.
EOF
}

native_dir="native"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --native-dir)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --native-dir" >&2
        usage >&2
        exit 2
      fi
      native_dir="$2"
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

resolved_native_dir="$(resolve_repo_path "$native_dir")"

python3 - "$resolved_native_dir" <<'PY'
import pathlib
import re
import sys

native_dir = pathlib.Path(sys.argv[1])
primitive_types = {
    "Bool",
    "Byte",
    "Char",
    "Double",
    "Float",
    "Int",
    "Int16",
    "Int64",
    "Int8",
    "UInt",
    "UInt16",
    "UInt64",
    "UInt8",
    "Unit",
}


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def split_top_level(text: str) -> list[str]:
    parts = []
    start = 0
    bracket_depth = 0
    paren_depth = 0
    for index, char in enumerate(text):
        if char == "[":
            bracket_depth += 1
        elif char == "]" and bracket_depth > 0:
            bracket_depth -= 1
        elif char == "(":
            paren_depth += 1
        elif char == ")" and paren_depth > 0:
            paren_depth -= 1
        elif char == "," and bracket_depth == 0 and paren_depth == 0:
            parts.append(text[start:index].strip())
            start = index + 1
    tail = text[start:].strip()
    if tail:
        parts.append(tail)
    return parts


def find_matching_paren(text: str, open_index: int) -> int:
    depth = 0
    for index in range(open_index, len(text)):
        char = text[index]
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return index
    fail("unterminated extern parameter list")


def parse_params(params_text: str, path: pathlib.Path, fn_name: str) -> dict[str, str]:
    params = {}
    for part in split_top_level(params_text):
        if not part:
            continue
        match = re.fullmatch(r"([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.+)", part, re.S)
        if not match:
            fail(f"{path}: could not parse parameter in {fn_name}: {part}")
        name = match.group(1)
        typ = match.group(2).strip()
        if name in params:
            fail(f"{path}: duplicate parameter {name} in {fn_name}")
        params[name] = typ
    return params


def is_non_primitive_type(typ: str) -> bool:
    normalized = re.sub(r"\s+", "", typ).rstrip("?")
    if normalized in primitive_types:
        return False
    return True


def parse_annotations(prefix: str, path: pathlib.Path, fn_name: str) -> tuple[dict[str, str], set[str]]:
    annotated = {}
    duplicate_annotations = set()
    for match in re.finditer(r"#(borrow|owned)\(([^)]*)\)", prefix):
        kind = match.group(1)
        for raw_name in match.group(2).split(","):
            name = raw_name.strip()
            if not name:
                continue
            previous = annotated.get(name)
            if previous is not None:
                duplicate_annotations.add(name)
            annotated[name] = kind
    if duplicate_annotations:
        fail(f"{path}: duplicate FFI ownership annotation(s) in {fn_name}: " + ", ".join(sorted(duplicate_annotations)))
    return annotated, duplicate_annotations


def check_block(block: str, path: pathlib.Path) -> None:
    extern_match = re.search(r'(?:pub\s+)?extern\s+"[Cc]"\s+fn\s+([A-Za-z_][A-Za-z0-9_]*)', block)
    if not extern_match:
        return

    fn_name = extern_match.group(1)
    open_index = block.find("(", extern_match.end())
    if open_index < 0:
        fail(f"{path}: missing parameter list for {fn_name}")
    close_index = find_matching_paren(block, open_index)
    params = parse_params(block[open_index + 1:close_index], path, fn_name)
    annotations, _duplicates = parse_annotations(block[:extern_match.start()], path, fn_name)

    param_names = set(params)
    unknown_annotations = sorted(set(annotations) - param_names)
    if unknown_annotations:
        fail(f"{path}: {fn_name} annotates unknown parameter(s): " + ", ".join(unknown_annotations))

    non_primitive = {name for name, typ in params.items() if is_non_primitive_type(typ)}
    primitive = set(params) - non_primitive

    missing = sorted(non_primitive - set(annotations))
    if missing:
        fail(f"{path}: {fn_name} is missing #borrow/#owned for non-primitive parameter(s): " + ", ".join(missing))

    unnecessary = sorted(primitive & set(annotations))
    if unnecessary:
        fail(f"{path}: {fn_name} annotates primitive parameter(s): " + ", ".join(unnecessary))


if not native_dir.is_dir():
    fail(f"native package directory is missing: {native_dir}")

files = sorted(native_dir.glob("*_native.mbt"))
if not files:
    fail(f"native package directory has no *_native.mbt files: {native_dir}")

for path in files:
    text = path.read_text(encoding="utf-8")
    for block in re.split(r"(?m)^///\|", text):
        check_block(block, path)

print(f"Verified native FFI borrow annotations in {native_dir}")
PY
