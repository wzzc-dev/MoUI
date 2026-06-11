param(
  [string] $LogDir = "logs",

  [string] $RevisionFile = "skia-revision.txt",

  [switch] $AcceptPlatformStatus,

  [string] $StatusFile = "skia-platform-status.json",

  [string] $ArtifactLabel = "linux-real-skia-smoke-log"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

function Invoke-CheckedScript {
  param(
    [Parameter(Mandatory = $true)]
    [scriptblock] $Command
  )

  $global:LASTEXITCODE = 0
  & $Command
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    exit $exitCode
  }
}

if ([System.IO.Path]::IsPathRooted($LogDir)) {
  $resolvedLogDir = $LogDir
} else {
  $resolvedLogDir = Join-Path $repoRoot $LogDir
}
if ([System.IO.Path]::IsPathRooted($RevisionFile)) {
  $resolvedRevisionFile = $RevisionFile
} else {
  $resolvedRevisionFile = Join-Path $repoRoot $RevisionFile
}
if ([System.IO.Path]::IsPathRooted($StatusFile)) {
  $resolvedStatusFile = $StatusFile
} else {
  $resolvedStatusFile = Join-Path $repoRoot $StatusFile
}

$acceptanceLog = Join-Path $resolvedLogDir "linux-real-skia-acceptance.log"

Invoke-CheckedScript {
  & (Join-Path $PSScriptRoot "verify-real-skia-artifact.ps1") `
    -Platform linux `
    -LogDir $resolvedLogDir `
    -RequireCommit
}

Invoke-CheckedScript {
  & (Join-Path $PSScriptRoot "pin-skia-revision.ps1") `
    -AcceptanceLog $acceptanceLog `
    -RevisionFile $resolvedRevisionFile
}

Invoke-CheckedScript {
  & (Join-Path $PSScriptRoot "verify-skia-revision-pin.ps1") `
    -AcceptanceLog $acceptanceLog `
    -RevisionFile $resolvedRevisionFile
}

if ($AcceptPlatformStatus) {
  Invoke-CheckedScript {
    & (Join-Path $PSScriptRoot "accept-platform-status.ps1") `
      -Platform linux `
      -LogDir $resolvedLogDir `
      -StatusFile $resolvedStatusFile `
      -RevisionFile $resolvedRevisionFile `
      -ArtifactLabel $ArtifactLabel
  }

  Write-Host "Linux source-built Skia artifact passed, $resolvedRevisionFile is pinned, and Linux is marked accepted."
} else {
  Write-Host "Linux source-built Skia artifact passed and $resolvedRevisionFile is pinned."
}
