#!/usr/bin/env node

import { lstatSync, readFileSync, readlinkSync } from "node:fs";
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

const assertSymlinkTarget = (path, target) => {
  const stat = lstatSync(join(root, path));
  if (!stat.isSymbolicLink()) {
    const text = read(path).trim();
    if (text !== target) {
      fail(`${path}: expected to be a symlink to ${target}`);
    }
    return;
  }
  const actual = readlinkSync(join(root, path));
  if (actual !== target) {
    fail(`${path}: expected symlink target '${target}', got '${actual}'`);
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
  if (member.startsWith("./examples/")) {
    const packageName = member.replace("./examples/", "");
    assertIncludes("docs/examples.md", `examples/${packageName}/app/`);
  }
}

for (const path of guidanceFiles) {
  assertAbsent(path, "Milky2018/window");
  assertAbsent(path, "`tests/*_conformance`");
  assertAbsent(path, "`tests/text_conformance/`");
  assertAbsent(path, "`tests/skia_renderer_smoke/native`");
  assertAbsent(path, "`README.mbt.md`");
}

assertSymlinkTarget("README.md", "moui/README.mbt.md");
assertIncludes("AGENTS.md", "`moui/README.mbt.md`");
assertIncludes("docs/templates.md", "`moui/README.mbt.md`");
assertIncludes("docs/roadmap-2026.md", "`moui/README.mbt.md`");
assertIncludes("skills/moui-app-development-skill/SKILL.md", "`README.md`");
assertIncludes("skills/moui-framework-development-skill/SKILL.md", "`README.md`");

for (const path of [
  "moui/README.mbt.md",
  "docs/architecture.md",
  "docs/platform-notes.md",
  "docs/testing.md",
  "skills/moui-framework-development-skill/SKILL.md",
]) {
  assertIncludes(path, "render/skia");
}

for (const platform of ["macos", "windows", "linux"]) {
  assertIncludes("AGENTS.md", `backend/${platform}/wgpu`);
  assertIncludes("AGENTS.md", `backend/${platform}/skia`);
  assertIncludes("docs/architecture.md", `moui/backend/${platform}/wgpu/`);
  assertIncludes("docs/architecture.md", `moui/backend/${platform}/skia/`);
}

assertIncludes("AGENTS.md", "`moui/tests/*_conformance`");
assertIncludes("docs/testing.md", "`moui/tests/*_conformance`");
assertIncludes("docs/testing.md", "`moui/tests/text_conformance/`");
assertIncludes("docs/text-system.md", "`moui/tests/text_conformance/`");
assertIncludes("docs/architecture.md", "moui/tests/text_conformance/");
assertIncludes("docs/architecture.md", "moui/tests/skia_renderer_smoke/native/");
assertIncludes("docs/examples.md", "examples/markdown_editor/windows_cosmic");
assertIncludes("docs/examples.md", "moon test examples/counter/app --target native");
assertIncludes("skills/moui-app-development-skill/SKILL.md", "moon build examples/counter/web_wasm --target wasm-gc");
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "`moui/tests/*_conformance`",
);
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "`moui/tests/text_conformance/{native,web}`",
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
