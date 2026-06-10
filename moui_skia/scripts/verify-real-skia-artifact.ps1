param(
  [ValidateSet("linux", "macos", "windows")]
  [string] $Platform = "",

  [string] $LogDir = "",

  [switch] $RequireCommit,

  [switch] $Help
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $repoRoot
$toolPackage = "tools/moui_skia/verify_real_skia_artifact"
$toolDir = Join-Path $workspaceRoot $toolPackage

if (!(Test-Path -LiteralPath $toolDir -PathType Container)) {
  $splitRepoToolDir = Join-Path $repoRoot $toolPackage
  if (Test-Path -LiteralPath $splitRepoToolDir -PathType Container) {
    $workspaceRoot = $repoRoot
    $toolDir = $splitRepoToolDir
  }
}

if (!(Test-Path -LiteralPath $toolDir -PathType Container)) {
  throw "MoonBit real Skia artifact verifier is missing: $toolDir"
}

$exitCode = 0
Push-Location $workspaceRoot
try {
  $toolArgs = @("--repo-root", $repoRoot)
  if ($Help) {
    $toolArgs += "--help"
  } else {
    if (!$Platform) {
      throw "--platform is required"
    }
    if (!$LogDir) {
      throw "--log-dir is required"
    }
    $toolArgs += @("--platform", $Platform, "--log-dir", $LogDir)
    if ($RequireCommit) {
      $toolArgs += "--require-commit"
    }
  }
  moon build $toolPackage --target native
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
  $toolExe = Join-Path $workspaceRoot "_build/native/debug/build/wzzc-dev/moui_tools/moui_skia/verify_real_skia_artifact/verify_real_skia_artifact.exe"
  & $toolExe @toolArgs
  $exitCode = $LASTEXITCODE
} finally {
  Pop-Location
}
if ($exitCode -ne 0) {
  exit $exitCode
}
