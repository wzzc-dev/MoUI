#!/usr/bin/env bash
# Mirror the locked Skia release assets and the MoUI stub archives to
# AtomGit/GitCode so Chinese networks can fetch them when GitHub is unreachable.
#
# Why this exists
# ---------------
# `skia-provider-lock.json` records a GitHub release as the binary provider. That
# host is sometimes unreachable from mainland China, so the same bytes are
# mirrored into the MoUI repository on AtomGit/GitCode and recorded under
# `providers.release.mirrors`. `fetch-release-skia.{sh,ps1}` try the primary host
# and then those mirrors, verifying the locked SHA256 and size on every candidate.
#
# The mirror never becomes the owner of the artifacts: `wzzc-dev/skia` still
# builds and releases Skia, and MoUI still publishes its own stub. This script
# only copies the locked subset into the GitCode MoUI repository, which keeps the
# GitCode side at one repository and two tags:
#   skia-<skia-tag>      Release static desktop assets (macos/linux/windows)
#   skia-stub-<skia-tag> the MoUI-built stub archives
#
# AtomGit exposes uploads through a signed object-storage URL obtained from
# `GET /repos/{owner}/{repo}/releases/{tag}/upload_url`, so a user token is
# required. Pass it through `GITCODE_TOKEN` (or `ATOMGIT_TOKEN`), never on the
# command line in a shared shell.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: mirror-release-assets.sh [options]

Options:
  --mirror NAME      Lock mirror entry to fill (default: the first `scope: skia`
                     entry in providers.<provider>.mirrors).
  --provider NAME    Lock provider key (default: release).
  --with-stub        Also mirror the stub archives (default).
  --no-stub          Mirror only the Skia packages.
  --list             Print the selection and exit; no network access.
  --dry-run          Print the planned tag/release/upload calls, then exit.
  --force            Re-upload assets even when the attachment already exists.
  --verify           Download every mirrored asset after uploading it and
                     compare its SHA256 with the lock.
  --verify-only      Skip uploads and only verify the assets that are already on
                     the mirror; no token is required.
  --ref BRANCH       Branch the mirror tag is created from (default: main).
  --cache-dir PATH   Where source archives are cached (default:
                     <module>/.skia-cache/release).
  --api-url URL      AtomGit API base (default: https://api.atomgit.com/api/v5).
  --token TOKEN      Access token; prefer the GITCODE_TOKEN / ATOMGIT_TOKEN env.
  --lock PATH        Lock path (default <module>/skia-provider-lock.json).
  -h, --help         Show this help.

The owner, repository, and mirror tag come from the lock mirror `base_url`
(https://<host>/<owner>/<repo>/releases/download/<tag>/), so the lock stays the
single source of truth for what is mirrored where.
EOF
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
module_root="$(cd "$script_dir/.." && pwd)"

lock_path="$module_root/skia-provider-lock.json"
cache_dir="$module_root/.skia-cache/release"
provider_key="release"
mirror_name=""
with_stub=1
list_only=0
dry_run=0
force=0
verify=0
verify_only=0
git_ref="main"
api_url="${ATOMGIT_API_URL:-https://api.atomgit.com/api/v5}"
token="${GITCODE_TOKEN:-${ATOMGIT_TOKEN:-}}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mirror) mirror_name="${2:-}"; shift 2 ;;
    --provider) provider_key="${2:-}"; shift 2 ;;
    --with-stub) with_stub=1; shift ;;
    --no-stub) with_stub=0; shift ;;
    --list) list_only=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    --force) force=1; shift ;;
    --verify) verify=1; shift ;;
    --verify-only) verify=1; verify_only=1; shift ;;
    --ref) git_ref="${2:-}"; shift 2 ;;
    --cache-dir) cache_dir="${2:-}"; shift 2 ;;
    --api-url) api_url="${2:-}"; shift 2 ;;
    --token) token="${2:-}"; shift 2 ;;
    --lock) lock_path="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ ! -f "$lock_path" ]]; then
  echo "Skia provider lock is missing: $lock_path" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "missing required command: python3" >&2
  exit 1
fi

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

size_of() {
  wc -c < "$1" | tr -d '[:space:]'
}

# The selection comes from the lock mirror filters, so the lock and the upload
# list can never disagree: --list, the uploads, and --verify read the same rules.
selection="$(python3 - "$lock_path" "$provider_key" "$mirror_name" "$with_stub" <<'PY'
import json
import pathlib
import re
import sys

