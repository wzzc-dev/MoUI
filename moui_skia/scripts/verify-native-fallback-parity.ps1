param(
  [string] $NativeDir = "native",
  [string] $PkgPath = "",
  [switch] $Help
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $repoRoot
$toolPackage = "tools/moui_skia/verify_native_fallback_parity"
$toolDir = Join-Path $workspaceRoot $toolPackage

if (!(Test-Path -LiteralPath $toolDir -PathType Container)) {
  $splitRepoToolDir = Join-Path $repoRoot $toolPackage
  if (Test-Path -LiteralPath $splitRepoToolDir -PathType Container) {
    $workspaceRoot = $repoRoot
    $toolDir = $splitRepoToolDir
  }
}

if (!(Test-Path -LiteralPath $toolDir -PathType Container)) {
  throw "MoonBit fallback parity tool is missing: $toolDir"
}

$exitCode = 0
Push-Location $workspaceRoot
try {
  $toolArgs = @("--repo-root", $repoRoot)
  if ($Help) {
    $toolArgs += "--help"
  } else {
    $toolArgs += @("--native-dir", $NativeDir)
    if (![string]::IsNullOrWhiteSpace($PkgPath)) {
      $toolArgs += @("--pkg", $PkgPath)
    }
  }
  moon build $toolPackage --target native
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
  $toolExe = Join-Path $workspaceRoot "_build/native/debug/build/wzzc-dev/moui_tools/moui_skia/verify_native_fallback_parity/verify_native_fallback_parity.exe"
  & $toolExe @toolArgs
  $exitCode = $LASTEXITCODE
} finally {
  Pop-Location
}
if ($exitCode -ne 0) {
  exit $exitCode
}
