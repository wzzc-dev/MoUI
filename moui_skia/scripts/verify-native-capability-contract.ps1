param(
  [string] $Manifest = "native/capabilities.json",
  [string] $NativeDir = "native",
  [string] $PkgPath = "native/moon.pkg",
  [string] $Ownership = "native/ownership.json",
  [string] $StatusFile = "skia-platform-status.json",
  [string] $SmokeSource = "scripts/native_smoke",
  [switch] $Help
)

$ErrorActionPreference = "Stop"

function Show-Usage {
  Write-Host @"
Usage: scripts/verify-native-capability-contract.ps1 [options]

Checks native/capabilities.json against native MoonBit implementation files,
fallback twins, ownership metadata, and smoke capability markers.

Options:
  -Manifest PATH       Native capability manifest. Defaults to native/capabilities.json.
  -NativeDir PATH      Native package directory. Defaults to native.
  -PkgPath PATH        Native moon.pkg path. Defaults to native/moon.pkg.
  -Ownership PATH      Native ownership manifest. Defaults to native/ownership.json.
  -StatusFile PATH     Platform status JSON. Defaults to skia-platform-status.json.
  -SmokeSource PATH    Native smoke source file or directory. Defaults to scripts/native_smoke.
  -Help                Show this help.
"@
}

if ($Help) {
  Show-Usage
  exit 0
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $repoRoot
$toolPackage = "tools/moui_skia/verify_native_capability_contract"
$toolDir = Join-Path $workspaceRoot $toolPackage

if (!(Test-Path -LiteralPath $toolDir -PathType Container)) {
  $splitRepoToolDir = Join-Path $repoRoot $toolPackage
  if (Test-Path -LiteralPath $splitRepoToolDir -PathType Container) {
    $workspaceRoot = $repoRoot
    $toolDir = $splitRepoToolDir
  }
}

if (!(Test-Path -LiteralPath $toolDir -PathType Container)) {
  throw "MoonBit native capability contract tool is missing: $toolDir"
}

function Resolve-RepoPath {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path
  )

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return $Path
  }
  return Join-Path $repoRoot $Path
}

$resolvedManifest = Resolve-RepoPath $Manifest
$resolvedNativeDir = Resolve-RepoPath $NativeDir
$resolvedPkgPath = Resolve-RepoPath $PkgPath
$resolvedOwnership = Resolve-RepoPath $Ownership
$resolvedStatusFile = Resolve-RepoPath $StatusFile
$resolvedSmokeSource = Resolve-RepoPath $SmokeSource

& (Join-Path $repoRoot "scripts/verify-native-fallback-parity.ps1") -NativeDir $resolvedNativeDir -PkgPath $resolvedPkgPath
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
& (Join-Path $repoRoot "scripts/verify-native-ownership.ps1") -Manifest $resolvedOwnership
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
& (Join-Path $repoRoot "scripts/verify-native-ffi-borrows.ps1") -NativeDir $resolvedNativeDir
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
& (Join-Path $repoRoot "scripts/verify-native-smoke-capabilities.ps1") -StatusFile $resolvedStatusFile -SmokeSource $resolvedSmokeSource
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$exitCode = 0
Push-Location $workspaceRoot
try {
  moon build $toolPackage --target native
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
  $toolExe = Join-Path $workspaceRoot "_build/native/debug/build/wzzc-dev/moui_tools/moui_skia/verify_native_capability_contract/verify_native_capability_contract.exe"
  & $toolExe `
    --repo-root $repoRoot `
    --manifest $resolvedManifest `
    --native-dir $resolvedNativeDir `
    --pkg $resolvedPkgPath `
    --ownership $resolvedOwnership `
    --status-file $resolvedStatusFile `
    --smoke-source $resolvedSmokeSource
  $exitCode = $LASTEXITCODE
} finally {
  Pop-Location
}
if ($exitCode -ne 0) {
  exit $exitCode
}
