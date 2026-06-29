<#
.SYNOPSIS
  Windows PowerShell entry point for daily MoUI development checks.

.DESCRIPTION
  Native PowerShell counterpart to scripts/dev-check.sh. Runs the same
  bounded mainline package checks, guidance consistency checks, and
  Windows platform backend tests without requiring MSYS/Git Bash.

  The window submodule is initialized on first run so the workspace
  resolves wzzc-dev/window from the local checkout.

.PARAMETER PlatformExamplesTest
  Also run Windows backend tests (moui/backend/windows, skia).

.PARAMETER PlatformExamplesBuild
  Also build Windows native examples. Cold builds may be slow.

.PARAMETER WgpuExperimental
  Also run native WGPU diagnostic package checks.

.PARAMETER ThemeDiagnostics
  Also run moui_theme and Design Systems addon diagnostic checks.

.PARAMETER SkipSubmoduleInit
  Skip the window submodule initialization check.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\windows\dev_check.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\windows\dev_check.ps1 -PlatformExamplesTest
#>
[CmdletBinding()]
param(
  [switch]$PlatformExamplesTest,
  [switch]$PlatformExamplesBuild,
  [switch]$WgpuExperimental,
  [switch]$ThemeDiagnostics,
  [switch]$SkipSubmoduleInit
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
Set-Location $repoRoot

Write-Host "==> repo root: $repoRoot"

function Invoke-Step {
  param([Parameter(Mandatory)][string[]]$StepArgs)
  Write-Host ""
  Write-Host "==> $($StepArgs -join ' ')"
  $exe = $StepArgs[0]
  $rest = if ($StepArgs.Count -gt 1) { $StepArgs[1..($StepArgs.Count - 1)] } else { @() }
  & $exe @rest
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Step failed with exit code $LASTEXITCODE: $($StepArgs -join ' ')"
    exit $LASTEXITCODE
  }
}

if (-not $SkipSubmoduleInit) {
  # Ensure the window submodule is initialized so the workspace resolves
  # wzzc-dev/window from the local checkout. Skip if already initialized to
  # avoid disrupting local in-progress edits inside the submodule.
  $windowMod = Join-Path $repoRoot "window\moon.mod"
  if (-not (Test-Path $windowMod)) {
    Write-Host ""
    Write-Host "==> Initializing window submodule..."
    & git -C $repoRoot submodule update --init window
    if ($LASTEXITCODE -ne 0) {
      Write-Error "Failed to initialize window submodule (exit code $LASTEXITCODE)."
      exit $LASTEXITCODE
    }
  }
}

# --------------------------------------------------------------------------
# Guidance consistency and manifest validation (node scripts, cross-platform)
# --------------------------------------------------------------------------
Invoke-Step @("node", "--check", "scripts/validate-api-surface.mjs")
Invoke-Step @("node", "scripts/validate-api-surface.mjs")
Invoke-Step @("node", "--check", "scripts/validate-maintenance-baseline.mjs")
Invoke-Step @("node", "scripts/validate-maintenance-baseline.mjs")
Invoke-Step @("node", "scripts/validate-renderer-provider-manifests.mjs")
Invoke-Step @("node", "scripts/validate-skia-entrypoints.mjs")
Invoke-Step @("node", "scripts/test-validate-skia-entrypoints.mjs")
Invoke-Step @("node", "scripts/test-validate-conformance-capture-manifest.mjs")
Invoke-Step @("node", "--check", "scripts/generate-grapheme-break-fixtures.mjs")
Invoke-Step @("node", "scripts/generate-grapheme-break-fixtures.mjs", "--check")
Invoke-Step @("node", "scripts/test-validate-web-runtime-handoff-manifest.mjs")
Invoke-Step @("node", "scripts/test-record-web-runtime-presentation.mjs")
Invoke-Step @("node", "scripts/test-validate-web-runtime-presentation-manifest.mjs")
Invoke-Step @("node", "--check", "scripts/smoke-check.mjs")
Invoke-Step @("node", "--check", "scripts/test-smoke-check.mjs")
Invoke-Step @("node", "scripts/test-smoke-check.mjs")
Invoke-Step @("node", "scripts/smoke-check.mjs", "--check")
Invoke-Step @("node", "--check", "scripts/smoke-gate.mjs")
Invoke-Step @("node", "--check", "scripts/test-smoke-gate.mjs")
Invoke-Step @("node", "scripts/test-smoke-gate.mjs")
Invoke-Step @("node", "scripts/smoke-gate.mjs", "--tier", "nightly", "--dry-run", "--json")

# Shell script syntax checks are skipped on native Windows (no sh required).
# Run scripts/dev-check.sh under Git Bash for those checks.

