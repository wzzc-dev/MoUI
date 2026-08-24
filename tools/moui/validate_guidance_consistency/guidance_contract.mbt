// Keep this contract small and aligned with current, runnable repository gates.

///|
fn guidance_include_rules() -> Array[TextRule] {
  [
    { path: "AGENTS.md", token: "sh scripts/check.sh --profile daily" },
    { path: "AGENTS.md", token: "node scripts/validate-api-surface.mjs" },
    { path: ".github/workflows/ci.yml", token: "name: PR profile gate" },
    {
      path: ".github/workflows/ci.yml",
      token: "run: sh scripts/check.sh --profile pr",
    },
    {
      path: ".github/workflows/ci.yml",
      token: "run: sh scripts/check.sh --profile platform",
    },
    {
      path: ".github/workflows/ci.yml",
      token: ".\\scripts\\windows\\check.ps1 -Profile Pr -DryRun -Json -SkipSubmoduleInit",
    },
    {
      path: ".github/workflows/feature-proof-summary.yml",
      token: "MoUI Renderer Real Skia CI",
    },
    {
      path: ".github/workflows/feature-proof-summary.yml",
      token: "moui-renderer-real-skia-ci.yml",
    },
    {
      path: ".github/workflows/moui-macos-platform-evidence.yml",
      token: "name: MoUI macOS Platform Evidence",
    },
    {
      path: ".github/workflows/moui-linux-platform-evidence.yml",
      token: "name: MoUI Linux Platform Evidence",
    },
    {
      path: ".github/workflows/moui-linux-riscv64-cross-build.yml",
      token: "name: MoUI Linux RISC-V64 Cross Build",
    },
    {
      path: ".github/workflows/moui-windows-platform-evidence.yml",
      token: "name: MoUI Windows Platform Evidence",
    },
    {
      path: ".github/workflows/moui-renderer-real-skia-ci.yml",
      token: "name: MoUI Renderer Real Skia CI",
    },
    {
      path: ".github/workflows/moui-macos-app-real-skia-manual.yml",
      token: "name: MoUI macOS App Real Skia Manual",
    },
    {
      path: ".github/workflows/moui-runtime-gates.yml",
      token: "name: MoUI Runtime Gates",
    },
    {
      path: ".github/workflows/moui-skia-provider-fallback-ci.yml",
      token: "name: MoUI Skia Provider Fallback CI",
    },
    {
      path: ".github/workflows/moui-skia-provider-real-skia-acceptance.yml",
      token: "name: MoUI Skia Provider Real Skia Acceptance",
    },
    {
      path: ".github/workflows/moui-skia-provider-linux-real-skia-nightly.yml",
      token: "name: MoUI Skia Provider Linux Real Skia Nightly",
    },
    {
      path: ".github/workflows/moui-skia-provider-macos-real-skia-manual.yml",
      token: "name: MoUI Skia Provider macOS Real Skia Manual",
    },
    {
      path: ".github/workflows/moui-skia-provider-windows-real-skia-manual.yml",
      token: "name: MoUI Skia Provider Windows Real Skia Manual",
    },
    { path: "docs/development.md", token: "repository-facts.md" },
    {
      path: "docs/development.md",
      token: "-Profile Pr -DryRun -Json -SkipSubmoduleInit",
    },
    {
      path: "docs/development.md",
      token: ".github/workflows/moui-renderer-real-skia-ci.yml",
    },
    {
      path: "docs/development.md",
      token: "moui-macos-app-real-skia-manual.yml",
    },
    {
      path: "docs/testing.md",
      token: "node scripts/validate-guidance-consistency.mjs",
    },
    { path: "docs/testing.md", token: "moui-renderer-real-skia-ci.yml" },
    {
      path: "docs/feature-proof-matrix.md",
      token: "moui-renderer-real-skia-ci.yml",
    },
    {
      path: "docs/feature-proof-matrix.md",
      token: "moui-macos-app-real-skia-manual.yml",
    },
    {
      path: "docs/feature-status-dashboard.md",
      token: "moui-renderer-real-skia-ci.yml",
    },
    { path: "docs/testing.md", token: "shared platform service checks" },
    {
      path: "docs/release-readiness.md",
      token: "shared platform service checks",
    },
    {
      path: "docs/testing.md",
      token: "moon test moui_sun_renderer --target native",
    },
    {
      path: "docs/testing.md",
      token: "node scripts/validate-window-dependency.mjs",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "node scripts/validate-guidance-consistency.mjs",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "shared platform service checks",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "moui-renderer-real-skia-ci.yml",
    },
    {
      path: "skills/moui-app-development/SKILL.md",
      token: "shared platform service checks",
    },
    { path: "AGENTS.md", token: "Windows check wrapper plan" },
    { path: "AGENTS.md", token: "shared platform service checks" },
    { path: "AGENTS.md", token: "Script Tooling Policy" },
    { path: "AGENTS.md", token: "EmbedderHostChannel" },
    { path: "AGENTS.md", token: "Native XComponent callbacks are the only" },
    { path: "docs/window-hosted-moui.md", token: "HostCmd" },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "SkiaGpuNative",
    },
    {
      path: "skills/moui-app-development/SKILL.md",
      token: "before/after pixel change",
    },
    { path: "docs/development.md", token: "Script Tooling Policy" },
    { path: "docs/testing.md", token: "Script Tooling Policy" },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "Script Tooling Policy",
    },
    { path: "docs/development.md", token: "Windows MSVC, vcpkg, and zlib" },
    { path: "docs/testing.md", token: "Windows MSVC, vcpkg, and zlib" },
    { path: "AGENTS.md", token: "rule`/`dev_build`" },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "rule`/`dev_build`",
    },
    {
      path: "skills/moui-app-development/SKILL.md",
      token: "examples/<name>/app",
    },
    { path: "AGENTS.md", token: "linux-skia-riscv64" },
    { path: "docs/platform-notes-linux.md", token: "riscv64-linux-gnu" },
    { path: "docs/testing.md", token: "test-linux-riscv64-cross-build.sh" },
    {
      path: "docs/platform-readiness-declaration.md",
      token: "checks/architecture-evidence/linux-skia-riscv64.json",
    },
    { path: "docs/zh-Hans/platform-notes-linux.md", token: "riscv64-linux-gnu" },
    {
      path: "docs/zh-Hans/testing.md",
      token: "test-linux-riscv64-cross-build.sh",
    },
    {
      path: "docs/zh-Hans/platform-readiness-declaration.md",
      token: "linux-skia-riscv64",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "linux-riscv64-cross-build.sh",
    },
    {
      path: "skills/moui-app-development/SKILL.md",
      token: "linux-skia-riscv64",
    },
  ]
}

