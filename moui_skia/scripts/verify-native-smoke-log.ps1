param(
  [Parameter(Position = 0)]
  [string] $LogPath = "",

  [Parameter(Position = 1)]
  [string] $Marker = "",

  [switch] $Help
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $repoRoot
$toolPackage = "tools/moui_skia/verify_native_smoke_log"
$toolDir = Join-Path $workspaceRoot $toolPackage

if (!(Test-Path -LiteralPath $toolDir -PathType Container)) {
  $splitRepoToolDir = Join-Path $repoRoot $toolPackage
  if (Test-Path -LiteralPath $splitRepoToolDir -PathType Container) {
    $workspaceRoot = $repoRoot
    $toolDir = $splitRepoToolDir
  }
}

if (!(Test-Path -LiteralPath $toolDir -PathType Container)) {
  throw "MoonBit native smoke log verifier is missing: $toolDir"
}

$exitCode = 0
$errorMessage = ""
Push-Location $workspaceRoot
try {
  $toolArgs = @("--repo-root", $repoRoot)
  if ($Help) {
    $toolArgs += "--help"
  } else {
    if (!$LogPath) {
      throw "missing LOG_PATH"
    }
    $toolArgs += $LogPath
    if ($Marker) {
      $toolArgs += $Marker
    }
  }
  moon build $toolPackage --target native
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
  $toolExe = Join-Path $workspaceRoot "_build/native/debug/build/wzzc-dev/moui_tools/moui_skia/verify_native_smoke_log/verify_native_smoke_log.exe"
  $toolOutput = & $toolExe @toolArgs 2>&1
  $exitCode = $LASTEXITCODE
  $toolOutput | ForEach-Object { Write-Host $_ }
  if ($exitCode -ne 0) {
    $errorMessage = ($toolOutput -join [Environment]::NewLine)
  } elseif (!$Help) {
    $verified = $false
    foreach ($line in @($toolOutput)) {
      if ("$line".StartsWith("Verified native smoke stage markers and success marker in ")) {
        $verified = $true
        break
      }
    }
    if (!$verified) {
      $exitCode = 1
      $errorMessage = ($toolOutput -join [Environment]::NewLine)
      if (!$errorMessage) {
        $errorMessage = "native smoke log verifier did not print a verification marker"
      }
    }
  }
} finally {
  Pop-Location
}
if ($exitCode -ne 0) {
  throw $errorMessage
}
