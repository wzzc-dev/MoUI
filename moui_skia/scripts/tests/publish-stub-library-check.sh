#!/usr/bin/env bash
# Offline regression test for the recipe-aware, line-ending-stable staleness
# check in publish-stub-library.sh.
#
# `--check` is the release workflow's no-op gate, so two mistakes are cheap to
# make and expensive in production:
#   - a recipe-only change (workflow, build.mbtx, publish script) must mark every
#     platform stale instead of silently keeping an old archive;
#   - a CRLF checkout (windows-latest) must fingerprint like an LF checkout,
#     otherwise the Windows leg rebuilds and rewrites its lock entry every run.
# The test builds a throwaway module plus the repo-relative recipe files, hashes
# an LF tree and a CRLF copy of it, and walks the lock states: matching entry,
# entry without `recipe_sha256` (the one-time migration), changed recipe, and
# changed sources. No network, no Skia build, no archive packaging.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
module_root="$(cd "$script_dir/../.." && pwd)"
publish_script="$module_root/scripts/publish-stub-library.sh"

if [[ ! -f "$publish_script" ]]; then
  echo "missing publish script: $publish_script" >&2
  exit 1
fi
for command in python3; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "missing required command: $command" >&2
    exit 1
  fi
done

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/moui-skia-stub-check-test.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

failures=0
check() {
  local description="$1"
  local expected_status="$2"
  local actual_status="$3"
  local detail="${4:-}"
  if [[ "$actual_status" == "$expected_status" ]]; then
    echo "PASS $description"
    return 0
  fi
  echo "FAIL $description (expected $expected_status, got $actual_status) $detail" >&2
  failures=$((failures + 1))
}

# Build a module tree shaped like the real repository: the publish script, the
# three recipe files relative to a repo root above the module, and two native
# sources. The workflow and build.mbtx are only read, never run, so stand-in
# contents are enough.
make_fixture() {
  local root="$1"
  mkdir -p "$root/moui_skia/scripts" "$root/moui_skia/native" "$root/.github/workflows"
  cp "$publish_script" "$root/moui_skia/scripts/publish-stub-library.sh"
  printf '// stub build recipe v1\n' > "$root/moui_skia/build.mbtx"
  printf 'name: stub-release\n' > "$root/.github/workflows/moui-skia-stub-release.yml"
  printf '#include "stub.h"\nint stub(void) { return 1; }\n' > "$root/moui_skia/native/stub.cpp"
  printf '#pragma once\nint stub(void);\n' > "$root/moui_skia/native/stub.h"
}

run_probe() (
  cd "$1/moui_skia"
  bash scripts/publish-stub-library.sh --print-sources \
    --platform linux --config Release --arch x64
)

run_check() (
  cd "$1/moui_skia"
  bash scripts/publish-stub-library.sh --check \
    --platform linux --config Release --arch x64
)

# Write the lock the check reads. LOCK_RECIPE_FIELD is `yes` (both digests),
# `no` (the pre-recipe shape), or `missing` (no stub_libraries entry at all).
write_lock() {
  LOCK_PATH="$1" LOCK_SOURCES="$2" LOCK_RECIPE="$3" LOCK_RECIPE_FIELD="$4" \
    python3 - <<'PY'
import json
import os
import pathlib

lock = {
    "schema_version": 2,
    "default_provider": "release",
    "default_config": "Release",
    "default_link_mode": "static",
    "providers": {
        "release": {
            "kind": "github-release",
            "owner": "wzzc-dev",
            "repo": "skia",
            "tag": "test",
            "stub_libraries": {},
        }
    },
}
if os.environ["LOCK_RECIPE_FIELD"] != "missing":
    node = {
        "name": "MoUISkiaStub-test-linux-Release-x64.zip",
        "url": "https://example.invalid/MoUISkiaStub-test-linux-Release-x64.zip",
        "sha256": "0" * 64,
        "size": 1,
        "sources_sha256": os.environ["LOCK_SOURCES"],
        "library_names": ["libmoui_skia_stub.a"],
    }
    if os.environ["LOCK_RECIPE_FIELD"] == "yes":
        node["recipe_sha256"] = os.environ["LOCK_RECIPE"]
    lock["providers"]["release"]["stub_libraries"] = {
        "linux": {"Release": {"x64": node}}
    }
pathlib.Path(os.environ["LOCK_PATH"]).write_text(
    json.dumps(lock, indent=2) + "\n", encoding="utf-8"
)
PY
}

