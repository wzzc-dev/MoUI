#!/usr/bin/env node

import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const read = path => readFileSync(join(root, path), "utf8");

let failed = false;

const fail = message => {
  console.error(message);
  failed = true;
};

const assertIncludes = (path, token) => {
  if (!read(path).includes(token)) {
    fail(`${path}: expected to include '${token}'`);
  }
};

const assertAbsent = (path, token) => {
  if (read(path).includes(token)) {
    fail(`${path}: stale guidance token '${token}'`);
  }
};

const moonWorkMembers = () => {
  const text = read("moon.work");
  return [...text.matchAll(/"([^"]+)"/g)].map(match => match[1]);
};

const guidanceFiles = [
  "AGENTS.md",
  "docs/development.md",
  "docs/testing.md",
  "docs/text-system.md",
  "skills/moui-app-development-skill/SKILL.md",
  "skills/moui-framework-development-skill/SKILL.md",
];

for (const member of moonWorkMembers()) {
  assertIncludes("docs/development.md", member);
}

for (const path of guidanceFiles) {
  assertAbsent(path, "Milky2018/window");
  assertAbsent(path, "`tests/*_conformance`");
  assertAbsent(path, "`tests/text_conformance/`");
  assertAbsent(path, "`tests/skia_renderer_smoke/native`");
}

assertIncludes("AGENTS.md", "`moui/tests/*_conformance`");
assertIncludes("docs/testing.md", "`moui/tests/*_conformance`");
assertIncludes("docs/testing.md", "`moui/tests/text_conformance/`");
assertIncludes("docs/text-system.md", "`moui/tests/text_conformance/`");
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "`moui/tests/*_conformance`",
);
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "`moui/tests/skia_renderer_smoke/native`",
);
assertIncludes("scripts/conformance-check.sh", "moon test moui/render/skia --target native");
assertIncludes("scripts/dev-check.sh", "node scripts/validate-guidance-consistency.mjs");
assertIncludes("docs/testing.md", "node scripts/validate-guidance-consistency.mjs");

if (failed) {
  process.exit(1);
}

console.log("guidance consistency guard: ok");
