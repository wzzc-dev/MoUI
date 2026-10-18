#!/usr/bin/env bash
# Graduate `examples/ai_world` into its own repository plus a submodule mount.
#
# This is the mechanical half of the graduation documented in
# docs/plans/active/ai-world-product.md. It refuses to run until the target
# repository exists, because a half-graduated tree (submodule pointing at a
# missing remote, moon.work referencing a path that is not checked out) breaks
# every check that walks the workspace.
#
# Usage:
#   scripts/graduate-ai-world.sh --dry-run     # show every step, change nothing
#   scripts/graduate-ai-world.sh              # do it
#
# Prerequisites (all human):
#   1. Create the empty GitHub repository `wzzc-dev/ai_world` (no README).
#   2. Commit or stash the working tree: graduation rewrites git history paths.
set -euo pipefail

REMOTE_URL_DEFAULT="git@github.com:wzzc-dev/ai_world.git"
PREFIX="examples/ai_world"
MOUNT="ai_world"
BRANCH="ai-world-graduate"

dry_run=0
remote_url="$REMOTE_URL_DEFAULT"
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    --remote=*) remote_url="${arg#--remote=}" ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      echo "unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

cd "$(dirname "$0")/.."
repo_root="$(pwd)"
echo "repo:   $repo_root"
echo "prefix: $PREFIX"
echo "mount:  $MOUNT"
echo "remote: $remote_url"
echo

step() {
  echo "==> $*"
  if [ "$dry_run" -eq 0 ]; then
    "$@"
  fi
}

# --- precondition 1: the remote exists -------------------------------------
echo "==> checking the target repository"
if ! git ls-remote "$remote_url" >/dev/null 2>&1; then
  cat >&2 <<EOF
ERROR: cannot read $remote_url

Create the empty repository first (no README, no .gitignore):

  https://github.com/new  →  owner: wzzc-dev  name: ai_world

Graduation cannot run before that: a submodule whose remote does not exist, or
a moon.work entry pointing at a missing directory, breaks every workspace
check. Re-run this script afterwards.
EOF
  exit 1
fi

# --- precondition 2: clean tree --------------------------------------------
# Untracked files are the dangerous case, not modified ones: `git subtree split`
# walks *commits*, so anything uncommitted is simply absent from the graduated
# repository — including brand-new source and test files. The check therefore
# names that consequence instead of just refusing.
echo "==> checking the working tree"
if [ -n "$(git status --porcelain)" ]; then
  untracked=$(git status --porcelain | grep -c '^??' || true)
  echo "ERROR: working tree is dirty. Commit first." >&2
  if [ "$untracked" -gt 0 ]; then
    cat >&2 <<EOF

$untracked untracked path(s) exist. 'git subtree split' reads committed history
only, so every one of them would be MISSING from the graduated repository while
this script still reported success. Commit them before graduating:

  git add -A && git commit -m "feat(ai_world): ..."

EOF
  fi
  git status --short >&2
  exit 1
fi

# --- precondition 2b: no junk that git would ignore ------------------------
# `.DS_Store` and editor backups are gitignored, so they never reach the
# graduated repo — which is correct, but only if the *real* files are all
# tracked. Reporting them keeps the check honest about what will exist.
# `grep` exits 1 when nothing matches and `set -o pipefail` would turn that into
# a script abort, so the pipeline ends with `|| true`.
junk=$(git status --porcelain --ignored examples/ai_world 2>/dev/null | grep '^!!' | grep -vE '_build|/target/' | wc -l | tr -d ' ' || true)
if [ "$junk" -gt 0 ]; then
  echo "note: $junk ignored path(s) under examples/ai_world (gitignored, will not ship)"
fi

# --- precondition 2c: unpublished-API footprint ---------------------------
# Recorded here because step 4 removes the in-tree example; step 6 needs these
# numbers to explain a standalone build failure in terms the reader can act on.
wrap_sites=$(grep -rn 'wrap=true' "$PREFIX/app" 2>/dev/null | wc -l | tr -d ' ' || true)
published_moui=$(sed -n 's/.*"wzzc-dev\/moui@\([^"]*\)".*/\1/p' "$PREFIX/moon.mod" | head -1)
if [ "$wrap_sites" -gt 0 ]; then
  echo "note: $wrap_sites use(s) of text(wrap=true); needs a moui newer than ${published_moui:-unknown} to be published"
fi

# --- precondition 3: subtree helper ----------------------------------------
# `git subtree --help` exits non-zero even when the command is installed, so
# probe for the helper script itself rather than relying on its exit code.
if ! git --exec-path >/dev/null 2>&1 ||
   [ ! -x "$(git --exec-path)/git-subtree" ]; then
  echo "ERROR: git-subtree is not installed (needed for the history split)." >&2
  echo "  macOS: brew install git-subtree" >&2
  exit 1
fi

echo
echo "==> 1/7 split the example's history into its own branch"
step git subtree split -P "$PREFIX" -b "$BRANCH"

echo "==> 2/7 push that branch to the new repository"
step git push "$remote_url" "$BRANCH:main"