probe_value() {
  local output="$1"
  local key="$2"
  printf '%s\n' "$output" | sed -n "s/^${key}=//p" | tail -n 1
}

fixture="$work_dir/lf"
make_fixture "$fixture"
lock="$fixture/moui_skia/skia-provider-lock.json"
# `--print-sources` still resolves the release tag from the lock, so seed one
# before probing; every later case rewrites it with the expected digests.
write_lock "$lock" pending pending yes

lf_probe="$(run_probe "$fixture")"
lf_sources="$(probe_value "$lf_probe" MOUI_SKIA_STUB_SOURCES_SHA256)"
lf_recipe="$(probe_value "$lf_probe" MOUI_SKIA_STUB_RECIPE_SHA256)"

# 1. The probe reports both digests, each a sha256.
if [[ "$lf_sources" =~ ^[0-9a-f]{64}$ && "$lf_recipe" =~ ^[0-9a-f]{64}$ ]]; then
  check "probe reports sha256 sources and recipe digests" 0 0
else
  check "probe reports sha256 sources and recipe digests" 0 1 "$lf_probe"
fi

# 2. A CRLF copy of the same tree fingerprints identically. Converting only the
#    source/recipe files keeps the copied .sh executable; `.gitattributes` also
#    pins `*.sh` to LF, and Windows checkouts keep it that way.
crlf="$work_dir/crlf"
cp -r "$fixture" "$crlf"
python3 - "$crlf" <<'PY'
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
relative_paths = [
    "moui_skia/native/stub.cpp",
    "moui_skia/native/stub.h",
    "moui_skia/build.mbtx",
    ".github/workflows/moui-skia-stub-release.yml",
]
for relative in relative_paths:
    path = root / relative
    data = path.read_bytes()
    if b"\r" in data:
        raise SystemExit(f"{relative} already contains CR")
    path.write_bytes(data.replace(b"\n", b"\r\n"))
PY
if grep -q $'\r' "$crlf/moui_skia/native/stub.cpp"; then
  check "CRLF fixture really has CRLF sources" 0 0
else
  check "CRLF fixture really has CRLF sources" 0 1
fi
crlf_probe="$(run_probe "$crlf")"
crlf_sources="$(probe_value "$crlf_probe" MOUI_SKIA_STUB_SOURCES_SHA256)"
crlf_recipe="$(probe_value "$crlf_probe" MOUI_SKIA_STUB_RECIPE_SHA256)"
check "CRLF sources fingerprint like LF sources" "$lf_sources" "$crlf_sources"
check "CRLF recipe fingerprints like the LF recipe" "$lf_recipe" "$crlf_recipe"

# 3. An unchanged tree whose lock has both digests is a no-op.
write_lock "$lock" "$lf_sources" "$lf_recipe" yes
if run_check "$fixture" >"$work_dir/ok.out" 2>"$work_dir/ok.err"; then
  check "unchanged tree check exit status" 0 0
else
  check "unchanged tree check exit status" 0 1 "$(tail -3 "$work_dir/ok.err" | tr '\n' ' ')"
fi
if grep -q 'status=ok' "$work_dir/ok.out"; then
  check "unchanged tree reports status=ok" 0 0
else
  check "unchanged tree reports status=ok" 0 1
fi

# 4. The Windows false-stale regression: a CRLF checkout must also pass the
#    lock written from LF digests, otherwise every Windows run republishes.
write_lock "$crlf/moui_skia/skia-provider-lock.json" "$lf_sources" "$lf_recipe" yes
if run_check "$crlf" >"$work_dir/crlf.out" 2>"$work_dir/crlf.err"; then
  check "CRLF checkout check exit status" 0 0
