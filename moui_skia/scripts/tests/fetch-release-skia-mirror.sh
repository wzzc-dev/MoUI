#!/usr/bin/env bash
# Offline regression test for the provider-mirror fallback in
# fetch-release-skia.sh.
#
# The real mirrors live on AtomGit/GitCode and need the network, so this test
# builds a throwaway module whose lock points the primary URL at a missing path
# and the mirror at a local `file://` directory. That keeps the fallback, the
# `--no-mirror` / `--mirror` switches, and the SHA256 rejection path covered by a
# gate instead of by manual smoke runs.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
module_root="$(cd "$script_dir/../.." && pwd)"
fetch_script="$module_root/scripts/fetch-release-skia.sh"

if [[ ! -f "$fetch_script" ]]; then
  echo "missing fetch script: $fetch_script" >&2
  exit 1
fi
for command in python3 zip unzip curl; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "missing required command: $command" >&2
    exit 1
  fi
done

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/moui-skia-mirror-test.XXXXXX")"
cleanup() {
  rm -rf "$work_dir"
}
trap cleanup EXIT

fixture="$work_dir/module"
mkdir -p "$fixture/scripts" "$work_dir/assets" "$work_dir/stub" "$work_dir/package/include/core" "$work_dir/package/lib" "$work_dir/stub-package"
cp "$fetch_script" "$fixture/scripts/fetch-release-skia.sh"
: > "$work_dir/package/include/core/SkSurface.h"
echo "fake-static-lib" > "$work_dir/package/lib/libskia.a"
echo "fake-stub" > "$work_dir/stub-package/libmoui_skia_stub.a"
(cd "$work_dir/package" && zip -qr "$work_dir/assets/Skia-test-macos-Release-arm64.zip" .)
(cd "$work_dir/stub-package" && zip -qr "$work_dir/stub/MoUISkiaStub-test-macos-Release-arm64.zip" .)

python3 - "$work_dir" <<'PY'
import hashlib
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
asset = root / "assets/Skia-test-macos-Release-arm64.zip"
stub = root / "stub/MoUISkiaStub-test-macos-Release-arm64.zip"


def meta(path):
    data = path.read_bytes()
    return hashlib.sha256(data).hexdigest(), len(data)


asset_sha, asset_size = meta(asset)
stub_sha, stub_size = meta(stub)
missing = (root / "missing-primary").as_uri()

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
            "commit": "0" * 40,
            "release_url": "https://github.com/wzzc-dev/skia/releases/tag/test",
            "mirrors": [
                {
                    "name": "test-mirror",
                    "scope": "skia",
                    "base_url": (root / "assets").as_uri() + "/",
                    "platforms": ["macos"],
                    "configs": ["Release"],
                    "link_modes": ["static"],
                    "arches": ["arm64"],
                },
                {
                    "name": "test-stub-mirror",
                    "scope": "stub",
                    "base_url": (root / "stub").as_uri() + "/",
                },
            ],
            "source_archive": {
                "name": "source.zip",
                "url": missing + "/source.zip",
            },
            "default_extra_cc_flags": {"macos": ""},
            "default_extra_link_flags": {"macos": ""},
            "assets": {
                "macos": {
                    "Release": {
                        "arm64": {
                            "static": {
                                "name": asset.name,
                                "url": missing + "/" + asset.name,
                                "sha256": asset_sha,
                                "size": asset_size,
                                "library_names": ["libskia.a"],
                            }
                        }
                    }
                }
            },
            "stub_libraries": {
                "macos": {
                    "Release": {
                        "arm64": {
                            "name": stub.name,
                            "url": missing + "/" + stub.name,
                            "sha256": stub_sha,
                            "size": stub_size,
                            "library_names": ["libmoui_skia_stub.a"],
                        }
                    }
                }
            },
        }
    },
}
(root / "module/skia-provider-lock.json").write_text(
    json.dumps(lock, indent=2), encoding="utf-8"
)
(root / "expected.txt").write_text(f"{asset_sha} {stub_sha}\n", encoding="utf-8")
PY

asset_sha="$(cut -d' ' -f1 "$work_dir/expected.txt")"

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

