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

function Get-LogField {
  param(
    [Parameter(Mandatory = $true)]
    [string] $LogPath,
    [Parameter(Mandatory = $true)]
    [string] $Field
  )

  if (!(Test-Path -LiteralPath $LogPath -PathType Leaf)) {
    return ""
  }
  $matches = Select-String -LiteralPath $LogPath -Pattern "^\s*$([regex]::Escape($Field))=(.*)$"
  if (!$matches) {
    return ""
  }
  return $matches[-1].Matches[0].Groups[1].Value.Trim()
}

$resolvedStatusFile = Resolve-RepoPath $StatusFile
$resolvedRevisionFile = Resolve-RepoPath $RevisionFile
$resolvedLogDir = Resolve-RepoPath $LogDir
$acceptanceLog = Join-Path $resolvedLogDir "$Platform-real-skia-acceptance.log"
$wrapperLog = Join-Path $resolvedLogDir "$Platform-real-skia-smoke.log"

if (!(Test-Path -LiteralPath $resolvedStatusFile -PathType Leaf)) {
  throw "Skia platform status file is missing: $resolvedStatusFile"
}

$detectedProvider = Get-LogField -LogPath $acceptanceLog -Field "skia_provider"
if ([string]::IsNullOrWhiteSpace($detectedProvider)) {
  $detectedProvider = Get-LogField -LogPath $wrapperLog -Field "skia_provider"
}
if ([string]::IsNullOrWhiteSpace($detectedProvider) -or $detectedProvider -eq "unknown") {
  $detectedProvider = "source"
}

$effectiveRequireCommit = $detectedProvider -eq "source" -and ($RequireCommit -or $Platform -eq "linux")

& (Join-Path $PSScriptRoot "verify-real-skia-artifact.ps1") `
  -Platform $Platform `
  -LogDir $resolvedLogDir `
  -RequireCommit:$effectiveRequireCommit

if (!(Test-Path -LiteralPath $acceptanceLog -PathType Leaf)) {
  throw "platform acceptance log is missing after artifact verification: $acceptanceLog"
}

if ($detectedProvider -eq "source") {
  & (Join-Path $PSScriptRoot "verify-skia-revision-pin.ps1") `
    -AcceptanceLog $acceptanceLog `
    -RevisionFile $resolvedRevisionFile
}

$status = Get-Content -LiteralPath $resolvedStatusFile -Raw | ConvertFrom-Json
if ($status.schema_version -notin @(1, 2)) {
  throw "unsupported Skia platform status schema_version: $($status.schema_version)"
}
if (!$status.platforms.PSObject.Properties.Name.Contains($Platform)) {
  throw "platform status is missing required platform: $Platform"
}

$acceptedCommit = Get-AcceptedSkiaCommit -LogPath $acceptanceLog
if (!$acceptedCommit) {
  throw "platform acceptance log is missing a full 40-character skia_commit hash: $acceptanceLog"
}
$acceptedProvider = $detectedProvider
$acceptedVersion = ""
if ($acceptedProvider -eq "jetbrains") {
  $providerLockPath = Resolve-RepoPath "skia-provider-lock.json"
  $providerLock = Get-Content -LiteralPath $providerLockPath -Raw | ConvertFrom-Json
  $jetbrains = $providerLock.providers.jetbrains
  $acceptedVersion = Get-LogField -LogPath $acceptanceLog -Field "jetbrains_tag"
  if ([string]::IsNullOrWhiteSpace($acceptedVersion) -or $acceptedVersion -eq "unknown") {
    $acceptedVersion = Get-LogField -LogPath $wrapperLog -Field "jetbrains_tag"
  }
  if ($acceptedCommit -ne $jetbrains.commit.ToLowerInvariant()) {
    throw "accepted JetBrains commit does not match provider lock"
  }
  if ($acceptedVersion -ne $jetbrains.tag) {
    throw "accepted JetBrains tag does not match provider lock"
  }
} elseif ($acceptedProvider -eq "source") {
  $acceptedVersion = (Get-Content -LiteralPath $resolvedRevisionFile | Where-Object {
      $line = $_.Trim()
      $line -ne "" -and !$line.StartsWith("#")
    } | Select-Object -First 1).Trim()
} else {
  throw "unsupported accepted provider in acceptance log: $acceptedProvider"
}
if ([string]::IsNullOrWhiteSpace($acceptedVersion)) {
  throw "accepted platform is missing accepted_version: $Platform"
}

if ([string]::IsNullOrWhiteSpace($ArtifactLabel)) {
  $ArtifactLabel = $LogDir
}

$entry = $status.platforms.$Platform
$entry.accepted = $true
$entry.state = "accepted"
$entry.accepted_artifact = $ArtifactLabel
$entry.accepted_commit = $acceptedCommit
$entry.accepted_provider = $acceptedProvider
$entry.accepted_version = $acceptedVersion
$entry.next_step = "Keep running real Skia smoke for this platform and verify each run against the accepted $acceptedProvider Skia version $acceptedVersion."

$json = $status | ConvertTo-Json -Depth 16 -Compress
Set-Content -LiteralPath $resolvedStatusFile -Value $json

& (Join-Path $PSScriptRoot "verify-platform-status.ps1") `
  -StatusFile $resolvedStatusFile `
  -RevisionFile $resolvedRevisionFile

Write-Host "Marked $Platform accepted in $resolvedStatusFile using artifact $ArtifactLabel."
