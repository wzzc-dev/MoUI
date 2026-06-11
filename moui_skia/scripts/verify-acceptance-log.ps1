param(
  [string] $LogPath = "",

  [switch] $RequireCommit,

  [switch] $Help
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $repoRoot
$toolPackage = "tools/moui_skia/verify_acceptance_log"
$toolDir = Join-Path $workspaceRoot $toolPackage

if (!(Test-Path -LiteralPath $toolDir -PathType Container)) {
  $splitRepoToolDir = Join-Path $repoRoot $toolPackage
  if (Test-Path -LiteralPath $splitRepoToolDir -PathType Container) {
    $workspaceRoot = $repoRoot
    $toolDir = $splitRepoToolDir
  }
}

if (!(Test-Path -LiteralPath $toolDir -PathType Container)) {
  throw "MoonBit acceptance log tool is missing: $toolDir"
}

$toolArgs = @("--repo-root", $repoRoot)
if ($Help) {
  $toolArgs += "--help"
} elseif (![string]::IsNullOrWhiteSpace($LogPath)) {
  if ([System.IO.Path]::IsPathRooted($LogPath)) {
    $resolvedLogPath = $LogPath
  } else {
    $resolvedLogPath = Join-Path (Get-Location) $LogPath
  }
  $toolArgs += $resolvedLogPath
  if ($RequireCommit) {
    $toolArgs += "--require-commit"
  }
} elseif ($RequireCommit) {
  $toolArgs += "--require-commit"
}

$exitCode = 0
$errorMessage = ""
Push-Location $workspaceRoot
try {
  moon build $toolPackage --target native
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
  $toolExe = Join-Path $workspaceRoot "_build/native/debug/build/wzzc-dev/moui_tools/moui_skia/verify_acceptance_log/verify_acceptance_log.exe"
  $toolOutput = & $toolExe @toolArgs 2>&1
  $exitCode = $LASTEXITCODE
  $toolOutput | ForEach-Object { Write-Host $_ }
  if ($exitCode -ne 0) {
    $errorMessage = ($toolOutput -join [Environment]::NewLine)
  } elseif (!$Help) {
    $verified = $false
    foreach ($line in @($toolOutput)) {
      if ("$line".StartsWith("Verified real Skia acceptance log in ")) {
        $verified = $true
        break
      }
    }
    if (!$verified) {
      $exitCode = 1
      $errorMessage = ($toolOutput -join [Environment]::NewLine)
      if (!$errorMessage) {
        $errorMessage = "acceptance log verifier did not print a verification marker"
      }
    }
  }
} finally {
  Pop-Location
}
if ($exitCode -ne 0) {
  throw $errorMessage
}
