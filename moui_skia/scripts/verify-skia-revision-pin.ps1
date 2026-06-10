param(
  [string] $AcceptanceLog = "",

  [string] $RevisionFile = "skia-revision.txt",

  [switch] $SkipIfUnpinned,

  [switch] $Help
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $repoRoot
$toolPackage = "tools/moui_skia/verify_skia_revision_pin"
$toolDir = Join-Path $workspaceRoot $toolPackage

if (!(Test-Path -LiteralPath $toolDir -PathType Container)) {
  $splitRepoToolDir = Join-Path $repoRoot $toolPackage
  if (Test-Path -LiteralPath $splitRepoToolDir -PathType Container) {
    $workspaceRoot = $repoRoot
    $toolDir = $splitRepoToolDir
  }
}

if (!(Test-Path -LiteralPath $toolDir -PathType Container)) {
  throw "MoonBit Skia revision pin tool is missing: $toolDir"
}

$toolArgs = @("--repo-root", $repoRoot)
if ($Help) {
  $toolArgs += "--help"
} else {
  if ([string]::IsNullOrWhiteSpace($AcceptanceLog)) {
    throw "missing AcceptanceLog"
  }
  $toolArgs += $AcceptanceLog
  $toolArgs += @("--revision-file", $RevisionFile)
  if ($SkipIfUnpinned) {
    $toolArgs += "--skip-if-unpinned"
  }
}

$exitCode = 0
Push-Location $workspaceRoot
try {
  moon build $toolPackage --target native
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
  $toolExe = Join-Path $workspaceRoot "_build/native/debug/build/wzzc-dev/moui_tools/moui_skia/verify_skia_revision_pin/verify_skia_revision_pin.exe"
  & $toolExe @toolArgs
  $exitCode = $LASTEXITCODE
} finally {
  Pop-Location
}
if ($exitCode -ne 0) {
  exit $exitCode
}
