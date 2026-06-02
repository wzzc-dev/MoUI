param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("linux", "macos", "windows")]
  [string] $Platform,

  [Parameter(Mandatory = $true)]
  [string] $LogDir,

  [switch] $RequireCommit
)

$ErrorActionPreference = "Stop"

if ([System.IO.Path]::IsPathRooted($LogDir)) {
  $resolvedLogDir = $LogDir
} else {
  $resolvedLogDir = Join-Path (Get-Location) $LogDir
}

if (!(Test-Path -LiteralPath $resolvedLogDir -PathType Container)) {
  throw "real Skia artifact log directory is missing: $resolvedLogDir"
}

$wrapperLog = Join-Path $resolvedLogDir "$Platform-real-skia-smoke.log"
$preflightLog = Join-Path $resolvedLogDir "$Platform-real-skia-smoke-preflight.log"
$buildLog = Join-Path $resolvedLogDir "$Platform-skia-build.log"
$nativeLog = Join-Path $resolvedLogDir "$Platform-native-smoke-output.log"
$acceptanceLog = Join-Path $resolvedLogDir "$Platform-real-skia-acceptance.log"

foreach ($logPath in @($preflightLog, $wrapperLog, $nativeLog, $acceptanceLog)) {
  if (!(Test-Path -LiteralPath $logPath -PathType Leaf)) {
    throw "real Skia artifact is missing expected log: $logPath"
  }
}

function Get-LogField {
  param(
    [Parameter(Mandatory = $true)]
    [string] $LogPath,
    [Parameter(Mandatory = $true)]
    [string] $Field
  )

  $matches = Select-String -LiteralPath $LogPath -Pattern "^\s*$([regex]::Escape($Field))=(.*)$"
  if (!$matches) {
    return ""
  }
  return $matches[-1].Matches[0].Groups[1].Value.Trim()
}

function Assert-LogFieldLine {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Content,
    [Parameter(Mandatory = $true)]
    [string] $Field,
    [Parameter(Mandatory = $true)]
    [string] $MessagePrefix
  )

  if ($Content -notmatch "(?m)^\s*$([regex]::Escape($Field))") {
    throw "${MessagePrefix}: $Field"
  }
}

function Assert-ExactLogLine {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Content,
    [Parameter(Mandatory = $true)]
    [string] $Line,
    [Parameter(Mandatory = $true)]
    [string] $MessagePrefix
  )

  if ($Content -notmatch "(?m)^\s*$([regex]::Escape($Line))\s*$") {
    throw "${MessagePrefix}: $Line"
  }
}

function Assert-NotDryRunLog {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Content,
    [Parameter(Mandatory = $true)]
    [string] $Label,
    [Parameter(Mandatory = $true)]
    [string] $Path
  )

  if ($Content -match "(?im)dry[_ -]?run(_config)?\s*=\s*true|Dry run complete|real .* smoke was not run|no build was run") {
    throw "$Label log is from a dry-run configuration: $Path"
  }
}

function Assert-AcceptanceLogReference {
  param(
    [Parameter(Mandatory = $true)]
    [string] $LogPath,
    [Parameter(Mandatory = $true)]
    [string] $Field,
    [Parameter(Mandatory = $true)]
    [string] $ExpectedPath
  )

  $actualPath = Get-LogField -LogPath $LogPath -Field $Field
  if ([string]::IsNullOrWhiteSpace($actualPath)) {
    throw "acceptance log is missing required artifact log field: $Field="
  }
  $expectedName = Split-Path -Leaf $ExpectedPath
  $actualName = Split-Path -Leaf $actualPath
  if ($actualName -ne $expectedName) {
    throw "acceptance log field $Field= does not reference expected artifact log: $expectedName actual_$Field=$actualPath"
  }
}

