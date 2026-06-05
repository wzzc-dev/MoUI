param(
  [string] $LogDir = "logs/windows-msvc-real-skia-smoke",
  [string] $SkiaRoot = $env:MOUI_SKIA_SKIA_ROOT,
  [string] $SkiaInclude = $env:MOUI_SKIA_SKIA_INCLUDE,
  [string] $SkiaZip = $env:MOUI_SKIA_SKIA_ZIP,
  [string] $SkiaLibDir = $env:MOUI_SKIA_SKIA_LIB_DIR,
  [string] $VcVarsAll = $env:VCVARSALL,
  [string] $VcArch = "x64",
  [string] $SkiaProvider = $env:MOUI_SKIA_SKIA_PROVIDER,
  [string] $SkiaLinkMode = $(if ($env:MOUI_SKIA_SKIA_LINK_MODE) { $env:MOUI_SKIA_SKIA_LINK_MODE } else { "static" }),
  [string] $ReleaseOwner = $env:MOUI_SKIA_RELEASE_OWNER,
  [string] $ReleaseRepo = $env:MOUI_SKIA_RELEASE_REPO,
  [string] $ReleaseTag = $env:MOUI_SKIA_RELEASE_TAG,
  [string] $ReleaseUrl = $env:MOUI_SKIA_RELEASE_URL,
  [string] $JetBrainsTag = $env:MOUI_SKIA_JETBRAINS_TAG,
  [string] $SkiaCommit = $env:MOUI_SKIA_SKIA_COMMIT,
  [string] $SkiaPackage = $env:MOUI_SKIA_SKIA_PACKAGE,
  [string] $SkiaPackageSha256 = $env:MOUI_SKIA_SKIA_PACKAGE_SHA256,
  [string] $ExtraCcFlags = $env:MOUI_SKIA_EXTRA_CC_FLAGS,
  [string] $ExtraLinkFlags = $env:MOUI_SKIA_EXTRA_LINK_FLAGS,
  [switch] $DryRunConfig,
  [switch] $ForceExtract
)

$ErrorActionPreference = "Stop"

