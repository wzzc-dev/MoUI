///|
fn guidance_include_rules() -> Array[TextRule] {
  [
    { path: "README.md", token: "sh scripts/dev-check.sh" },
    { path: "README.md", token: "manual smoke" },
    { path: "README.md", token: "artifacts/ is ignored" },
    { path: "moui/README.mbt.md", token: "sh scripts/dev-check.sh" },
    { path: "moui/README.mbt.md", token: "manual smoke" },
    { path: "moui/README.mbt.md", token: "artifacts/ is ignored" },
    { path: "docs/testing.md", token: "Daily" },
    { path: "docs/testing.md", token: "Focused" },
    { path: "docs/testing.md", token: "Smoke" },
    { path: "docs/testing.md", token: "sh scripts/dev-check.sh" },
    { path: "docs/testing.md", token: "moon check" },
    {
      path: "docs/testing.md",
      token: "moon build examples/showcase/web_wasm --target wasm-gc",
    },
    { path: "docs/testing.md", token: "scripts/macos-skia-renderer-smoke.sh" },
    { path: "docs/release-readiness.md", token: "daily baseline" },
    { path: "docs/release-readiness.md", token: "manual smoke" },
    { path: "docs/release-readiness.md", token: "CI run or smoke log" },
    { path: "AGENTS.md", token: "daily validation script" },
    { path: "AGENTS.md", token: "manual smoke" },
    { path: "AGENTS.md", token: "Do not commit artifacts/" },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "Daily check",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "Manual smoke",
    },
    {
      path: "scripts/dev-check.sh",
      token: "node scripts/validate-guidance-consistency.mjs",
    },
    {
      path: "scripts/dev-check.sh",
      token: "node scripts/validate-api-surface.mjs",
    },
    { path: "scripts/dev-check.sh", token: "moon check" },
    {
      path: "scripts/dev-check.sh",
      token: "moon test moui/core --target native",
    },
    {
      path: "scripts/dev-check.sh",
      token: "moon test moui/views --target native",
    },
    {
      path: "scripts/dev-check.sh",
      token: "moon test moui/render/skia --target native",
    },
    {
      path: "scripts/dev-check.sh",
      token: "moon test moui/backend/host --target native",
    },
    {
      path: "scripts/dev-check.sh",
      token: "moon test moui/backend/web --target wasm-gc",
    },
    {
      path: "scripts/dev-check.sh",
      token: "moon build examples/showcase/web_wasm --target wasm-gc",
    },
    {
      path: "scripts/dev-check.sh",
      token: "moon build examples/markdown_editor/web_wasm --target wasm-gc",
    },
    {
      path: "scripts/conformance-check.sh",
      token: "moon test moui/backend/host --target native",
    },
    {
      path: "scripts/conformance-check.sh",
      token: "moon test moui/backend/web --target wasm-gc",
    },
    {
      path: "scripts/ci-web-runtime-presentation.sh",
      token: "artifacts/smoke/web-runtime-presentation",
    },
    {
      path: "scripts/ci-web-runtime-presentation.sh",
      token: "record-web-runtime-presentation.mjs",
    },
    {
      path: "scripts/ci-web-runtime-presentation.sh",
      token: "validate-web-runtime-presentation-manifest.mjs",
    },
    { path: ".gitignore", token: "artifacts/" },
    {
      path: ".github/workflows/ci.yml",
      token: "Run daily development and guidance checks",
    },
    { path: ".github/workflows/ci.yml", token: "Linux platform contracts" },
    { path: ".github/workflows/ci.yml", token: "macOS packaging smoke" },
    { path: ".github/workflows/ci.yml", token: "Windows MSVC native smoke" },
  ]
}

///|
fn stale_renderer_proof_token() -> String {
  "renderer" + "-" + "proof"
}

///|
fn stale_platform_runtime_evidence_token() -> String {
  "platform" + "-" + "runtime" + "-" + "evidence"
}

///|
fn stale_checked_conformance_artifacts_script() -> String {
  "validate" + "-" + "checked" + "-" + "conformance" + "-" + "artifacts.mjs"
}

