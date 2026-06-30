#!/usr/bin/env node
// Guard: wzzc-dev/window must resolve from mooncakes.io on the main branch.
//
// Enforces the dependency policy documented in docs/development.md:
//   1. moon.work must NOT list "./window" as a workspace member. The local
//      submodule checkout is only for dev-mode overrides via
//      scripts/window-dev-mode.sh; committing it would silently shadow the
//      published dependency for everyone else.
//   2. Every moon.mod that declares wzzc-dev/window must pin the same
//      published version, so minimal-version selection never picks a stale
//      patch.
//
// Run locally via `sh scripts/dev-check.sh` and in CI via ci.yml.

import { readFileSync, existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

function readText(relativePath) {
  const absolute = join(repoRoot, relativePath);
  if (!existsSync(absolute)) {
    throw new Error(`missing file: ${relativePath}`);
  }
  return readFileSync(absolute, "utf8");
}

const WINDOW_MEMBER_PATTERN = /^(\s*)"\.\/window",\s*$/gm;
const WINDOW_DEP_PATTERN = /"wzzc-dev\/window@([^"]+)"/g;

// moon.mod files expected to declare wzzc-dev/window. Keep in sync with the
// repository's actual consumers; fail loudly if any are missing or if a new
// consumer appears without being listed here.
const EXPECTED_WINDOW_CONSUMERS = [
  "moui/moon.mod",
  "moui_skia/moon.mod",
  "moui_webview/moon.mod",
  "examples/markdown_editor/moon.mod",
];

const errors = [];

// Rule 1: moon.work must not list ./window as a workspace member.
const moonWork = readText("moon.work");
const memberMatches = [ ...moonWork.matchAll(WINDOW_MEMBER_PATTERN) ];
if (memberMatches.length > 0) {
  errors.push(
    `moon.work lists "./window" as a workspace member (${memberMatches.length} occurrence(s)).\n` +
      `  This shadows the published wzzc-dev/window dependency for all workspace consumers.\n` +
      `  Run \`sh scripts/window-dev-mode.sh off\` to restore mooncakes.io resolution.\n` +
      `  Local window edits belong in a dev-mode worktree, not on the main branch.`,
  );
}

// Rule 2: every expected consumer pins the same wzzc-dev/window version.
const versionsByConsumer = new Map();
const allVersions = new Set();
for (const rel of EXPECTED_WINDOW_CONSUMERS) {
  const text = readText(rel);
  const matches = [ ...text.matchAll(WINDOW_DEP_PATTERN) ];
  if (matches.length === 0) {
    errors.push(
      `${rel}: expected a "wzzc-dev/window@<version>" declaration but found none.\n` +
        `  If this module no longer depends on window, remove it from EXPECTED_WINDOW_CONSUMERS.\n` +
        `  Otherwise restore the import.`,
    );
    continue;
  }
  const versions = matches.map((m) => m[1]);
  for (const v of versions) {
    allVersions.add(v);
  }
  versionsByConsumer.set(rel, versions);
  if (new Set(versions).size > 1) {
    errors.push(
      `${rel}: declares wzzc-dev/window at multiple versions: ${versions.join(", ")}.\n` +
        `  A single moon.mod must pin exactly one window version.`,
    );
  }
}

if (allVersions.size > 1) {
  const list = [ ...versionsByConsumer.entries() ]
    .map(([ rel, vs ]) => `  - ${rel}: ${vs.join(", ")}`)
    .join("\n");
  errors.push(
    `wzzc-dev/window version mismatch across consumers:\n${list}\n` +
      `  Align all moon.mod files to a single published version.\n` +
      `  Use \`moon -C <module> mod tidy\` or edit the import block directly.`,
  );
}

if (errors.length > 0) {
  console.error("validate-window-dependency: FAIL");
  for (const e of errors) {
    console.error("\n" + e);
  }
  process.exit(1);
}

const pinned = allVersions.size === 1 ? [ ...allVersions ][0] : "(none)";
console.log(
  `validate-window-dependency: OK (mooncakes mode, wzzc-dev/window@${pinned})`,
);