///|
fn guidance_absent_rules() -> Array[TextRule] {
  [{ path: "moon.work", token: "\"./window\"" }]
}

///|
fn guidance_window_dependency_paths() -> Array[String] {
  [
    "docs/development.md", "docs/platform-notes.md", "docs/platform-notes-linux.md",
    "docs/examples.md", "docs/release-readiness.md", "moui/README.mbt.md", "skills/moui-framework-development-skill/SKILL.md",
  ]
}

///|
fn guidance_file_exists_rules() -> Array[String] {
  [
    "README.md", "AGENTS.md", "docs/architecture.md", "docs/development.md", "docs/testing.md",
    "docs/window-hosted-moui.md", "scripts/check.mjs", "scripts/check.sh", "scripts/windows/check.ps1",
    "scripts/validate-guidance-consistency.mjs", ".github/workflows/moui-renderer-real-skia-ci.yml",
    ".github/workflows/moui-macos-app-real-skia-manual.yml", ".github/workflows/moui-runtime-gates.yml",
    ".github/workflows/moui-skia-provider-fallback-ci.yml", ".github/workflows/moui-skia-provider-linux-real-skia-nightly.yml",
    ".github/workflows/moui-skia-provider-macos-real-skia-manual.yml", ".github/workflows/moui-skia-provider-windows-real-skia-manual.yml",
    ".github/workflows/moui-skia-provider-real-skia-acceptance.yml", "checks/profiles.json",
    ".github/workflows/moui-linux-riscv64-cross-build.yml", "checks/toolchains/linux-riscv64.json",
    "checks/architecture-evidence/linux-skia-riscv64.json", "scripts/prepare-linux-riscv64-sysroot.sh",
    "scripts/linux-riscv64-cross-build.sh", "scripts/test-linux-riscv64-cross-build.sh",
    "skills/moui-app-development/SKILL.md", "skills/moui-framework-development-skill/SKILL.md",
    "tools/moui/validate_guidance_consistency/moon.pkg",
  ]
}

///|
fn guidance_no_workflow_file_rules() -> Array[String] {
  ["moui_skia/.github/workflows"]
}

///|
fn guidance_regular_file_rules() -> Array[String] {
  ["README.md"]
}
