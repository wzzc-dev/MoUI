param(
  [string] $StatusFile = "skia-platform-status.json",
  [string] $RevisionFile = "skia-revision.txt",
  [string] $ProviderLock = "skia-provider-lock.json"
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
$resolvedProviderLock = Resolve-RepoPath $ProviderLock

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

$providerLockData = $null
if (Test-Path -LiteralPath $resolvedProviderLock -PathType Leaf) {
  $providerLockData = Get-Content -LiteralPath $resolvedProviderLock -Raw | ConvertFrom-Json
}
$jetbrainsCommit = ""
$jetbrainsTag = ""
if ($providerLockData -and $providerLockData.providers.jetbrains) {
  $jetbrainsCommit = $providerLockData.providers.jetbrains.commit.ToLowerInvariant()
  $jetbrainsTag = $providerLockData.providers.jetbrains.tag
}

if ($status.schema_version -notin @(1, 2, 3)) {
  throw "unsupported Skia platform status schema_version: $($status.schema_version)"
}

if ($status.schema_version -ge 3) {
  $capabilities = @($status.native_smoke_capabilities)
  if ($capabilities.Count -eq 0) {
    throw "schema v3 platform status is missing native_smoke_capabilities list"
  }

  $requiredCapabilityIds = @(
    "surface.descriptor",
    "canvas.state",
    "shader.draw",
    "filter.layer",
    "path.geometry",
    "surface.readback",
    "surface.bounded-readback",
    "surface.bounded-snapshot",
    "image.encode-png",
    "image.decode",
    "codec.metadata",
    "bitmap.decode-readback",
    "text.font-spacing",
    "text.measure",
    "text.glyph-count",
    "text.glyph-id",
    "text.glyph-width",
    "text.glyph-position",
    "text.glyph-x-position",
    "text.glyph-bounds",
    "text.bounds",
    "fontmgr.family-count",
    "fontmgr.family-name"
  )
  $seenIds = @{}
  $seenMarkers = @{}
  $seenAreas = @{}
  foreach ($capability in $capabilities) {
    $capabilityId = "$($capability.id)".Trim()
    $area = "$($capability.area)".Trim()
    $marker = "$($capability.marker)".Trim()
    if ([string]::IsNullOrWhiteSpace($capabilityId)) {
      throw "native smoke capability is missing id"
    }
    if ([string]::IsNullOrWhiteSpace($area)) {
      throw "native smoke capability is missing area: $capabilityId"
    }
    if ([string]::IsNullOrWhiteSpace($marker)) {
      throw "native smoke capability is missing marker: $capabilityId"
    }
    if ($seenIds.ContainsKey($capabilityId)) {
      throw "duplicate native smoke capability id: $capabilityId"
    }
    if ($seenMarkers.ContainsKey($marker)) {
      throw "duplicate native smoke capability marker: $marker"
    }
    $seenIds[$capabilityId] = $true
    $seenMarkers[$marker] = $true
    $seenAreas[$area] = $true
  }
  $missingIds = @($requiredCapabilityIds | Where-Object { !$seenIds.ContainsKey($_) })
  if ($missingIds.Count -gt 0) {
    throw "native smoke capability coverage is missing ids: $($missingIds -join ', ')"
  }
  $requiredAreas = @("Surface", "Canvas", "Shader", "Filter", "Path", "Image", "Text", "FontMgr")
  $missingAreas = @($requiredAreas | Where-Object { !$seenAreas.ContainsKey($_) })
  if ($missingAreas.Count -gt 0) {
    throw "native smoke capability coverage is missing areas: $($missingAreas -join ', ')"
  }
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
    $acceptedProvider = if ($status.schema_version -ge 2) { $entry.accepted_provider } else { "source" }
    $acceptedVersion = if ($status.schema_version -ge 2) { $entry.accepted_version } else { $revision }
    if ($acceptedProvider -notin @("source", "jetbrains")) {
      throw "accepted platform has unsupported accepted_provider: $platform"
    }
    if ([string]::IsNullOrWhiteSpace($acceptedVersion)) {
      throw "accepted platform is missing accepted_version: $platform"
    }
    Add-Member -InputObject $entry -NotePropertyName __accepted_provider -NotePropertyValue $acceptedProvider -Force
    Add-Member -InputObject $entry -NotePropertyName __accepted_version -NotePropertyValue $acceptedVersion -Force
  } elseif ($null -ne $entry.accepted_artifact) {
    throw "unaccepted platform must not record accepted_artifact: $platform"
  } elseif ($null -ne $entry.accepted_commit) {
    throw "unaccepted platform must not record accepted_commit: $platform"
  }
  if (!$entry.accepted -and $status.schema_version -ge 2 -and $null -ne $entry.accepted_provider) {
    throw "unaccepted platform must not record accepted_provider: $platform"
  }
  if (!$entry.accepted -and $status.schema_version -ge 2 -and $null -ne $entry.accepted_version) {
    throw "unaccepted platform must not record accepted_version: $platform"
  }
}

$sourceAcceptedPlatforms = @($acceptedPlatforms | Where-Object { $status.platforms.$_.__accepted_provider -eq "source" })
if ($revision -eq "main" -and $sourceAcceptedPlatforms.Count -gt 0) {
  throw "source platforms cannot be accepted while skia-revision.txt is still main: $($sourceAcceptedPlatforms -join ', ')"
}

if ($revision -ne "main" -and $revision -notmatch '^[0-9a-fA-F]{40}$') {
  throw "Skia revision must be main or a full 40-character commit: $revision"
}

foreach ($platform in $acceptedPlatforms) {
  $acceptedCommit = $status.platforms.$platform.accepted_commit.ToLowerInvariant()
  $acceptedProvider = $status.platforms.$platform.__accepted_provider
  $acceptedVersion = $status.platforms.$platform.__accepted_version
  if ($acceptedProvider -eq "source" -and $acceptedCommit -ne $revision.ToLowerInvariant()) {
    throw "accepted platform commit does not match pinned revision: platform=$platform accepted_commit=$acceptedCommit revision=$revision"
  }
  if ($acceptedProvider -eq "source" -and $acceptedVersion -ne $revision) {
    throw "accepted source platform version does not match pinned revision: platform=$platform accepted_version=$acceptedVersion revision=$revision"
  }
  if ($acceptedProvider -eq "jetbrains") {
    if ([string]::IsNullOrWhiteSpace($jetbrainsCommit) -or [string]::IsNullOrWhiteSpace($jetbrainsTag)) {
      throw "JetBrains provider lock is missing tag or commit"
    }
    if ($acceptedCommit -ne $jetbrainsCommit) {
      throw "accepted JetBrains platform commit does not match provider lock: platform=$platform accepted_commit=$acceptedCommit jetbrains_commit=$jetbrainsCommit"
    }
    if ($acceptedVersion -ne $jetbrainsTag) {
      throw "accepted JetBrains platform version does not match provider lock tag: platform=$platform accepted_version=$acceptedVersion jetbrains_tag=$jetbrainsTag"
    }
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