///|
fn stale_renderer_proof_manifest_script(prefix : String) -> String {
  prefix + "-" + stale_renderer_proof_token() + "-" + "manifest.mjs"
}

///|
fn stale_platform_evidence_manifest_script(prefix : String) -> String {
  prefix + "-" + "platform" + "-" + "evidence" + "-" + "manifest.mjs"
}

///|
fn stale_web_renderer_proof_manifest_script() -> String {
  "record" +
  "-" +
  "web" +
  "-" +
  stale_renderer_proof_token() +
  "-" +
  "manifest.mjs"
}

///|
fn guidance_absent_rules() -> Array[TextRule] {
  [
    { path: ".gitignore", token: "!artifacts/conformance/" },
    {
      path: ".github/workflows/ci.yml",
      token: stale_renderer_proof_token() + "-" + "wgpu-native",
    },
    {
      path: ".github/workflows/ci.yml",
      token: stale_renderer_proof_token() + "-" + "skia-native",
    },
    {
      path: ".github/workflows/ci.yml",
      token: stale_renderer_proof_token() + "-" + "summary",
    },
    { path: ".github/workflows/ci.yml", token: "web-runtime-presentation:" },
    {
      path: ".github/workflows/ci.yml",
      token: "macos" + "-" + stale_platform_runtime_evidence_token(),
    },
    {
      path: ".github/workflows/ci.yml",
      token: "run_macos_platform_runtime_evidence",
    },
    {
      path: "scripts/dev-check.sh",
      token: stale_checked_conformance_artifacts_script(),
    },
    {
      path: "scripts/dev-check.sh",
      token: stale_renderer_proof_manifest_script("validate"),
    },
    {
      path: "scripts/dev-check.sh",
      token: stale_renderer_proof_manifest_script("record"),
    },
    {
      path: "scripts/dev-check.sh",
      token: stale_web_renderer_proof_manifest_script(),
    },
    {
      path: "scripts/dev-check.sh",
      token: stale_platform_evidence_manifest_script("validate"),
    },
    {
      path: "scripts/dev-check.sh",
      token: stale_platform_evidence_manifest_script("record"),
    },
    {
      path: "scripts/ci-web-runtime-presentation.sh",
      token: stale_web_renderer_proof_manifest_script(),
    },
    {
      path: "scripts/ci-web-runtime-presentation.sh",
      token: stale_platform_evidence_manifest_script("record"),
    },
    {
      path: "scripts/ci-web-runtime-presentation.sh",
      token: stale_platform_evidence_manifest_script("validate"),
    },
    {
      path: "README.md",
      token: stale_platform_runtime_evidence_token() + ".json",
    },
    { path: "README.md", token: stale_renderer_proof_token() },
    {
      path: "moui/README.mbt.md",
      token: stale_platform_runtime_evidence_token() + ".json",
    },
    { path: "moui/README.mbt.md", token: stale_renderer_proof_token() },
    {
      path: "docs/testing.md",
      token: stale_checked_conformance_artifacts_script(),
    },
    {
      path: "docs/testing.md",
      token: stale_platform_runtime_evidence_token() + ".json",
    },
    {
      path: "docs/testing.md",
      token: stale_renderer_proof_manifest_script("validate"),
    },
    {
      path: "docs/testing.md",
      token: stale_renderer_proof_manifest_script("record"),
    },
    {
      path: "docs/testing.md",
      token: stale_platform_evidence_manifest_script("record"),
    },
    {
      path: "docs/testing.md",
      token: stale_renderer_proof_token() + "-" + "summary",
    },
    {
      path: "docs/release-readiness.md",
      token: stale_platform_runtime_evidence_token() + ".json",
    },
    { path: "docs/release-readiness.md", token: stale_renderer_proof_token() },
    {
      path: "AGENTS.md",
      token: stale_platform_runtime_evidence_token() + ".json",
    },
    { path: "AGENTS.md", token: stale_renderer_proof_token() },
    { path: "AGENTS.md", token: stale_checked_conformance_artifacts_script() },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: stale_platform_runtime_evidence_token() + ".json",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: stale_renderer_proof_token(),
    },
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