$wrapperContent = Get-Content -LiteralPath $wrapperLog -Raw
$nativeContent = Get-Content -LiteralPath $nativeLog -Raw
$acceptanceContent = Get-Content -LiteralPath $acceptanceLog -Raw
Assert-NotDryRunLog -Content $wrapperContent -Label "artifact wrapper" -Path $wrapperLog
Assert-NotDryRunLog -Content $nativeContent -Label "artifact native smoke" -Path $nativeLog
Assert-NotDryRunLog -Content $acceptanceContent -Label "artifact acceptance" -Path $acceptanceLog
$wrapperProvider = Get-LogField -LogPath $wrapperLog -Field "skia_provider"
$acceptanceProvider = Get-LogField -LogPath $acceptanceLog -Field "skia_provider"
if ([string]::IsNullOrWhiteSpace($wrapperProvider) -or $wrapperProvider -eq "unknown") {
  $wrapperProvider = "source"
}
if ([string]::IsNullOrWhiteSpace($acceptanceProvider) -or $acceptanceProvider -eq "unknown") {
  $acceptanceProvider = $wrapperProvider
}
if ($wrapperProvider -ne $acceptanceProvider) {
  throw "wrapper and acceptance logs disagree on skia_provider: wrapper_provider=$wrapperProvider acceptance_provider=$acceptanceProvider"
}

if ($Platform -eq "linux" -and $RequireCommit -and $wrapperProvider -eq "source") {
  if (!(Test-Path -LiteralPath $buildLog -PathType Leaf)) {
    throw "source-built Linux artifact is missing expected build log: $buildLog"
  }
}

& (Join-Path $PSScriptRoot "verify-native-smoke-log.ps1") -LogPath $nativeLog
& (Join-Path $PSScriptRoot "verify-acceptance-log.ps1") -LogPath $acceptanceLog -RequireCommit:$RequireCommit

foreach ($field in @("skia_include=", "skia_lib_dir=", "skia_lib=", "stub_cc_flags=", "cc_link_flags=")) {
  Assert-LogFieldLine -Content $wrapperContent -Field $field -MessagePrefix "wrapper log is missing required field"
}

if ($Platform -eq "linux" -and $RequireCommit -and $wrapperProvider -eq "source") {
  Assert-LogFieldLine -Content $wrapperContent -Field "build_log=" -MessagePrefix "wrapper log is missing required field"
}

if ($wrapperContent -notmatch 'library=.*\b(lib)?skia\.(a|so|dylib|lib)\b') {
  throw "wrapper log does not record a Skia library file"
}

$artifactLogReferences = @(
  @{ Field = "preflight_log"; Path = $preflightLog }
  @{ Field = "wrapper_log"; Path = $wrapperLog }
  @{ Field = "native_log"; Path = $nativeLog }
  @{ Field = "acceptance_log"; Path = $acceptanceLog }
)
foreach ($reference in $artifactLogReferences) {
  Assert-AcceptanceLogReference `
    -LogPath $acceptanceLog `
    -Field $reference.Field `
    -ExpectedPath $reference.Path
}

if ($Platform -eq "linux" -and $RequireCommit -and $wrapperProvider -eq "source") {
  Assert-AcceptanceLogReference `
    -LogPath $acceptanceLog `
    -Field "build_log" `
    -ExpectedPath $buildLog
}

if ($RequireCommit -and $wrapperContent -notmatch 'skia_commit=[0-9a-fA-F]{40}(\r?\n|$)') {
  throw "wrapper log is missing a full 40-character skia_commit hash"
}

