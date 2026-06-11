#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"

cat <<'EOF'
No editable window checkout is required.

MoUI resolves wzzc-dev/window from the MoonBit registry as
wzzc-dev/window@0.5.1-fork.3. Run `moon update` when the registry cache is
missing or dependency resolution looks stale, then run
`sh scripts/check-local-deps.sh`.
EOF

sh scripts/check-local-deps.sh
