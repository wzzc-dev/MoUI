// Generated from scripts/validate-guidance-consistency.mjs during the tools migration.
// Keep this contract synchronized with guidance policy changes.

///|
fn guidance_include_rules() -> Array[TextRule] {
  [
    { path: "docs/development.md", token: "./moui" },
    { path: "docs/development.md", token: "./tools" },
    { path: "docs/development.md", token: "./moui_skia" },
    { path: "docs/development.md", token: "./examples/counter" },
    { path: "docs/examples.md", token: "examples/counter/app/" },
    { path: "docs/development.md", token: "./examples/button_freeze_probe" },
    { path: "docs/examples.md", token: "examples/button_freeze_probe/app/" },
    { path: "docs/development.md", token: "./examples/showcase" },
    { path: "docs/examples.md", token: "examples/showcase/app/" },
    { path: "docs/development.md", token: "./examples/markdown_editor" },
    { path: "docs/examples.md", token: "examples/markdown_editor/app/" },
    { path: "docs/development.md", token: "./examples/pdf_workbench" },
    { path: "docs/examples.md", token: "examples/pdf_workbench/app/" },
    { path: "docs/development.md", token: "./examples/settings" },
    { path: "docs/examples.md", token: "examples/settings/app/" },
    { path: "docs/development.md", token: "./examples/data_table" },
    { path: "docs/examples.md", token: "examples/data_table/app/" },
    { path: "docs/development.md", token: "./examples/file_importer" },
    { path: "docs/examples.md", token: "examples/file_importer/app/" },
    { path: "docs/development.md", token: "./examples/command_palette" },
    { path: "docs/examples.md", token: "examples/command_palette/app/" },
    { path: "docs/development.md", token: "./examples/mo_workbench" },
    { path: "docs/examples.md", token: "examples/mo_workbench/app/" },
    { path: "docs/development.md", token: "./benchmarks/app_cached_layer" },
    { path: "docs/development.md", token: "./website" },
    {
      path: ".github/workflows/moui-skia-fallback.yml",
      token: "working-directory: moui_skia",
    },
    {
      path: ".github/workflows/moui-skia-linux-real-skia-smoke.yml",
      token: "working-directory: moui_skia",
    },
    {
      path: ".github/workflows/moui-skia-macos-real-skia-smoke.yml",
      token: "working-directory: moui_skia",
    },
    {
      path: ".github/workflows/moui-skia-windows-real-skia-smoke.yml",
      token: "working-directory: moui_skia",
    },
    {
      path: ".github/workflows/moui-skia-real-skia-acceptance.yml",
      token: "working-directory: moui_skia",
    },
    {
      path: ".github/workflows/moui-skia-fallback.yml",
      token: "branches: [ main ]",
    },
    {
      path: ".github/workflows/moui-skia-real-skia-acceptance.yml",
      token: "branches: [ main ]",
    },
    {
      path: ".github/workflows/moui-skia-linux-real-skia-smoke.yml",
      token: "path: moui_skia/.skia-cache",
    },
    {
      path: ".github/workflows/moui-skia-macos-real-skia-smoke.yml",
      token: "path: moui_skia/.skia-cache",
    },
    {
      path: ".github/workflows/moui-skia-real-skia-acceptance.yml",
      token: "path: moui_skia/.skia-cache",
    },
    {
      path: ".github/workflows/copilot-setup-steps.yml",
      token: "working-directory: moui_skia",
    },
    { path: "AGENTS.md", token: "`moui/README.mbt.md`" },
    { path: "docs/templates.md", token: "`moui/README.mbt.md`" },
    { path: "docs/roadmap-2026.md", token: "`moui/README.mbt.md`" },
    { path: "skills/moui-app-development-skill/SKILL.md", token: "`README.md`" },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "`README.md`",
    },
    { path: "moui/README.mbt.md", token: "render/skia" },
    { path: "moui/README.mbt.md", token: "docs/maintenance.md" },
    { path: "docs/maintenance.md", token: "mainline" },
    { path: "docs/maintenance.md", token: "diagnostic" },
    { path: "docs/maintenance.md", token: "pending" },
    { path: "docs/architecture.md", token: "render/skia" },
    { path: "docs/platform-notes.md", token: "render/skia" },
    { path: "docs/testing.md", token: "render/skia" },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "render/skia",
    },
    { path: "AGENTS.md", token: "backend/macos/wgpu" },
    { path: "AGENTS.md", token: "backend/macos/skia" },
    { path: "docs/architecture.md", token: "moui/backend/macos/wgpu/" },
    { path: "docs/architecture.md", token: "moui/backend/macos/skia/" },
    { path: "AGENTS.md", token: "backend/windows/wgpu" },
    { path: "AGENTS.md", token: "backend/windows/skia" },
    { path: "docs/architecture.md", token: "moui/backend/windows/wgpu/" },
    { path: "docs/architecture.md", token: "moui/backend/windows/skia/" },
    { path: "AGENTS.md", token: "backend/linux/wgpu" },
    { path: "AGENTS.md", token: "backend/linux/skia" },
    { path: "docs/architecture.md", token: "moui/backend/linux/wgpu/" },
    { path: "docs/architecture.md", token: "moui/backend/linux/skia/" },
    { path: "AGENTS.md", token: "`moui/tests/*_conformance`" },
    { path: "docs/testing.md", token: "`moui/tests/*_conformance`" },
    { path: "docs/testing.md", token: "`moui/tests/text_conformance/`" },
    { path: "docs/text-system.md", token: "`moui/tests/text_conformance/`" },
    { path: "docs/architecture.md", token: "moui/tests/text_conformance/" },
    {
      path: "docs/architecture.md",
      token: "moui/tests/skia_renderer_smoke/native/",
    },
    {
      path: "docs/examples.md",
      token: "examples/markdown_editor/windows_wgpu_cosmic",
    },
    {
      path: "docs/examples.md",
      token: "moon test examples/counter/app --target native",
    },
    {
      path: "skills/moui-app-development-skill/SKILL.md",
      token: "moon build examples/counter/web_wasm --target wasm-gc",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "`moui/tests/*_conformance`",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "`moui/tests/text_conformance/{native,web}`",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "`moui/tests/skia_renderer_smoke/native`",
    },
    {
      path: "scripts/conformance-check.sh",
      token: "moon test moui/render/skia --target native",
    },
    {
      path: "scripts/conformance-check.sh",
      token: "validate-conformance-capture-manifest.mjs",
    },
    { path: "scripts/conformance-check.sh", token: "markdown-editor-web-wasm" },
    {
      path: "scripts/conformance-check.sh",
      token: "platform-runtime-evidence.json",
    },
    {
      path: "scripts/conformance-check.sh",
      token: "validate-platform-evidence-manifest.mjs",
    },
    {
      path: "scripts/record-platform-evidence-manifest.mjs",
      token: "validate-platform-evidence-manifest.mjs",
    },
    {
      path: "scripts/record-platform-evidence-manifest.mjs",
      token: "--web-presentation-manifest",
    },
    {
      path: "scripts/record-native-skia-evidence.mjs",
      token: "record-platform-evidence-manifest.mjs",
    },
    {
      path: "tools/moui/record_native_skia_evidence/main.mbt",
      token: "Skia route evidence",
    },
    {
      path: "scripts/record-native-ime-evidence.mjs",
      token: "record-platform-evidence-manifest.mjs",
    },
    {
      path: "tools/moui/record_native_ime_evidence/main.mbt",
      token: "native IME runtime evidence",
    },
    {
      path: "scripts/conformance-check.sh",
      token: "validate-web-runtime-handoff.mjs",
    },
    { path: "scripts/conformance-check.sh", token: "web-runtime-handoff.json" },
    { path: "scripts/validate-web-runtime-handoff.mjs", token: "--manifest" },
    {
      path: "scripts/validate-web-runtime-handoff.mjs",
      token: "validate-web-runtime-handoff-manifest.mjs",
    },
    {
      path: "scripts/dev-check.sh",
      token: "node scripts/validate-guidance-consistency.mjs",
    },
    {
      path: "scripts/dev-check.sh",
      token: "node scripts/validate-web-runtime-handoff.mjs",
    },
    {
      path: "scripts/dev-check.sh",
      token: "node scripts/test-validate-web-runtime-handoff.mjs",
    },
    {
      path: "scripts/dev-check.sh",
      token: "node scripts/test-validate-web-runtime-handoff-manifest.mjs",
    },
    {
      path: "scripts/dev-check.sh",
      token: "node scripts/test-record-web-runtime-presentation.mjs",
    },
    {
      path: "scripts/dev-check.sh",
      token: "node scripts/test-validate-web-runtime-presentation-manifest.mjs",
    },
    {
      path: "scripts/dev-check.sh",
      token: "sh -n scripts/ci-web-runtime-presentation.sh",
    },
    {
      path: "scripts/dev-check.sh",
      token: "node scripts/test-record-native-ime-evidence.mjs",
    },
    {
      path: "scripts/dev-check.sh",
      token: "node scripts/test-record-native-skia-evidence.mjs",
    },
    {
      path: "scripts/dev-check.sh",
      token: "node --check scripts/generate-grapheme-break-fixtures.mjs",
    },
    {
      path: "scripts/dev-check.sh",
      token: "node scripts/generate-grapheme-break-fixtures.mjs --check",
    },
    {
      path: "docs/testing.md",
      token: "generate-grapheme-break-fixtures.mjs --check",
    },
    {
      path: "scripts/dev-check.sh",
      token: "node --check scripts/validate-renderer-proof-manifest.mjs",
    },
    {
      path: "scripts/dev-check.sh",
      token: "node scripts/test-validate-renderer-proof-manifest.mjs",
    },
    {
      path: "scripts/dev-check.sh",
      token: "node --check scripts/record-renderer-proof-manifest.mjs",
    },
    {
      path: "scripts/dev-check.sh",
      token: "node scripts/test-record-renderer-proof-manifest.mjs",
    },
    {
      path: "scripts/dev-check.sh",
      token: "node --check scripts/record-web-renderer-proof-manifest.mjs",
    },
    {
      path: "scripts/dev-check.sh",
      token: "node scripts/test-record-web-renderer-proof-manifest.mjs",
    },
    {
      path: "scripts/dev-check.sh",
      token: "node --check scripts/ci-renderer-proof-native.mjs",
    },
    {
      path: "scripts/dev-check.sh",
      token: "sh -n scripts/ci-renderer-proof-native.sh",
    },
    {
      path: "scripts/dev-check.sh",
      token: "sh -n scripts/ci-renderer-proof-summary.sh",
    },
    { path: "scripts/dev-check.sh", token: "--wgpu-experimental" },
    {
      path: "scripts/dev-check.sh",
      token: "Skipping native WGPU renderer diagnostics",
    },
    { path: "scripts/conformance-check.sh", token: "--wgpu-experimental" },
    {
      path: "scripts/conformance-check.sh",
      token: "Native WGPU entrypoints are retained as experimental diagnostics outside this mainline manifest.",
    },
    { path: "moui/README.mbt.md", token: "native Skia raster" },
    {
      path: "moui/render/renderer.mbt",
      token: "RendererSelection::Backend(RendererBackendKind::SkiaRasterNative)",
    },
    { path: ".github/workflows/ci.yml", token: "web-runtime-presentation:" },
    {
      path: ".github/workflows/ci.yml",
      token: "name: Web runtime presentation",
    },
    { path: ".github/workflows/ci.yml", token: "runs-on: ubuntu-24.04" },
    {
      path: ".github/workflows/ci.yml",
      token: "WEB_RUNTIME_BASE_URL: http://127.0.0.1:18080",
    },
    {
      path: ".github/workflows/ci.yml",
      token: "WEB_RUNTIME_CDP_URL: http://127.0.0.1:9223",
    },
    {
      path: ".github/workflows/ci.yml",
      token: "WEB_RUNTIME_PRESENTATION_MANIFEST: artifacts/conformance/web-runtime-presentation.json",
    },
    {
      path: ".github/workflows/ci.yml",
      token: "WEB_RUNTIME_PRESENTATION_ARTIFACT_NAME: moui-web-runtime-presentation",
    },
    {
      path: ".github/workflows/ci.yml",
      token: "sh scripts/ci-web-runtime-presentation.sh",
    },
    {
      path: ".github/workflows/ci.yml",
      token: "uses: actions/upload-artifact@v4",
    },
    {
      path: ".github/workflows/ci.yml",
      token: "artifacts/conformance/web-runtime-presentation.json",
    },
    {
      path: ".github/workflows/ci.yml",
      token: "artifacts/conformance/web-runtime-presentation/",
    },
    {
      path: ".github/workflows/ci.yml",
      token: "artifacts/platform-evidence/web/",
    },
    {
      path: ".github/workflows/ci.yml",
      token: "artifacts/conformance/platform-runtime-evidence.json",
    },
    { path: ".github/workflows/ci.yml", token: "if-no-files-found: warn" },
    { path: ".github/workflows/ci.yml", token: "renderer-proof-wgpu-native:" },
    {
      path: ".github/workflows/ci.yml",
      token: "name: Native WGPU renderer diagnostic",
    },
    { path: ".github/workflows/ci.yml", token: "continue-on-error: true" },
    { path: ".github/workflows/ci.yml", token: "renderer-proof-skia-native:" },
    { path: ".github/workflows/ci.yml", token: "renderer-proof-summary:" },
    {
      path: ".github/workflows/ci.yml",
      token: "node scripts/ci-renderer-proof-native.mjs wgpu-native",
    },
    {
      path: ".github/workflows/ci.yml",
      token: "node scripts/ci-renderer-proof-native.mjs skia-native",
    },
    {
      path: ".github/workflows/ci.yml",
      token: "--enable-skparagraph --require-skparagraph --write",
    },
    {
      path: ".github/workflows/ci.yml",
      token: "-EnableSkParagraph -RequireSkParagraph -Write",
    },
    {
      path: ".github/workflows/ci.yml",
      token: "artifacts/conformance/renderer-proof/",
    },
    {
      path: ".github/workflows/ci.yml",
      token: "artifacts/platform-evidence/${{ matrix.platform }}/",
    },
    {
      path: "scripts/ci-renderer-proof-native.mjs",
      token: "if (backend === \"skia-native\")",
    },
    {
      path: "scripts/ci-renderer-proof-native.mjs",
      token: "recordArgs.push(\"--require-passed\")",
    },
    {
      path: "scripts/ci-renderer-proof-native.sh",
      token: "if [ \"$backend\" = \"skia-native\" ]; then",
    },
    {
      path: "scripts/ci-renderer-proof-native.sh",
      token: "set -- \"$@\" --require-passed",
    },
    {
      path: "scripts/macos-skia-renderer-smoke.sh",
      token: "--run-text-emoji-smoke",
    },
    {
      path: "scripts/macos-skia-renderer-smoke.sh",
      token: "MoUI renderer proof selectionRects passed engine=skparagraph",
    },
    {
      path: "scripts/macos-skia-renderer-smoke.sh",
      token: "fallback_request_character",
    },
    { path: "scripts/macos-skia-renderer-smoke.sh", token: "emoji-u+" },
    {
      path: "scripts/macos-skia-renderer-smoke.sh",
      token: "grapheme-boundary utf8-offsets",
    },
    {
      path: "scripts/macos-skia-renderer-smoke.sh",
      token: "composition-cursor",
    },
    { path: "docs/testing.md", token: "--run-text-emoji-smoke" },
    { path: "docs/testing.md", token: "fallback_request_character" },
    { path: "docs/testing.md", token: "grapheme-boundary` / `utf8-offsets" },
    { path: "docs/testing.md", token: "WINDOW_MOUI_MACOS_SMOKE_LOG_PATH" },
    {
      path: "docs/release-readiness.md",
      token: "WINDOW_MOUI_MACOS_SMOKE_LOG_PATH",
    },
    { path: "AGENTS.md", token: "WINDOW_MOUI_MACOS_SMOKE_LOG_PATH" },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "WINDOW_MOUI_MACOS_SMOKE_LOG_PATH",
    },
    {
      path: ".github/workflows/ci.yml",
      token: "WINDOW_MOUI_MACOS_SMOKE_LOG_PATH",
    },
    {
      path: "scripts/run-window-package-smoke.sh",
      token: "WINDOW_MOUI_MACOS_SMOKE_LOG_PATH",
    },
    {
      path: "scripts/dev-check.sh",
      token: "sh -n scripts/record-macos-local-runtime-evidence.sh",
    },
    {
      path: "scripts/record-macos-local-runtime-evidence.sh",
      token: "record-native-ime-evidence.mjs",
    },
    {
      path: "scripts/record-macos-local-runtime-evidence.sh",
      token: "record-macos-platform-runtime-evidence.mjs",
    },
    {
      path: "scripts/record-macos-local-runtime-evidence.sh",
      token: "matching-host-artifact",
    },
    {
      path: "docs/testing.md",
      token: "scripts/record-macos-local-runtime-evidence.sh",
    },
    {
      path: "docs/release-readiness.md",
      token: "scripts/record-macos-local-runtime-evidence.sh",
    },
    {
      path: "AGENTS.md",
      token: "scripts/record-macos-local-runtime-evidence.sh",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "scripts/record-macos-local-runtime-evidence.sh",
    },
    {
      path: ".github/workflows/ci.yml",
      token: "sh scripts/ci-renderer-proof-summary.sh artifacts/downloaded-renderer-proof",
    },
    { path: "scripts/ci-renderer-proof-summary.sh", token: "--artifact-root" },
    {
      path: "scripts/ci-renderer-proof-summary.sh",
      token: "skia-native-macos.json",
    },
    {
      path: "scripts/ci-renderer-proof-summary.sh",
      token: "skia-native-windows.json",
    },
    {
      path: "scripts/ci-renderer-proof-summary.sh",
      token: "skia-native-linux.json",
    },
    {
      path: "scripts/ci-renderer-proof-summary.sh",
      token: "webgpu-wasm-web.json",
    },
    {
      path: ".github/workflows/moui-real-skia-smoke.yml",
      token: "name: MoUI Real Skia Smoke",
    },
    {
      path: ".github/workflows/moui-real-skia-smoke.yml",
      token: "workflow_dispatch:",
    },
    {
      path: ".github/workflows/moui-real-skia-smoke.yml",
      token: "macos-real-skia-smoke:",
    },
    {
      path: ".github/workflows/moui-real-skia-smoke.yml",
      token: "scripts/macos-skia-renderer-smoke.sh",
    },
    {
      path: ".github/workflows/moui-real-skia-smoke.yml",
      token: "--smoke-log artifacts/platform-evidence/macos/skia-renderer-smoke.log",
    },
    {
      path: ".github/workflows/moui-real-skia-smoke.yml",
      token: "--run-showcase-smoke",
    },
    {
      path: ".github/workflows/moui-real-skia-smoke.yml",
      token: "--run-markdown-smoke",
    },
    {
      path: ".github/workflows/moui-real-skia-smoke.yml",
      token: "moui-macos-real-skia-smoke",
    },
    {
      path: "docs/testing.md",
      token: ".github/workflows/moui-real-skia-smoke.yml",
    },
    { path: "docs/testing.md", token: "not create a skipped real-Skia check" },
    { path: "AGENTS.md", token: ".github/workflows/moui-real-skia-smoke.yml" },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: ".github/workflows/moui-real-skia-smoke.yml",
    },
    {
      path: "scripts/ci-web-runtime-presentation.sh",
      token: "moon build examples/showcase/web_wasm --target wasm-gc",
    },
    {
      path: "scripts/ci-web-runtime-presentation.sh",
      token: "python3 -m http.server",
    },
    {
      path: "scripts/ci-web-runtime-presentation.sh",
      token: "--remote-debugging-port=\"$WEB_RUNTIME_CDP_PORT\"",
    },
    {
      path: "scripts/ci-web-runtime-presentation.sh",
      token: "--enable-unsafe-webgpu",
    },
    {
      path: "scripts/ci-web-runtime-presentation.sh",
      token: "--use-angle=swiftshader",
    },
    {
      path: "scripts/ci-web-runtime-presentation.sh",
      token: "node scripts/record-web-runtime-presentation.mjs",
    },
    {
      path: "scripts/ci-web-runtime-presentation.sh",
      token: "--require-passed",
    },
    {
      path: "scripts/ci-web-runtime-presentation.sh",
      token: "node scripts/validate-web-runtime-presentation-manifest.mjs",
    },
    {
      path: "scripts/ci-web-runtime-presentation.sh",
      token: "node scripts/record-web-renderer-proof-manifest.mjs",
    },
    {
      path: "scripts/ci-web-runtime-presentation.sh",
      token: "artifacts/conformance/renderer-proof/webgpu-wasm-web.json",
    },
    {
      path: "scripts/ci-web-runtime-presentation.sh",
      token: "sh scripts/conformance-check.sh --platform-services",
    },
    {
      path: "scripts/ci-web-runtime-presentation.sh",
      token: "node scripts/record-platform-evidence-manifest.mjs",
    },
    {
      path: "scripts/ci-web-runtime-presentation.sh",
      token: "--web-presentation-manifest",
    },
    {
      path: "scripts/ci-web-runtime-presentation.sh",
      token: "node scripts/validate-platform-evidence-manifest.mjs",
    },
    { path: "scripts/ci-web-runtime-presentation.sh", token: "--platform web" },
    {
      path: "docs/testing.md",
      token: "node scripts/validate-guidance-consistency.mjs",
    },
    {
      path: "docs/testing.md",
      token: "validate-conformance-capture-manifest.mjs",
    },
    { path: "docs/testing.md", token: "markdown-editor-web-wasm" },
    {
      path: "docs/testing.md",
      token: "validate-platform-evidence-manifest.mjs",
    },
    { path: "docs/testing.md", token: "record-platform-evidence-manifest.mjs" },
    { path: "docs/testing.md", token: "exact whitespace-delimited tokens" },
    { path: "docs/testing.md", token: "record-native-skia-evidence.mjs" },
    { path: "docs/testing.md", token: "validate-web-runtime-handoff.mjs" },
    { path: "docs/testing.md", token: "test-validate-web-runtime-handoff.mjs" },
    {
      path: "docs/testing.md",
      token: "validate-web-runtime-handoff-manifest.mjs",
    },
    {
      path: "docs/testing.md",
      token: "test-validate-web-runtime-handoff-manifest.mjs",
    },
    { path: "docs/testing.md", token: "record-web-runtime-presentation.mjs" },
    {
      path: "docs/testing.md",
      token: "test-record-web-runtime-presentation.mjs",
    },
    { path: "docs/testing.md", token: "CDP browser is unavailable" },
    {
      path: "docs/testing.md",
      token: "validate-web-runtime-presentation-manifest.mjs",
    },
    {
      path: "docs/testing.md",
      token: "test-validate-web-runtime-presentation-manifest.mjs",
    },
    { path: "docs/testing.md", token: "validate-renderer-proof-manifest.mjs" },
    {
      path: "docs/testing.md",
      token: "test-validate-renderer-proof-manifest.mjs",
    },
    { path: "docs/testing.md", token: "record-renderer-proof-manifest.mjs" },
    {
      path: "docs/testing.md",
      token: "test-record-renderer-proof-manifest.mjs",
    },
    { path: "docs/testing.md", token: "record-web-renderer-proof-manifest.mjs" },
    {
      path: "docs/testing.md",
      token: "test-record-web-renderer-proof-manifest.mjs",
    },
    { path: "docs/testing.md", token: "ci-renderer-proof-native.sh" },
    { path: "docs/testing.md", token: "ci-renderer-proof-summary.sh" },
    { path: "docs/testing.md", token: "renderer-proof-summary" },
    { path: "docs/testing.md", token: "skia-text-emoji-smoke.log" },
    { path: "docs/testing.md", token: "resize/input event-bridge" },
    { path: "docs/testing.md", token: "Markdown Editor text input" },
    { path: "docs/testing.md", token: "clean target close" },
    { path: "docs/testing.md", token: "--web-presentation-manifest" },
    { path: "docs/testing.md", token: "web-runtime-presentation.json" },
    { path: "docs/testing.md", token: "web-runtime-handoff.json" },
    { path: "docs/testing.md", token: "platform-runtime-evidence.json" },
    { path: "docs/testing.md", token: "monitorCursor" },
    { path: "docs/testing.md", token: "monitor/cursor" },
    { path: "docs/testing.md", token: "evidenceProvenance" },
    {
      path: "docs/testing.md",
      token: "non-skipped successful GitHub Actions job",
    },
    { path: "docs/testing.md", token: "Web runtime presentation" },
    {
      path: "docs/testing.md",
      token: "`moui-web-runtime-presentation` artifact",
    },
    {
      path: "tools/moui/validate_platform_evidence_manifest/main.mbt",
      token: "schemaVersion must be 2",
    },
    {
      path: "tools/moui/validate_platform_evidence_manifest/main.mbt",
      token: "evidenceProvenance",
    },
    {
      path: "tools/moui/validate_platform_evidence_manifest/main.mbt",
      token: "README.md placeholder documentation",
    },
    {
      path: "scripts/test-validate-platform-evidence-manifest.mjs",
      token: "passed platform rejects README placeholder artifact",
    },
    {
      path: "scripts/test-validate-platform-evidence-manifest.mjs",
      token: "linux evidence requires linux_skia runtime command",
    },
    {
      path: "scripts/test-record-native-skia-evidence.mjs",
      token: "moon build examples/showcase/linux_skia --target native",
    },
    {
      path: "scripts/test-record-native-skia-evidence.mjs",
      token: "moon run examples/showcase/linux_skia --target native",
    },
    {
      path: "scripts/conformance-check.sh",
      token: "moon build examples/showcase/linux_skia --target native",
    },
    {
      path: "scripts/conformance-check.sh",
      token: "moon run examples/showcase/linux_skia --target native",
    },
    {
      path: "tools/moui/validate_platform_evidence_manifest/main.mbt",
      token: "moon build examples/showcase/linux_skia --target native",
    },
    {
      path: "tools/moui/validate_platform_evidence_manifest/main.mbt",
      token: "moon run examples/showcase/linux_skia --target native",
    },
    {
      path: "scripts/test-record-platform-evidence-manifest.mjs",
      token: "moon build examples/showcase/linux_skia --target native",
    },
    {
      path: "scripts/test-record-platform-evidence-manifest.mjs",
      token: "moon run examples/showcase/linux_skia --target native",
    },
    {
      path: "docs/release-readiness.md",
      token: "Platform evidence guard refresh",
    },
    {
      path: "docs/testing.md",
      token: "README.md` files under `artifacts/platform-evidence/`",
    },
    {
      path: "AGENTS.md",
      token: "must not be used as passed platform, Skia, or provenance",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "must not be used as passed platform, Skia, or",
    },
    {
      path: "tools/moui/record_platform_evidence_manifest/main.mbt",
      token: "monitorCursor",
    },
    {
      path: "scripts/record-platform-evidence-manifest.mjs",
      token: "provenance-kind",
    },
    {
      path: "tools/moui/record_platform_evidence_manifest/main.mbt",
      token: "browser_observable_passed",
    },
    { path: "scripts/conformance-check.sh", token: "\"schemaVersion\": 2" },
    {
      path: "scripts/conformance-check.sh",
      token: "\"monitorCursor\": \"pending\"",
    },
    {
      path: "docs/testing.md",
      token: "node scripts/test-validate-conformance-capture-manifest.mjs",
    },
    {
      path: "docs/testing.md",
      token: "node scripts/test-validate-platform-evidence-manifest.mjs",
    },
    {
      path: "docs/testing.md",
      token: "node scripts/test-record-platform-evidence-manifest.mjs",
    },
    {
      path: "docs/testing.md",
      token: "node scripts/test-record-native-ime-evidence.mjs",
    },
    {
      path: "docs/testing.md",
      token: "node scripts/test-record-native-skia-evidence.mjs",
    },
    {
      path: "scripts/dev-check.sh",
      token: "node scripts/test-validate-conformance-capture-manifest.mjs",
    },
    {
      path: "scripts/dev-check.sh",
      token: "node scripts/test-validate-platform-evidence-manifest.mjs",
    },
    {
      path: "scripts/dev-check.sh",
      token: "node scripts/test-record-platform-evidence-manifest.mjs",
    },
    {
      path: "scripts/check-local-deps.sh",
      token: "wzzc-dev/window@$WINDOW_VERSION",
    },
    {
      path: "scripts/check-local-deps.sh",
      token: "moon.work must not include .local_repos/window",
    },
    { path: "scripts/check-local-deps.sh", token: "xdg-shell-protocol.c" },
    {
      path: "scripts/run-window-package-smoke.sh",
      token: "scripts/check_moui_macos_smoke.sh",
    },
    { path: "scripts/check-local-deps.sh", token: "skia-platform-status.json" },
    { path: "scripts/check-local-deps.sh", token: "skia-provider-lock.json" },
    { path: "scripts/check-local-deps.sh", token: "verify-platform-status.sh" },
    { path: "scripts/check-local-deps.sh", token: "native/capabilities.json" },
    { path: "scripts/check-local-deps.sh", token: "native/ownership.json" },
    {
      path: "scripts/check-local-deps.sh",
      token: "verify-native-capability-contract.sh",
    },
    {
      path: "docs/development.md",
      token: "wzzc-dev/window@0.5.1-0.1.4",
    },
    {
      path: "docs/development.md",
      token: "scripts/run-window-package-smoke.sh <platform>",
    },
    { path: "docs/development.md", token: "skia-platform-status.json" },
    { path: "docs/development.md", token: "verify-platform-status.sh" },
    { path: "docs/development.md", token: "native/capabilities.json" },
    {
      path: "docs/development.md",
      token: "verify-native-capability-contract.sh",
    },
    { path: "docs/development.md", token: ".github/workflows/moui-skia-*.yml" },
    {
      path: "docs/testing.md",
      token: ".github/workflows/moui-skia-fallback.yml",
    },
    {
      path: "docs/testing.md",
      token: ".github/workflows/moui-skia-real-skia-acceptance.yml",
    },
    {
      path: "docs/testing.md",
      token: ".github/workflows/copilot-setup-steps.yml",
    },
    { path: "AGENTS.md", token: ".github/workflows/moui-skia-*.yml" },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: ".github/workflows/moui-skia-*.yml",
    },
    { path: "scripts/conformance-check.sh", token: "xdg-shell-protocol.c" },
    {
      path: "examples/counter/web_wasm/index.html",
      token: "../../../moui/backend/web/runtime.js",
    },
    {
      path: "examples/showcase/web_wasm/index.html",
      token: "../../../moui/backend/web/runtime.js",
    },
    {
      path: "examples/markdown_editor/web_wasm/index.html",
      token: "../../../moui/backend/web/runtime.js",
    },
    { path: "docs/testing.md", token: "scripts/record_moui_evidence.sh" },
    { path: "docs/testing.md", token: "generated Wayland" },
    {
      path: "docs/testing.md",
      token: "the macOS helper still executes the AppKit smoke through `moon run`",
    },
    { path: "docs/testing.md", token: "module-qualified" },
    { path: "docs/testing.md", token: "public consumer sentinel lines" },
    { path: "docs/testing.md", token: "skia-platform-status.json" },
    { path: "docs/testing.md", token: "verify-platform-status.sh" },
    { path: "docs/testing.md", token: "native/capabilities.json" },
    { path: "docs/testing.md", token: "verify-native-capability-contract.sh" },
    {
      path: "docs/platform-notes.md",
      token: "scripts/run-window-package-smoke.sh linux --run",
    },
    { path: "docs/platform-notes.md", token: "Wayland key/modifier mapping" },
    { path: "docs/platform-notes.md", token: "current pointer coordinates" },
    {
      path: "docs/release-readiness.md",
      token: "platform-runtime-evidence.json",
    },
    { path: "docs/release-readiness.md", token: "skia-platform-status.json" },
    { path: "docs/release-readiness.md", token: "verify-platform-status.sh" },
    { path: "docs/release-readiness.md", token: "native/capabilities.json" },
    {
      path: "docs/release-readiness.md",
      token: "verify-native-capability-contract.sh",
    },
    { path: "docs/release-readiness.md", token: "Wayland key/modifier mapping" },
    {
      path: "docs/release-readiness.md",
      token: "current button-event coordinates",
    },
    {
      path: "docs/release-readiness.md",
      token: "record-platform-evidence-manifest.mjs",
    },
    {
      path: "docs/release-readiness.md",
      token: "record-native-ime-evidence.mjs",
    },
    {
      path: "docs/release-readiness.md",
      token: "record-native-skia-evidence.mjs",
    },
    {
      path: "docs/release-readiness.md",
      token: "validate-web-runtime-handoff.mjs",
    },
    {
      path: "docs/release-readiness.md",
      token: "validate-web-runtime-handoff-manifest.mjs",
    },
    { path: "docs/release-readiness.md", token: "web-runtime-handoff.json" },
    {
      path: "docs/release-readiness.md",
      token: "record-web-runtime-presentation.mjs",
    },
    {
      path: "docs/release-readiness.md",
      token: "validate-web-runtime-presentation-manifest.mjs",
    },
    {
      path: "docs/release-readiness.md",
      token: "web-runtime-presentation.json",
    },
    { path: "docs/release-readiness.md", token: "Renderer proof manifest" },
    {
      path: "docs/release-readiness.md",
      token: "validate-renderer-proof-manifest.mjs",
    },
    { path: "docs/release-readiness.md", token: "artifact root" },
    { path: "docs/release-readiness.md", token: "radialGradient" },
    { path: "docs/release-readiness.md", token: "colorEmojiPixels" },
    { path: "docs/release-readiness.md", token: "stable-glyph-key" },
    { path: "docs/release-readiness.md", token: "fallback request character" },
    { path: "docs/testing.md", token: "fallback request character" },
    { path: "docs/text-system.md", token: "fallback request character" },
    {
      path: "docs/renderer-capability-report.md",
      token: "fallback request character",
    },
    {
      path: "docs/text-system.md",
      token: "emoji-u+<fallback request character>",
    },
    {
      path: "tools/moui/validate_renderer_proof_manifest/main.mbt",
      token: "stable-glyph-key",
    },
    {
      path: "tools/moui/validate_renderer_proof_manifest/main.mbt",
      token: "fallbackRequestCharacter",
    },
    {
      path: "tools/moui/validate_renderer_proof_manifest/main.mbt",
      token: "emoji-u+",
    },
    {
      path: "tools/moui/record_renderer_proof_manifest/main.mbt",
      token: "fallback-request",
    },
    {
      path: "tools/moui/record_renderer_proof_manifest/main.mbt",
      token: "fallback_request_character",
    },
    {
      path: "scripts/ci-renderer-proof-native.mjs",
      token: "fallback request character metadata",
    },
    {
      path: "scripts/ci-renderer-proof-native.sh",
      token: "fallback request character metadata",
    },
    { path: "docs/release-readiness.md", token: "selectionRects" },
    {
      path: "docs/release-readiness.md",
      token: "selection-rects line-range rect-geometry hit-test",
    },
    {
      path: "tools/moui/validate_renderer_proof_manifest/main.mbt",
      token: "hit-test",
    },
    {
      path: "tools/moui/validate_renderer_proof_manifest/main.mbt",
      token: "rect-geometry",
    },
    {
      path: "tools/moui/record_renderer_proof_manifest/main.mbt",
      token: "hit-test",
    },
    {
      path: "tools/moui/record_renderer_proof_manifest/main.mbt",
      token: "rect-geometry",
    },
    {
      path: "docs/release-readiness.md",
      token: "grapheme-boundary` and `utf8-offsets`",
    },
    {
      path: "docs/testing.md",
      token: "UTF-8 offset evidence from host IME diagnostics",
    },
    { path: "docs/testing.md", token: "nearest_boundary_utf8_offset" },
    { path: "docs/text-system.md", token: "nearest_boundary_utf8_offset" },
    { path: "docs/release-readiness.md", token: "nearest_boundary_utf8_offset" },
    {
      path: "docs/release-readiness.md",
      token: "every-index `nearest_boundary_utf8_offset`",
    },
    { path: "docs/release-readiness.md", token: "Skia-produced boundaries" },
    { path: "docs/text-system.md", token: "Skia-produced cluster boundaries" },
    {
      path: "moui/core/pkg.generated.mbti",
      token: "nearest_boundary_utf8_offset",
    },
    {
      path: "docs/text-system.md",
      token: "Native Skia `imeCandidateAnchor` also requires `utf8-offsets`",
    },
    {
      path: "tools/moui/validate_renderer_proof_manifest/main.mbt",
      token: "utf8-offsets",
    },
    {
      path: "tools/moui/record_renderer_proof_manifest/main.mbt",
      token: "utf8-offsets",
    },
    {
      path: "scripts/ci-renderer-proof-native.mjs",
      token: "grapheme-boundary, and utf8-offsets evidence",
    },
    {
      path: "scripts/ci-renderer-proof-native.sh",
      token: "grapheme-boundary, and utf8-offsets evidence",
    },
    { path: "AGENTS.md", token: "host IME request diagnostics including UTF-8" },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "host IME request diagnostics including UTF-8",
    },
    { path: "docs/release-readiness.md", token: "imeCompositionVisual" },
    {
      path: "docs/release-readiness.md",
      token: "`composition-cursor` evidence",
    },
    { path: "docs/testing.md", token: "`composition-cursor`" },
    { path: "docs/text-system.md", token: "`composition-cursor` evidence" },
    { path: "AGENTS.md", token: "composition cursor evidence" },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "composition cursor evidence",
    },
    {
      path: "tools/moui/validate_renderer_proof_manifest/main.mbt",
      token: "composition-cursor",
    },
    {
      path: "tools/moui/record_renderer_proof_manifest/main.mbt",
      token: "composition-cursor",
    },
    {
      path: "scripts/ci-renderer-proof-native.mjs",
      token: "composition cursor",
    },
    { path: "scripts/ci-renderer-proof-native.sh", token: "composition cursor" },
    {
      path: "moui/tests/skia_text_emoji_smoke/native/main.mbt",
      token: "composition cursor",
    },
    { path: "docs/release-readiness.md", token: "asyncImageSecondFrame" },
    { path: "docs/release-readiness.md", token: "resize/input event-bridge" },
    { path: "docs/release-readiness.md", token: "Showcase runtime artifacts" },
    { path: "docs/release-readiness.md", token: "--web-presentation-manifest" },
    { path: "docs/release-readiness.md", token: "monitor/cursor" },
    { path: "docs/release-readiness.md", token: "evidenceProvenance" },
    {
      path: "docs/release-readiness.md",
      token: "non-skipped successful GitHub Actions job",
    },
    {
      path: "docs/release-readiness.md",
      token: "Web host capability reporting now advertises browser IME plumbing",
    },
    {
      path: "docs/release-readiness.md",
      token: "HostEventSource::subscription",
    },
    { path: "docs/release-readiness.md", token: "HostEventSource::publish" },
    {
      path: "docs/release-readiness.md",
      token: "host-event subscription fanout",
    },
    {
      path: "docs/release-readiness.md",
      token: "HostWindowEventSource::subscription",
    },
    {
      path: "docs/release-readiness.md",
      token: "HostWindowEventSource::publish",
    },
    {
      path: "docs/release-readiness.md",
      token: "window-scoped subscription fanout",
    },
    { path: "docs/release-readiness.md", token: "HostPlatformEventSources" },
    {
      path: "docs/release-readiness.md",
      token: "normalized runtime host/window events",
    },
    {
      path: "docs/release-readiness.md",
      token: "HostRouteSource::subscription",
    },
    { path: "docs/release-readiness.md", token: "HostRouteSource::publish" },
    {
      path: "docs/release-readiness.md",
      token: "route/deep-link subscription fanout",
    },
    {
      path: "docs/release-readiness.md",
      token: "HostTimerSource::subscription",
    },
    { path: "docs/release-readiness.md", token: "HostTimerSource::new" },
    {
      path: "docs/release-readiness.md",
      token: "scheduler-backed timer subscriptions",
    },
    { path: "docs/architecture.md", token: "`HostEventSource`" },
    { path: "docs/architecture.md", token: "`Subscription::host_event`" },
    { path: "docs/architecture.md", token: "`HostWindowEventSource`" },
    { path: "docs/architecture.md", token: "`HostWindowEvent`" },
    { path: "docs/architecture.md", token: "`Subscription::window_event`" },
    { path: "docs/architecture.md", token: "`HostPlatformEventSources`" },
    {
      path: "docs/architecture.md",
      token: "Web, macOS, Windows, and Linux app options",
    },
    { path: "docs/architecture.md", token: "`HostRouteSource`" },
    { path: "docs/architecture.md", token: "`HostRouteEvent`" },
    { path: "docs/architecture.md", token: "`Subscription::route_event`" },
    { path: "docs/architecture.md", token: "`HostTimerSource`" },
    { path: "docs/architecture.md", token: "`Subscription::timer`" },
    {
      path: "docs/testing.md",
      token: "Host event, window, timer, and route subscriptions",
    },
    { path: "docs/testing.md", token: "window identity preservation" },
    {
      path: "docs/testing.md",
      token: "window/timer/route subscription adapter start/cleanup",
    },
    { path: "docs/testing.md", token: "scheduler interval capture" },
    { path: "docs/testing.md", token: "HostPlatformEventSources" },
    {
      path: "docs/testing.md",
      token: "event-source wiring through `HostPlatformEventSources`",
    },
    {
      path: "moui/backend/host/subscription_adapters.mbt",
      token: "pub struct HostEventSource",
    },
    {
      path: "moui/backend/host/subscription_adapters.mbt",
      token: "pub struct HostPlatformEventSources",
    },
    {
      path: "moui/backend/host/subscription_adapters.mbt",
      token: "pub(all) struct HostPlatformEventPublishResult",
    },
    {
      path: "moui/backend/host/subscription_adapters.mbt",
      token: "HostPlatformEventSources::publish",
    },
    {
      path: "moui/backend/host/subscription_adapters.mbt",
      token: "Subscription::host_event",
    },
    {
      path: "moui/backend/web/host_runtime.mbt",
      token: "event_sources : @host.HostPlatformEventSources?",
    },
    {
      path: "moui/backend/web/host_runtime.mbt",
      token: "publish_subscription_event",
    },
    {
      path: "moui/backend/macos/macos_backend.mbt",
      token: "event_sources : @host.HostPlatformEventSources?",
    },
    {
      path: "moui/backend/macos/macos_window_requests.mbt",
      token: "publish_subscription_event",
    },
    {
      path: "moui/backend/windows/windows_backend.mbt",
      token: "event_sources : @host.HostPlatformEventSources?",
    },
    {
      path: "moui/backend/windows/windows_backend.mbt",
      token: "publish_subscription_event",
    },
    {
      path: "moui/backend/linux/linux_backend.mbt",
      token: "event_sources : @host.HostPlatformEventSources?",
    },
    {
      path: "moui/backend/linux/linux_window_requests.mbt",
      token: "publish_subscription_event",
    },
    {
      path: "moui/backend/host/subscription_adapters.mbt",
      token: "pub(all) struct HostWindowEvent",
    },
    {
      path: "moui/backend/host/subscription_adapters.mbt",
      token: "pub struct HostWindowEventSource",
    },
    {
      path: "moui/backend/host/subscription_adapters.mbt",
      token: "HostWindowEventSource::publish",
    },
    {
      path: "moui/backend/host/subscription_adapters.mbt",
      token: "HostWindowEventSource::subscription",
    },
    {
      path: "moui/backend/host/subscription_adapters.mbt",
      token: "Subscription::window_event",
    },
    {
      path: "moui/backend/host/subscription_adapters.mbt",
      token: "pub(all) struct HostRouteEvent",
    },
    {
      path: "moui/backend/host/subscription_adapters.mbt",
      token: "pub struct HostRouteSource",
    },
    {
      path: "moui/backend/host/subscription_adapters.mbt",
      token: "HostRouteEvent::from_route",
    },
    {
      path: "moui/backend/host/subscription_adapters.mbt",
      token: "HostRouteSource::publish",
    },
    {
      path: "moui/backend/host/subscription_adapters.mbt",
      token: "HostRouteSource::subscription",
    },
    {
      path: "moui/backend/host/subscription_adapters.mbt",
      token: "Subscription::route_event",
    },
    {
      path: "moui/backend/host/subscription_adapters.mbt",
      token: "pub struct HostTimerSource",
    },
    {
      path: "moui/backend/host/subscription_adapters.mbt",
      token: "HostTimerSource::subscription",
    },
    {
      path: "moui/backend/host/subscription_adapters.mbt",
      token: "Subscription::timer",
    },
    {
      path: "moui/backend/host/host_test.mbt",
      token: "host event source subscription dispatches mapped host events",
    },
    {
      path: "moui/backend/host/host_test.mbt",
      token: "host event source subscription cleanup removes late publishers",
    },
    {
      path: "moui/backend/host/host_test.mbt",
      token: "host platform event sources publish host and window subscriptions",
    },
    {
      path: "moui/backend/host/host_test.mbt",
      token: "host window event source subscription dispatches mapped window events",
    },
    {
      path: "moui/backend/host/host_test.mbt",
      token: "host window event source subscription cleanup removes late publishers",
    },
    {
      path: "moui/backend/host/host_test.mbt",
      token: "host route source subscription dispatches mapped route events",
    },
    {
      path: "moui/backend/host/host_test.mbt",
      token: "host route event constructor preserves location and source",
    },
    {
      path: "moui/backend/host/host_test.mbt",
      token: "host route source subscription cleanup removes late publishers",
    },
    {
      path: "moui/backend/host/host_test.mbt",
      token: "host timer source subscription starts timer and dispatches mapped frames",
    },
    {
      path: "moui/backend/host/host_test.mbt",
      token: "host timer source subscription cleanup cancels timer",
    },
    {
      path: "docs/release-readiness.md",
      token: "HostImageResourceCompletionSource",
    },
    {
      path: "docs/release-readiness.md",
      token: "native async image completion",
    },
    {
      path: "docs/release-readiness.md",
      token: "provider/platform async loader",
    },
    { path: "docs/release-readiness.md", token: "ImageResourceLoadCompletion" },
    {
      path: "docs/release-readiness.md",
      token: "HostWindowRenderer::apply_image_resource_load_completion",
    },
    { path: "docs/release-readiness.md", token: "HostAsyncImageLoader" },
    {
      path: "docs/release-readiness.md",
      token: "optional provider-owned async image loader hooks",
    },
    { path: "docs/release-readiness.md", token: "native_image_load_completion" },
    {
      path: "docs/release-readiness.md",
      token: "WGPU provider-owned source completion wiring",
    },
    {
      path: "docs/release-readiness.md",
      token: "deferred native-source callbacks can carry",
    },
    {
      path: "docs/release-readiness.md",
      token: "skia_image_load_completion` payloads",
    },
    {
      path: "docs/architecture.md",
      token: "`HostImageResourceCompletionSource`",
    },
    {
      path: "docs/architecture.md",
      token: "`HostWindowRenderer::apply_image_resource_load_completion`",
    },
    { path: "docs/architecture.md", token: "`HostAsyncImageLoader`" },
    {
      path: "docs/architecture.md",
      token: "optional provider-owned loader hook",
    },
    {
      path: "docs/architecture.md",
      token: "Native WGPU provider packages now supply",
    },
    { path: "docs/testing.md", token: "Native async image completion" },
    { path: "docs/testing.md", token: "schedule/publish/apply/redraw/cleanup" },
    {
      path: "docs/testing.md",
      token: "native provider async-image hook wiring",
    },
    {
      path: "docs/testing.md",
      token: "moon test moui/backend/macos/wgpu --target native",
    },
    { path: "docs/testing.md", token: "provider package tests also pin" },
    { path: "docs/testing.md", token: "`HostNativeAsyncImageSource` callback" },
    { path: "docs/testing.md", token: "native-source callback boundary" },
    {
      path: "docs/platform-notes.md",
      token: "optional provider-owned `HostAsyncImageLoader`",
    },
    { path: "AGENTS.md", token: "native async image completion source" },
    { path: "AGENTS.md", token: "image-resource load completion apply bridge" },
    { path: "AGENTS.md", token: "native async image loading-record scheduler" },
    { path: "AGENTS.md", token: "native provider async-image scheduling hooks" },
    { path: "AGENTS.md", token: "native_image_load_completion" },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "native async image completion source",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "`HostWindowRenderer::apply_image_resource_load_completion`",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "`HostAsyncImageLoader`",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "provider-owned image loaders",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "native_image_load_completion",
    },
    {
      path: "moui/render/image_lifecycle.mbt",
      token: "pub(all) struct ImageResourceLoadCompletion",
    },
    {
      path: "moui/render/image_lifecycle.mbt",
      token: "ImageResourceLifecycle::apply_load_completion",
    },
    {
      path: "moui/render/wgpu/native_image.mbt",
      token: "pub fn native_image_load_completion",
    },
    {
      path: "moui/backend/host/renderer.mbt",
      token: "HostWindowRenderer::apply_image_resource_load_completion",
    },
    {
      path: "moui/backend/host/image_repaint.mbt",
      token: "pub struct HostImageResourceCompletionSource",
    },
    {
      path: "moui/backend/host/image_repaint.mbt",
      token: "pub struct HostAsyncImageLoader",
    },
    {
      path: "moui/backend/host/image_repaint.mbt",
      token: "pub struct HostNativeAsyncImageSource",
    },
    {
      path: "moui/backend/host/image_repaint.mbt",
      token: "HostImageResourceCompletionSource::publish",
    },
    {
      path: "moui/backend/host/image_repaint.mbt",
      token: "HostImageResourceCompletionSource::complete",
    },
    {
      path: "moui/backend/host/image_repaint.mbt",
      token: "HostAsyncImageLoader::schedule_loading_resources",
    },
    {
      path: "moui/backend/host/image_repaint.mbt",
      token: "HostNativeAsyncImageSource::loader",
    },
    {
      path: "moui/backend/host/image_repaint.mbt",
      token: "HostNativeAsyncImageSource::complete",
    },
    {
      path: "moui/backend/host/pkg.generated.mbti",
      token: "pub fn HostNativeAsyncImageSource::complete",
    },
    {
      path: "moui/backend/macos/macos_backend.mbt",
      token: "image_loader? : @host.HostAsyncImageLoader? = None",
    },
    {
      path: "moui/backend/macos/macos_window_requests.mbt",
      token: "MacosRendererProvider::schedule_image_resource_loads",
    },
    {
      path: "moui/backend/macos/macos_window_requests.mbt",
      token: "cancel_image_resource_loads",
    },
    {
      path: "moui/backend/windows/windows_backend.mbt",
      token: "image_loader? : @host.HostAsyncImageLoader? = None",
    },
    {
      path: "moui/backend/windows/windows_backend.mbt",
      token: "WindowsRendererProvider::schedule_image_resource_loads",
    },
    {
      path: "moui/backend/windows/windows_backend.mbt",
      token: "cancel_image_resource_loads",
    },
    {
      path: "moui/backend/linux/linux_backend.mbt",
      token: "image_loader? : @host.HostAsyncImageLoader? = None",
    },
    {
      path: "moui/backend/linux/linux_backend.mbt",
      token: "LinuxRendererProvider::schedule_image_resource_loads",
    },
    {
      path: "moui/backend/linux/linux_backend.mbt",
      token: "cancel_image_resource_loads",
    },
    {
      path: "moui/backend/macos/wgpu/macos_wgpu_provider.mbt",
      token: "wgpu_native_image_loader",
    },
    {
      path: "moui/backend/macos/wgpu/macos_wgpu_provider.mbt",
      token: "image_loader=Some(wgpu_native_image_loader())",
    },
    {
      path: "moui/backend/windows/wgpu/windows_wgpu_provider.mbt",
      token: "wgpu_native_image_loader",
    },
    {
      path: "moui/backend/windows/wgpu/windows_wgpu_provider.mbt",
      token: "image_loader=Some(wgpu_native_image_loader())",
    },
    {
      path: "moui/backend/linux/wgpu/linux_wgpu_provider.mbt",
      token: "wgpu_native_image_loader",
    },
    {
      path: "moui/backend/linux/wgpu/linux_wgpu_provider.mbt",
      token: "image_loader=Some(wgpu_native_image_loader())",
    },
    {
      path: "moui/render/skia/renderer_image.mbt",
      token: "pub fn skia_image_load_completion",
    },
    {
      path: "moui/render/skia/pkg.generated.mbti",
      token: "pub fn skia_image_load_completion(String) -> @render.ImageResourceLoadCompletion",
    },
    {
      path: "moui/render/skia/pkg.generated.mbti",
      token: "async_image_loading? : Bool",
    },
    {
      path: "moui/render/skia/skia_renderer_wbtest.mbt",
      token: "skia image load completion reports decoded dimensions or fallback failure",
    },
    {
      path: "moui/render/skia/skia_renderer_wbtest.mbt",
      token: "skia renderer async image loading waits for explicit completion before caching",
    },
    {
      path: "moui/render/skia/renderer.mbt",
      token: "async_image_loading? : Bool = false",
    },
    {
      path: "moui/tests/skia_renderer_smoke/native/main.mbt",
      token: "MoUI Skia async image second-frame smoke passed",
    },
    {
      path: "tools/moui/record_platform_evidence_manifest/main.mbt",
      token: "asyncImageSecondFrame",
    },
    {
      path: "scripts/record-native-skia-evidence.mjs",
      token: "--async-image-log",
    },
    {
      path: "scripts/record-macos-platform-runtime-evidence.mjs",
      token: "--window-smoke-log",
    },
    {
      path: "scripts/record-macos-platform-runtime-evidence.mjs",
      token: "--app-runtime-log",
    },
    {
      path: "tools/moui/record_macos_platform_runtime_evidence/main.mbt",
      token: "examples/showcase/macos_skia",
    },
    {
      path: "moui/backend/macos/macos_backend.mbt",
      token: "native_ime_runtime_evidence",
    },
    {
      path: "examples/showcase/macos_skia/main.mbt",
      token: "MOUI_MACOS_NATIVE_IME_EVIDENCE",
    },
    {
      path: ".github/workflows/ci.yml",
      token: "MOUI_MACOS_NATIVE_IME_EVIDENCE=1",
    },
    {
      path: ".github/workflows/ci.yml",
      token: "artifacts/platform-evidence/macos/ime-showcase-runtime.log",
    },
    {
      path: "tools/moui/record_macos_platform_runtime_evidence/main.mbt",
      token: "macos.skiaEvidence.status must already be passed",
    },
    {
      path: "scripts/test-record-macos-platform-runtime-evidence.mjs",
      token: "reject source window smoke log missing cursor probe",
    },
    {
      path: "scripts/test-record-macos-platform-runtime-evidence.mjs",
      token: "reject source window smoke log missing IME probe",
    },
    {
      path: "scripts/test-record-macos-platform-runtime-evidence.mjs",
      token: "reject source app runtime log with wrong title",
    },
    {
      path: "docs/testing.md",
      token: "record-macos-platform-runtime-evidence.mjs",
    },
    { path: "docs/testing.md", token: "MOUI_MACOS_NATIVE_IME_EVIDENCE=1" },
    { path: "docs/testing.md", token: "--window-smoke-log" },
    { path: "docs/testing.md", token: "--app-runtime-log" },
    {
      path: "docs/release-readiness.md",
      token: "record-macos-platform-runtime-evidence.mjs",
    },
    {
      path: "docs/release-readiness.md",
      token: "MOUI_MACOS_NATIVE_IME_EVIDENCE=1",
    },
    { path: "docs/release-readiness.md", token: "appkit-setMarkedText" },
    { path: "docs/release-readiness.md", token: "appkit-insertText" },
    {
      path: "docs/renderer-capability-report.md",
      token: "macOS-only runtime claim",
    },
    { path: "AGENTS.md", token: "record-macos-platform-runtime-evidence.mjs" },
    { path: "AGENTS.md", token: "MOUI_MACOS_NATIVE_IME_EVIDENCE=1" },
    { path: "AGENTS.md", token: "NSTextInputClient" },
    { path: "AGENTS.md", token: "appkit-firstRectForCharacterRange" },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "record-macos-platform-runtime-evidence.mjs",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "MOUI_MACOS_NATIVE_IME_EVIDENCE=1",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "appkit-setMarkedText",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "appkit-insertText",
    },
    {
      path: "scripts/record-native-ime-evidence.mjs",
      token: "--candidate-anchor-log",
    },
    {
      path: "scripts/record-native-ime-evidence.mjs",
      token: "--scale-dpr-anchor-log",
    },
    {
      path: "tools/moui/record_native_ime_evidence/main.mbt",
      token: "appkit-setMarkedText",
    },
    {
      path: "tools/moui/record_native_ime_evidence/main.mbt",
      token: "appkit-firstRectForCharacterRange",
    },
    {
      path: "tools/moui/record_native_ime_evidence/main.mbt",
      token: "appkit-insertText",
    },
    {
      path: "tools/moui/record_native_ime_evidence/main.mbt",
      token: "platform-protocol=windows-ime",
    },
    { path: "tools/moui/record_native_ime_evidence/main.mbt", token: "renderer=skia" },
    {
      path: "tools/moui/record_native_ime_evidence/main.mbt",
      token: "has_whitespace_delimited_token",
    },
    { path: "tools/moui/record_native_ime_evidence/main.mbt", token: "app=showcase" },
    {
      path: "tools/moui/record_native_ime_evidence/main.mbt",
      token: "candidate-window",
    },
    {
      path: "tools/moui/record_native_ime_evidence/main.mbt",
      token: "composition-range",
    },
    {
      path: "tools/moui/record_native_ime_evidence/main.mbt",
      token: "preedit-underline",
    },
    {
      path: "tools/moui/record_native_ime_evidence/main.mbt",
      token: "\"examples/showcase/\" + options.platform + \"_skia\"",
    },
    {
      path: "scripts/test-record-native-ime-evidence.mjs",
      token: "platform-protocol=wayland-text-input",
    },
    {
      path: "scripts/test-record-native-ime-evidence.mjs",
      token: "renderer marker suffix",
    },
    {
      path: "scripts/test-record-native-ime-evidence.mjs",
      token: "platform protocol marker suffix",
    },
    {
      path: "scripts/test-record-native-ime-evidence.mjs",
      token: "common runtime marker suffixes",
    },
    {
      path: "scripts/test-record-native-ime-evidence.mjs",
      token: "host unit test",
    },
    {
      path: "scripts/test-record-native-ime-evidence.mjs",
      token: "reject macOS IME log without AppKit markers",
    },
    {
      path: "scripts/test-record-native-ime-evidence.mjs",
      token: "reject macOS cursor update log without AppKit insert marker",
    },
    {
      path: "scripts/test-record-native-ime-evidence.mjs",
      token: "reject non Skia app consumer command",
    },
    {
      path: "scripts/test-record-native-ime-evidence.mjs",
      token: "reject IME log from a non-Skia renderer",
    },
    { path: "docs/testing.md", token: "asyncImageSecondFrame=yes" },
    { path: "docs/testing.md", token: "selection rectangles" },
    { path: "docs/testing.md", token: "IME candidate anchors" },
    {
      path: "docs/testing.md",
      token: "examples/showcase/<platform>_skia",
    },
    { path: "docs/testing.md", token: "platform-protocol=windows-ime" },
    { path: "docs/testing.md", token: "appkit-firstRectForCharacterRange" },
    { path: "AGENTS.md", token: "platform-protocol=wayland-text-input" },
    { path: "AGENTS.md", token: "whitespace-delimited tokens" },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "whitespace-delimited tokens",
    },
    {
      path: "moui/backend/macos/skia/macos_skia_provider.mbt",
      token: "skia_native_image_loader",
    },
    {
      path: "moui/backend/macos/skia/macos_skia_provider.mbt",
      token: "image_loader=Some(skia_native_image_loader())",
    },
    {
      path: "moui/backend/macos/skia/macos_skia_provider.mbt",
      token: "renderer_image_loader=skia_image_load_completion",
    },
    {
      path: "moui/backend/macos/skia/macos_skia_provider.mbt",
      token: "renderer_async_image_loading=post-present",
    },
    {
      path: "moui/backend/macos/skia/macos_skia_provider.mbt",
      token: "async_image_loading=true",
    },
    {
      path: "moui/backend/macos/skia/macos_skia_provider_wbtest.mbt",
      token: "macos skia native image loader completes loading resources",
    },
    {
      path: "moui/backend/windows/skia/windows_skia_provider.mbt",
      token: "skia_native_image_loader",
    },
    {
      path: "moui/backend/windows/skia/windows_skia_provider.mbt",
      token: "image_loader=Some(skia_native_image_loader())",
    },
    {
      path: "moui/backend/windows/skia/windows_skia_provider.mbt",
      token: "renderer_image_loader=skia_image_load_completion",
    },
    {
      path: "moui/backend/windows/skia/windows_skia_provider.mbt",
      token: "renderer_async_image_loading=post-present",
    },
    {
      path: "moui/backend/windows/skia/windows_skia_provider.mbt",
      token: "async_image_loading=true",
    },
    {
      path: "moui/backend/windows/skia/windows_skia_provider_wbtest.mbt",
      token: "windows skia native image loader completes loading resources",
    },
    {
      path: "moui/backend/linux/skia/linux_skia_provider.mbt",
      token: "skia_native_image_loader",
    },
    {
      path: "moui/backend/linux/skia/linux_skia_provider.mbt",
      token: "image_loader=Some(skia_native_image_loader())",
    },
    {
      path: "moui/backend/linux/skia/linux_skia_provider.mbt",
      token: "renderer_image_loader=skia_image_load_completion",
    },
    {
      path: "moui/backend/linux/skia/linux_skia_provider.mbt",
      token: "renderer_async_image_loading=post-present",
    },
    {
      path: "moui/backend/linux/skia/linux_skia_provider.mbt",
      token: "async_image_loading=true",
    },
    {
      path: "moui/backend/linux/skia/linux_skia_provider_wbtest.mbt",
      token: "linux skia native image loader completes loading resources",
    },
    { path: "AGENTS.md", token: "skia_image_load_completion" },
    { path: "docs/architecture.md", token: "skia_image_load_completion" },
    { path: "docs/release-readiness.md", token: "skia_image_load_completion" },
    {
      path: "docs/renderer-capability-report.md",
      token: "skia_image_load_completion",
    },
    { path: "docs/testing.md", token: "skia_image_load_completion" },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "skia_image_load_completion",
    },
    { path: "AGENTS.md", token: "deferred native completion request source" },
    { path: "docs/architecture.md", token: "HostNativeAsyncImageSource" },
    { path: "docs/release-readiness.md", token: "HostNativeAsyncImageSource" },
    {
      path: "docs/renderer-capability-report.md",
      token: "HostNativeAsyncImageSource",
    },
    {
      path: "docs/renderer-capability-report.md",
      token: "renderer decode-helper payloads",
    },
    {
      path: "docs/renderer-capability-report.md",
      token: "deferred native-source callback",
    },
    { path: "docs/testing.md", token: "deferred native request capture" },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "HostNativeAsyncImageSource",
    },
    {
      path: "moui/render/wgpu/renderer.mbt",
      token: "WgpuRenderer::apply_image_resource_load_completion",
    },
    {
      path: "moui/render/skia/renderer_image.mbt",
      token: "SkiaRasterRenderer::apply_image_resource_load_completion",
    },
    {
      path: "moui/render/webgpu_adapter/adapter_image_resources.mbt",
      token: "WebGpuWasmRenderer::apply_image_resource_load_completion",
    },
    {
      path: "moui/backend/web/webgpu_renderer.mbt",
      token: "WebRenderer::apply_image_resource_load_completion",
    },
    {
      path: "moui/backend/macos/wgpu/macos_wgpu_provider.mbt",
      token: "apply_image_resource_load_completion=Some",
    },
    {
      path: "moui/backend/windows/wgpu/windows_wgpu_provider.mbt",
      token: "apply_image_resource_load_completion=Some",
    },
    {
      path: "moui/backend/linux/wgpu/linux_wgpu_provider.mbt",
      token: "apply_image_resource_load_completion=Some",
    },
    {
      path: "moui/backend/macos/skia/macos_skia_provider.mbt",
      token: "renderer_image_resource_apply=SkiaRasterRenderer.apply_image_resource_load_completion",
    },
    {
      path: "moui/backend/windows/skia/windows_skia_provider.mbt",
      token: "renderer_image_resource_apply=SkiaRasterRenderer.apply_image_resource_load_completion",
    },
    {
      path: "moui/backend/linux/skia/linux_skia_provider.mbt",
      token: "renderer_image_resource_apply=SkiaRasterRenderer.apply_image_resource_load_completion",
    },
    {
      path: "moui/backend/host/host_test.mbt",
      token: "host image completion source routes native loader completions",
    },
    {
      path: "moui/backend/host/host_test.mbt",
      token: "host image completion source discards closed-window completions",
    },
    {
      path: "moui/backend/host/host_test.mbt",
      token: "host image completion source ignores stale completion revisions",
    },
    {
      path: "moui/backend/host/host_test.mbt",
      token: "host image completion source applies renderer load completions",
    },
    {
      path: "moui/backend/host/host_test.mbt",
      token: "host async image loader schedules loading records and completes redraw",
    },
    {
      path: "moui/backend/host/host_test.mbt",
      token: "host async image loader cancels window loads and ignores late completions",
    },
    {
      path: "moui/backend/host/host_test.mbt",
      token: "host async image loader ignores mismatched completion sources",
    },
    {
      path: "moui/backend/host/host_test.mbt",
      token: "host native async image source defers completion until platform callback",
    },
    {
      path: "moui/backend/host/host_test.mbt",
      token: "host native async image source drops completions after loader cancellation",
    },
    {
      path: "moui/backend/macos/macos_backend_wbtest.mbt",
      token: "macos renderer provider exposes async image loader hook",
    },
    {
      path: "moui/backend/macos/macos_backend_wbtest.mbt",
      token: "macos renderer provider async image hook defaults to unavailable",
    },
    {
      path: "moui/backend/windows/windows_backend_wbtest.mbt",
      token: "windows renderer provider exposes async image loader hook",
    },
    {
      path: "moui/backend/windows/windows_backend_wbtest.mbt",
      token: "windows renderer provider async image hook defaults to unavailable",
    },
    {
      path: "moui/backend/linux/linux_backend_wbtest.mbt",
      token: "linux renderer provider exposes async image loader hook",
    },
    {
      path: "moui/backend/linux/linux_backend_wbtest.mbt",
      token: "linux renderer provider async image hook defaults to unavailable",
    },
    {
      path: "moui/render/wgpu/native_image_wbtest.mbt",
      token: "native image load completion reports decoded dimensions or failure",
    },
    {
      path: "moui/backend/macos/wgpu/macos_wgpu_provider_wbtest.mbt",
      token: "macos wgpu native image loader completes loading resources",
    },
    {
      path: "moui/backend/macos/wgpu/macos_wgpu_provider_wbtest.mbt",
      token: "macos wgpu deferred native source completes through decode helper",
    },
    {
      path: "moui/backend/macos/skia/macos_skia_provider_wbtest.mbt",
      token: "macos skia deferred native source completes through decode helper",
    },
    {
      path: "moui/backend/windows/wgpu/windows_wgpu_provider_wbtest.mbt",
      token: "windows wgpu native image loader completes loading resources",
    },
    {
      path: "moui/backend/windows/wgpu/windows_wgpu_provider_wbtest.mbt",
      token: "windows wgpu deferred native source completes through decode helper",
    },
    {
      path: "moui/backend/windows/skia/windows_skia_provider_wbtest.mbt",
      token: "windows skia deferred native source completes through decode helper",
    },
    {
      path: "moui/backend/linux/wgpu/linux_wgpu_provider_wbtest.mbt",
      token: "linux wgpu native image loader completes loading resources",
    },
    {
      path: "moui/backend/linux/wgpu/linux_wgpu_provider_wbtest.mbt",
      token: "linux wgpu deferred native source completes through decode helper",
    },
    {
      path: "moui/backend/linux/skia/linux_skia_provider_wbtest.mbt",
      token: "linux skia deferred native source completes through decode helper",
    },
    {
      path: "moui/render/capabilities_test.mbt",
      token: "image lifecycle applies async load completions",
    },
    {
      path: "docs/platform-notes.md",
      token: "The Web host now advertises IME readiness",
    },
    {
      path: "docs/text-system.md",
      token: "routes browser IME composition events",
    },
    { path: "moui/backend/web/web_host.mbt", token: "ime_ready=true" },
    {
      path: "examples/showcase/app/showcase_app_test.mbt",
      token: "web ime readiness",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "scripts/record_moui_evidence.sh",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "evidenceProvenance",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "non-skipped successful GitHub Actions job",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "wzzc-dev/window@0.5.1-0.1.4",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "scripts/run-window-package-smoke.sh <platform>",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "dependency resolution, registry cache state",
    },
    { path: "AGENTS.md", token: "scripts/record_moui_evidence.sh" },
    { path: "AGENTS.md", token: "wzzc-dev/window@0.5.1-0.1.4" },
    {
      path: "AGENTS.md",
      token: "scripts/run-window-package-smoke.sh <platform>",
    },
    {
      path: "AGENTS.md",
      token: "package-version regressions as plausible causes",
    },
    { path: "AGENTS.md", token: "skia-platform-status.json" },
    { path: "AGENTS.md", token: "verify-platform-status.sh" },
    { path: "AGENTS.md", token: "native/capabilities.json" },
    { path: "AGENTS.md", token: "verify-native-capability-contract.sh" },
    { path: "AGENTS.md", token: "platform-runtime-evidence.json" },
    { path: "AGENTS.md", token: "record-platform-evidence-manifest.mjs" },
    { path: "AGENTS.md", token: "record-native-ime-evidence.mjs" },
    { path: "AGENTS.md", token: "record-native-skia-evidence.mjs" },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "record-native-ime-evidence.mjs",
    },
    { path: "AGENTS.md", token: "evidenceProvenance" },
    { path: "AGENTS.md", token: "validate-web-runtime-handoff.mjs" },
    { path: "AGENTS.md", token: "test-validate-web-runtime-handoff.mjs" },
    { path: "AGENTS.md", token: "validate-web-runtime-handoff-manifest.mjs" },
    { path: "AGENTS.md", token: "record-web-runtime-presentation.mjs" },
    { path: "AGENTS.md", token: "test-record-web-runtime-presentation.mjs" },
    {
      path: "AGENTS.md",
      token: "validate-web-runtime-presentation-manifest.mjs",
    },
    { path: "AGENTS.md", token: "validate-renderer-proof-manifest.mjs" },
    { path: "AGENTS.md", token: "test-validate-renderer-proof-manifest.mjs" },
    { path: "AGENTS.md", token: "record-renderer-proof-manifest.mjs" },
    { path: "AGENTS.md", token: "test-record-renderer-proof-manifest.mjs" },
    { path: "AGENTS.md", token: "record-web-renderer-proof-manifest.mjs" },
    { path: "AGENTS.md", token: "test-record-web-renderer-proof-manifest.mjs" },
    { path: "AGENTS.md", token: "generate-grapheme-break-fixtures.mjs --check" },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "generate-grapheme-break-fixtures.mjs --check",
    },
    { path: "AGENTS.md", token: "renderer-proof-summary" },
    { path: "AGENTS.md", token: "colorEmojiPixels" },
    { path: "AGENTS.md", token: "stable-glyph-key" },
    { path: "AGENTS.md", token: "fallback request character" },
    { path: "AGENTS.md", token: "fallback-request-character" },
    { path: "AGENTS.md", token: "selectionRects" },
    {
      path: "AGENTS.md",
      token: "selection-rects line-range rect-geometry hit-test",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "fallback request character",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "fallback-request-character",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "`line-range`, `rect-geometry`, and `hit-test`",
    },
    { path: "AGENTS.md", token: "imeCompositionVisual" },
    { path: "AGENTS.md", token: "CDP is unavailable" },
    { path: "AGENTS.md", token: "resize/input event-bridge" },
    { path: "AGENTS.md", token: "--web-presentation-manifest" },
    { path: "AGENTS.md", token: "monitor/cursor" },
    { path: "AGENTS.md", token: "host-event fanout subscription adapters" },
    { path: "AGENTS.md", token: "window-scoped subscription adapters" },
    { path: "AGENTS.md", token: "platform event-source bundles" },
    { path: "AGENTS.md", token: "scheduler-backed timer subscription adapters" },
    { path: "AGENTS.md", token: "route/deep-link subscription adapters" },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "resize/input event-bridge delivery",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "verify-platform-status.sh",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "native/capabilities.json",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "verify-native-capability-contract.sh",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "test-record-web-runtime-presentation.mjs",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "validate-renderer-proof-manifest.mjs",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "test-record-renderer-proof-manifest.mjs",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "renderer-proof-summary",
    },
    { path: "AGENTS.md", token: "test-webgpu-runtime-radial.mjs" },
    { path: "docs/testing.md", token: "test-webgpu-runtime-radial.mjs" },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "test-webgpu-runtime-radial.mjs",
    },
    {
      path: "scripts/conformance-check.sh",
      token: "test-webgpu-runtime-radial.mjs",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "host-event subscription source fanout",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "HostEventSource::subscription",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "window-scoped subscription source",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "HostWindowEventSource::subscription",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "HostPlatformEventSources",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "normalized runtime host/window event stream",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "route/deep-link subscription source",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "HostRouteSource::subscription",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "scheduler-backed timer subscription source",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "HostTimerSource::subscription",
    },
    {
      path: "skills/moui-app-development-skill/SKILL.md",
      token: "HostRouteSource",
    },
    { path: "docs/platform-notes.md", token: "`HostRouteSource`" },
    { path: "docs/view-catalog.md", token: "`@host.HostRouteSource`" },
    { path: "docs/examples.md", token: "`HostRouteSource`" },
    { path: "docs/release-readiness.md", token: "`web-runtime-presentation`" },
    {
      path: "docs/release-readiness.md",
      token: "`moui-web-runtime-presentation`",
    },
    { path: "AGENTS.md", token: "`web-runtime-presentation`" },
    { path: "AGENTS.md", token: "`moui-web-runtime-presentation`" },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "`web-runtime-presentation`",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "`moui-web-runtime-presentation`",
    },
    {
      path: "moui/README.mbt.md",
      token: "sh scripts/dev-check.sh --platform-examples-test",
    },
    {
      path: "moui/README.mbt.md",
      token: "sh scripts/conformance-check.sh --platform-services",
    },
    { path: "moui/README.mbt.md", token: "verify-platform-status.sh" },
    {
      path: "moui/README.mbt.md",
      token: "verify-native-capability-contract.sh",
    },
    { path: "moui/README.mbt.md", token: "platform-runtime-evidence.json" },
    {
      path: "moui/README.mbt.md",
      token: "record-platform-evidence-manifest.mjs",
    },
    { path: "moui/README.mbt.md", token: "validate-web-runtime-handoff.mjs" },
    { path: "moui/README.mbt.md", token: "record-web-runtime-presentation.mjs" },
    { path: "moui/README.mbt.md", token: "resize/input" },
    { path: "moui/README.mbt.md", token: "--web-presentation-manifest" },
    { path: "moui/README.mbt.md", token: "monitor/cursor" },
    { path: "moui/README.mbt.md", token: "artifacts/conformance/" },
    {
      path: "scripts/record-web-runtime-presentation.mjs",
      token: "platformObservations",
    },
    {
      path: "scripts/record-web-runtime-presentation.mjs",
      token: "writePreflightFailureManifest",
    },
    {
      path: "scripts/record-web-runtime-presentation.mjs",
      token: "resizeEvent",
    },
    {
      path: "scripts/record-web-runtime-presentation.mjs",
      token: "targetClosed",
    },
    {
      path: "tools/moui/validate_web_runtime_presentation_manifest/main.mbt",
      token: "platformObservations",
    },
    {
      path: "tools/moui/record_platform_evidence_manifest/main.mbt",
      token: "platformObservations",
    },
    {
      path: "moui/backend/web/browser_runtime.js",
      token: "__mouiWebRuntimeEvidence",
    },
  ]
}

