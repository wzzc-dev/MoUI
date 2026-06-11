param(
  [string] $Manifest = "native/ownership.json",
  [string] $Header = "",
  [string] $Source = "",
  [string] $Handles = "",
  [string] $Types = "",
  [switch] $Help
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $repoRoot
$toolPackage = "tools/moui_skia/verify_native_ownership"
$toolDir = Join-Path $workspaceRoot $toolPackage

if (!(Test-Path -LiteralPath $toolDir -PathType Container)) {
  $splitRepoToolDir = Join-Path $repoRoot $toolPackage
  if (Test-Path -LiteralPath $splitRepoToolDir -PathType Container) {
    $workspaceRoot = $repoRoot
    $toolDir = $splitRepoToolDir
  }
}

if (!(Test-Path -LiteralPath $toolDir -PathType Container)) {
  throw "MoonBit native ownership tool is missing: $toolDir"
}

$exitCode = 0
Push-Location $workspaceRoot
try {
  $toolArgs = @("--repo-root", $repoRoot)
  if ($Help) {
    $toolArgs += "--help"
  } else {
    $toolArgs += @("--manifest", $Manifest)
    if ($Header) {
      $toolArgs += @("--header", $Header)
    }
    if ($Source) {
      $toolArgs += @("--source", $Source)
    }
    if ($Handles) {
      $toolArgs += @("--handles", $Handles)
    }
    if ($Types) {
      $toolArgs += @("--types", $Types)
    }
  }
  moon build $toolPackage --target native
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
  $toolExe = Join-Path $workspaceRoot "_build/native/debug/build/wzzc-dev/moui_tools/moui_skia/verify_native_ownership/verify_native_ownership.exe"
  & $toolExe @toolArgs
  $exitCode = $LASTEXITCODE
} finally {
  Pop-Location
}
if ($exitCode -ne 0) {
  exit $exitCode
}
