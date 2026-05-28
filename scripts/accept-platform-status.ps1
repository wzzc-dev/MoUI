param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("linux", "macos", "windows")]
  [string] $Platform,

  [Parameter(Mandatory = $true)]
  [string] $LogDir,

  [string] $StatusFile = "skia-platform-status.json",

  [string] $RevisionFile = "skia-revision.txt",

  [string] $ArtifactLabel = "",

  [switch] $RequireCommit
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

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

function Get-AcceptedSkiaCommit {
  param(
    [Parameter(Mandatory = $true)]
    [string] $LogPath
  )

  $matches = Select-String -LiteralPath $LogPath -Pattern '^\s*skia_commit=([0-9a-fA-F]{40})\s*$'
  if (!$matches) {
    return $null
  }
  return $matches[-1].Matches[0].Groups[1].Value.ToLowerInvariant()
}

$resolvedStatusFile = Resolve-RepoPath $StatusFile
$resolvedRevisionFile = Resolve-RepoPath $RevisionFile
$resolvedLogDir = Resolve-RepoPath $LogDir
$acceptanceLog = Join-Path $resolvedLogDir "$Platform-real-skia-acceptance.log"

if (!(Test-Path -LiteralPath $resolvedStatusFile -PathType Leaf)) {
  throw "Skia platform status file is missing: $resolvedStatusFile"
}

$effectiveRequireCommit = $RequireCommit -or $Platform -eq "linux"

& (Join-Path $PSScriptRoot "verify-real-skia-artifact.ps1") `
  -Platform $Platform `
  -LogDir $resolvedLogDir `
  -RequireCommit:$effectiveRequireCommit

if (!(Test-Path -LiteralPath $acceptanceLog -PathType Leaf)) {
  throw "platform acceptance log is missing after artifact verification: $acceptanceLog"
}

& (Join-Path $PSScriptRoot "verify-skia-revision-pin.ps1") `
  -AcceptanceLog $acceptanceLog `
  -RevisionFile $resolvedRevisionFile

$status = Get-Content -LiteralPath $resolvedStatusFile -Raw | ConvertFrom-Json
if ($status.schema_version -ne 1) {
  throw "unsupported Skia platform status schema_version: $($status.schema_version)"
}
if (!$status.platforms.PSObject.Properties.Name.Contains($Platform)) {
  throw "platform status is missing required platform: $Platform"
}

$acceptedCommit = Get-AcceptedSkiaCommit -LogPath $acceptanceLog
if (!$acceptedCommit) {
  throw "platform acceptance log is missing a full 40-character skia_commit hash: $acceptanceLog"
}

if ([string]::IsNullOrWhiteSpace($ArtifactLabel)) {
  $ArtifactLabel = $LogDir
}

$entry = $status.platforms.$Platform
$entry.accepted = $true
$entry.state = "accepted"
$entry.accepted_artifact = $ArtifactLabel
$entry.accepted_commit = $acceptedCommit
$entry.next_step = "Keep running real Skia smoke for this platform and verify each run against the pinned Skia revision $acceptedCommit."

$json = $status | ConvertTo-Json -Depth 16 -Compress
Set-Content -LiteralPath $resolvedStatusFile -Value $json

& (Join-Path $PSScriptRoot "verify-platform-status.ps1") `
  -StatusFile $resolvedStatusFile `
  -RevisionFile $resolvedRevisionFile

Write-Host "Marked $Platform accepted in $resolvedStatusFile using artifact $ArtifactLabel."