///|
fn guidance_absent_rules() -> Array[TextRule] {
  [
    { path: "AGENTS.md", token: "Milky2018/window" },
    { path: "AGENTS.md", token: "moui_skia/.github/workflows" },
    { path: "AGENTS.md", token: "`tests/*_conformance`" },
    { path: "AGENTS.md", token: "`tests/text_conformance/`" },
    { path: "AGENTS.md", token: "`tests/skia_renderer_smoke/native`" },
    { path: "AGENTS.md", token: "`README.mbt.md`" },
    { path: "docs/development.md", token: "Milky2018/window" },
    { path: "docs/development.md", token: "moui_skia/.github/workflows" },
    { path: "docs/development.md", token: "`tests/*_conformance`" },
    { path: "docs/development.md", token: "`tests/text_conformance/`" },
    { path: "docs/development.md", token: "`tests/skia_renderer_smoke/native`" },
    { path: "docs/development.md", token: "`README.mbt.md`" },
    { path: "docs/testing.md", token: "Milky2018/window" },
    { path: "docs/testing.md", token: "moui_skia/.github/workflows" },
    { path: "docs/testing.md", token: "`tests/*_conformance`" },
    { path: "docs/testing.md", token: "`tests/text_conformance/`" },
    { path: "docs/testing.md", token: "`tests/skia_renderer_smoke/native`" },
    { path: "docs/testing.md", token: "`README.mbt.md`" },
    { path: "docs/text-system.md", token: "Milky2018/window" },
    { path: "docs/text-system.md", token: "moui_skia/.github/workflows" },
    { path: "docs/text-system.md", token: "`tests/*_conformance`" },
    { path: "docs/text-system.md", token: "`tests/text_conformance/`" },
    { path: "docs/text-system.md", token: "`tests/skia_renderer_smoke/native`" },
    { path: "docs/text-system.md", token: "`README.mbt.md`" },
    {
      path: "skills/moui-app-development-skill/SKILL.md",
      token: "Milky2018/window",
    },
    {
      path: "skills/moui-app-development-skill/SKILL.md",
      token: "moui_skia/.github/workflows",
    },
    {
      path: "skills/moui-app-development-skill/SKILL.md",
      token: "`tests/*_conformance`",
    },
    {
      path: "skills/moui-app-development-skill/SKILL.md",
      token: "`tests/text_conformance/`",
    },
    {
      path: "skills/moui-app-development-skill/SKILL.md",
      token: "`tests/skia_renderer_smoke/native`",
    },
    {
      path: "skills/moui-app-development-skill/SKILL.md",
      token: "`README.mbt.md`",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "Milky2018/window",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "moui_skia/.github/workflows",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "`tests/*_conformance`",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "`tests/text_conformance/`",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "`tests/skia_renderer_smoke/native`",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "`README.mbt.md`",
    },
    {
      path: "scripts/ci-renderer-proof-summary.sh",
      token: "wgpu-native-macos.json",
    },
    {
      path: "scripts/ci-renderer-proof-summary.sh",
      token: "wgpu-native-windows.json",
    },
    {
      path: "scripts/ci-renderer-proof-summary.sh",
      token: "wgpu-native-linux.json",
    },
    { path: ".github/workflows/ci.yml", token: "run_real_skia_smoke" },
    { path: ".github/workflows/ci.yml", token: "real-skia-smoke:" },
  ]
}

///|
fn guidance_file_exists_rules() -> Array[String] {
  [
    ".github/workflows/moui-skia-fallback.yml", ".github/workflows/moui-skia-linux-real-skia-smoke.yml",
    ".github/workflows/moui-skia-macos-real-skia-smoke.yml", ".github/workflows/moui-skia-windows-real-skia-smoke.yml",
    ".github/workflows/moui-skia-real-skia-acceptance.yml", ".github/workflows/copilot-setup-steps.yml",
    ".github/workflows/moui-real-skia-smoke.yml", "docs/maintenance.md",
  ]
}

///|
fn guidance_no_workflow_file_rules() -> Array[String] {
  ["moui_skia/.github/workflows"]
}

///|
fn guidance_symlink_rules() -> Array[SymlinkRule] {
  [{ path: "README.md", target: "moui/README.mbt.md" }]
}
