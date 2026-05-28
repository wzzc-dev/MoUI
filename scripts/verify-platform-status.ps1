param(
  [string] $StatusFile = "skia-platform-status.json",
  [string] $RevisionFile = "skia-revision.txt"
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

$resolvedStatusFile = Resolve-RepoPath $StatusFile
$resolvedRevisionFile = Resolve-RepoPath $RevisionFile

if (!(Test-Path -LiteralPath $resolvedStatusFile -PathType Leaf)) {
  throw "Skia platform status file is missing: $resolvedStatusFile"
}

if (!(Test-Path -LiteralPath $resolvedRevisionFile -PathType Leaf)) {
  throw "Skia revision file is missing: $resolvedRevisionFile"
}

$status = Get-Content -LiteralPath $resolvedStatusFile -Raw | ConvertFrom-Json
$revision = (Get-Content -LiteralPath $resolvedRevisionFile | Where-Object {
    $line = $_.Trim()
    $line -ne "" -and !$line.StartsWith("#")
  } | Select-Object -First 1).Trim()

if ($status.schema_version -ne 1) {
  throw "unsupported Skia platform status schema_version: $($status.schema_version)"
}

if ($status.revision_file -ne (Split-Path -Leaf $resolvedRevisionFile)) {
  throw "status revision_file does not match requested revision file: status=$($status.revision_file) revision=$(Split-Path -Leaf $resolvedRevisionFile)"
}

if (!$revision) {
  throw "Skia revision file does not contain a revision"
}

$platforms = @("linux", "macos", "windows")
foreach ($platform in $platforms) {
  if (!$status.platforms.PSObject.Properties.Name.Contains($platform)) {
    throw "platform status is missing required platform: $platform"
  }
}

$acceptedPlatforms = @()
foreach ($platform in $platforms) {
  $entry = $status.platforms.$platform
  if ($null -eq $entry.accepted) {
    throw "platform status is missing accepted flag: $platform"
  }
  if ([string]::IsNullOrWhiteSpace($entry.state)) {
    throw "platform status is missing state: $platform"
  }
  if ($entry.required_artifact_logs.Count -lt 3) {
    throw "platform status does not list enough artifact logs: $platform"
  }
  if ([string]::IsNullOrWhiteSpace($entry.required_verifier)) {
    throw "platform status is missing required verifier: $platform"
  }
  if ([string]::IsNullOrWhiteSpace($entry.next_step)) {
    throw "platform status is missing next step: $platform"
  }

  if ($entry.accepted) {
    $acceptedPlatforms += $platform
    if ([string]::IsNullOrWhiteSpace($entry.accepted_artifact)) {
      throw "accepted platform is missing accepted_artifact: $platform"
    }
    if ($entry.accepted_commit -notmatch '^[0-9a-fA-F]{40}$') {
      throw "accepted platform is missing accepted_commit: $platform"
    }
  } elseif ($null -ne $entry.accepted_artifact) {
    throw "unaccepted platform must not record accepted_artifact: $platform"
  } elseif ($null -ne $entry.accepted_commit) {
    throw "unaccepted platform must not record accepted_commit: $platform"
  }
}

if ($revision -eq "main" -and $acceptedPlatforms.Count -gt 0) {
  throw "platforms cannot be accepted while skia-revision.txt is still main: $($acceptedPlatforms -join ', ')"
}

if ($revision -ne "main" -and $revision -notmatch '^[0-9a-fA-F]{40}$') {
  throw "Skia revision must be main or a full 40-character commit: $revision"
}

foreach ($platform in $acceptedPlatforms) {
  $acceptedCommit = $status.platforms.$platform.accepted_commit.ToLowerInvariant()
  if ($acceptedCommit -ne $revision.ToLowerInvariant()) {
    throw "accepted platform commit does not match pinned revision: platform=$platform accepted_commit=$acceptedCommit revision=$revision"
  }
}

if (!$status.platforms.linux.first_acceptance_platform) {
  throw "Linux must remain the first acceptance platform until the initial source-built pin is established"
}

if (!$status.platforms.linux.source_build) {
  throw "Linux status must keep source_build=true for first acceptance"
}

if ($status.platforms.windows.source_build) {
  throw "Windows status must not claim source_build=true until a repeatable Windows Skia build path exists"
}

Write-Host "Verified Skia platform status in $resolvedStatusFile with revision $revision."