lock_path = pathlib.Path(sys.argv[1])
provider_key = sys.argv[2]
requested_mirror = sys.argv[3]
with_stub = sys.argv[4] == "1"

lock = json.loads(lock_path.read_text(encoding="utf-8"))
providers = lock.get("providers", {})
provider = providers.get(provider_key)
if not isinstance(provider, dict):
    raise SystemExit(f"skia-provider-lock.json is missing providers.{provider_key}")

tag = provider.get("tag", "")
mirrors = [m for m in provider.get("mirrors") or [] if isinstance(m, dict)]
if not mirrors:
    raise SystemExit(f"providers.{provider_key}.mirrors is empty; nothing to mirror")

DOWNLOAD_PATTERN = re.compile(
    r"^https://[^/]+/([^/]+)/([^/]+)/releases/download/([^/]+)/$"
)


def scope_matches(mirror, scope):
    scopes = mirror.get("scope")
    if isinstance(scopes, str):
        scopes = [scopes]
    return scope in (scopes or [])


def pick(scope):
    for mirror in mirrors:
        if not scope_matches(mirror, scope):
            continue
        if mirror.get("kind", "release-download") != "release-download":
            # url-prefix entries (ghproxy-style) front GitHub at download time and
            # have nothing to upload, so they are never mirror targets.
            continue
        if requested_mirror and mirror.get("name") != requested_mirror:
            continue
        return mirror
    return None


if requested_mirror:
    for mirror in mirrors:
        if mirror.get("name") != requested_mirror:
            continue
        if mirror.get("kind", "release-download") != "release-download":
            raise SystemExit(
                f"mirror {requested_mirror} is a {mirror.get('kind')} download proxy; "
                "it needs no upload, so --mirror only accepts hosted release copies"
            )


def matches(mirror, platform, config, arch, link_mode):
    platforms = mirror.get("platforms")
    if platforms and platform not in platforms:
        return False
    configs = mirror.get("configs")
    if configs and config not in configs:
        return False
    arches = mirror.get("arches")
    if arches and arch not in arches:
        return False
    link_modes = mirror.get("link_modes")
    if link_modes and link_mode not in link_modes:
        return False
    return True


def emit_target(scope, mirror):
    base_url = mirror.get("base_url", "")
    match = DOWNLOAD_PATTERN.match(base_url)
    if not match:
        raise SystemExit(
            f"mirror {mirror.get('name')} base_url is not a release download URL: {base_url!r}"
        )
    owner, repo, mirror_tag = match.groups()
    print(f"{scope}_owner={owner}")
    print(f"{scope}_repo={repo}")
    print(f"{scope}_tag={mirror_tag.replace('{tag}', tag)}")
    print(f"{scope}_base_url={base_url.replace('{tag}', tag)}")


skia_mirror = pick("skia")
if not isinstance(skia_mirror, dict):
    raise SystemExit("no skia-scope mirror matches the request; pass a recorded --mirror name")
emit_target("skia", skia_mirror)

for platform, configs in provider.get("assets", {}).items():
    for config, arches in configs.items():
        for arch, modes in arches.items():
            for link_mode, asset in modes.items():
                if not matches(skia_mirror, platform, config, arch, link_mode):
                    continue
                print(
                    "skia_asset="
                    + "|".join(
                        [
                            asset["name"],
                            asset["sha256"],
                            str(asset.get("size", "")),
                            asset["url"],
                            platform,
                            config,
                            arch,
                            link_mode,
                        ]
                    )
                )

if with_stub:
    stub_mirror = pick("stub")
    if not isinstance(stub_mirror, dict):
        raise SystemExit("provider records no stub-scope mirror; pass --no-stub to skip the stub")
    emit_target("stub", stub_mirror)
    for platform, configs in provider.get("stub_libraries", {}).items():
        for config, arches in configs.items():
            for arch, entry in arches.items():
                if not isinstance(entry, dict):
                    continue
                if not matches(stub_mirror, platform, config, arch, "static"):
                    continue
                print(
                    "stub_asset="
                    + "|".join(
                        [
                            entry["name"],
                            entry["sha256"],
                            str(entry.get("size", "")),
                            entry["url"],
                            platform,
                            config,
                            arch,
                            "static",
                        ]
                    )
                )
PY
)"

value_of() {
  printf '%s\n' "$selection" | sed -n "s/^$1=//p" | tail -n 1
}

skia_owner="$(value_of skia_owner)"
skia_repo="$(value_of skia_repo)"
skia_tag="$(value_of skia_tag)"
skia_base_url="$(value_of skia_base_url)"
stub_owner="$(value_of stub_owner)"
stub_repo="$(value_of stub_repo)"
stub_tag="$(value_of stub_tag)"
stub_base_url="$(value_of stub_base_url)"

