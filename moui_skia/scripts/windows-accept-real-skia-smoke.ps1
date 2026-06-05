param(
  [string] $LogDir = "logs/windows-real-skia-smoke",

  [string] $SkiaInclude = $env:MOUI_SKIA_SKIA_INCLUDE,

  [string] $SkiaLibDir = $env:MOUI_SKIA_SKIA_LIB_DIR,

  [string] $SkiaLib = $(if ($env:MOUI_SKIA_SKIA_LIB) { $env:MOUI_SKIA_SKIA_LIB } else { "skia" }),
  [string] $ExtraCcFlags = $env:MOUI_SKIA_EXTRA_CC_FLAGS,
  [string] $ExtraLinkFlags = $env:MOUI_SKIA_EXTRA_LINK_FLAGS,
  [switch] $DryRunConfig
)

$ErrorActionPreference = "Stop"

if ($DryRunConfig) {
  throw "acceptance requires a real smoke run; use scripts/windows-skia-smoke.ps1 -DryRunConfig for preflight"
}

if ([string]::IsNullOrWhiteSpace($SkiaInclude) -or [string]::IsNullOrWhiteSpace($SkiaLibDir)) {
  throw "SkiaInclude and SkiaLibDir are required; pass -SkiaInclude/-SkiaLibDir or set MOUI_SKIA_SKIA_INCLUDE/MOUI_SKIA_SKIA_LIB_DIR"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([System.IO.Path]::IsPathRooted($LogDir)) {
  $resolvedLogDir = $LogDir
} else {
  $resolvedLogDir = Join-Path $repoRoot $LogDir
}

$preflightLog = Join-Path $resolvedLogDir "windows-real-skia-smoke-preflight.log"
$wrapperLog = Join-Path $resolvedLogDir "windows-real-skia-smoke.log"
$nativeLog = Join-Path $resolvedLogDir "windows-native-smoke-output.log"
$acceptanceLog = Join-Path $resolvedLogDir "windows-real-skia-acceptance.log"
$nativePkg = Join-Path $repoRoot "native/moon.pkg"
$backupPkg = "$nativePkg.smoke.bak"

function Convert-LogToUtf8NoBom {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path
  )

  if (Test-Path -LiteralPath $Path) {
    $content = Get-Content -LiteralPath $Path -Raw
    [System.IO.File]::WriteAllText(
      $Path,
      $content,
      [System.Text.UTF8Encoding]::new($false)
    )
  }
}

function Get-Sha256Hex {
  param([Parameter(Mandatory = $true)][string] $Path)
  if (Get-Command Get-FileHash -ErrorAction SilentlyContinue) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
  }

  $stream = [System.IO.File]::OpenRead($Path)
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  try {
    $hashBytes = $sha256.ComputeHash($stream)
    return ([System.BitConverter]::ToString($hashBytes) -replace "-", "")
  } finally {
    $sha256.Dispose()
    $stream.Dispose()
  }
}

if (Test-Path -LiteralPath $backupPkg) {
  throw "native/moon.pkg smoke backup already exists: $backupPkg. Resolve the stale backup before running acceptance."
}

New-Item -ItemType Directory -Force -Path $resolvedLogDir | Out-Null

$beforePkgHash = Get-Sha256Hex -Path $nativePkg

Write-Host "Windows real Skia acceptance logs:"
Write-Host "  preflight_log=$preflightLog"
Write-Host "  wrapper_log=$wrapperLog"
Write-Host "  native_log=$nativeLog"
Write-Host "  acceptance_log=$acceptanceLog"

& (Join-Path $repoRoot "scripts/windows-skia-smoke.ps1") `
  -SkiaInclude $SkiaInclude `
  -SkiaLibDir $SkiaLibDir `
  -SkiaLib $SkiaLib `
  -ExtraCcFlags $ExtraCcFlags `
  -ExtraLinkFlags $ExtraLinkFlags `
  -SmokeLog $nativeLog `
  -DryRunConfig 2>&1 | Tee-Object -FilePath $preflightLog
Convert-LogToUtf8NoBom -Path $preflightLog
$smokeStatus = 0
try {
  & (Join-Path $repoRoot "scripts/windows-skia-smoke.ps1") `
    -SkiaInclude $SkiaInclude `
    -SkiaLibDir $SkiaLibDir `
    -SkiaLib $SkiaLib `
    -ExtraCcFlags $ExtraCcFlags `
    -ExtraLinkFlags $ExtraLinkFlags `
    -SmokeLog $nativeLog 2>&1 | Tee-Object -FilePath $wrapperLog
  if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
    $smokeStatus = $LASTEXITCODE
  }
} catch {
  $smokeStatus = 1
  $_ | Out-String | Tee-Object -FilePath $wrapperLog -Append | Write-Host
}
Convert-LogToUtf8NoBom -Path $wrapperLog

$afterPkgHash = Get-Sha256Hex -Path $nativePkg
$restoreStatus = "passed"
if (Test-Path -LiteralPath $backupPkg) {
  Write-Error "native/moon.pkg smoke backup remains after acceptance run" -ErrorAction Continue
  $restoreStatus = "failed"
}
if ($beforePkgHash -ne $afterPkgHash) {
  Write-Error "native/moon.pkg hash changed after acceptance run" -ErrorAction Continue
  $restoreStatus = "failed"
}

$markerStatus = "not run"
if ($smokeStatus -eq 0) {
  if ((Test-Path -LiteralPath $nativeLog) -and (Select-String -LiteralPath $nativeLog -SimpleMatch "moui_skia native smoke test passed" -Quiet)) {
    $markerStatus = "passed"
  } else {
    $markerStatus = "failed"
  }
}

$skiaCommit = ""
if (Test-Path -LiteralPath $wrapperLog) {
  $commitLine = Select-String -LiteralPath $wrapperLog -Pattern '^\s*skia_commit=' | Select-Object -Last 1
  if ($commitLine) {
    $skiaCommit = $commitLine.Line -replace '^\s*skia_commit=', ''
  }
}
if ($skiaCommit.Trim().Length -eq 0) {
  $skiaCommit = "unknown"
}

@(
  "Windows real Skia acceptance result:"
  "  smoke_status=$smokeStatus"
  "  native_smoke_marker=$markerStatus"
  "  native_pkg_restore=$restoreStatus"
  "  skia_commit=$skiaCommit"
  "  preflight_log=$preflightLog"
  "  wrapper_log=$wrapperLog"
  "  native_log=$nativeLog"
  "  acceptance_log=$acceptanceLog"
) | Tee-Object -FilePath $acceptanceLog
Convert-LogToUtf8NoBom -Path $acceptanceLog

if ($env:GITHUB_ENV) {
  @(
    "native_smoke_marker_status=$markerStatus"
    "restore_status=$restoreStatus"
    "windows_acceptance_log=$acceptanceLog"
    "windows_skia_commit=$skiaCommit"
  ) | Add-Content -LiteralPath $env:GITHUB_ENV
}

if ($restoreStatus -ne "passed") {
  exit 1
}
if ($smokeStatus -ne 0) {
  exit $smokeStatus
}
if ($markerStatus -ne "passed") {
  exit 1
}
