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
assertIncludes(
  "scripts/conformance-check.sh",
  "validate-conformance-capture-manifest.mjs",
);
assertIncludes("scripts/conformance-check.sh", "markdown-editor-web-wasm");
assertIncludes(
  "scripts/conformance-check.sh",
  "platform-runtime-evidence.json",
);
assertIncludes(
  "scripts/conformance-check.sh",
  "validate-platform-evidence-manifest.mjs",
);
assertIncludes(
  "scripts/record-platform-evidence-manifest.mjs",
  "validate-platform-evidence-manifest.mjs",
);
assertIncludes(
  "scripts/record-platform-evidence-manifest.mjs",
  "--web-presentation-manifest",
);
assertIncludes(
  "scripts/conformance-check.sh",
  "validate-web-runtime-handoff.mjs",
);
assertIncludes("scripts/conformance-check.sh", "web-runtime-handoff.json");
assertIncludes("scripts/validate-web-runtime-handoff.mjs", "--manifest");
assertIncludes(
  "scripts/validate-web-runtime-handoff.mjs",
  "validate-web-runtime-handoff-manifest.mjs",
);
assertIncludes("scripts/dev-check.sh", "node scripts/validate-guidance-consistency.mjs");
assertIncludes("scripts/dev-check.sh", "node scripts/validate-web-runtime-handoff.mjs");
assertIncludes("scripts/dev-check.sh", "node scripts/test-validate-web-runtime-handoff.mjs");
assertIncludes(
  "scripts/dev-check.sh",
  "node scripts/test-validate-web-runtime-handoff-manifest.mjs",
);
assertIncludes(
  "scripts/dev-check.sh",
  "node scripts/test-record-web-runtime-presentation.mjs",
);
assertIncludes(
  "scripts/dev-check.sh",
  "node scripts/test-validate-web-runtime-presentation-manifest.mjs",
);
assertIncludes("docs/testing.md", "node scripts/validate-guidance-consistency.mjs");
assertIncludes("docs/testing.md", "validate-conformance-capture-manifest.mjs");
assertIncludes("docs/testing.md", "markdown-editor-web-wasm");
assertIncludes("docs/testing.md", "validate-platform-evidence-manifest.mjs");
assertIncludes("docs/testing.md", "record-platform-evidence-manifest.mjs");
assertIncludes("docs/testing.md", "validate-web-runtime-handoff.mjs");
assertIncludes("docs/testing.md", "test-validate-web-runtime-handoff.mjs");
assertIncludes("docs/testing.md", "validate-web-runtime-handoff-manifest.mjs");
assertIncludes("docs/testing.md", "test-validate-web-runtime-handoff-manifest.mjs");
assertIncludes("docs/testing.md", "record-web-runtime-presentation.mjs");
assertIncludes("docs/testing.md", "test-record-web-runtime-presentation.mjs");
assertIncludes("docs/testing.md", "CDP browser is unavailable");
assertIncludes("docs/testing.md", "validate-web-runtime-presentation-manifest.mjs");
assertIncludes("docs/testing.md", "test-validate-web-runtime-presentation-manifest.mjs");
assertIncludes("docs/testing.md", "resize/input event-bridge");
assertIncludes("docs/testing.md", "Markdown Editor text input");
assertIncludes("docs/testing.md", "clean target close");
assertIncludes("docs/testing.md", "--web-presentation-manifest");
assertIncludes("docs/testing.md", "web-runtime-presentation.json");
assertIncludes("docs/testing.md", "web-runtime-handoff.json");
assertIncludes("docs/testing.md", "platform-runtime-evidence.json");
assertIncludes("docs/testing.md", "monitorCursor");
assertIncludes("docs/testing.md", "monitor/cursor");
assertIncludes("scripts/validate-platform-evidence-manifest.mjs", "schemaVersion must be 2");
assertIncludes("scripts/record-platform-evidence-manifest.mjs", "monitorCursor");
assertIncludes("scripts/record-platform-evidence-manifest.mjs", "browserObservablePlatformObservationsPassed");
assertIncludes("scripts/conformance-check.sh", '"schemaVersion": 2');
assertIncludes("scripts/conformance-check.sh", '"monitorCursor": "pending"');
assertIncludes(
  "docs/testing.md",
  "node scripts/test-validate-conformance-capture-manifest.mjs",
);
assertIncludes(
  "docs/testing.md",
  "node scripts/test-validate-platform-evidence-manifest.mjs",
);
assertIncludes(
  "docs/testing.md",
  "node scripts/test-record-platform-evidence-manifest.mjs",
);
assertIncludes(
  "scripts/dev-check.sh",
  "node scripts/test-validate-conformance-capture-manifest.mjs",
);
assertIncludes(
  "scripts/dev-check.sh",
  "node scripts/test-validate-platform-evidence-manifest.mjs",
);
assertIncludes(
  "scripts/dev-check.sh",
  "node scripts/test-record-platform-evidence-manifest.mjs",
);
assertIncludes("scripts/check-local-deps.sh", "docs/moui-integration-smoke.md");
assertIncludes("scripts/check-local-deps.sh", "scripts/record_moui_evidence.sh");
assertIncludes("scripts/check-local-deps.sh", "xdg-shell-protocol.c");
assertIncludes("scripts/check-local-deps.sh", "skia-platform-status.json");
assertIncludes("scripts/check-local-deps.sh", "skia-provider-lock.json");
assertIncludes("scripts/check-local-deps.sh", "verify-platform-status.sh");
assertIncludes("scripts/setup-local-deps.sh", "merge --ff-only");
assertIncludes("docs/development.md", "fast-forwards existing clean checkouts");
assertIncludes("docs/development.md", "skia-platform-status.json");
assertIncludes("docs/development.md", "verify-platform-status.sh");
assertIncludes("scripts/conformance-check.sh", "xdg-shell-protocol.c");
for (const path of [
  "examples/counter/web_wasm/index.html",
  "examples/showcase/web_wasm/index.html",
  "examples/markdown_editor/web_wasm/index.html",
]) {
  assertIncludes(path, "../../../moui/backend/web/runtime.js");
}
assertIncludes("docs/testing.md", "scripts/record_moui_evidence.sh");
assertIncludes("docs/testing.md", "generated Wayland protocol C sources");
assertIncludes("docs/testing.md", "skia-platform-status.json");
assertIncludes("docs/testing.md", "verify-platform-status.sh");
assertIncludes("docs/platform-notes.md", "check_moui_linux_smoke.sh");
assertIncludes("docs/release-readiness.md", "platform-runtime-evidence.json");
assertIncludes("docs/release-readiness.md", "skia-platform-status.json");
assertIncludes("docs/release-readiness.md", "verify-platform-status.sh");
assertIncludes("docs/release-readiness.md", "record-platform-evidence-manifest.mjs");
assertIncludes("docs/release-readiness.md", "validate-web-runtime-handoff.mjs");
assertIncludes("docs/release-readiness.md", "validate-web-runtime-handoff-manifest.mjs");
assertIncludes("docs/release-readiness.md", "web-runtime-handoff.json");
assertIncludes("docs/release-readiness.md", "record-web-runtime-presentation.mjs");
assertIncludes("docs/release-readiness.md", "validate-web-runtime-presentation-manifest.mjs");
assertIncludes("docs/release-readiness.md", "web-runtime-presentation.json");
assertIncludes("docs/release-readiness.md", "resize/input event-bridge");
assertIncludes("docs/release-readiness.md", "Markdown Editor text input");
assertIncludes("docs/release-readiness.md", "--web-presentation-manifest");
assertIncludes("docs/release-readiness.md", "monitor/cursor");
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "scripts/record_moui_evidence.sh",
);
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "fast-forwards clean local dependency checkouts",
);
assertIncludes("AGENTS.md", "scripts/record_moui_evidence.sh");
assertIncludes("AGENTS.md", "fast-forwards existing clean local dependency");
assertIncludes("AGENTS.md", "skia-platform-status.json");
assertIncludes("AGENTS.md", "verify-platform-status.sh");
assertIncludes("AGENTS.md", "platform-runtime-evidence.json");
assertIncludes("AGENTS.md", "record-platform-evidence-manifest.mjs");
assertIncludes("AGENTS.md", "validate-web-runtime-handoff.mjs");
assertIncludes("AGENTS.md", "test-validate-web-runtime-handoff.mjs");
assertIncludes("AGENTS.md", "validate-web-runtime-handoff-manifest.mjs");
assertIncludes("AGENTS.md", "record-web-runtime-presentation.mjs");
assertIncludes("AGENTS.md", "test-record-web-runtime-presentation.mjs");
assertIncludes("AGENTS.md", "validate-web-runtime-presentation-manifest.mjs");
assertIncludes("AGENTS.md", "CDP is unavailable");
assertIncludes("AGENTS.md", "resize/input event-bridge");
assertIncludes("AGENTS.md", "--web-presentation-manifest");
assertIncludes("AGENTS.md", "monitor/cursor");
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "resize/input event-bridge delivery",
);
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "verify-platform-status.sh",
);
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "test-record-web-runtime-presentation.mjs",
);
assertIncludes("moui/README.mbt.md", "sh scripts/dev-check.sh --platform-examples-test");
assertIncludes("moui/README.mbt.md", "sh scripts/conformance-check.sh --platform-services");
assertIncludes("moui/README.mbt.md", "verify-platform-status.sh");
assertIncludes("moui/README.mbt.md", "platform-runtime-evidence.json");
assertIncludes("moui/README.mbt.md", "record-platform-evidence-manifest.mjs");
assertIncludes("moui/README.mbt.md", "validate-web-runtime-handoff.mjs");
assertIncludes("moui/README.mbt.md", "record-web-runtime-presentation.mjs");
assertIncludes("moui/README.mbt.md", "resize/input");
assertIncludes("moui/README.mbt.md", "--web-presentation-manifest");
assertIncludes("moui/README.mbt.md", "monitor/cursor");
assertIncludes("moui/README.mbt.md", "artifacts/conformance/");
assertIncludes("scripts/record-web-runtime-presentation.mjs", "platformObservations");
assertIncludes("scripts/record-web-runtime-presentation.mjs", "writePreflightFailureManifest");
assertIncludes("scripts/record-web-runtime-presentation.mjs", "resizeEvent");
assertIncludes("scripts/record-web-runtime-presentation.mjs", "targetClosed");
assertIncludes("scripts/validate-web-runtime-presentation-manifest.mjs", "platformObservations");
assertIncludes("scripts/record-platform-evidence-manifest.mjs", "webPlatformObservations");
assertIncludes("moui/backend/web/browser_runtime.js", "__mouiWebRuntimeEvidence");

if (failed) {
  process.exit(1);
}

console.log("guidance consistency guard: ok");