else
  check "CRLF checkout check exit status" 0 1 "$(tail -3 "$work_dir/crlf.err" | tr '\n' ' ')"
fi
if grep -q 'status=ok' "$work_dir/crlf.out"; then
  check "CRLF checkout reports status=ok" 0 0
else
  check "CRLF checkout reports status=ok" 0 1
fi

# 5. A lock entry written before `recipe_sha256` existed is stale (one migration
#    rebuild) and must say so without crashing.
write_lock "$lock" "$lf_sources" "$lf_recipe" no
if run_check "$fixture" >"$work_dir/no-recipe.out" 2>"$work_dir/no-recipe.err"; then
  check "missing recipe_sha256 is stale" 0 1
else
  check "missing recipe_sha256 is stale" 0 0
fi
if grep -q 'recipe_sha256' "$work_dir/no-recipe.err"; then
  check "missing recipe_sha256 explains the migration" 0 0
else
  check "missing recipe_sha256 explains the migration" 0 1 "$(tail -3 "$work_dir/no-recipe.err" | tr '\n' ' ')"
fi
if grep -q 'Traceback' "$work_dir/no-recipe.err"; then
  check "missing recipe_sha256 does not crash" 0 1
else
  check "missing recipe_sha256 does not crash" 0 0
fi
if grep -q 'status=ok' "$work_dir/no-recipe.out"; then
  check "missing recipe_sha256 never reports ok" 0 1
else
  check "missing recipe_sha256 never reports ok" 0 0
fi

# 6. A recipe-only change (build.mbtx here) is stale even though every source
#    still matches, so the workflow must rebuild all platforms.
write_lock "$lock" "$lf_sources" "$lf_recipe" yes
printf '// stub build recipe v2\n' > "$fixture/moui_skia/build.mbtx"
if run_check "$fixture" >"$work_dir/recipe.out" 2>"$work_dir/recipe.err"; then
  check "recipe change is stale" 0 1
else
  check "recipe change is stale" 0 0
fi
if grep -q 'build recipe changed' "$work_dir/recipe.err"; then
  check "recipe change names the recipe" 0 0
else
  check "recipe change names the recipe" 0 1 "$(tail -3 "$work_dir/recipe.err" | tr '\n' ' ')"
fi
if grep -q "sources_sha256=$lf_sources" "$work_dir/recipe.out"; then
  check "recipe change leaves the sources digest intact" 0 0
else
  check "recipe change leaves the sources digest intact" 0 1
fi

# 7. A source-only change is still stale on the source digest, with the recipe
#    restored to the locked value.
printf '// stub build recipe v1\n' > "$fixture/moui_skia/build.mbtx"
printf '// changed\n' >> "$fixture/moui_skia/native/stub.cpp"
if run_check "$fixture" >"$work_dir/source.out" 2>"$work_dir/source.err"; then
  check "source change is stale" 0 1
else
  check "source change is stale" 0 0
fi
if grep -q 'stub sources changed' "$work_dir/source.err"; then
  check "source change names the sources" 0 0
else
  check "source change names the sources" 0 1 "$(tail -3 "$work_dir/source.err" | tr '\n' ' ')"
fi

# 8. A missing lock entry stays a hard failure.
write_lock "$lock" "$lf_sources" "$lf_recipe" missing
if run_check "$fixture" >"$work_dir/missing.out" 2>"$work_dir/missing.err"; then
  check "missing lock entry is stale" 0 1
else
  check "missing lock entry is stale" 0 0
fi
if grep -q 'status=missing' "$work_dir/missing.out"; then
  check "missing lock entry reports status=missing" 0 0
else
  check "missing lock entry reports status=missing" 0 1
fi

if [[ "$failures" -ne 0 ]]; then
  echo "stub check test failed with $failures failure(s)" >&2
  exit 1
fi
echo "stub check test passed (sources $lf_sources, recipe $lf_recipe)"