if ($DryRunConfig) {
  throw "acceptance requires a real smoke run; use scripts/windows-msvc-skia-smoke.ps1 -DryRunConfig for preflight"
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
$smokePkg = Join-Path $repoRoot "scripts/native_smoke/moon.pkg"
$backupPkg = "$nativePkg.smoke.bak"
$smokeBackupPkg = "$smokePkg.smoke.bak"

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
if (Test-Path -LiteralPath $smokeBackupPkg) {
  throw "scripts/native_smoke/moon.pkg smoke backup already exists: $smokeBackupPkg. Resolve the stale backup before running acceptance."
}

New-Item -ItemType Directory -Force -Path $resolvedLogDir | Out-Null

$beforePkgHash = Get-Sha256Hex -Path $nativePkg
$beforeSmokePkgHash = Get-Sha256Hex -Path $smokePkg

Write-Host "Windows MSVC real Skia acceptance logs:"
Write-Host "  preflight_log=$preflightLog"
Write-Host "  wrapper_log=$wrapperLog"
Write-Host "  native_log=$nativeLog"
Write-Host "  acceptance_log=$acceptanceLog"

& (Join-Path $repoRoot "scripts/windows-msvc-skia-smoke.ps1") `
  -SkiaRoot $SkiaRoot `
  -SkiaInclude $SkiaInclude `
  -SkiaZip $SkiaZip `
  -SkiaLibDir $SkiaLibDir `
  -VcVarsAll $VcVarsAll `
  -VcArch $VcArch `
  -SkiaProvider $SkiaProvider `
  -SkiaLinkMode $SkiaLinkMode `
  -ReleaseOwner $ReleaseOwner `
  -ReleaseRepo $ReleaseRepo `
  -ReleaseTag $ReleaseTag `
  -ReleaseUrl $ReleaseUrl `
  -JetBrainsTag $JetBrainsTag `
  -SkiaCommit $SkiaCommit `
  -SkiaPackage $SkiaPackage `
  -SkiaPackageSha256 $SkiaPackageSha256 `
  -ExtraCcFlags $ExtraCcFlags `
  -ExtraLinkFlags $ExtraLinkFlags `
  -SmokeLog $nativeLog `
  -ForceExtract:$ForceExtract `
  -DryRunConfig 2>&1 | Tee-Object -FilePath $preflightLog
Convert-LogToUtf8NoBom -Path $preflightLog

$smokeStatus = 0
try {
  & (Join-Path $repoRoot "scripts/windows-msvc-skia-smoke.ps1") `
    -SkiaRoot $SkiaRoot `
    -SkiaInclude $SkiaInclude `
    -SkiaZip $SkiaZip `
    -SkiaLibDir $SkiaLibDir `
    -VcVarsAll $VcVarsAll `
    -VcArch $VcArch `
    -SkiaProvider $SkiaProvider `
    -SkiaLinkMode $SkiaLinkMode `
    -ReleaseOwner $ReleaseOwner `
    -ReleaseRepo $ReleaseRepo `
    -ReleaseTag $ReleaseTag `
    -ReleaseUrl $ReleaseUrl `
    -JetBrainsTag $JetBrainsTag `
    -SkiaCommit $SkiaCommit `
    -SkiaPackage $SkiaPackage `
    -SkiaPackageSha256 $SkiaPackageSha256 `
    -ExtraCcFlags $ExtraCcFlags `
    -ExtraLinkFlags $ExtraLinkFlags `
    -SmokeLog $nativeLog `
    -ForceExtract:$ForceExtract 2>&1 | Tee-Object -FilePath $wrapperLog
  if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
    $smokeStatus = $LASTEXITCODE
  }
} catch {
  $smokeStatus = 1
  $_ | Out-String | Tee-Object -FilePath $wrapperLog -Append | Write-Host
}
Convert-LogToUtf8NoBom -Path $wrapperLog

$restoreStatus = "passed"
if (Test-Path -LiteralPath $backupPkg) {
  Write-Error "native/moon.pkg smoke backup remains after acceptance run" -ErrorAction Continue
  $restoreStatus = "failed"
}
if (Test-Path -LiteralPath $smokeBackupPkg) {
  Write-Error "scripts/native_smoke/moon.pkg smoke backup remains after acceptance run" -ErrorAction Continue
  $restoreStatus = "failed"
}
if (!(Test-Path -LiteralPath $nativePkg -PathType Leaf)) {
  Write-Error "native/moon.pkg is missing after acceptance run" -ErrorAction Continue
  $restoreStatus = "failed"
} else {
  $afterPkgHash = Get-Sha256Hex -Path $nativePkg
  if ($beforePkgHash -ne $afterPkgHash) {
    Write-Error "native/moon.pkg hash changed after acceptance run" -ErrorAction Continue
    $restoreStatus = "failed"
  }
}
if (!(Test-Path -LiteralPath $smokePkg -PathType Leaf)) {
  Write-Error "scripts/native_smoke/moon.pkg is missing after acceptance run" -ErrorAction Continue
  $restoreStatus = "failed"
} else {
  $afterSmokePkgHash = Get-Sha256Hex -Path $smokePkg
  if ($beforeSmokePkgHash -ne $afterSmokePkgHash) {
    Write-Error "scripts/native_smoke/moon.pkg hash changed after acceptance run" -ErrorAction Continue
    $restoreStatus = "failed"
  }
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
$skiaProvider = ""
$skiaLinkMode = ""
$releaseOwner = ""
$releaseRepo = ""
$releaseTag = ""
$releaseUrl = ""
$jetbrainsTag = ""
$skiaPackage = ""
$skiaPackageSha256 = ""
if (Test-Path -LiteralPath $wrapperLog) {
  $commitLine = Select-String -LiteralPath $wrapperLog -Pattern '^\s*skia_commit=' | Select-Object -Last 1
  if ($commitLine) {
    $skiaCommit = $commitLine.Line -replace '^\s*skia_commit=', ''
  }
  $providerLine = Select-String -LiteralPath $wrapperLog -Pattern '^\s*skia_provider=' | Select-Object -Last 1
  if ($providerLine) {
    $skiaProvider = $providerLine.Line -replace '^\s*skia_provider=', ''
  }
  $linkModeLine = Select-String -LiteralPath $wrapperLog -Pattern '^\s*skia_link_mode=' | Select-Object -Last 1
  if ($linkModeLine) {
    $skiaLinkMode = $linkModeLine.Line -replace '^\s*skia_link_mode=', ''
  }
  $releaseOwnerLine = Select-String -LiteralPath $wrapperLog -Pattern '^\s*release_owner=' | Select-Object -Last 1
  if ($releaseOwnerLine) {
    $releaseOwner = $releaseOwnerLine.Line -replace '^\s*release_owner=', ''
  }
  $releaseRepoLine = Select-String -LiteralPath $wrapperLog -Pattern '^\s*release_repo=' | Select-Object -Last 1
  if ($releaseRepoLine) {
    $releaseRepo = $releaseRepoLine.Line -replace '^\s*release_repo=', ''
  }
  $releaseTagLine = Select-String -LiteralPath $wrapperLog -Pattern '^\s*release_tag=' | Select-Object -Last 1
  if ($releaseTagLine) {
    $releaseTag = $releaseTagLine.Line -replace '^\s*release_tag=', ''
  }
  $releaseUrlLine = Select-String -LiteralPath $wrapperLog -Pattern '^\s*release_url=' | Select-Object -Last 1
  if ($releaseUrlLine) {
    $releaseUrl = $releaseUrlLine.Line -replace '^\s*release_url=', ''
  }
  $tagLine = Select-String -LiteralPath $wrapperLog -Pattern '^\s*jetbrains_tag=' | Select-Object -Last 1
  if ($tagLine) {
    $jetbrainsTag = $tagLine.Line -replace '^\s*jetbrains_tag=', ''
  }
  $packageLine = Select-String -LiteralPath $wrapperLog -Pattern '^\s*skia_package=' | Select-Object -Last 1
  if ($packageLine) {
    $skiaPackage = $packageLine.Line -replace '^\s*skia_package=', ''
  }
  $shaLine = Select-String -LiteralPath $wrapperLog -Pattern '^\s*skia_package_sha256=' | Select-Object -Last 1
  if ($shaLine) {
    $skiaPackageSha256 = $shaLine.Line -replace '^\s*skia_package_sha256=', ''
  }
}
if ($skiaCommit.Trim().Length -eq 0) {
  $skiaCommit = "unknown"
}
if ($skiaProvider.Trim().Length -eq 0) {
  $skiaProvider = "unknown"
}
if ($skiaLinkMode.Trim().Length -eq 0) {
  $skiaLinkMode = "unknown"
}
if ($releaseOwner.Trim().Length -eq 0) {
  $releaseOwner = "unknown"
}
if ($releaseRepo.Trim().Length -eq 0) {
  $releaseRepo = "unknown"
}
if ($releaseTag.Trim().Length -eq 0) {
  $releaseTag = "unknown"
}
if ($releaseUrl.Trim().Length -eq 0) {
  $releaseUrl = "unknown"
}
if ($jetbrainsTag.Trim().Length -eq 0) {
  $jetbrainsTag = "unknown"
}
if ($skiaPackage.Trim().Length -eq 0) {
  $skiaPackage = "unknown"
}
if ($skiaPackageSha256.Trim().Length -eq 0) {
  $skiaPackageSha256 = "unknown"
}

@(
  "Windows MSVC real Skia acceptance result:"
  "  smoke_status=$smokeStatus"
  "  native_smoke_marker=$markerStatus"
  "  native_pkg_restore=$restoreStatus"
  "  skia_provider=$skiaProvider"
  "  skia_link_mode=$skiaLinkMode"
  "  release_owner=$releaseOwner"
  "  release_repo=$releaseRepo"
  "  release_tag=$releaseTag"
  "  release_url=$releaseUrl"
  "  jetbrains_tag=$jetbrainsTag"
  "  skia_commit=$skiaCommit"
  "  skia_package=$skiaPackage"
  "  skia_package_sha256=$skiaPackageSha256"
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
    "windows_msvc_acceptance_log=$acceptanceLog"
    "windows_skia_provider=$skiaProvider"
    "windows_skia_link_mode=$skiaLinkMode"
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
