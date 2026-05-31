param(
  [string] $StatusFile = "skia-platform-status.json",
  [string] $SmokeSource = "scripts/native_smoke/main.mbt",
  [string] $UnixLogVerifier = "scripts/verify-native-smoke-log.sh",
  [string] $PowershellLogVerifier = "scripts/verify-native-smoke-log.ps1"
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
$resolvedSmokeSource = Resolve-RepoPath $SmokeSource
$resolvedUnixLogVerifier = Resolve-RepoPath $UnixLogVerifier
$resolvedPowershellLogVerifier = Resolve-RepoPath $PowershellLogVerifier

foreach ($path in @(
    $resolvedStatusFile,
    $resolvedSmokeSource,
    $resolvedUnixLogVerifier,
    $resolvedPowershellLogVerifier
  )) {
  if (!(Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "required capability proof input is missing: $path"
  }
}

$status = Get-Content -LiteralPath $resolvedStatusFile -Raw | ConvertFrom-Json
$capabilities = @($status.native_smoke_capabilities)
if ($capabilities.Count -eq 0) {
  throw "platform status is missing native_smoke_capabilities"
}

$smokeSourceContent = Get-Content -LiteralPath $resolvedSmokeSource -Raw
$unixLogVerifierContent = Get-Content -LiteralPath $resolvedUnixLogVerifier -Raw
$powershellLogVerifierContent = Get-Content -LiteralPath $resolvedPowershellLogVerifier -Raw

$seenMarkers = @{}
$missingFromSource = @()
$missingFromUnixLogVerifier = @()
$missingFromPowershellLogVerifier = @()

foreach ($capability in $capabilities) {
  $capabilityId = "$($capability.id)".Trim()
  $marker = "$($capability.marker)".Trim()
  if ([string]::IsNullOrWhiteSpace($marker)) {
    throw "native smoke capability is missing marker: $capabilityId"
  }
  if ($seenMarkers.ContainsKey($marker)) {
    throw "duplicate native smoke capability marker: $marker"
  }
  $seenMarkers[$marker] = $true
  if (!$smokeSourceContent.Contains($marker)) {
    $missingFromSource += $marker
  }
  if (!$unixLogVerifierContent.Contains($marker)) {
    $missingFromUnixLogVerifier += $marker
  }
  if (!$powershellLogVerifierContent.Contains($marker)) {
    $missingFromPowershellLogVerifier += $marker
  }
}

if ($missingFromSource.Count -gt 0) {
  throw "native smoke capabilities are not emitted by ${resolvedSmokeSource}: $($missingFromSource -join ', ')"
}
if ($missingFromUnixLogVerifier.Count -gt 0) {
  throw "native smoke capabilities are missing from Unix log verifier fallback markers: $($missingFromUnixLogVerifier -join ', ')"
}
if ($missingFromPowershellLogVerifier.Count -gt 0) {
  throw "native smoke capabilities are missing from PowerShell log verifier fallback markers: $($missingFromPowershellLogVerifier -join ', ')"
}

Write-Host "Verified native smoke capability markers across $resolvedStatusFile, $resolvedSmokeSource, $resolvedUnixLogVerifier, and $resolvedPowershellLogVerifier."
