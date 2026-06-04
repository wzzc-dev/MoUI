#!/usr/bin/env node

import {
  existsSync,
  lstatSync,
  readFileSync,
  readdirSync,
  readlinkSync,
} from "node:fs";
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

const assertFileExists = path => {
  if (!existsSync(join(root, path))) {
    fail(`${path}: expected file to exist`);
  }
};

const assertNoWorkflowFiles = path => {
  const absolute = join(root, path);
  if (!existsSync(absolute)) return;
  const entries = readdirSync(absolute).filter(entry => /\.ya?ml$/.test(entry));
  if (entries.length > 0) {
    fail(`${path}: workflow files must live in root .github/workflows: ${entries.join(", ")}`);
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
  assertAbsent(path, "moui_skia/.github/workflows");
  assertAbsent(path, "`tests/*_conformance`");
  assertAbsent(path, "`tests/text_conformance/`");
  assertAbsent(path, "`tests/skia_renderer_smoke/native`");
  assertAbsent(path, "`README.mbt.md`");
}

for (const path of [
  ".github/workflows/moui-skia-fallback.yml",
  ".github/workflows/moui-skia-linux-real-skia-smoke.yml",
  ".github/workflows/moui-skia-macos-real-skia-smoke.yml",
  ".github/workflows/moui-skia-windows-real-skia-smoke.yml",
  ".github/workflows/moui-skia-real-skia-acceptance.yml",
  ".github/workflows/copilot-setup-steps.yml",
]) {
  assertFileExists(path);
}

for (const path of [
  ".github/workflows/moui-skia-fallback.yml",
  ".github/workflows/moui-skia-linux-real-skia-smoke.yml",
  ".github/workflows/moui-skia-macos-real-skia-smoke.yml",
  ".github/workflows/moui-skia-windows-real-skia-smoke.yml",
  ".github/workflows/moui-skia-real-skia-acceptance.yml",
]) {
  assertIncludes(path, "working-directory: moui_skia");
}

assertIncludes(".github/workflows/moui-skia-fallback.yml", "branches: [ main ]");
assertIncludes(".github/workflows/moui-skia-real-skia-acceptance.yml", "branches: [ main ]");
assertIncludes(".github/workflows/moui-skia-linux-real-skia-smoke.yml", "path: moui_skia/.skia-cache");
assertIncludes(".github/workflows/moui-skia-macos-real-skia-smoke.yml", "path: moui_skia/.skia-cache");
assertIncludes(".github/workflows/moui-skia-real-skia-acceptance.yml", "path: moui_skia/.skia-cache");
assertIncludes(".github/workflows/copilot-setup-steps.yml", "working-directory: moui_skia");
assertNoWorkflowFiles("moui_skia/.github/workflows");

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
  "scripts/record-native-skia-evidence.mjs",
  "record-platform-evidence-manifest.mjs",
);
assertIncludes(
  "scripts/record-native-skia-evidence.mjs",
  "Skia route evidence",
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
assertIncludes("scripts/dev-check.sh", "sh -n scripts/ci-web-runtime-presentation.sh");
assertIncludes(
  "scripts/dev-check.sh",
  "node scripts/test-record-native-skia-evidence.mjs",
);
assertIncludes(".github/workflows/ci.yml", "web-runtime-presentation:");
assertIncludes(".github/workflows/ci.yml", "name: Web runtime presentation");
assertIncludes(".github/workflows/ci.yml", "runs-on: ubuntu-24.04");
assertIncludes(".github/workflows/ci.yml", "WEB_RUNTIME_BASE_URL: http://127.0.0.1:18080");
assertIncludes(".github/workflows/ci.yml", "WEB_RUNTIME_CDP_URL: http://127.0.0.1:9223");
assertIncludes(".github/workflows/ci.yml", "WEB_RUNTIME_PRESENTATION_MANIFEST: artifacts/conformance/web-runtime-presentation.json");
assertIncludes(".github/workflows/ci.yml", "WEB_RUNTIME_PRESENTATION_ARTIFACT_NAME: moui-web-runtime-presentation");
assertIncludes(".github/workflows/ci.yml", "sh scripts/ci-web-runtime-presentation.sh");
assertIncludes(".github/workflows/ci.yml", "uses: actions/upload-artifact@v4");
assertIncludes(".github/workflows/ci.yml", "artifacts/conformance/web-runtime-presentation.json");
assertIncludes(".github/workflows/ci.yml", "artifacts/conformance/web-runtime-presentation/");
assertIncludes(".github/workflows/ci.yml", "artifacts/platform-evidence/web/");
assertIncludes(".github/workflows/ci.yml", "artifacts/conformance/platform-runtime-evidence.json");
assertIncludes(".github/workflows/ci.yml", "if-no-files-found: warn");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "moon build examples/showcase/web_wasm --target wasm-gc");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "moon build examples/markdown_editor/web_wasm --target wasm-gc");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "python3 -m http.server");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "--remote-debugging-port=\"$WEB_RUNTIME_CDP_PORT\"");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "--enable-unsafe-webgpu");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "--use-angle=swiftshader");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "node scripts/record-web-runtime-presentation.mjs");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "--require-passed");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "node scripts/validate-web-runtime-presentation-manifest.mjs");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "sh scripts/conformance-check.sh --platform-services");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "node scripts/record-platform-evidence-manifest.mjs");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "--web-presentation-manifest");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "node scripts/validate-platform-evidence-manifest.mjs");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "--platform web");
assertIncludes("docs/testing.md", "node scripts/validate-guidance-consistency.mjs");
assertIncludes("docs/testing.md", "validate-conformance-capture-manifest.mjs");
assertIncludes("docs/testing.md", "markdown-editor-web-wasm");
assertIncludes("docs/testing.md", "validate-platform-evidence-manifest.mjs");
assertIncludes("docs/testing.md", "record-platform-evidence-manifest.mjs");
assertIncludes("docs/testing.md", "record-native-skia-evidence.mjs");
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
assertIncludes("docs/testing.md", "evidenceProvenance");
assertIncludes("docs/testing.md", "non-skipped successful GitHub Actions job");
assertIncludes("docs/testing.md", "Web runtime presentation");
assertIncludes("docs/testing.md", "`moui-web-runtime-presentation` artifact");
assertIncludes("scripts/validate-platform-evidence-manifest.mjs", "schemaVersion must be 2");
assertIncludes("scripts/validate-platform-evidence-manifest.mjs", "evidenceProvenance");
assertIncludes("scripts/record-platform-evidence-manifest.mjs", "monitorCursor");
assertIncludes("scripts/record-platform-evidence-manifest.mjs", "provenance-kind");
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
  "docs/testing.md",
  "node scripts/test-record-native-skia-evidence.mjs",
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
assertIncludes("scripts/check-local-deps.sh", "check_web_assets.sh");
assertIncludes("scripts/check-local-deps.sh", "moon run \"$pkg\" --target native");
assertIncludes("scripts/check-local-deps.sh", "wzzc-dev/window/examples/window_web/window_web.wasm");
assertIncludes("scripts/check-local-deps.sh", "wzzc-dev/window/examples/moui_web_smoke/moui_web_smoke.wasm");
assertIncludes("scripts/check-local-deps.sh", "MOUISmoke: surface canvas_id=moui-web-smoke-canvas size=640x360");
assertIncludes("scripts/check-local-deps.sh", "skia-platform-status.json");
assertIncludes("scripts/check-local-deps.sh", "skia-provider-lock.json");
assertIncludes("scripts/check-local-deps.sh", "verify-platform-status.sh");
assertIncludes("scripts/check-local-deps.sh", "native/capabilities.json");
assertIncludes("scripts/check-local-deps.sh", "native/ownership.json");
assertIncludes("scripts/check-local-deps.sh", "verify-native-capability-contract.sh");
assertIncludes("scripts/setup-local-deps.sh", "merge --ff-only");
assertIncludes("docs/development.md", "fast-forwards the existing clean window checkout");
assertIncludes("docs/development.md", "module-qualified `wzzc-dev/window/examples/...`");
assertIncludes("docs/development.md", "skia-platform-status.json");
assertIncludes("docs/development.md", "verify-platform-status.sh");
assertIncludes("docs/development.md", "native/capabilities.json");
assertIncludes("docs/development.md", "verify-native-capability-contract.sh");
assertIncludes("docs/development.md", ".github/workflows/moui-skia-*.yml");
assertIncludes("docs/testing.md", ".github/workflows/moui-skia-fallback.yml");
assertIncludes("docs/testing.md", ".github/workflows/moui-skia-real-skia-acceptance.yml");
assertIncludes("docs/testing.md", ".github/workflows/copilot-setup-steps.yml");
assertIncludes("AGENTS.md", ".github/workflows/moui-skia-*.yml");
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  ".github/workflows/moui-skia-*.yml",
);
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
assertIncludes("docs/testing.md", "the macOS helper still executes the AppKit smoke through `moon run`");
assertIncludes("docs/testing.md", "module-qualified");
assertIncludes("docs/testing.md", "public consumer sentinel lines");
assertIncludes("docs/testing.md", "skia-platform-status.json");
assertIncludes("docs/testing.md", "verify-platform-status.sh");
assertIncludes("docs/testing.md", "native/capabilities.json");
assertIncludes("docs/testing.md", "verify-native-capability-contract.sh");
assertIncludes("docs/platform-notes.md", "check_moui_linux_smoke.sh");
assertIncludes("docs/platform-notes.md", "Wayland key/modifier mapping");
assertIncludes("docs/platform-notes.md", "current pointer coordinates");
assertIncludes("docs/release-readiness.md", "platform-runtime-evidence.json");
assertIncludes("docs/release-readiness.md", "skia-platform-status.json");
assertIncludes("docs/release-readiness.md", "verify-platform-status.sh");
assertIncludes("docs/release-readiness.md", "native/capabilities.json");
assertIncludes("docs/release-readiness.md", "verify-native-capability-contract.sh");
assertIncludes("docs/release-readiness.md", "Wayland key/modifier mapping");
assertIncludes("docs/release-readiness.md", "current button-event coordinates");
assertIncludes("docs/release-readiness.md", "record-platform-evidence-manifest.mjs");
assertIncludes("docs/release-readiness.md", "record-native-skia-evidence.mjs");
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
assertIncludes("docs/release-readiness.md", "evidenceProvenance");
assertIncludes("docs/release-readiness.md", "non-skipped successful GitHub Actions job");
assertIncludes("docs/release-readiness.md", "Web host capability reporting now advertises browser IME plumbing");
assertIncludes("docs/platform-notes.md", "The Web host now advertises IME readiness");
assertIncludes("docs/text-system.md", "routes browser IME composition events");
assertIncludes("moui/backend/web/web_host.mbt", "ime_ready=true");
assertIncludes("examples/showcase/app/showcase_app_test.mbt", "web ime readiness");
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "scripts/record_moui_evidence.sh",
);
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "evidenceProvenance",
);
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "non-skipped successful GitHub Actions job",
);
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "fast-forwards the clean local window dependency checkout",
);
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "`moon run examples/moui_macos_smoke --target native`",
);
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "module-qualified `wzzc-dev/window/examples/...`",
);
assertIncludes("AGENTS.md", "scripts/record_moui_evidence.sh");
assertIncludes("AGENTS.md", "fast-forwards the existing clean window");
assertIncludes("AGENTS.md", "`moon run examples/moui_macos_smoke --target native`");
assertIncludes("AGENTS.md", "module-qualified `wzzc-dev/window/examples/...`");
assertIncludes("AGENTS.md", "skia-platform-status.json");
assertIncludes("AGENTS.md", "verify-platform-status.sh");
assertIncludes("AGENTS.md", "native/capabilities.json");
assertIncludes("AGENTS.md", "verify-native-capability-contract.sh");
assertIncludes("AGENTS.md", "platform-runtime-evidence.json");
assertIncludes("AGENTS.md", "record-platform-evidence-manifest.mjs");
assertIncludes("AGENTS.md", "record-native-skia-evidence.mjs");
assertIncludes("AGENTS.md", "evidenceProvenance");
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
  "native/capabilities.json",
);
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "verify-native-capability-contract.sh",
);
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "test-record-web-runtime-presentation.mjs",
);
assertIncludes("docs/release-readiness.md", "`web-runtime-presentation`");
assertIncludes("docs/release-readiness.md", "`moui-web-runtime-presentation`");
assertIncludes("AGENTS.md", "`web-runtime-presentation`");
assertIncludes("AGENTS.md", "`moui-web-runtime-presentation`");
assertIncludes("skills/moui-framework-development-skill/SKILL.md", "`web-runtime-presentation`");
assertIncludes("skills/moui-framework-development-skill/SKILL.md", "`moui-web-runtime-presentation`");
assertIncludes("moui/README.mbt.md", "sh scripts/dev-check.sh --platform-examples-test");
assertIncludes("moui/README.mbt.md", "sh scripts/conformance-check.sh --platform-services");
assertIncludes("moui/README.mbt.md", "verify-platform-status.sh");
assertIncludes("moui/README.mbt.md", "verify-native-capability-contract.sh");
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