echo "==> 3/7 clone it and rename the module"
work_dir="$(mktemp -d)"
step git clone "$remote_url" "$work_dir/ai_world"
if [ "$dry_run" -eq 0 ]; then
  (
    cd "$work_dir/ai_world"
    sed -i.bak 's|^name = "examples/ai_world"|name = "wzzc-dev/ai_world"|' moon.mod
    rm -f moon.mod.bak
    # Sub-package imports and cross-package references move to the new module.
    # Cover every text file, not just sources: README links, the Web page, and
    # committed `pkg.generated.mbti` headers all carry the old module name, and
    # a stale reference there fails the interface/gate checks after graduation.
    grep -rIl 'examples/ai_world' . \
      --exclude-dir=.git \
      --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' \
      | while read -r file; do
          sed -i.bak 's|examples/ai_world|wzzc-dev/ai_world|g' "$file"
          rm -f "$file.bak"
        done
    git add -A
    git -c user.name="${GIT_AUTHOR_NAME:-ai-world}" \
        -c user.email="${GIT_AUTHOR_EMAIL:-ai-world@localhost}" \
        commit -m "chore: rename module to wzzc-dev/ai_world"
    git push origin main
  )
fi

echo "==> 4/7 remove the in-tree example and add the submodule"
step git rm -r --quiet "$PREFIX"
# Git refuses `file://` submodule transports by default (CVE-2022-39253 guard).
# That only affects local-path remotes used for rehearsal; a real
# `git@github.com:` remote is unaffected. Allow it for the local case so the
# dry-rehearsal path matches the real one.
if printf '%s' "$remote_url" | grep -qE '^(/|\./|file:)'; then
  step git -c protocol.file.allow=always submodule add "$remote_url" "$MOUNT"
else
  step git submodule add "$remote_url" "$MOUNT"
fi

echo "==> 5/7 rewrite the MoUI-side references"
if [ "$dry_run" -eq 0 ]; then
  # moon.work member
  sed -i.bak "s|\"./$PREFIX\"|\"./$MOUNT\"|" moon.work && rm -f moon.work.bak
  for file in checks/profiles.json checks/dead-message-catalog.json \
              examples/catalog.json memories/repo/ai-world-web-host-bridge.md \
              docs/examples.md; do
    if [ -f "$file" ]; then
      sed -i.bak "s|$PREFIX|$MOUNT|g" "$file"
      rm -f "$file.bak"
    fi
  done
  # examples/catalog.json points at a directory name, not a path prefix.
  python3 - <<'PY'
import json, pathlib
p = pathlib.Path("examples/catalog.json")
data = json.loads(p.read_text())
def walk(node):
    if isinstance(node, dict):
        if node.get("id") == "ai_world":
            node["path"] = "ai_world"
        for value in node.values():
            walk(value)
    elif isinstance(node, list):
        for value in node:
            walk(value)
walk(data)
p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
PY
fi

echo "==> 6/7 check the example builds WITHOUT the workspace"

# The example uses API that must exist in the *published* moui, not only in the
# local ./moui workspace member. Graduating while it depends on unreleased API
# produces a repository that does not compile for anyone.
if [ "$dry_run" -eq 0 ]; then
  if ! (cd "$work_dir/ai_world" && moon check app --target native >/dev/null 2>&1); then
    cat >&2 <<'EOF'
ERROR: the graduated repository does not compile on its own.

`examples/ai_world` currently builds against the workspace member `./moui`,
which contains changes not yet published to the registry. A standalone
repository resolves `wzzc-dev/moui` from the registry instead, so any use of
unreleased API (for example `text(..., wrap=true)`) fails there.

Resolve by either:
  a) publishing the current `moui` and bumping `moui/moon.mod`'s version, then
     updating `examples/ai_world/moon.mod` to that version; or
  b) removing the example's dependency on unreleased API.

Re-run this script afterwards. The temporary clone is at:
EOF
    # Separate, unquoted heredoc: these facts must be interpolated.
    cat >&2 <<EOF
  $work_dir/ai_world

This run saw ${wrap_sites:-0} use(s) of text(wrap=true); the example depends on
wzzc-dev/moui@${published_moui:-unknown}, whose published text() has no \`wrap\`.
EOF
    exit 1
  fi
fi

echo "==> 6/7 regenerate interfaces for the new workspace shape"
step moon info

echo "==> 7/7 verify"
if [ "$dry_run" -eq 1 ]; then
  echo "(dry run: skipping verification)"
else
  node scripts/validate-maintenance-baseline.mjs
  node scripts/validate-api-surface.mjs
  node scripts/validate-release-module-closures.mjs
  node scripts/validate-guidance-consistency.mjs
  node scripts/check-generated-interfaces.mjs
  sh scripts/check.sh --profile pr
fi

cat <<EOF

Done. Remaining manual follow-ups:
  - Review and commit the MoUI-side diff (moon.work, checks/, docs/, .gitmodules).
  - Mark docs/plans/active/ai-world-product.md Status: done and move it to
    docs/plans/done/.
  - Add docs/ai-world.md as the pointer page (mirroring docs/markdown-editor.md).
  - Clean up the temporary clone: $work_dir
EOF