if ($wrapperProvider -eq "jetbrains") {
  foreach ($field in @("skia_provider=", "jetbrains_tag=", "skia_commit=", "skia_package=", "skia_package_sha256=")) {
    Assert-LogFieldLine -Content $wrapperContent -Field $field -MessagePrefix "JetBrains wrapper log is missing required field"
  }
  if ($wrapperContent -notmatch '(?m)^\s*skia_commit=[0-9a-fA-F]{40}\s*$') {
    throw "JetBrains wrapper log is missing a full 40-character skia_commit hash"
  }
  if ($wrapperContent -notmatch '(?m)^\s*skia_package_sha256=[0-9a-fA-F]{64}\s*$') {
    throw "JetBrains wrapper log is missing a full 64-character skia_package_sha256 hash"
  }

  $manifestPath = Join-Path (Split-Path -Parent $PSScriptRoot) "skia-provider-lock.json"
  if (!(Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "JetBrains provider manifest is missing: $manifestPath"
  }
  $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  $provider = $manifest.providers.jetbrains
  if (!$provider) {
    throw "JetBrains provider manifest is missing providers.jetbrains"
  }
  $jetbrainsTag = Get-LogField -LogPath $wrapperLog -Field "jetbrains_tag"
  $jetbrainsCommit = (Get-LogField -LogPath $wrapperLog -Field "skia_commit").ToLowerInvariant()
  $jetbrainsPackage = Get-LogField -LogPath $wrapperLog -Field "skia_package"
  $jetbrainsSha256 = (Get-LogField -LogPath $wrapperLog -Field "skia_package_sha256").ToLowerInvariant()
  if ($jetbrainsTag -ne $provider.tag) {
    throw "JetBrains tag mismatch: log=$jetbrainsTag manifest=$($provider.tag)"
  }
  if ($jetbrainsCommit -ne $provider.commit.ToLowerInvariant()) {
    throw "JetBrains commit mismatch: log=$jetbrainsCommit manifest=$($provider.commit)"
  }
  $platformAssets = $provider.assets.PSObject.Properties[$Platform].Value
  $matchedAssets = @()
  foreach ($configProperty in $platformAssets.PSObject.Properties) {
    foreach ($archProperty in $configProperty.Value.PSObject.Properties) {
      $asset = $archProperty.Value
      if ($asset.name -eq $jetbrainsPackage) {
        $matchedAssets += $asset
      }
    }
  }
  if ($matchedAssets.Count -eq 0) {
    throw "JetBrains package is not locked for platform=${Platform}: $jetbrainsPackage"
  }
  $shaMatched = $false
  foreach ($asset in $matchedAssets) {
    if ($asset.sha256.ToLowerInvariant() -eq $jetbrainsSha256) {
      $shaMatched = $true
    }
  }
  if (!$shaMatched) {
    throw "JetBrains package SHA256 mismatch for $jetbrainsPackage`: $jetbrainsSha256"
  }

  foreach ($field in @("jetbrains_tag", "skia_commit", "skia_package", "skia_package_sha256")) {
    $wrapperValue = (Get-LogField -LogPath $wrapperLog -Field $field).ToLowerInvariant()
    $acceptanceValue = (Get-LogField -LogPath $acceptanceLog -Field $field).ToLowerInvariant()
    if ($wrapperValue -ne $acceptanceValue) {
      throw "wrapper and acceptance logs disagree on JetBrains $field`: wrapper_$field=$wrapperValue acceptance_$field=$acceptanceValue"
    }
  }
}

function Get-AcceptedSkiaCommit([string] $LogPath) {
  $matches = Select-String -LiteralPath $LogPath -Pattern '^\s*skia_commit=([0-9a-fA-F]{40})\s*$'
  if (!$matches) {
    return $null
  }
  return $matches[-1].Matches[0].Groups[1].Value.ToLowerInvariant()
}

if ($RequireCommit) {
  $wrapperCommit = Get-AcceptedSkiaCommit $wrapperLog
  $acceptanceCommit = Get-AcceptedSkiaCommit $acceptanceLog
  if ($wrapperCommit -ne $acceptanceCommit) {
    throw "wrapper and acceptance logs disagree on skia_commit: wrapper_commit=$wrapperCommit acceptance_commit=$acceptanceCommit"
  }
}

if ($Platform -eq "linux" -and $RequireCommit -and $wrapperProvider -eq "source") {
  $buildContent = Get-Content -LiteralPath $buildLog -Raw
  Assert-ExactLogLine `
    -Content $buildContent `
    -Line "Linux Skia source build environment:" `
    -MessagePrefix "Linux source build log is missing required field"
  foreach ($field in @("skia_checkout=", "skia_commit=", "gn_args=")) {
    Assert-LogFieldLine -Content $buildContent -Field $field -MessagePrefix "Linux source build log is missing required field"
  }
  $buildCommit = Get-AcceptedSkiaCommit $buildLog
  if ($wrapperCommit -ne $buildCommit) {
    throw "Linux build and wrapper logs disagree on skia_commit: build_commit=$buildCommit wrapper_commit=$wrapperCommit"
  }
}

Write-Host "Verified $Platform real Skia artifact logs in $resolvedLogDir."