skia_assets="$(printf '%s\n' "$selection" | sed -n 's/^skia_asset=//p')"
stub_assets="$(printf '%s\n' "$selection" | sed -n 's/^stub_asset=//p')"

count_lines() {
  local text="$1"
  if [[ -z "$text" ]]; then
    printf '0'
    return 0
  fi
  printf '%s\n' "$text" | wc -l | tr -d '[:space:]'
}

sum_sizes() {
  local total=0
  local line size
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    size="$(printf '%s' "$line" | cut -d'|' -f3)"
    if [[ -n "$size" ]]; then
      total=$((total + size))
    fi
  done <<< "$1"
  printf '%s' "$total"
}

echo "Skia mirror selection:"
echo "  provider=$provider_key"
echo "  skia_target=$skia_owner/$skia_repo@$skia_tag"
echo "  skia_assets=$(count_lines "$skia_assets")"
echo "  skia_bytes=$(sum_sizes "$skia_assets")"
if [[ "$with_stub" -eq 1 ]]; then
  echo "  stub_target=$stub_owner/$stub_repo@$stub_tag"
  echo "  stub_assets=$(count_lines "$stub_assets")"
  echo "  stub_bytes=$(sum_sizes "$stub_assets")"
fi
while IFS= read -r line; do
  if [[ -n "$line" ]]; then
    echo "  skia_asset=$(printf '%s' "$line" | cut -d'|' -f1) ($(printf '%s' "$line" | cut -d'|' -f5-8))"
  fi
done <<< "$skia_assets"
while IFS= read -r line; do
  if [[ -n "$line" ]]; then
    echo "  stub_asset=$(printf '%s' "$line" | cut -d'|' -f1)"
  fi
done <<< "$stub_assets"

if [[ "$list_only" -eq 1 ]]; then
  exit 0
fi

needs_api=0
if [[ "$dry_run" -eq 0 && "$verify_only" -eq 0 ]]; then
  needs_api=1
fi
if [[ "$needs_api" -eq 1 && -z "$token" ]]; then
  echo "no AtomGit/GitCode token: export GITCODE_TOKEN (or ATOMGIT_TOKEN) before mirroring" >&2
  exit 2
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "missing required command: curl" >&2
  exit 1
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/moui-skia-mirror.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
api_status=""
api_body=""

redacted_url() {
  local url="$1"
  printf '%s' "${url//access_token=*/access_token=***}"
}

# AtomGit takes the token in the query string, so every URL is redacted before
# it is echoed.
api_call() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  local url="$api_url$path"
  local sep="?"
  if [[ "$url" == *\?* ]]; then
    sep="&"
  fi
  if [[ -n "$token" ]]; then
    url="$url$sep""access_token=$token"
  fi
  if [[ "$dry_run" -eq 1 ]]; then
    echo "  [dry-run] $method $(redacted_url "$url")" >&2
    api_status="000"
    api_body=""
    return 0
  fi
  local -a args=(--silent --show-error --max-time 180 --request "$method" --header 'Accept: application/json')
  if [[ -n "$data" ]]; then
    args+=(--header 'Content-Type: application/json' --data "$data")
  fi
  api_status="$(curl "${args[@]}" --output "$tmp_dir/response.json" --write-out '%{http_code}' "$url")"
  api_body="$(cat "$tmp_dir/response.json" 2>/dev/null || true)"
  if [[ "$api_status" -lt 200 || "$api_status" -ge 300 ]]; then
    return 1
  fi
  return 0
}

json_field() {
  python3 - "$1" "$2" <<'PY'
import json
import sys

payload, field = sys.argv[1], sys.argv[2]
try:
    data = json.loads(payload)
except json.JSONDecodeError:
    raise SystemExit(0)
if isinstance(data, dict) and data.get(field) is not None:
    print(data[field])
PY
}

# AtomGit has returned release attachments under more than one key, so accept any
# string field named name/file_name instead of pinning one response shape.
attachment_present() {
  python3 - "$1" "$2" <<'PY'
import json
import sys

payload, target = sys.argv[1], sys.argv[2]
try:
    data = json.loads(payload)
except json.JSONDecodeError:
    raise SystemExit(1)
found = []


def walk(node):
    if isinstance(node, dict):
        for key, value in node.items():
            if key in ("name", "file_name") and value == target:
                found.append(target)
            walk(value)
    elif isinstance(node, list):
        for item in node:
            walk(item)


walk(data)
raise SystemExit(0 if found else 1)
PY
}

