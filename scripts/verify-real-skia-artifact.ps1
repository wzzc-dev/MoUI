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
$buildLog = Join-Path $resolvedLogDir "$Platform-skia-build.log"
$nativeLog = Join-Path $resolvedLogDir "$Platform-native-smoke-output.log"
$acceptanceLog = Join-Path $resolvedLogDir "$Platform-real-skia-acceptance.log"

foreach ($logPath in @($wrapperLog, $nativeLog, $acceptanceLog)) {
  if (!(Test-Path -LiteralPath $logPath -PathType Leaf)) {
    throw "real Skia artifact is missing expected log: $logPath"
  }
}

if ($Platform -eq "linux" -and $RequireCommit) {
  if (!(Test-Path -LiteralPath $buildLog -PathType Leaf)) {
    throw "source-built Linux artifact is missing expected build log: $buildLog"
  }
}

& (Join-Path $PSScriptRoot "verify-native-smoke-log.ps1") -LogPath $nativeLog
& (Join-Path $PSScriptRoot "verify-acceptance-log.ps1") -LogPath $acceptanceLog -RequireCommit:$RequireCommit

$wrapperContent = Get-Content -LiteralPath $wrapperLog -Raw
$acceptanceContent = Get-Content -LiteralPath $acceptanceLog -Raw

foreach ($field in @("skia_include=", "skia_lib_dir=", "skia_lib=", "stub_cc_flags=", "cc_link_flags=")) {
  if (!$wrapperContent.Contains($field)) {
    throw "wrapper log is missing required field: $field"
  }
}

if ($Platform -eq "linux" -and $RequireCommit -and !$wrapperContent.Contains("build_log=")) {
  throw "wrapper log is missing required field: build_log="
}

if ($wrapperContent -notmatch 'library=.*\b(lib)?skia\.(a|so|dylib|lib)\b') {
  throw "wrapper log does not record a Skia library file"
}

foreach ($logName in @(
  (Split-Path -Leaf $wrapperLog),
  (Split-Path -Leaf $nativeLog),
  (Split-Path -Leaf $acceptanceLog)
)) {
  if (!$acceptanceContent.Contains($logName)) {
    throw "acceptance log does not reference expected artifact log: $logName"
  }
}

if ($Platform -eq "linux" -and $RequireCommit) {
  $buildLogName = Split-Path -Leaf $buildLog
  if (!$acceptanceContent.Contains($buildLogName)) {
    throw "acceptance log does not reference expected source build log: $buildLogName"
  }
}

if ($RequireCommit -and $wrapperContent -notmatch 'skia_commit=[0-9a-fA-F]{40}(\r?\n|$)') {
  throw "wrapper log is missing a full 40-character skia_commit hash"
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

if ($Platform -eq "linux" -and $RequireCommit) {
  $buildContent = Get-Content -LiteralPath $buildLog -Raw
  foreach ($field in @("Linux Skia source build environment:", "skia_checkout=", "skia_commit=", "gn_args=")) {
    if (!$buildContent.Contains($field)) {
      throw "Linux source build log is missing required field: $field"
    }
  }
  $buildCommit = Get-AcceptedSkiaCommit $buildLog
  if ($wrapperCommit -ne $buildCommit) {
    throw "Linux build and wrapper logs disagree on skia_commit: build_commit=$buildCommit wrapper_commit=$wrapperCommit"
  }
}

Write-Host "Verified $Platform real Skia artifact logs in $resolvedLogDir."
