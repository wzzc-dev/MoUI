param(
  [string] $Manifest = "native/capabilities.json",
  [string] $NativeDir = "native",
  [string] $PkgPath = "native/moon.pkg",
  [string] $Ownership = "native/ownership.json",
  [string] $StatusFile = "skia-platform-status.json",
  [string] $SmokeSource = "scripts/native_smoke/main.mbt"
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

function Get-TargetEntries {
  param(
    [Parameter(Mandatory = $true)]
    [string] $PkgText
  )

  $entries = @{}
  foreach ($match in [regex]::Matches($PkgText, '"([^"]+\.mbt)"\s*:\s*\[([^\]]*)\]', [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
    $fileName = $match.Groups[1].Value
    if ($entries.ContainsKey($fileName)) {
      throw "duplicate target entry in native moon.pkg: $fileName"
    }
    $targets = @()
    foreach ($targetMatch in [regex]::Matches($match.Groups[2].Value, '"([^"]+)"')) {
      $targets += $targetMatch.Groups[1].Value
    }
    $entries[$fileName] = $targets
  }
  return $entries
}

function Get-PublicFunctions {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Text
  )

  $names = @{}
  $pattern = '\bpub(?:\([^)]*\))?\s+(?:extern\s+"[Cc]"\s+)?fn\s+((?:[A-Za-z_][A-Za-z0-9_]*::)?[A-Za-z_][A-Za-z0-9_]*)\s*\('
  foreach ($match in [regex]::Matches($Text, $pattern)) {
    $names[$match.Groups[1].Value] = $true
  }
  return $names
}

function Assert-TargetList {
  param(
    [Parameter(Mandatory = $true)]
    [hashtable] $Entries,
    [Parameter(Mandatory = $true)]
    [string] $FileName,
    [Parameter(Mandatory = $true)]
    [string[]] $Expected,
    [Parameter(Mandatory = $true)]
    [string] $CapabilityId
  )

  if (!$Entries.ContainsKey($FileName)) {
    throw "native capability is missing moon.pkg target mapping: ${CapabilityId}: $FileName"
  }
  $actual = @($Entries[$FileName])
  if ($actual.Count -ne $Expected.Count) {
    throw "native capability has wrong targets in moon.pkg: ${CapabilityId}: $FileName"
  }
  for ($index = 0; $index -lt $Expected.Count; $index += 1) {
    if ($actual[$index] -ne $Expected[$index]) {
      throw "native capability has wrong targets in moon.pkg: ${CapabilityId}: $FileName"
    }
  }
}

& (Join-Path $repoRoot "scripts/verify-native-fallback-parity.ps1") -NativeDir $NativeDir -PkgPath $PkgPath
& (Join-Path $repoRoot "scripts/verify-native-ownership.ps1") -Manifest $Ownership
& (Join-Path $repoRoot "scripts/verify-native-ffi-borrows.ps1") -NativeDir $NativeDir
& (Join-Path $repoRoot "scripts/verify-native-smoke-capabilities.ps1") -StatusFile $StatusFile -SmokeSource $SmokeSource

$resolvedManifest = Resolve-RepoPath $Manifest
$resolvedNativeDir = Resolve-RepoPath $NativeDir
$resolvedPkgPath = Resolve-RepoPath $PkgPath
$resolvedOwnership = Resolve-RepoPath $Ownership
$resolvedStatusFile = Resolve-RepoPath $StatusFile
$resolvedSmokeSource = Resolve-RepoPath $SmokeSource

foreach ($path in @($resolvedManifest, $resolvedPkgPath, $resolvedOwnership, $resolvedStatusFile, $resolvedSmokeSource)) {
  if (!(Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "native capability contract input is missing: $path"
  }
}
if (!(Test-Path -LiteralPath $resolvedNativeDir -PathType Container)) {
  throw "native package directory is missing: $resolvedNativeDir"
}

$manifestData = Get-Content -LiteralPath $resolvedManifest -Raw | ConvertFrom-Json
$ownershipData = Get-Content -LiteralPath $resolvedOwnership -Raw | ConvertFrom-Json
$statusData = Get-Content -LiteralPath $resolvedStatusFile -Raw | ConvertFrom-Json

if ($manifestData.schema_version -ne 1) {
  throw "unsupported native capability schema_version: $($manifestData.schema_version)"
}

$capabilities = @($manifestData.capabilities)
if ($capabilities.Count -eq 0) {
  throw "native capability manifest is missing capabilities"
}

$targetEntries = Get-TargetEntries -PkgText (Get-Content -LiteralPath $resolvedPkgPath -Raw)
$smokeSourceText = Get-Content -LiteralPath $resolvedSmokeSource -Raw

$ownedNames = @{}
foreach ($section in @("external_wrappers", "regular_objects")) {
  foreach ($entry in @($ownershipData.$section)) {
    $name = "$($entry.name)".Trim()
    if (![string]::IsNullOrWhiteSpace($name)) {
      $ownedNames[$name] = $true
    }
  }
}

$statusMarkers = @{}
foreach ($section in @("native_smoke_capabilities", "native_smoke_conditional_capabilities")) {
  foreach ($entry in @($statusData.$section)) {
    $marker = "$($entry.marker)".Trim()
    if (![string]::IsNullOrWhiteSpace($marker)) {
      $statusMarkers[$marker] = $true
    }
  }
}

$nativeFiles = @{}
foreach ($file in Get-ChildItem -LiteralPath $resolvedNativeDir -Filter "*_native.mbt" -File) {
  $nativeFiles[$file.Name] = $true
}
$fallbackFiles = @{}
foreach ($file in Get-ChildItem -LiteralPath $resolvedNativeDir -Filter "*_unavailable.mbt" -File) {
  $fallbackFiles[$file.Name] = $true
}
$coveredNativeFiles = @{}
$coveredFallbackFiles = @{}
$seenIds = @{}
$seenMarkers = @{}

foreach ($capability in $capabilities) {
  $capabilityId = "$($capability.id)".Trim()
  $area = "$($capability.area)".Trim()
  $nativeFile = "$($capability.native_file)".Trim()
  $unavailableFile = "$($capability.unavailable_file)".Trim()
  $rationale = "$($capability.non_smoke_rationale)".Trim()
  $handles = @($capability.handles)
  $markers = @($capability.smoke_markers)

  if ([string]::IsNullOrWhiteSpace($capabilityId)) {
    throw "native capability is missing id"
  }
  if ($seenIds.ContainsKey($capabilityId)) {
    throw "duplicate native capability id: $capabilityId"
  }
  $seenIds[$capabilityId] = $true
  if ([string]::IsNullOrWhiteSpace($area)) {
    throw "native capability is missing area: $capabilityId"
  }
  if (!$nativeFile.EndsWith("_native.mbt")) {
    throw "native capability native_file must end with _native.mbt: $capabilityId"
  }
  if (!$unavailableFile.EndsWith("_unavailable.mbt")) {
    throw "native capability unavailable_file must end with _unavailable.mbt: $capabilityId"
  }

  $nativePath = Join-Path $resolvedNativeDir $nativeFile
  $unavailablePath = Join-Path $resolvedNativeDir $unavailableFile
  if (!(Test-Path -LiteralPath $nativePath -PathType Leaf)) {
    throw "native capability references missing native file: ${capabilityId}: $nativeFile"
  }
  if (!(Test-Path -LiteralPath $unavailablePath -PathType Leaf)) {
    throw "native capability references missing fallback file: ${capabilityId}: $unavailableFile"
  }

  $coveredNativeFiles[$nativeFile] = $true
  $coveredFallbackFiles[$unavailableFile] = $true
  Assert-TargetList -Entries $targetEntries -FileName $nativeFile -Expected @("native", "llvm") -CapabilityId $capabilityId
  Assert-TargetList -Entries $targetEntries -FileName $unavailableFile -Expected @("wasm", "wasm-gc", "js") -CapabilityId $capabilityId

  $nativeExports = Get-PublicFunctions -Text (Get-Content -LiteralPath $nativePath -Raw)
  $fallbackExports = Get-PublicFunctions -Text (Get-Content -LiteralPath $unavailablePath -Raw)
  $missingFallbackExports = @($nativeExports.Keys | Where-Object { !$fallbackExports.ContainsKey($_) } | Sort-Object)
  if ($missingFallbackExports.Count -gt 0) {
    throw "native capability fallback is missing public APIs: ${capabilityId}: $($missingFallbackExports -join ', ')"
  }
  $extraFallbackExports = @($fallbackExports.Keys | Where-Object { !$nativeExports.ContainsKey($_) } | Sort-Object)
  if ($extraFallbackExports.Count -gt 0) {
    throw "native capability fallback has public APIs absent from native side: ${capabilityId}: $($extraFallbackExports -join ', ')"
  }

  foreach ($handle in $handles) {
    $handleName = "$handle".Trim()
    if ([string]::IsNullOrWhiteSpace($handleName)) {
      throw "native capability has an empty handle entry: $capabilityId"
    }
    if (!$ownedNames.ContainsKey($handleName)) {
      throw "native capability handle is missing from ownership manifest: ${capabilityId}: $handleName"
    }
  }

  if ($markers.Count -eq 0 -and [string]::IsNullOrWhiteSpace($rationale)) {
    throw "native capability must list smoke_markers or non_smoke_rationale: $capabilityId"
  }
  foreach ($marker in $markers) {
    $markerText = "$marker".Trim()
    if ([string]::IsNullOrWhiteSpace($markerText)) {
      throw "native capability has an empty smoke marker: $capabilityId"
    }
    if (!$statusMarkers.ContainsKey($markerText)) {
      throw "native capability smoke marker is missing from platform status: ${capabilityId}: $markerText"
    }
    if (!$smokeSourceText.Contains($markerText)) {
      throw "native capability smoke marker is not emitted by native smoke source: ${capabilityId}: $markerText"
    }
    $seenMarkers[$markerText] = $true
  }
}

$missingManifestNative = @($nativeFiles.Keys | Where-Object { !$coveredNativeFiles.ContainsKey($_) } | Sort-Object)
if ($missingManifestNative.Count -gt 0) {
  throw "native capability manifest does not cover native files: $($missingManifestNative -join ', ')"
}
$missingManifestFallback = @($fallbackFiles.Keys | Where-Object { !$coveredFallbackFiles.ContainsKey($_) } | Sort-Object)
if ($missingManifestFallback.Count -gt 0) {
  throw "native capability manifest does not cover fallback files: $($missingManifestFallback -join ', ')"
}
if ($seenMarkers.Count -eq 0) {
  throw "native capability manifest does not bind any runtime smoke marker"
}

Write-Host "Verified native capability contract in $resolvedManifest"
