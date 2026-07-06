// Keep this contract small and aligned with current, runnable repository gates.

///|
fn guidance_include_rules() -> Array[TextRule] {
  [
    { path: "AGENTS.md", token: "sh scripts/dev-check.sh" },
    { path: "AGENTS.md", token: "node scripts/validate-api-surface.mjs" },
    { path: "docs/development.md", token: "./moui_webview" },
    { path: "docs/development.md", token: "./moui_sun" },
    { path: "docs/development.md", token: "./examples/mo_workbench" },
    {
      path: "docs/testing.md",
      token: "node scripts/validate-guidance-consistency.mjs",
    },
    {
      path: "docs/testing.md",
      token: "moon test moui/render/sun --target native",
    },
    {
      path: "docs/testing.md",
      token: "node scripts/validate-window-dependency.mjs",
    },
    {
      path: "docs/testing.md",
      token: "node scripts/validate-openseek-workbench.mjs",
    },
    {
      path: "skills/moui-framework-development-skill/SKILL.md",
      token: "node scripts/validate-guidance-consistency.mjs",
    },
    { path: "AGENTS.md", token: "Script Tooling Policy" },
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
  ]
}

///|
fn guidance_absent_rules() -> Array[TextRule] {
  [{ path: "moon.work", token: "\"./window\"" }]
}

///|
fn guidance_window_dependency_paths() -> Array[String] {
  [
    "docs/development.md", "docs/platform-notes.md", "docs/examples.md", "docs/release-readiness.md",
    "moui/README.mbt.md", "skills/moui-framework-development-skill/SKILL.md",
  ]
}

///|
fn guidance_file_exists_rules() -> Array[String] {
  [
    "AGENTS.md", "docs/architecture.md", "docs/development.md", "docs/testing.md",
    "scripts/dev-check.sh", "scripts/validate-guidance-consistency.mjs", "skills/moui-app-development/SKILL.md",
    "skills/moui-framework-development-skill/SKILL.md", "tools/moui/validate_guidance_consistency/moon.pkg",
  ]
}

///|
fn guidance_no_workflow_file_rules() -> Array[String] {
  ["moui_skia/.github/workflows"]
}

///|
fn guidance_symlink_rules() -> Array[SymlinkRule] {
  [{ path: "README.md", target: "README.mbt.md" }]
}