run_fetch() {
  local cache_name="$1"
  shift
  (
    cd "$fixture"
    bash scripts/fetch-release-skia.sh --platform macos --arch arm64 \
      --cache-dir "$work_dir/$cache_name" "$@"
  )
}

# 1. The primary URL is missing, so the mirror must serve both artifacts.
if run_fetch cache-fallback --print-env >"$work_dir/fallback.out" 2>"$work_dir/fallback.err"; then
  check "mirror fallback exit status" 0 0
else
  check "mirror fallback exit status" 0 1 "see $work_dir/fallback.err"
fi
if grep -qx "MOUI_SKIA_SKIA_PACKAGE_MIRROR=test-mirror" "$work_dir/fallback.out"; then
  check "package served by the mirror" 0 0
else
  check "package served by the mirror" 0 1 "$(grep MIRROR "$work_dir/fallback.out" || true)"
fi
if grep -qx "MOUI_SKIA_STUB_ASSET_MIRROR=test-stub-mirror" "$work_dir/fallback.out"; then
  check "stub served by the mirror" 0 0
else
  check "stub served by the mirror" 0 1 "$(grep STUB "$work_dir/fallback.out" || true)"
fi
if grep -q "MOUI_SKIA_STUB_LIB=.*libmoui_skia_stub.a" "$work_dir/fallback.out"; then
  check "stub archive resolved from the mirror" 0 0
else
  check "stub archive resolved from the mirror" 0 1
fi

# 2. --no-mirror must fail instead of silently using the mirror.
if run_fetch cache-no-mirror --no-mirror --print-env >"$work_dir/no-mirror.out" 2>"$work_dir/no-mirror.err"; then
  check "--no-mirror rejects the mirror" 0 1
else
  check "--no-mirror rejects the mirror" 0 0
fi
if grep -q "could not download Skia release asset" "$work_dir/no-mirror.err"; then
  check "--no-mirror reports the missing primary" 0 0
else
  check "--no-mirror reports the missing primary" 0 1
fi

# 3. --mirror names the mirror that is tried first.
if run_fetch cache-prefer --mirror test-mirror --print-env >"$work_dir/prefer.out" 2>"$work_dir/prefer.err"; then
  check "--mirror run exit status" 0 0
else
  check "--mirror run exit status" 0 1
fi
first_candidate="$(grep -m 1 'candidate=' "$work_dir/prefer.err" || true)"
case "$first_candidate" in
  *candidate=test-mirror) check "--mirror is tried first" 0 0 ;;
  *) check "--mirror is tried first" 0 1 "$first_candidate" ;;
esac

# 4. A mirror name also covers mirrors named `<name>-something`.
if run_fetch cache-prefer-group --mirror test --print-env >"$work_dir/group.out" 2>"$work_dir/group.err"; then
  check "--mirror group run exit status" 0 0
else
  check "--mirror group run exit status" 0 1
fi
if grep -qx "MOUI_SKIA_SKIA_PACKAGE_MIRROR=test-mirror" "$work_dir/group.out" \
  && grep -qx "MOUI_SKIA_STUB_ASSET_MIRROR=test-stub-mirror" "$work_dir/group.out"; then
  check "--mirror group covers both mirrors" 0 0
else
  check "--mirror group covers both mirrors" 0 1 "$(grep MIRROR "$work_dir/group.out" | tr '\n' ' ')"
fi

# 5. A mirror that serves the wrong bytes must be rejected, not trusted.
cp "$work_dir/assets/Skia-test-macos-Release-arm64.zip" "$work_dir/assets/corrupt.zip"
printf 'corrupt' >> "$work_dir/assets/Skia-test-macos-Release-arm64.zip"
if run_fetch cache-mismatch --print-env >"$work_dir/mismatch.out" 2>"$work_dir/mismatch.err"; then
  check "corrupt mirror asset rejected" 0 1
else
  check "corrupt mirror asset rejected" 0 0
fi
if grep -q "SHA256 mismatch" "$work_dir/mismatch.err"; then
  check "corrupt mirror asset reports the digest" 0 0
else
  check "corrupt mirror asset reports the digest" 0 1
fi

if [[ "$failures" -ne 0 ]]; then
  echo "mirror fallback test failed with $failures failure(s)" >&2
  exit 1
fi
echo "mirror fallback test passed (asset sha256 $asset_sha)"