# --------------------------------------------------------------------------
# MoonBit workspace checks
# --------------------------------------------------------------------------
Invoke-Step @("moon", "check")

Invoke-Step @("moon", "test", "moui/core", "--target", "native")
Invoke-Step @("moon", "test", "moui/views", "--target", "native")
Invoke-Step @("moon", "test", "moui/render", "--target", "native")
Invoke-Step @("moon", "test", "moui/render/skia", "--target", "native")
Invoke-Step @("moon", "test", "moui/render/sun", "--target", "native")
Invoke-Step @("moon", "test", "moui/backend/host", "--target", "native")
Invoke-Step @("moon", "test", "moui_tester", "--target", "native")
Invoke-Step @("moon", "test", "moui_devtools", "--target", "native")

Invoke-Step @("moon", "test", "moui_skia", "--target", "native")

Invoke-Step @("moon", "test", "moui/render/webgpu_adapter", "--target", "wasm-gc")
Invoke-Step @("moon", "test", "moui/backend/web", "--target", "wasm-gc")

Invoke-Step @("moon", "test", "examples/showcase/app", "--target", "native")
Invoke-Step @("moon", "test", "examples/markdown_editor/app", "--target", "native")

Invoke-Step @("moon", "build", "examples/showcase/web_wasm", "--target", "wasm-gc")
Invoke-Step @("moon", "build", "examples/markdown_editor/web_wasm", "--target", "wasm-gc")
Invoke-Step @("node", "scripts/test-validate-web-runtime-handoff.mjs")
Invoke-Step @("node", "scripts/validate-web-runtime-handoff.mjs")

# --------------------------------------------------------------------------
# Optional: theme diagnostics
# --------------------------------------------------------------------------
if ($ThemeDiagnostics) {
  Invoke-Step @("moon", "test", "moui_theme/common", "--target", "native")
  Invoke-Step @("moon", "test", "moui_theme/common", "--target", "wasm-gc")
  Invoke-Step @("moon", "test", "moui_theme/material", "--target", "native")
  Invoke-Step @("moon", "test", "moui_theme/carbon", "--target", "native")
  Invoke-Step @("moon", "test", "moui_theme/primer", "--target", "native")
  Invoke-Step @("moon", "test", "moui_theme/fluent", "--target", "native")
  Invoke-Step @("moon", "test", "examples/design_systems/app", "--target", "native")
  Invoke-Step @("moon", "build", "examples/design_systems/web_wasm", "--target", "wasm-gc")
} else {
  Write-Host ""
  Write-Host "Skipping Design Systems addon diagnostics. Pass -ThemeDiagnostics to run moui_theme and Design Systems checks."
}

# --------------------------------------------------------------------------
# Optional: native WGPU renderer diagnostics
# --------------------------------------------------------------------------
if ($WgpuExperimental) {
  Invoke-Step @("moon", "test", "moui/render/wgpu", "--target", "native")
} else {
  Write-Host ""
  Write-Host "Skipping native WGPU renderer diagnostics. Pass -WgpuExperimental to run them."
}

# --------------------------------------------------------------------------
# Optional: Windows platform backend tests and example builds
# --------------------------------------------------------------------------
if ($PlatformExamplesTest -or $PlatformExamplesBuild) {
  if ($PlatformExamplesTest) {
    Invoke-Step @("moon", "test", "moui/backend/windows", "--target", "native")
    Invoke-Step @("moon", "test", "moui/backend/windows/skia", "--target", "native")
    if ($WgpuExperimental) {
      Invoke-Step @("moon", "test", "moui/backend/windows/wgpu", "--target", "native")
    }
  }
  if ($PlatformExamplesBuild) {
    Write-Host ""
    Write-Host "Including selected Windows Skia native example builds. These builds may be slow on a cold cache."
    Invoke-Step @("moon", "build", "examples/showcase/windows_skia", "--target", "native")
    Invoke-Step @("moon", "build", "examples/markdown_editor/windows_skia", "--target", "native")
    if ($WgpuExperimental) {
      Invoke-Step @("moon", "build", "examples/showcase/windows_wgpu", "--target", "native")
      Invoke-Step @("moon", "build", "examples/showcase/windows_wgpu_cosmic", "--target", "native")
      Invoke-Step @("moon", "build", "examples/markdown_editor/windows_wgpu", "--target", "native")
    }
  }
} else {
  Write-Host ""
  Write-Host "Skipping Windows platform checks. Pass -PlatformExamplesTest for backend tests or -PlatformExamplesBuild for slow example builds."
}

Write-Host ""
Write-Host "Daily development checks passed."
