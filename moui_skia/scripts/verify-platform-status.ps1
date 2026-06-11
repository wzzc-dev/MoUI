param(
  [string] $StatusFile = "skia-platform-status.json",
  [string] $RevisionFile = "skia-revision.txt",
  [string] $ProviderLock = "skia-provider-lock.json",
  [string] $StatusDoc = "SKIA_PLATFORM_STATUS.md",
  [switch] $Help
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $repoRoot
$toolPackage = "tools/moui_skia/verify_platform_status"
$toolDir = Join-Path $workspaceRoot $toolPackage

if (!(Test-Path -LiteralPath $toolDir -PathType Container)) {
  $splitRepoToolDir = Join-Path $repoRoot $toolPackage
  if (Test-Path -LiteralPath $splitRepoToolDir -PathType Container) {
    $workspaceRoot = $repoRoot
    $toolDir = $splitRepoToolDir
  }
}

if (!(Test-Path -LiteralPath $toolDir -PathType Container)) {
  throw "MoonBit platform status tool is missing: $toolDir"
}

$toolArgs = @("--repo-root", $repoRoot)
if ($Help) {
  $toolArgs += "--help"
} else {
  $toolArgs += @(
    "--status-file", $StatusFile,
    "--revision-file", $RevisionFile,
    "--provider-lock", $ProviderLock
  )
  if ($PSBoundParameters.ContainsKey("StatusDoc")) {
    $toolArgs += @("--status-doc", $StatusDoc)
  }
}

$exitCode = 0
Push-Location $workspaceRoot
try {
  moon build $toolPackage --target native
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
  $toolExe = Join-Path $workspaceRoot "_build/native/debug/build/wzzc-dev/moui_tools/moui_skia/verify_platform_status/verify_platform_status.exe"
  & $toolExe @toolArgs
  $exitCode = $LASTEXITCODE
} finally {
  Pop-Location
}
if ($exitCode -ne 0) {
  exit $exitCode
}
