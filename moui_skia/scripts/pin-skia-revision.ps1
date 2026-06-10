param(
  [string] $AcceptanceLog = "logs/linux-real-skia-smoke/linux-real-skia-acceptance.log",

  [string] $RevisionFile = "skia-revision.txt",

  [switch] $Help
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $repoRoot
$toolPackage = "tools/moui_skia/pin_skia_revision"
$toolDir = Join-Path $workspaceRoot $toolPackage

if (!(Test-Path -LiteralPath $toolDir -PathType Container)) {
  $splitRepoToolDir = Join-Path $repoRoot $toolPackage
  if (Test-Path -LiteralPath $splitRepoToolDir -PathType Container) {
    $workspaceRoot = $repoRoot
    $toolDir = $splitRepoToolDir
  }
}

if (!(Test-Path -LiteralPath $toolDir -PathType Container)) {
  throw "MoonBit Skia revision pin writer tool is missing: $toolDir"
}

$toolArgs = @("--repo-root", $repoRoot)
if ($Help) {
  $toolArgs += "--help"
} else {
  $toolArgs += $AcceptanceLog
  $toolArgs += @("--revision-file", $RevisionFile)
}

$exitCode = 0
Push-Location $workspaceRoot
try {
  moon build $toolPackage --target native
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
  $toolExe = Join-Path $workspaceRoot "_build/native/debug/build/wzzc-dev/moui_tools/moui_skia/pin_skia_revision/pin_skia_revision.exe"
  & $toolExe @toolArgs
  $exitCode = $LASTEXITCODE
} finally {
  Pop-Location
}
if ($exitCode -ne 0) {
  exit $exitCode
}