json_string() {
  python3 - "$@" <<'PY'
import json
import sys

print(json.dumps(sys.argv[1], ensure_ascii=False))
PY
}

release_body="Read-only mirror of the locked \`wzzc-dev/skia\` release assets for networks that cannot reach GitHub. Every asset keeps the SHA256 recorded in \`moui_skia/skia-provider-lock.json\`."

ensure_release() {
  local owner="$1"
  local repo="$2"
  local tag="$3"
  local title="$4"
  echo "Release $owner/$repo@$tag"
  if [[ "$dry_run" -eq 1 ]]; then
    echo "  [dry-run] ensure tag $tag from $git_ref and the release '$title'"
    return 0
  fi
  if api_call GET "/repos/$owner/$repo/releases/tags/$tag"; then
    echo "  release=present"
    return 0
  fi
  echo "  release=missing"
  if ! api_call GET "/repos/$owner/$repo/tags/$tag"; then
    echo "  tag=missing"
    if ! api_call POST "/repos/$owner/$repo/tags" "$(python3 - "$tag" "$git_ref" <<'PY'
import json
import sys

tag, ref = sys.argv[1], sys.argv[2]
print(json.dumps({"tag_name": tag, "ref": ref, "message": "MoUI Skia mirror"}))
PY
)"; then
      echo "  failed to create tag $tag: HTTP $api_status $api_body" >&2
      return 1
    fi
    echo "  tag=created"
  fi
  if ! api_call POST "/repos/$owner/$repo/releases" "$(python3 - "$tag" "$title" "$release_body" <<'PY'
import json
import sys

tag, title, body = sys.argv[1], sys.argv[2], sys.argv[3]
print(json.dumps({"tag_name": tag, "name": title, "body": body, "prerelease": False}))
PY
)"; then
    echo "  failed to create release $tag: HTTP $api_status $api_body" >&2
    return 1
  fi
  echo "  release=created"
}

