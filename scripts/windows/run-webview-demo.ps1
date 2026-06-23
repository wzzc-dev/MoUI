<#
.SYNOPSIS
  Build and run the WebView demo on Windows with MSVC.

.DESCRIPTION
  Sources the MSVC build environment (vcvarsall, zlib), builds the
  webview_demo windows_skia target with moon, and runs it.

  The WebView2 SDK is auto-detected by the moui_webview prebuild script
  from .tools/webview2/ — no additional environment variables needed.

.PARAMETER BuildOnly
  If set, only build without running.
#>
[CmdletBinding()]
param(
  [switch]$BuildOnly
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path

. (Join-Path $scriptDir "msvc_env.ps1")

if (-not (Get-Command moon -ErrorAction SilentlyContinue)) {
  throw "MoonBit toolchain is not available in PATH. Install moon and try again."
}

Push-Location $repoRoot
try {
  Write-Host "==> repo root: $repoRoot"
  Write-Host "==> renderer route: native Skia mainline"
  Write-Host "==> WebView2 bridge: auto-detected by prebuild"

  if ($BuildOnly) {
    & moon build examples/webview_demo/windows_skia --target native
    if ($LASTEXITCODE -ne 0) {
      throw "moon build failed with exit code $LASTEXITCODE"
    }
    Write-Host "==> Build succeeded."
  } else {
    & moon run examples/webview_demo/windows_skia --target native
    if ($LASTEXITCODE -ne 0) {
      throw "moon run failed with exit code $LASTEXITCODE"
    }
  }
}
finally {
  Pop-Location
}
