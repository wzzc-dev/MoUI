param(
  [string] $StatusFile = "skia-platform-status.json",
  [string] $SmokeSource = "scripts/native_smoke",
  [string] $UnixLogVerifier = "scripts/verify-native-smoke-log.sh",
  [string] $PowershellLogVerifier = "scripts/verify-native-smoke-log.ps1",
  [switch] $Help
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $repoRoot
$toolPackage = "tools/moui_skia/verify_native_smoke_capabilities"
$toolDir = Join-Path $workspaceRoot $toolPackage

if (!(Test-Path -LiteralPath $toolDir -PathType Container)) {
  $splitRepoToolDir = Join-Path $repoRoot $toolPackage
  if (Test-Path -LiteralPath $splitRepoToolDir -PathType Container) {
    $workspaceRoot = $repoRoot
    $toolDir = $splitRepoToolDir
  }
}

if (!(Test-Path -LiteralPath $toolDir -PathType Container)) {
  throw "MoonBit native smoke capability tool is missing: $toolDir"
}

$exitCode = 0
Push-Location $workspaceRoot
try {
  $logVerifierSource = Join-Path $workspaceRoot "tools/moui_skia/native_smoke_log_contract"
  $toolArgs = @("--repo-root", $repoRoot, "--log-verifier-source", $logVerifierSource)
  if ($Help) {
    $toolArgs += "--help"
  } else {
    $toolArgs += @(
      "--status-file", $StatusFile,
      "--smoke-source", $SmokeSource,
      "--unix-log-verifier", $UnixLogVerifier,
      "--powershell-log-verifier", $PowershellLogVerifier
    )
  }
  moon build $toolPackage --target native
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
  $toolExe = Join-Path $workspaceRoot "_build/native/debug/build/wzzc-dev/moui_tools/moui_skia/verify_native_smoke_capabilities/verify_native_smoke_capabilities.exe"
  & $toolExe @toolArgs
  $exitCode = $LASTEXITCODE
} finally {
  Pop-Location
}
if ($exitCode -ne 0) {
  exit $exitCode
}