# Source archives download once per run. GitHub-hosted assets go through
# `gh release download` when available because it handles redirects and resume
# better than a bare curl on a slow link.
download_source() {
  local url="$1"
  local output="$2"
  local name="$3"
  if [[ -s "$output" ]]; then
    echo "  source=cache"
    return 0
  fi
  mkdir -p "$(dirname "$output")"
  if [[ "$url" =~ ^https://github\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/ ]]; then
    local owner="${BASH_REMATCH[1]}"
    local repo="${BASH_REMATCH[2]}"
    local tag="${BASH_REMATCH[3]}"
    if command -v gh >/dev/null 2>&1; then
      echo "  source=gh:$owner/$repo@$tag"
      if gh release download "$tag" --repo "$owner/$repo" --pattern "$name" --dir "$(dirname "$output")" --clobber >/dev/null 2>&1; then
        return 0
      fi
      echo "  gh download failed; falling back to curl" >&2
    fi
  fi
  echo "  source=curl"
  curl --fail --silent --show-error --location --http1.1 --connect-timeout 30 --retry 5 --retry-delay 2 \
    --speed-limit 1024 --speed-time 60 --output "$output" "$url"
}

upload_asset() {
  local owner="$1"
  local repo="$2"
  local tag="$3"
  local name="$4"
  local path="$5"
  local expected_sha="$6"
  local expected_size="$7"
  local local_sha
  local local_size
  local_sha="$(sha256_of "$path")"
  local_size="$(size_of "$path")"
  if [[ "$local_sha" != "$expected_sha" ]]; then
    echo "  source SHA256 mismatch for $name: expected=$expected_sha actual=$local_sha" >&2
    return 1
  fi
  if [[ -n "$expected_size" && "$local_size" != "$expected_size" ]]; then
    echo "  source size mismatch for $name: expected=$expected_size actual=$local_size" >&2
    return 1
  fi
  if [[ "$dry_run" -eq 1 ]]; then
    echo "  [dry-run] upload $name ($local_size bytes) to $owner/$repo@$tag" >&2
    return 0
  fi
  if ! api_call GET "/repos/$owner/$repo/releases/$tag/upload_url?file_name=$name"; then
    echo "  failed to obtain an upload URL for $name: HTTP $api_status $api_body" >&2
    return 1
  fi
  local upload_url
  upload_url="$(json_field "$api_body" url)"
  if [[ -z "$upload_url" ]]; then
    echo "  upload URL response carried no url field: $api_body" >&2
    return 1
  fi
  local -a header_args=()
  local header_line
  while IFS= read -r header_line; do
    if [[ -n "$header_line" ]]; then
      header_args+=(--header "$header_line")
    fi
  done < <(python3 - "$api_body" <<'PY'
import json
import sys

try:
    data = json.loads(sys.argv[1])
except json.JSONDecodeError:
    raise SystemExit(0)
headers = data.get("headers")
if isinstance(headers, dict):
    for key, value in headers.items():
        print(f"{key}: {value}")
PY
)
  local status
  status="$(curl --silent --show-error --max-time 1800 --request PUT --upload-file "$path" \
    "${header_args[@]}" --output "$tmp_dir/upload.json" --write-out '%{http_code}' "$upload_url")"
  if [[ "$status" -lt 200 || "$status" -ge 300 ]]; then
    echo "  upload failed for $name: HTTP $status $(head -c 400 "$tmp_dir/upload.json" 2>/dev/null)" >&2
    return 1
  fi
  echo "  uploaded=$name"
}

verify_mirror_asset() {
  local base_url="$1"
  local name="$2"
  local expected_sha="$3"
  local output="$tmp_dir/verify-$name"
  echo "  verify=$name"
  if ! curl --fail --silent --show-error --location --http1.1 --connect-timeout 30 --retry 3 --retry-delay 2 \
    --output "$output" "$base_url$name"; then
    echo "  mirror download failed for $name ($base_url$name)" >&2
    return 1
  fi
  local actual
  actual="$(sha256_of "$output")"
  rm -f "$output"
  if [[ "$actual" != "$expected_sha" ]]; then
    echo "  mirror SHA256 mismatch for $name: expected=$expected_sha actual=$actual" >&2
    return 1
  fi
  echo "  verified=$name"
}

failed=0
skia_title="MoUI Skia mirror $(value_of skia_tag)"
stub_title="MoUI Skia stub mirror $(value_of skia_tag)"

if [[ "$needs_api" -eq 1 ]]; then
  ensure_release "$skia_owner" "$skia_repo" "$skia_tag" "$skia_title" || exit 1
  if [[ "$with_stub" -eq 1 ]]; then
    ensure_release "$stub_owner" "$stub_repo" "$stub_tag" "$stub_title" || exit 1
  fi
fi

upload_one() {
  local kind="$1"
  local payload="$2"
  local owner repo tag base_url
  local name sha size url platform config arch link_mode
  IFS='|' read -r name sha size url platform config arch link_mode <<< "$payload"
  if [[ "$kind" == "skia" ]]; then
    owner="$skia_owner"
    repo="$skia_repo"
    tag="$skia_tag"
    base_url="$skia_base_url"
  else
    owner="$stub_owner"
    repo="$stub_repo"
    tag="$stub_tag"
    base_url="$stub_base_url"
  fi
  echo "Asset $name ($platform/$config/$arch/$link_mode, $size bytes)"
  if [[ "$verify_only" -eq 0 ]]; then
    if [[ "$dry_run" -eq 1 ]]; then
      echo "  [dry-run] download $url then upload $name to $owner/$repo@$tag"
      return 0
    fi
    local present=0
    if [[ "$force" -eq 0 ]] && api_call GET "/repos/$owner/$repo/releases/tags/$tag" && attachment_present "$api_body" "$name"; then
      echo "  attachment=present (use --force to re-upload)"
      present=1
    fi
    if [[ "$present" -eq 0 ]]; then
      local source_path="$cache_dir/$skia_tag/mirror-$kind/$name"
      if ! download_source "$url" "$source_path" "$name"; then
        echo "  failed to obtain $name" >&2
        return 1
      fi
      if ! upload_asset "$owner" "$repo" "$tag" "$name" "$source_path" "$sha" "$size"; then
        return 1
      fi
    fi
  fi
  if [[ "$verify" -eq 1 && "$dry_run" -eq 0 ]]; then
    verify_mirror_asset "$base_url" "$name" "$sha" || return 1
  fi
  return 0
}

while IFS= read -r line; do
  if [[ -n "$line" ]]; then
    upload_one skia "$line" || failed=1
  fi
done <<< "$skia_assets"

while IFS= read -r line; do
  if [[ -n "$line" ]]; then
    upload_one stub "$line" || failed=1
  fi
done <<< "$stub_assets"

if [[ "$failed" -ne 0 ]]; then
  echo "mirror run finished with failures" >&2
  exit 1
fi
echo "mirror run finished"
