#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/verify-skia-revision-pin.sh ACCEPTANCE_LOG [options]

Checks that skia-revision.txt is pinned to the same 40-character Skia commit
recorded by a passing real Skia acceptance log. This is a read-only guard for
platform follow-up runs; use scripts/pin-skia-revision.sh after the first Linux
source-built acceptance to write the pin.

Options:
  --revision-file PATH  File containing the pinned Skia revision.
                        Default: skia-revision.txt.
  --skip-if-unpinned    Exit successfully when the revision file is not pinned
                        to a full 40-character commit.
  -h, --help            Show this help.
EOF
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 2
fi

acceptance_log="$1"
shift
revision_file="skia-revision.txt"
skip_if_unpinned=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --revision-file)
      revision_file="${2:-}"
      shift 2
      ;;
    --skip-if-unpinned)
      skip_if_unpinned=1
      shift
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
case "$acceptance_log" in
  /*) resolved_acceptance_log="$acceptance_log" ;;
  *) resolved_acceptance_log="$repo_root/$acceptance_log" ;;
esac
case "$revision_file" in
  /*) resolved_revision_file="$revision_file" ;;
  *) resolved_revision_file="$repo_root/$revision_file" ;;
esac

if [[ ! -f "$resolved_revision_file" ]]; then
  echo "Skia revision file is missing: $resolved_revision_file" >&2
  exit 1
fi

pinned_revision="$(grep -v '^[[:space:]]*#' "$resolved_revision_file" | grep -v '^[[:space:]]*$' | head -n 1 | tr '[:upper:]' '[:lower:]' || true)"

if [[ ! "$pinned_revision" =~ ^[0-9a-f]{40}$ ]]; then
  if [[ $skip_if_unpinned -eq 1 ]]; then
    echo "Skipping Skia revision pin check because revision is not pinned: ${pinned_revision:-<empty>}"
    exit 0
  fi
  echo "Skia revision is not pinned to a full 40-character commit: ${pinned_revision:-<empty>}" >&2
  exit 1
fi

bash "$repo_root/scripts/verify-acceptance-log.sh" "$resolved_acceptance_log" --require-commit

accepted_commit="$(grep -E '^[[:space:]]*skia_commit=[0-9a-fA-F]{40}[[:space:]]*$' "$resolved_acceptance_log" | tail -n 1 | sed -E 's/^[[:space:]]*skia_commit=([0-9a-fA-F]{40})[[:space:]]*$/\1/' | tr '[:upper:]' '[:lower:]')"

if [[ "$pinned_revision" != "$accepted_commit" ]]; then
  echo "Skia revision pin does not match acceptance commit" >&2
  echo "  pinned_revision=$pinned_revision" >&2
  echo "  acceptance_commit=$accepted_commit" >&2
  exit 1
fi

echo "Verified skia-revision.txt matches accepted Skia commit $accepted_commit."
