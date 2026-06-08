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
  ".github/workflows/moui-real-skia-smoke.yml",
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
assertIncludes("docs/examples.md", "examples/markdown_editor/windows_wgpu_cosmic");
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
  "scripts/record-native-ime-evidence.mjs",
  "record-platform-evidence-manifest.mjs",
);
assertIncludes(
  "scripts/record-native-ime-evidence.mjs",
  "native IME runtime evidence",
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
  "node scripts/test-record-native-ime-evidence.mjs",
);
assertIncludes(
  "scripts/dev-check.sh",
  "node scripts/test-record-native-skia-evidence.mjs",
);
assertIncludes("scripts/dev-check.sh", "node --check scripts/validate-renderer-proof-manifest.mjs");
assertIncludes(
  "scripts/dev-check.sh",
  "node scripts/test-validate-renderer-proof-manifest.mjs",
);
assertIncludes("scripts/dev-check.sh", "node --check scripts/record-renderer-proof-manifest.mjs");
assertIncludes(
  "scripts/dev-check.sh",
  "node scripts/test-record-renderer-proof-manifest.mjs",
);
assertIncludes("scripts/dev-check.sh", "node --check scripts/record-web-renderer-proof-manifest.mjs");
assertIncludes(
  "scripts/dev-check.sh",
  "node scripts/test-record-web-renderer-proof-manifest.mjs",
);
assertIncludes("scripts/dev-check.sh", "node --check scripts/ci-renderer-proof-native.mjs");
assertIncludes("scripts/dev-check.sh", "sh -n scripts/ci-renderer-proof-native.sh");
assertIncludes("scripts/dev-check.sh", "sh -n scripts/ci-renderer-proof-summary.sh");
assertIncludes("scripts/dev-check.sh", "--wgpu-experimental");
assertIncludes("scripts/dev-check.sh", "Skipping native WGPU renderer diagnostics");
assertIncludes("scripts/conformance-check.sh", "--wgpu-experimental");
assertIncludes(
  "scripts/conformance-check.sh",
  "Native WGPU entrypoints are retained as experimental diagnostics outside this mainline manifest.",
);
assertIncludes("moui/README.mbt.md", "native Skia raster");
assertIncludes(
  "moui/render/renderer.mbt",
  "RendererSelection::Backend(RendererBackendKind::SkiaRasterNative)",
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
assertIncludes(".github/workflows/ci.yml", "renderer-proof-wgpu-native:");
assertIncludes(".github/workflows/ci.yml", "name: Native WGPU renderer diagnostic");
assertIncludes(".github/workflows/ci.yml", "continue-on-error: true");
assertIncludes(".github/workflows/ci.yml", "renderer-proof-skia-native:");
assertIncludes(".github/workflows/ci.yml", "renderer-proof-summary:");
assertIncludes(".github/workflows/ci.yml", "node scripts/ci-renderer-proof-native.mjs wgpu-native");
assertIncludes(".github/workflows/ci.yml", "node scripts/ci-renderer-proof-native.mjs skia-native");
assertIncludes(".github/workflows/ci.yml", "--enable-skparagraph --require-skparagraph --write");
assertIncludes(".github/workflows/ci.yml", "-EnableSkParagraph -RequireSkParagraph -Write");
assertIncludes(".github/workflows/ci.yml", "artifacts/conformance/renderer-proof/");
assertIncludes(".github/workflows/ci.yml", "artifacts/platform-evidence/${{ matrix.platform }}/");
assertIncludes("scripts/ci-renderer-proof-native.mjs", 'if (backend === "skia-native")');
assertIncludes("scripts/ci-renderer-proof-native.mjs", 'recordArgs.push("--require-passed")');
assertIncludes("scripts/ci-renderer-proof-native.sh", 'if [ "$backend" = "skia-native" ]; then');
assertIncludes("scripts/ci-renderer-proof-native.sh", 'set -- "$@" --require-passed');
assertIncludes(".github/workflows/ci.yml", "sh scripts/ci-renderer-proof-summary.sh artifacts/downloaded-renderer-proof");
assertIncludes("scripts/ci-renderer-proof-summary.sh", "--artifact-root");
assertIncludes("scripts/ci-renderer-proof-summary.sh", "skia-native-macos.json");
assertIncludes("scripts/ci-renderer-proof-summary.sh", "skia-native-windows.json");
assertIncludes("scripts/ci-renderer-proof-summary.sh", "skia-native-linux.json");
assertIncludes("scripts/ci-renderer-proof-summary.sh", "webgpu-wasm-web.json");
assertAbsent("scripts/ci-renderer-proof-summary.sh", "wgpu-native-macos.json");
assertAbsent("scripts/ci-renderer-proof-summary.sh", "wgpu-native-windows.json");
assertAbsent("scripts/ci-renderer-proof-summary.sh", "wgpu-native-linux.json");
assertAbsent(".github/workflows/ci.yml", "run_real_skia_smoke");
assertAbsent(".github/workflows/ci.yml", "real-skia-smoke:");
assertIncludes(".github/workflows/moui-real-skia-smoke.yml", "name: MoUI Real Skia Smoke");
assertIncludes(".github/workflows/moui-real-skia-smoke.yml", "workflow_dispatch:");
assertIncludes(".github/workflows/moui-real-skia-smoke.yml", "macos-real-skia-smoke:");
assertIncludes(".github/workflows/moui-real-skia-smoke.yml", "scripts/macos-skia-renderer-smoke.sh");
assertIncludes(".github/workflows/moui-real-skia-smoke.yml", "--smoke-log artifacts/platform-evidence/macos/skia-renderer-smoke.log");
assertIncludes(".github/workflows/moui-real-skia-smoke.yml", "--run-showcase-smoke");
assertIncludes(".github/workflows/moui-real-skia-smoke.yml", "--run-markdown-smoke");
assertIncludes(".github/workflows/moui-real-skia-smoke.yml", "moui-macos-real-skia-smoke");
assertIncludes("docs/testing.md", ".github/workflows/moui-real-skia-smoke.yml");
assertIncludes("docs/testing.md", "not create a skipped real-Skia check");
assertIncludes("AGENTS.md", ".github/workflows/moui-real-skia-smoke.yml");
assertIncludes("skills/moui-framework-development-skill/SKILL.md", ".github/workflows/moui-real-skia-smoke.yml");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "moon build examples/showcase/web_wasm --target wasm-gc");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "moon build examples/markdown_editor/web_wasm --target wasm-gc");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "python3 -m http.server");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "--remote-debugging-port=\"$WEB_RUNTIME_CDP_PORT\"");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "--enable-unsafe-webgpu");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "--use-angle=swiftshader");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "node scripts/record-web-runtime-presentation.mjs");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "--require-passed");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "node scripts/validate-web-runtime-presentation-manifest.mjs");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "node scripts/record-web-renderer-proof-manifest.mjs");
assertIncludes("scripts/ci-web-runtime-presentation.sh", "artifacts/conformance/renderer-proof/webgpu-wasm-web.json");
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
assertIncludes("docs/testing.md", "validate-renderer-proof-manifest.mjs");
assertIncludes("docs/testing.md", "test-validate-renderer-proof-manifest.mjs");
assertIncludes("docs/testing.md", "record-renderer-proof-manifest.mjs");
assertIncludes("docs/testing.md", "test-record-renderer-proof-manifest.mjs");
assertIncludes("docs/testing.md", "record-web-renderer-proof-manifest.mjs");
assertIncludes("docs/testing.md", "test-record-web-renderer-proof-manifest.mjs");
assertIncludes("docs/testing.md", "ci-renderer-proof-native.sh");
assertIncludes("docs/testing.md", "ci-renderer-proof-summary.sh");
assertIncludes("docs/testing.md", "renderer-proof-summary");
assertIncludes("docs/testing.md", "skia-text-emoji-smoke.log");
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
assertIncludes(
  "scripts/validate-platform-evidence-manifest.mjs",
  "README.md placeholder documentation",
);
assertIncludes(
  "scripts/test-validate-platform-evidence-manifest.mjs",
  "passed platform rejects README placeholder artifact",
);
assertIncludes(
  "scripts/test-validate-platform-evidence-manifest.mjs",
  "linux evidence requires linux_skia runtime command",
);
assertIncludes(
  "scripts/test-record-native-skia-evidence.mjs",
  "moon build examples/showcase/linux_skia --target native",
);
assertIncludes(
  "scripts/test-record-native-skia-evidence.mjs",
  "moon run examples/showcase/linux_skia --target native",
);
assertIncludes(
  "scripts/conformance-check.sh",
  "moon build examples/showcase/linux_skia --target native",
);
assertIncludes(
  "scripts/conformance-check.sh",
  "moon run examples/showcase/linux_skia --target native",
);
assertIncludes(
  "scripts/validate-platform-evidence-manifest.mjs",
  "moon build examples/showcase/linux_skia --target native",
);
assertIncludes(
  "scripts/validate-platform-evidence-manifest.mjs",
  "moon run examples/showcase/linux_skia --target native",
);
assertIncludes(
  "scripts/test-record-platform-evidence-manifest.mjs",
  "moon build examples/showcase/linux_skia --target native",
);
assertIncludes(
  "scripts/test-record-platform-evidence-manifest.mjs",
  "moon run examples/showcase/linux_skia --target native",
);
assertIncludes("docs/release-readiness.md", "Platform evidence guard refresh");
assertIncludes("docs/testing.md", "README.md` files under `artifacts/platform-evidence/`");
assertIncludes("AGENTS.md", "must not be used as passed platform, Skia, or provenance");
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "must not be used as passed platform, Skia, or",
);
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
  "node scripts/test-record-native-ime-evidence.mjs",
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
assertIncludes("docs/release-readiness.md", "record-native-ime-evidence.mjs");
assertIncludes("docs/release-readiness.md", "record-native-skia-evidence.mjs");
assertIncludes("docs/release-readiness.md", "validate-web-runtime-handoff.mjs");
assertIncludes("docs/release-readiness.md", "validate-web-runtime-handoff-manifest.mjs");
assertIncludes("docs/release-readiness.md", "web-runtime-handoff.json");
assertIncludes("docs/release-readiness.md", "record-web-runtime-presentation.mjs");
assertIncludes("docs/release-readiness.md", "validate-web-runtime-presentation-manifest.mjs");
assertIncludes("docs/release-readiness.md", "web-runtime-presentation.json");
assertIncludes("docs/release-readiness.md", "Renderer proof manifest");
assertIncludes("docs/release-readiness.md", "validate-renderer-proof-manifest.mjs");
assertIncludes("docs/release-readiness.md", "artifact root");
assertIncludes("docs/release-readiness.md", "radialGradient");
assertIncludes("docs/release-readiness.md", "colorEmojiPixels");
assertIncludes("docs/release-readiness.md", "stable-glyph-key");
assertIncludes("scripts/validate-renderer-proof-manifest.mjs", "stable-glyph-key");
assertIncludes("scripts/record-renderer-proof-manifest.mjs", "fallback-request");
assertIncludes("docs/release-readiness.md", "selectionRects");
assertIncludes("docs/release-readiness.md", "imeCompositionVisual");
assertIncludes("docs/release-readiness.md", "asyncImageSecondFrame");
assertIncludes("docs/release-readiness.md", "resize/input event-bridge");
assertIncludes("docs/release-readiness.md", "Markdown Editor text input");
assertIncludes("docs/release-readiness.md", "--web-presentation-manifest");
assertIncludes("docs/release-readiness.md", "monitor/cursor");
assertIncludes("docs/release-readiness.md", "evidenceProvenance");
assertIncludes("docs/release-readiness.md", "non-skipped successful GitHub Actions job");
assertIncludes("docs/release-readiness.md", "Web host capability reporting now advertises browser IME plumbing");
assertIncludes("docs/release-readiness.md", "HostEventSource::subscription");
assertIncludes("docs/release-readiness.md", "HostEventSource::publish");
assertIncludes("docs/release-readiness.md", "host-event subscription fanout");
assertIncludes("docs/release-readiness.md", "HostWindowEventSource::subscription");
assertIncludes("docs/release-readiness.md", "HostWindowEventSource::publish");
assertIncludes("docs/release-readiness.md", "window-scoped subscription fanout");
assertIncludes("docs/release-readiness.md", "HostPlatformEventSources");
assertIncludes("docs/release-readiness.md", "normalized runtime host/window events");
assertIncludes("docs/release-readiness.md", "HostRouteSource::subscription");
assertIncludes("docs/release-readiness.md", "HostRouteSource::publish");
assertIncludes("docs/release-readiness.md", "route/deep-link subscription fanout");
assertIncludes("docs/release-readiness.md", "HostTimerSource::subscription");
assertIncludes("docs/release-readiness.md", "HostTimerSource::new");
assertIncludes("docs/release-readiness.md", "scheduler-backed timer subscriptions");
assertIncludes("docs/architecture.md", "`HostEventSource`");
assertIncludes("docs/architecture.md", "`Subscription::host_event`");
assertIncludes("docs/architecture.md", "`HostWindowEventSource`");
assertIncludes("docs/architecture.md", "`HostWindowEvent`");
assertIncludes("docs/architecture.md", "`Subscription::window_event`");
assertIncludes("docs/architecture.md", "`HostPlatformEventSources`");
assertIncludes("docs/architecture.md", "Web, macOS, Windows, and Linux app options");
assertIncludes("docs/architecture.md", "`HostRouteSource`");
assertIncludes("docs/architecture.md", "`HostRouteEvent`");
assertIncludes("docs/architecture.md", "`Subscription::route_event`");
assertIncludes("docs/architecture.md", "`HostTimerSource`");
assertIncludes("docs/architecture.md", "`Subscription::timer`");
assertIncludes("docs/testing.md", "Host event, window, timer, and route subscriptions");
assertIncludes("docs/testing.md", "window identity preservation");
assertIncludes("docs/testing.md", "window/timer/route subscription adapter start/cleanup");
assertIncludes("docs/testing.md", "scheduler interval capture");
assertIncludes("docs/testing.md", "HostPlatformEventSources");
assertIncludes("docs/testing.md", "event-source wiring through `HostPlatformEventSources`");
assertIncludes("moui/backend/host/subscription_adapters.mbt", "pub struct HostEventSource");
assertIncludes("moui/backend/host/subscription_adapters.mbt", "pub struct HostPlatformEventSources");
assertIncludes("moui/backend/host/subscription_adapters.mbt", "pub(all) struct HostPlatformEventPublishResult");
assertIncludes("moui/backend/host/subscription_adapters.mbt", "HostPlatformEventSources::publish");
assertIncludes("moui/backend/host/subscription_adapters.mbt", "Subscription::host_event");
assertIncludes("moui/backend/web/host_runtime.mbt", "event_sources : @host.HostPlatformEventSources?");
assertIncludes("moui/backend/web/host_runtime.mbt", "publish_subscription_event");
assertIncludes("moui/backend/macos/macos_backend.mbt", "event_sources : @host.HostPlatformEventSources?");
assertIncludes("moui/backend/macos/macos_backend.mbt", "publish_subscription_event");
assertIncludes("moui/backend/windows/windows_backend.mbt", "event_sources : @host.HostPlatformEventSources?");
assertIncludes("moui/backend/windows/windows_backend.mbt", "publish_subscription_event");
assertIncludes("moui/backend/linux/linux_backend.mbt", "event_sources : @host.HostPlatformEventSources?");
assertIncludes("moui/backend/linux/linux_backend.mbt", "publish_subscription_event");
assertIncludes("moui/backend/host/subscription_adapters.mbt", "pub(all) struct HostWindowEvent");
assertIncludes("moui/backend/host/subscription_adapters.mbt", "pub struct HostWindowEventSource");
assertIncludes("moui/backend/host/subscription_adapters.mbt", "HostWindowEventSource::publish");
assertIncludes("moui/backend/host/subscription_adapters.mbt", "HostWindowEventSource::subscription");
assertIncludes("moui/backend/host/subscription_adapters.mbt", "Subscription::window_event");
assertIncludes("moui/backend/host/subscription_adapters.mbt", "pub(all) struct HostRouteEvent");
assertIncludes("moui/backend/host/subscription_adapters.mbt", "pub struct HostRouteSource");
assertIncludes("moui/backend/host/subscription_adapters.mbt", "HostRouteEvent::from_route");
assertIncludes("moui/backend/host/subscription_adapters.mbt", "HostRouteSource::publish");
assertIncludes("moui/backend/host/subscription_adapters.mbt", "HostRouteSource::subscription");
assertIncludes("moui/backend/host/subscription_adapters.mbt", "Subscription::route_event");
assertIncludes("moui/backend/host/subscription_adapters.mbt", "pub struct HostTimerSource");
assertIncludes("moui/backend/host/subscription_adapters.mbt", "HostTimerSource::subscription");
assertIncludes("moui/backend/host/subscription_adapters.mbt", "Subscription::timer");
assertIncludes("moui/backend/host/host_test.mbt", "host event source subscription dispatches mapped host events");
assertIncludes("moui/backend/host/host_test.mbt", "host event source subscription cleanup removes late publishers");
assertIncludes("moui/backend/host/host_test.mbt", "host platform event sources publish host and window subscriptions");
assertIncludes("moui/backend/host/host_test.mbt", "host window event source subscription dispatches mapped window events");
assertIncludes("moui/backend/host/host_test.mbt", "host window event source subscription cleanup removes late publishers");
assertIncludes("moui/backend/host/host_test.mbt", "host route source subscription dispatches mapped route events");
assertIncludes("moui/backend/host/host_test.mbt", "host route event constructor preserves location and source");
assertIncludes("moui/backend/host/host_test.mbt", "host route source subscription cleanup removes late publishers");
assertIncludes("moui/backend/host/host_test.mbt", "host timer source subscription starts timer and dispatches mapped frames");
assertIncludes("moui/backend/host/host_test.mbt", "host timer source subscription cleanup cancels timer");
assertIncludes("docs/release-readiness.md", "HostImageResourceCompletionSource");
assertIncludes("docs/release-readiness.md", "native async image completion");
assertIncludes("docs/release-readiness.md", "provider/platform async loader");
assertIncludes("docs/release-readiness.md", "ImageResourceLoadCompletion");
assertIncludes("docs/release-readiness.md", "HostWindowRenderer::apply_image_resource_load_completion");
assertIncludes("docs/release-readiness.md", "HostAsyncImageLoader");
assertIncludes("docs/release-readiness.md", "optional provider-owned async image loader hooks");
assertIncludes("docs/release-readiness.md", "native_image_load_completion");
assertIncludes("docs/release-readiness.md", "WGPU provider-owned source completion wiring");
assertIncludes("docs/release-readiness.md", "deferred native-source callbacks can carry");
assertIncludes("docs/release-readiness.md", "skia_image_load_completion` payloads");
assertIncludes("docs/architecture.md", "`HostImageResourceCompletionSource`");
assertIncludes("docs/architecture.md", "`HostWindowRenderer::apply_image_resource_load_completion`");
assertIncludes("docs/architecture.md", "`HostAsyncImageLoader`");
assertIncludes("docs/architecture.md", "optional provider-owned loader hook");
assertIncludes("docs/architecture.md", "Native WGPU provider packages now supply");
assertIncludes("docs/testing.md", "Native async image completion");
assertIncludes("docs/testing.md", "schedule/publish/apply/redraw/cleanup");
assertIncludes("docs/testing.md", "native provider async-image hook wiring");
assertIncludes("docs/testing.md", "moon test moui/backend/macos/wgpu --target native");
assertIncludes("docs/testing.md", "provider package tests also pin");
assertIncludes("docs/testing.md", "`HostNativeAsyncImageSource` callback");
assertIncludes("docs/testing.md", "native-source callback boundary");
assertIncludes("docs/platform-notes.md", "optional provider-owned `HostAsyncImageLoader`");
assertIncludes("AGENTS.md", "native async image completion source");
assertIncludes("AGENTS.md", "image-resource load completion apply bridge");
assertIncludes("AGENTS.md", "native async image loading-record scheduler");
assertIncludes("AGENTS.md", "native provider async-image scheduling hooks");
assertIncludes("AGENTS.md", "native_image_load_completion");
assertIncludes("skills/moui-framework-development-skill/SKILL.md", "native async image completion source");
assertIncludes("skills/moui-framework-development-skill/SKILL.md", "`HostWindowRenderer::apply_image_resource_load_completion`");
assertIncludes("skills/moui-framework-development-skill/SKILL.md", "`HostAsyncImageLoader`");
assertIncludes("skills/moui-framework-development-skill/SKILL.md", "provider-owned image loaders");
assertIncludes("skills/moui-framework-development-skill/SKILL.md", "native_image_load_completion");
assertIncludes("moui/render/image_lifecycle.mbt", "pub(all) struct ImageResourceLoadCompletion");
assertIncludes("moui/render/image_lifecycle.mbt", "ImageResourceLifecycle::apply_load_completion");
assertIncludes("moui/render/wgpu/native_image.mbt", "pub fn native_image_load_completion");
assertIncludes("moui/backend/host/renderer.mbt", "HostWindowRenderer::apply_image_resource_load_completion");
assertIncludes("moui/backend/host/image_repaint.mbt", "pub struct HostImageResourceCompletionSource");
assertIncludes("moui/backend/host/image_repaint.mbt", "pub struct HostAsyncImageLoader");
assertIncludes("moui/backend/host/image_repaint.mbt", "pub struct HostNativeAsyncImageSource");
assertIncludes("moui/backend/host/image_repaint.mbt", "HostImageResourceCompletionSource::publish");
assertIncludes("moui/backend/host/image_repaint.mbt", "HostImageResourceCompletionSource::complete");
assertIncludes("moui/backend/host/image_repaint.mbt", "HostAsyncImageLoader::schedule_loading_resources");
assertIncludes("moui/backend/host/image_repaint.mbt", "HostNativeAsyncImageSource::loader");
assertIncludes("moui/backend/host/image_repaint.mbt", "HostNativeAsyncImageSource::complete");
assertIncludes(
  "moui/backend/host/pkg.generated.mbti",
  "pub fn HostNativeAsyncImageSource::complete",
);
assertIncludes("moui/backend/macos/macos_backend.mbt", "image_loader? : @host.HostAsyncImageLoader? = None");
assertIncludes("moui/backend/macos/macos_backend.mbt", "MacosRendererProvider::schedule_image_resource_loads");
assertIncludes("moui/backend/macos/macos_backend.mbt", "cancel_image_resource_loads");
assertIncludes("moui/backend/windows/windows_backend.mbt", "image_loader? : @host.HostAsyncImageLoader? = None");
assertIncludes("moui/backend/windows/windows_backend.mbt", "WindowsRendererProvider::schedule_image_resource_loads");
assertIncludes("moui/backend/windows/windows_backend.mbt", "cancel_image_resource_loads");
assertIncludes("moui/backend/linux/linux_backend.mbt", "image_loader? : @host.HostAsyncImageLoader? = None");
assertIncludes("moui/backend/linux/linux_backend.mbt", "LinuxRendererProvider::schedule_image_resource_loads");
assertIncludes("moui/backend/linux/linux_backend.mbt", "cancel_image_resource_loads");
assertIncludes("moui/backend/macos/wgpu/macos_wgpu_provider.mbt", "wgpu_native_image_loader");
assertIncludes("moui/backend/macos/wgpu/macos_wgpu_provider.mbt", "image_loader=Some(wgpu_native_image_loader())");
assertIncludes("moui/backend/windows/wgpu/windows_wgpu_provider.mbt", "wgpu_native_image_loader");
assertIncludes("moui/backend/windows/wgpu/windows_wgpu_provider.mbt", "image_loader=Some(wgpu_native_image_loader())");
assertIncludes("moui/backend/linux/wgpu/linux_wgpu_provider.mbt", "wgpu_native_image_loader");
assertIncludes("moui/backend/linux/wgpu/linux_wgpu_provider.mbt", "image_loader=Some(wgpu_native_image_loader())");
assertIncludes("moui/render/skia/renderer.mbt", "pub fn skia_image_load_completion");
assertIncludes(
  "moui/render/skia/pkg.generated.mbti",
  "pub fn skia_image_load_completion(String) -> @render.ImageResourceLoadCompletion",
);
assertIncludes(
  "moui/render/skia/pkg.generated.mbti",
  "async_image_loading? : Bool",
);
assertIncludes(
  "moui/render/skia/skia_renderer_wbtest.mbt",
  "skia image load completion reports decoded dimensions or fallback failure",
);
assertIncludes(
  "moui/render/skia/skia_renderer_wbtest.mbt",
  "skia renderer async image loading waits for explicit completion before caching",
);
assertIncludes("moui/render/skia/renderer.mbt", "async_image_loading? : Bool = false");
assertIncludes(
  "moui/tests/skia_renderer_smoke/native/main.mbt",
  "MoUI Skia async image second-frame smoke passed",
);
assertIncludes("scripts/record-platform-evidence-manifest.mjs", "asyncImageSecondFrame");
assertIncludes("scripts/record-native-skia-evidence.mjs", "--async-image-log");
assertIncludes("scripts/record-native-ime-evidence.mjs", "--candidate-anchor-log");
assertIncludes("scripts/record-native-ime-evidence.mjs", "--scale-dpr-anchor-log");
assertIncludes("scripts/record-native-ime-evidence.mjs", "platform-protocol=windows-ime");
assertIncludes("scripts/record-native-ime-evidence.mjs", "candidate-window");
assertIncludes("scripts/record-native-ime-evidence.mjs", "preedit-underline");
assertIncludes("scripts/test-record-native-ime-evidence.mjs", "platform-protocol=wayland-text-input");
assertIncludes("scripts/test-record-native-ime-evidence.mjs", "host unit test");
assertIncludes("docs/testing.md", "asyncImageSecondFrame=yes");
assertIncludes("docs/testing.md", "selection rectangles");
assertIncludes("docs/testing.md", "IME candidate anchors");
assertIncludes("docs/testing.md", "platform-protocol=windows-ime");
assertIncludes("AGENTS.md", "platform-protocol=wayland-text-input");
for (const platform of ["macos", "windows", "linux"]) {
  assertIncludes(
    `moui/backend/${platform}/skia/${platform}_skia_provider.mbt`,
    "skia_native_image_loader",
  );
  assertIncludes(
    `moui/backend/${platform}/skia/${platform}_skia_provider.mbt`,
    "image_loader=Some(skia_native_image_loader())",
  );
  assertIncludes(
    `moui/backend/${platform}/skia/${platform}_skia_provider.mbt`,
    "renderer_image_loader=skia_image_load_completion",
  );
  assertIncludes(
    `moui/backend/${platform}/skia/${platform}_skia_provider.mbt`,
    "renderer_async_image_loading=post-present",
  );
  assertIncludes(
    `moui/backend/${platform}/skia/${platform}_skia_provider.mbt`,
    "async_image_loading=true",
  );
  assertIncludes(
    `moui/backend/${platform}/skia/${platform}_skia_provider_wbtest.mbt`,
    `${platform} skia native image loader completes loading resources`,
  );
}
assertIncludes("AGENTS.md", "skia_image_load_completion");
assertIncludes("docs/architecture.md", "skia_image_load_completion");
assertIncludes("docs/release-readiness.md", "skia_image_load_completion");
assertIncludes("docs/renderer-capability-report.md", "skia_image_load_completion");
assertIncludes("docs/testing.md", "skia_image_load_completion");
assertIncludes("skills/moui-framework-development-skill/SKILL.md", "skia_image_load_completion");
assertIncludes("AGENTS.md", "deferred native completion request source");
assertIncludes("docs/architecture.md", "HostNativeAsyncImageSource");
assertIncludes("docs/release-readiness.md", "HostNativeAsyncImageSource");
assertIncludes("docs/renderer-capability-report.md", "HostNativeAsyncImageSource");
assertIncludes("docs/renderer-capability-report.md", "renderer decode-helper payloads");
assertIncludes("docs/renderer-capability-report.md", "deferred native-source callback");
assertIncludes("docs/testing.md", "deferred native request capture");
assertIncludes("skills/moui-framework-development-skill/SKILL.md", "HostNativeAsyncImageSource");
assertIncludes("moui/render/wgpu/renderer.mbt", "WgpuRenderer::apply_image_resource_load_completion");
assertIncludes("moui/render/skia/renderer.mbt", "SkiaRasterRenderer::apply_image_resource_load_completion");
assertIncludes("moui/render/webgpu_adapter/adapter.mbt", "WebGpuWasmRenderer::apply_image_resource_load_completion");
assertIncludes("moui/backend/web/webgpu_renderer.mbt", "WebRenderer::apply_image_resource_load_completion");
assertIncludes("moui/backend/macos/wgpu/macos_wgpu_provider.mbt", "apply_image_resource_load_completion=Some");
assertIncludes("moui/backend/windows/wgpu/windows_wgpu_provider.mbt", "apply_image_resource_load_completion=Some");
assertIncludes("moui/backend/linux/wgpu/linux_wgpu_provider.mbt", "apply_image_resource_load_completion=Some");
assertIncludes("moui/backend/macos/skia/macos_skia_provider.mbt", "renderer_image_resource_apply=SkiaRasterRenderer.apply_image_resource_load_completion");
assertIncludes("moui/backend/windows/skia/windows_skia_provider.mbt", "renderer_image_resource_apply=SkiaRasterRenderer.apply_image_resource_load_completion");
assertIncludes("moui/backend/linux/skia/linux_skia_provider.mbt", "renderer_image_resource_apply=SkiaRasterRenderer.apply_image_resource_load_completion");
assertIncludes("moui/backend/host/host_test.mbt", "host image completion source routes native loader completions");
assertIncludes("moui/backend/host/host_test.mbt", "host image completion source discards closed-window completions");
assertIncludes("moui/backend/host/host_test.mbt", "host image completion source ignores stale completion revisions");
assertIncludes("moui/backend/host/host_test.mbt", "host image completion source applies renderer load completions");
assertIncludes("moui/backend/host/host_test.mbt", "host async image loader schedules loading records and completes redraw");
assertIncludes("moui/backend/host/host_test.mbt", "host async image loader cancels window loads and ignores late completions");
assertIncludes("moui/backend/host/host_test.mbt", "host async image loader ignores mismatched completion sources");
assertIncludes(
  "moui/backend/host/host_test.mbt",
  "host native async image source defers completion until platform callback",
);
assertIncludes(
  "moui/backend/host/host_test.mbt",
  "host native async image source drops completions after loader cancellation",
);
assertIncludes("moui/backend/macos/macos_backend_wbtest.mbt", "macos renderer provider exposes async image loader hook");
assertIncludes("moui/backend/macos/macos_backend_wbtest.mbt", "macos renderer provider async image hook defaults to unavailable");
assertIncludes("moui/backend/windows/windows_backend_wbtest.mbt", "windows renderer provider exposes async image loader hook");
assertIncludes("moui/backend/windows/windows_backend_wbtest.mbt", "windows renderer provider async image hook defaults to unavailable");
assertIncludes("moui/backend/linux/linux_backend_wbtest.mbt", "linux renderer provider exposes async image loader hook");
assertIncludes("moui/backend/linux/linux_backend_wbtest.mbt", "linux renderer provider async image hook defaults to unavailable");
assertIncludes("moui/render/wgpu/native_image_wbtest.mbt", "native image load completion reports decoded dimensions or failure");
for (const platform of ["macos", "windows", "linux"]) {
  assertIncludes(
    `moui/backend/${platform}/wgpu/${platform}_wgpu_provider_wbtest.mbt`,
    `${platform} wgpu native image loader completes loading resources`,
  );
  assertIncludes(
    `moui/backend/${platform}/wgpu/${platform}_wgpu_provider_wbtest.mbt`,
    `${platform} wgpu deferred native source completes through decode helper`,
  );
  assertIncludes(
    `moui/backend/${platform}/skia/${platform}_skia_provider_wbtest.mbt`,
    `${platform} skia deferred native source completes through decode helper`,
  );
}
assertIncludes("moui/render/capabilities_test.mbt", "image lifecycle applies async load completions");
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
assertIncludes("AGENTS.md", "record-native-ime-evidence.mjs");
assertIncludes("AGENTS.md", "record-native-skia-evidence.mjs");
assertIncludes("skills/moui-framework-development-skill/SKILL.md", "record-native-ime-evidence.mjs");
assertIncludes("AGENTS.md", "evidenceProvenance");
assertIncludes("AGENTS.md", "validate-web-runtime-handoff.mjs");
assertIncludes("AGENTS.md", "test-validate-web-runtime-handoff.mjs");
assertIncludes("AGENTS.md", "validate-web-runtime-handoff-manifest.mjs");
assertIncludes("AGENTS.md", "record-web-runtime-presentation.mjs");
assertIncludes("AGENTS.md", "test-record-web-runtime-presentation.mjs");
assertIncludes("AGENTS.md", "validate-web-runtime-presentation-manifest.mjs");
assertIncludes("AGENTS.md", "validate-renderer-proof-manifest.mjs");
assertIncludes("AGENTS.md", "test-validate-renderer-proof-manifest.mjs");
assertIncludes("AGENTS.md", "record-renderer-proof-manifest.mjs");
assertIncludes("AGENTS.md", "test-record-renderer-proof-manifest.mjs");
assertIncludes("AGENTS.md", "record-web-renderer-proof-manifest.mjs");
assertIncludes("AGENTS.md", "test-record-web-renderer-proof-manifest.mjs");
assertIncludes("AGENTS.md", "renderer-proof-summary");
assertIncludes("AGENTS.md", "colorEmojiPixels");
assertIncludes("AGENTS.md", "stable-glyph-key");
assertIncludes("AGENTS.md", "selectionRects");
assertIncludes("AGENTS.md", "imeCompositionVisual");
assertIncludes("AGENTS.md", "CDP is unavailable");
assertIncludes("AGENTS.md", "resize/input event-bridge");
assertIncludes("AGENTS.md", "--web-presentation-manifest");
assertIncludes("AGENTS.md", "monitor/cursor");
assertIncludes("AGENTS.md", "host-event fanout subscription adapters");
assertIncludes("AGENTS.md", "window-scoped subscription adapters");
assertIncludes("AGENTS.md", "platform event-source bundles");
assertIncludes("AGENTS.md", "scheduler-backed timer subscription adapters");
assertIncludes("AGENTS.md", "route/deep-link subscription adapters");
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
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "validate-renderer-proof-manifest.mjs",
);
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "test-record-renderer-proof-manifest.mjs",
);
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "renderer-proof-summary",
);
assertIncludes("AGENTS.md", "test-webgpu-runtime-radial.mjs");
assertIncludes("docs/testing.md", "test-webgpu-runtime-radial.mjs");
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "test-webgpu-runtime-radial.mjs",
);
assertIncludes("scripts/conformance-check.sh", "test-webgpu-runtime-radial.mjs");
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "host-event subscription source fanout",
);
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "HostEventSource::subscription",
);
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "window-scoped subscription source",
);
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "HostWindowEventSource::subscription",
);
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "HostPlatformEventSources",
);
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "normalized runtime host/window event stream",
);
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "route/deep-link subscription source",
);
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "HostRouteSource::subscription",
);
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "scheduler-backed timer subscription source",
);
assertIncludes(
  "skills/moui-framework-development-skill/SKILL.md",
  "HostTimerSource::subscription",
);
assertIncludes("skills/moui-app-development-skill/SKILL.md", "HostRouteSource");
assertIncludes("docs/platform-notes.md", "`HostRouteSource`");
assertIncludes("docs/view-catalog.md", "`@host.HostRouteSource`");
assertIncludes("docs/examples.md", "`HostRouteSource`");
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
