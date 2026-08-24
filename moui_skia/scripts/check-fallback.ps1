param(
  [switch] $SkipInfo
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$nativePkg = Join-Path $repoRoot "native/moon.pkg"
$smokePkg = Join-Path $repoRoot "scripts/native_smoke/moon.pkg"

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

function Assert-NativePkgUnchanged {
  param(
    [Parameter(Mandatory = $true)]
    [string] $ExpectedHash,
    [Parameter(Mandatory = $true)]
    [string] $ExpectedSmokeHash
  )

  $actualHash = Get-Sha256Hex -Path $nativePkg
  if ($actualHash -ne $ExpectedHash) {
    throw "native/moon.pkg changed during fallback validation"
  }
  $actualSmokeHash = Get-Sha256Hex -Path $smokePkg
  if ($actualSmokeHash -ne $ExpectedSmokeHash) {
    throw "scripts/native_smoke/moon.pkg changed during fallback validation"
  }
  $backupPkg = "$nativePkg.smoke.bak"
  if (Test-Path -LiteralPath $backupPkg) {
    throw "native/moon.pkg smoke backup was left behind: $backupPkg"
  }
  $smokeBackupPkg = "$smokePkg.smoke.bak"
  if (Test-Path -LiteralPath $smokeBackupPkg) {
    throw "scripts/native_smoke/moon.pkg smoke backup was left behind: $smokeBackupPkg"
  }
}

function Assert-CommandFailsWith {
  param(
    [Parameter(Mandatory = $true)]
    [scriptblock] $Command,
    [Parameter(Mandatory = $true)]
    [string] $ExpectedMessage
  )

  try {
    $global:LASTEXITCODE = 0
    $output = & $Command 2>&1
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    if ($exitCode -eq 0) {
      throw "command unexpectedly succeeded"
    }
    $message = ($output -join [Environment]::NewLine)
    if ($message -notlike "*$ExpectedMessage*") {
      throw "command failed with exit code $exitCode but did not include expected message: $ExpectedMessage"
    }
  } catch {
    if ($_.Exception.Message -notlike "*$ExpectedMessage*") {
      throw
    }
  }
}

function Assert-WorkflowUsesHashtableSplatting {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path
  )

  $content = Get-Content -LiteralPath $Path -Raw
  foreach ($pattern in @('\$(args|acceptArgs)\s*=\s*@\(', '\$(args|acceptArgs)\s*\+=\s*@\(')) {
    if ($content -match $pattern) {
      throw "workflow uses array splatting for PowerShell named parameters: $Path"
    }
  }
}

function Assert-WindowsMsvcSmokePassesResolvedLinkMode {
  $path = Join-Path $repoRoot "scripts/windows-msvc-skia-smoke.ps1"
  $content = Get-Content -LiteralPath $path -Raw
  if ($content -notmatch '(?s)configure-windows-msvc-native-pkg\.ps1.*-SkiaLinkMode\s+\$resolvedSkiaLinkMode') {
    throw "windows-msvc-skia-smoke.ps1 must pass the resolved Skia link mode to configure-windows-msvc-native-pkg.ps1"
  }
}

function Resolve-WorkflowPath {
  param(
    [Parameter(Mandatory = $true)]
    [string] $RelativePath
  )

  $candidates = @(
    (Join-Path $repoRoot $RelativePath),
    (Join-Path (Split-Path -Parent $repoRoot) $RelativePath)
  )
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      return $candidate
    }
  }
  throw "workflow file is missing: $RelativePath"
}

function Set-FakeNativeSmokeLog {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path
  )

  $statusPath = Join-Path $repoRoot "skia-platform-status.json"
  $status = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
  $expectedValues = @{}
  foreach ($expected in @($status.native_smoke_expected_values)) {
    $marker = "$($expected.marker)".Trim()
    $value = "$($expected.value)".Trim()
    if (![string]::IsNullOrWhiteSpace($marker) -and ![string]::IsNullOrWhiteSpace($value)) {
      $expectedValues[$marker] = $value
    }
  }
  $lines = @()
  $markerValues = @{}
  foreach ($capability in @($status.native_smoke_capabilities)) {
    $marker = "$($capability.marker)".Trim()
    if (![string]::IsNullOrWhiteSpace($marker)) {
      $value = "1"
      if ($expectedValues.ContainsKey($marker)) {
        $value = $expectedValues[$marker]
      }
      $markerValues[$marker] = $value
      $lines += $marker
      $lines += $value
    }
  }
  foreach ($conditional in @($status.native_smoke_conditional_capabilities)) {
    $marker = "$($conditional.marker)".Trim()
    $whenMarker = "$($conditional.when_marker)".Trim()
    $whenValue = "$($conditional.when_value)".Trim()
    if (![string]::IsNullOrWhiteSpace($marker) -and
      $markerValues.ContainsKey($whenMarker) -and
      $markerValues[$whenMarker] -eq $whenValue) {
      $lines += $marker
      $lines += "1"
    }
  }
  $lines += "moui_skia native smoke test passed"
  $lines | Set-Content -LiteralPath $Path
}

function New-FakeLinuxSourceArtifact {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Directory,
    [string] $Commit = "0123456789abcdef0123456789abcdef01234567",
    [string] $BuildCommit = "0123456789abcdef0123456789abcdef01234567",
    [string] $AcceptanceCommit = "0123456789abcdef0123456789abcdef01234567",
    [switch] $OmitWrapperBuildLog,
    [switch] $OmitAcceptanceBuildLog
  )

  New-Item -ItemType Directory -Force -Path $Directory | Out-Null
  $preflightLog = Join-Path $Directory "linux-real-skia-smoke-preflight.log"
  $wrapperLog = Join-Path $Directory "linux-real-skia-smoke.log"
  $buildLog = Join-Path $Directory "linux-skia-build.log"
  $nativeLog = Join-Path $Directory "linux-native-smoke-output.log"
  $acceptanceLog = Join-Path $Directory "linux-real-skia-acceptance.log"

  "Linux Skia dry-run preflight" | Set-Content -LiteralPath $preflightLog
  $wrapperLines = @(
    "Linux Skia smoke environment:"
    "  skia_include=C:/fake/skia"
    "  skia_lib_dir=C:/fake/skia/out/moonbit-smoke"
    "  skia_lib=skia"
    "  skia_commit=$Commit"
    "  library=libskia.a 123 bytes"
    "  stub_cc_flags=-DMOUI_SKIA_HAS_SKIA -IC:/fake/skia"
    "  cc_link_flags=-LC:/fake/skia/out/moonbit-smoke -lskia"
  )
  if (!$OmitWrapperBuildLog) {
    $wrapperLines += "  build_log=$buildLog"
  }
  $wrapperLines | Set-Content -LiteralPath $wrapperLog

  @(
    "Linux Skia source build environment:"
    "  git=git version 2.0.0"
    "  python3=Python 3.12.0"
    "  ninja=1.11.1"
    "  clang=Ubuntu clang version 18.0.0"
    "  clang++=Ubuntu clang version 18.0.0"
    "  skia_checkout=C:/fake/skia"
    "  skia_commit=$BuildCommit"
    "  gn=1.0.0"
    "  gn_args=is_official_build=true cc=`"clang`" cxx=`"clang++`""
  ) | Set-Content -LiteralPath $buildLog
  Set-FakeNativeSmokeLog -Path $nativeLog

  $acceptanceLines = @(
    "Linux real Skia acceptance result:"
    "  smoke_status=0"
    "  native_smoke_marker=passed"
    "  native_pkg_restore=passed"
    "  skia_commit=$AcceptanceCommit"
    "  preflight_log=$preflightLog"
    "  wrapper_log=$wrapperLog"
  )
  if (!$OmitAcceptanceBuildLog) {
    $acceptanceLines += "  build_log=$buildLog"
  }
  $acceptanceLines += @(
    "  native_log=$nativeLog"
    "  acceptance_log=$acceptanceLog"
  )
  $acceptanceLines | Set-Content -LiteralPath $acceptanceLog
}

function New-FakeReleaseArtifact {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Directory,
    [string] $Owner = "wzzc-dev",
    [string] $Repo = "skia",
    [string] $Tag = "dev-6d73578a36",
    [string] $ReleaseUrl = "https://github.com/wzzc-dev/skia/releases/tag/dev-6d73578a36",
    [string] $Commit = "6d73578a36506d10bc044e920cc71037982e481d",
    [string] $Package = "Skia-dev-6d73578a36-windows-Release-x64.zip",
    [string] $Sha256 = "c38ef245dc18dec445b371ed66cf6ae13d11ef804cfd1f11bf5139294f9c80fd",
    [string] $LinkMode = "static",
    [string] $AcceptanceOwner = "",
    [string] $AcceptanceRepo = "",
    [string] $AcceptanceCommit = "",
    [string] $AcceptanceTag = "",
    [string] $AcceptanceReleaseUrl = "",
    [string] $AcceptancePackage = "",
    [string] $AcceptanceSha256 = "",
    [string] $AcceptanceLinkMode = ""
  )

  if ([string]::IsNullOrWhiteSpace($AcceptanceOwner)) {
    $AcceptanceOwner = $Owner
  }
  if ([string]::IsNullOrWhiteSpace($AcceptanceRepo)) {
    $AcceptanceRepo = $Repo
  }
  if ([string]::IsNullOrWhiteSpace($AcceptanceCommit)) {
    $AcceptanceCommit = $Commit
  }
  if ([string]::IsNullOrWhiteSpace($AcceptanceTag)) {
    $AcceptanceTag = $Tag
  }
  if ([string]::IsNullOrWhiteSpace($AcceptanceReleaseUrl)) {
    $AcceptanceReleaseUrl = $ReleaseUrl
  }
  if ([string]::IsNullOrWhiteSpace($AcceptancePackage)) {
    $AcceptancePackage = $Package
  }
  if ([string]::IsNullOrWhiteSpace($AcceptanceSha256)) {
    $AcceptanceSha256 = $Sha256
  }
  if ([string]::IsNullOrWhiteSpace($AcceptanceLinkMode)) {
    $AcceptanceLinkMode = $LinkMode
  }

  New-Item -ItemType Directory -Force -Path $Directory | Out-Null
  $preflightLog = Join-Path $Directory "windows-real-skia-smoke-preflight.log"
  $wrapperLog = Join-Path $Directory "windows-real-skia-smoke.log"
  $nativeLog = Join-Path $Directory "windows-native-smoke-output.log"
  $acceptanceLog = Join-Path $Directory "windows-real-skia-acceptance.log"
  if ($LinkMode.Trim().ToLowerInvariant() -eq "dynamic") {
    $libraryLines = @("  library=skia.dll.lib 123 bytes")
    $libraryLines += "  library=skia.dll 456 bytes"
    $linkLibrary = "skia.dll.lib"
  } else {
    $libraryLines = @("  library=skia.lib 123 bytes")
    $linkLibrary = "skia.lib"
  }

  "release Skia provider dry run" | Set-Content -LiteralPath $preflightLog
  $wrapperLines = @(
    "Windows MSVC Skia smoke environment:"
    "  skia_include=C:/fake/skia"
    "  skia_lib_dir=C:/fake/skia/out/Release-x64"
    "  skia_lib=skia"
    "  skia_link_mode=$LinkMode"
    "  skia_provider=release"
    "  release_owner=$Owner"
    "  release_repo=$Repo"
    "  release_tag=$Tag"
    "  release_url=$ReleaseUrl"
    "  skia_commit=$Commit"
    "  skia_package=$Package"
    "  skia_package_sha256=$Sha256"
  ) + $libraryLines + @(
    "  stub_cc_flags=/DMOUI_SKIA_HAS_SKIA /IC:/fake/skia"
    "  cc_link_flags=C:/fake/skia/out/Release-x64/$linkLibrary user32.lib"
  )
  $wrapperLines | Set-Content -LiteralPath $wrapperLog
  Set-FakeNativeSmokeLog -Path $nativeLog
  @(
    "Windows MSVC real Skia acceptance result:"
    "  smoke_status=0"
    "  native_smoke_marker=passed"
    "  native_pkg_restore=passed"
    "  skia_provider=release"
    "  skia_link_mode=$AcceptanceLinkMode"
    "  release_owner=$AcceptanceOwner"
    "  release_repo=$AcceptanceRepo"
    "  release_tag=$AcceptanceTag"
    "  release_url=$AcceptanceReleaseUrl"
    "  skia_commit=$AcceptanceCommit"
    "  skia_package=$AcceptancePackage"
    "  skia_package_sha256=$AcceptanceSha256"
    "  preflight_log=$preflightLog"
    "  wrapper_log=$wrapperLog"
    "  native_log=$nativeLog"
    "  acceptance_log=$acceptanceLog"
  ) | Set-Content -LiteralPath $acceptanceLog
}

Push-Location $repoRoot
try {
  moon fmt
  moon check --fmt
  moon check
  moon check --target all
  if (!$SkipInfo) {
    moon info
  }
  moon test
  Get-Content -LiteralPath (Join-Path $repoRoot "skia-provider-lock.json") -Raw | ConvertFrom-Json | Out-Null
  Get-Content -LiteralPath (Join-Path $repoRoot "native/ownership.json") -Raw | ConvertFrom-Json | Out-Null
  & (Join-Path $repoRoot "scripts/verify-native-ownership.ps1")
  & (Join-Path $repoRoot "scripts/verify-native-ffi-borrows.ps1")
  & (Join-Path $repoRoot "scripts/verify-native-fallback-parity.ps1")
  & (Join-Path $repoRoot "scripts/verify-example-link-config.ps1")
  & (Join-Path $repoRoot "scripts/verify-native-smoke-capabilities.ps1")
  & (Join-Path $repoRoot "scripts/verify-native-capability-contract.ps1")
  Assert-WorkflowUsesHashtableSplatting -Path (Resolve-WorkflowPath ".github/workflows/moui-skia-provider-windows-real-skia-manual.yml")
  Assert-WorkflowUsesHashtableSplatting -Path (Resolve-WorkflowPath ".github/workflows/moui-skia-provider-real-skia-acceptance.yml")
  Assert-WindowsMsvcSmokePassesResolvedLinkMode

  Push-Location (Join-Path $repoRoot "scripts/native_smoke")
  try {
    moon check
    moon build --target native
  } finally {
    Pop-Location
  }

  $beforeNativePkgHash = Get-Sha256Hex -Path $nativePkg
  $beforeSmokePkgHash = Get-Sha256Hex -Path $smokePkg
  $dryRunRoot = Join-Path $repoRoot ".skia-dry-run/windows-fallback"
  try {
    $fakeSkiaInclude = Join-Path $dryRunRoot "skia"
    $fakeSkiaLibDir = Join-Path $dryRunRoot "lib"
    New-Item -ItemType Directory -Force -Path (Join-Path $fakeSkiaInclude "include/core") | Out-Null
    New-Item -ItemType Directory -Force -Path $fakeSkiaLibDir | Out-Null
    New-Item -ItemType File -Force -Path (Join-Path $fakeSkiaInclude "include/core/SkSurface.h") | Out-Null
    New-Item -ItemType File -Force -Path (Join-Path $fakeSkiaLibDir "libskia.a") | Out-Null

    & (Join-Path $repoRoot "scripts/windows-skia-smoke.ps1") `
      -SkiaInclude $fakeSkiaInclude `
      -SkiaLibDir $fakeSkiaLibDir `
      -DryRunConfig

    $fakeWindowsNativePkg = Join-Path $dryRunRoot "fake-windows-native.moon.pkg"
    & (Join-Path $repoRoot "scripts/configure-windows-native-pkg.ps1") `
      -SkiaInclude $fakeSkiaInclude `
      -SkiaLibDir $fakeSkiaLibDir `
      -ExtraCcFlags "-DMOUI_SKIA_FAKE_CONFIG_CC" `
      -ExtraLinkFlags "-lskia_fake_config_dep" `
      -Output $fakeWindowsNativePkg `
      -Write
    & (Join-Path $repoRoot "scripts/configure-windows-native-pkg.ps1") `
      -SkiaInclude $fakeSkiaInclude `
      -SkiaLibDir $fakeSkiaLibDir `
      -ExtraCcFlags "-DMOUI_SKIA_FAKE_CONFIG_CC" `
      -ExtraLinkFlags "-lskia_fake_config_dep" `
      -Output $fakeWindowsNativePkg `
      -Check
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/configure-windows-native-pkg.ps1") -SkiaInclude $fakeSkiaInclude -SkiaLibDir $fakeSkiaLibDir -Output $fakeWindowsNativePkg -Check } `
      -ExpectedMessage "does not match generated Windows Skia link config"

    $env:MOUI_SKIA_SKIA_INCLUDE = $fakeSkiaInclude
    $env:MOUI_SKIA_SKIA_LIB_DIR = $fakeSkiaLibDir
    $env:MOUI_SKIA_EXTRA_CC_FLAGS = "-DMOUI_SKIA_FAKE_ENV_CC"
    $env:MOUI_SKIA_EXTRA_LINK_FLAGS = "-lskia_fake_env_dep"
    try {
      & (Join-Path $repoRoot "scripts/windows-skia-smoke.ps1") -DryRunConfig
    } finally {
      Remove-Item Env:MOUI_SKIA_SKIA_INCLUDE -ErrorAction SilentlyContinue
      Remove-Item Env:MOUI_SKIA_SKIA_LIB_DIR -ErrorAction SilentlyContinue
      Remove-Item Env:MOUI_SKIA_EXTRA_CC_FLAGS -ErrorAction SilentlyContinue
      Remove-Item Env:MOUI_SKIA_EXTRA_LINK_FLAGS -ErrorAction SilentlyContinue
    }

    Assert-NativePkgUnchanged -ExpectedHash $beforeNativePkgHash -ExpectedSmokeHash $beforeSmokePkgHash

    $fetchDryRunEnv = & (Join-Path $repoRoot "scripts/fetch-release-skia.ps1") `
      -Platform windows `
      -Arch x64 `
      -Config Release `
      -LinkMode static `
      -CacheDir (Join-Path $dryRunRoot "release-cache") `
      -DryRunConfig `
      -PrintEnv
    if (($fetchDryRunEnv -join "`n") -notlike "*MOUI_SKIA_SKIA_PROVIDER=release*" -or
      ($fetchDryRunEnv -join "`n") -notlike "*MOUI_SKIA_LINK_MODE=static*" -or
      ($fetchDryRunEnv -join "`n") -notlike "*MOUI_SKIA_SKIA_PACKAGE=Skia-dev-6d73578a36-windows-Release-x64.zip*" -or
      ($fetchDryRunEnv -join "`n") -notlike "*MOUI_SKIA_SKIA_PACKAGE_SHA256=c38ef245dc18dec445b371ed66cf6ae13d11ef804cfd1f11bf5139294f9c80fd*") {
      throw "fetch-release-skia.ps1 did not map Windows x64 Release static to the locked package"
    }

    $fetchDynamicDryRunEnv = & (Join-Path $repoRoot "scripts/fetch-release-skia.ps1") `
      -Platform windows `
      -Arch x64 `
      -Config Release `
      -LinkMode dynamic `
      -CacheDir (Join-Path $dryRunRoot "release-cache") `
      -DryRunConfig `
      -PrintEnv
    if (($fetchDynamicDryRunEnv -join "`n") -notlike "*MOUI_SKIA_LINK_MODE=dynamic*" -or
      ($fetchDynamicDryRunEnv -join "`n") -notlike "*MOUI_SKIA_SKIA_PACKAGE=Skia-dev-6d73578a36-windows-Release-x64-shared.zip*" -or
      ($fetchDynamicDryRunEnv -join "`n") -notlike "*MOUI_SKIA_SKIA_PACKAGE_SHA256=2a8a54ae44c0370d8b20000e0bc044bf0da14059b76bcfde00256c37fb0ea41c*") {
      throw "fetch-release-skia.ps1 did not map Windows x64 Release dynamic to the locked package"
    }

    $fetchHarmonyosDryRunEnv = & (Join-Path $repoRoot "scripts/fetch-release-skia.ps1") `
      -Platform harmonyos `
      -Arch arm64 `
      -Config Release `
      -LinkMode dynamic `
      -CacheDir (Join-Path $dryRunRoot "release-cache") `
      -DryRunConfig `
      -PrintEnv
    if (($fetchHarmonyosDryRunEnv -join "`n") -notlike "*MOUI_SKIA_SKIA_PROVIDER=harmonyos_release*" -or
      ($fetchHarmonyosDryRunEnv -join "`n") -notlike "*MOUI_SKIA_LINK_MODE=dynamic*" -or
      ($fetchHarmonyosDryRunEnv -join "`n") -notlike "*MOUI_SKIA_SKIA_PACKAGE=Skia-dev-fcb9c18e54-harmonyos-Release-arm64-shared.zip*" -or
      ($fetchHarmonyosDryRunEnv -join "`n") -notlike "*MOUI_SKIA_SKIA_PACKAGE_SHA256=55c050fec9da3468c56022b7188cb133ca476c4c90d9ce1aa67d31f22f374aa1*") {
      throw "fetch-release-skia.ps1 did not map HarmonyOS arm64 Release dynamic to the locked package"
    }

    $fakeMsvcSharedRoot = Join-Path $dryRunRoot "fake-msvc-shared-root"
    New-Item -ItemType Directory -Force -Path (Join-Path $fakeMsvcSharedRoot "include/core") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $fakeMsvcSharedRoot "out/Release-windows-x64-shared") | Out-Null
    New-Item -ItemType File -Force -Path (Join-Path $fakeMsvcSharedRoot "include/core/SkSurface.h") | Out-Null
    New-Item -ItemType File -Force -Path (Join-Path $fakeMsvcSharedRoot "out/Release-windows-x64-shared/skia.dll.lib") | Out-Null
    New-Item -ItemType File -Force -Path (Join-Path $fakeMsvcSharedRoot "out/Release-windows-x64-shared/skia.dll") | Out-Null
    $fakeMsvcSharedZip = Join-Path $dryRunRoot "Skia-dev-6d73578a36-windows-Release-x64-shared.zip"
    Compress-Archive -Path (Join-Path $fakeMsvcSharedRoot "*") -DestinationPath $fakeMsvcSharedZip -Force
    $fakeMsvcSharedExtract = Join-Path $dryRunRoot "fake-msvc-shared-extract"
    $fakeMsvcSharedPkg = Join-Path $dryRunRoot "fake-msvc-shared.moon.pkg"
    & (Join-Path $repoRoot "scripts/configure-windows-msvc-native-pkg.ps1") `
      -SkiaRoot $fakeMsvcSharedExtract `
      -SkiaZip $fakeMsvcSharedZip `
      -SkiaLinkMode dynamic `
      -Output $fakeMsvcSharedPkg `
      -Write
    $fakeMsvcSharedConfig = Get-Content -LiteralPath $fakeMsvcSharedPkg -Raw
    if ($fakeMsvcSharedConfig -notlike "*out/Release-windows-x64-shared/skia.dll.lib*" -or
      $fakeMsvcSharedConfig -notlike "*/DMOUI_SKIA_HAS_SKIA*" -or
      $fakeMsvcSharedConfig -notlike "*cc-link-flags*") {
      throw "configure-windows-msvc-native-pkg.ps1 did not resolve the Windows shared release zip layout"
    }
    & (Join-Path $repoRoot "scripts/configure-windows-msvc-native-pkg.ps1") `
      -SkiaRoot $fakeMsvcSharedExtract `
      -SkiaLinkMode dynamic `
      -Output $fakeMsvcSharedPkg `
      -Check

    try {
      & (Join-Path $repoRoot "scripts/windows-accept-real-skia-smoke.ps1") `
        -SkiaInclude $fakeSkiaInclude `
        -SkiaLibDir $fakeSkiaLibDir `
        -DryRunConfig
      throw "windows acceptance dry-run unexpectedly succeeded"
    } catch {
      if ($_.Exception.Message -notlike "*acceptance requires a real smoke run*") {
        throw
      }
    }

    Assert-NativePkgUnchanged -ExpectedHash $beforeNativePkgHash -ExpectedSmokeHash $beforeSmokePkgHash

    $fakeNativeSmokeLog = Join-Path $dryRunRoot "fake-native-smoke.log"
    Set-FakeNativeSmokeLog -Path $fakeNativeSmokeLog
    & (Join-Path $repoRoot "scripts/verify-native-smoke-log.ps1") -LogPath $fakeNativeSmokeLog

    $fakeMissingConditionalNativeSmokeLog = Join-Path $dryRunRoot "fake-native-smoke-missing-conditional.log"
    $missingConditionalLines = @()
    $nativeSmokeLines = @(Get-Content -LiteralPath $fakeNativeSmokeLog)
    for ($index = 0; $index -lt $nativeSmokeLines.Count; $index += 1) {
      if ($nativeSmokeLines[$index] -eq "native smoke shaped glyph count") {
        $index += 1
      } else {
        $missingConditionalLines += $nativeSmokeLines[$index]
      }
    }
    $missingConditionalLines | Set-Content -LiteralPath $fakeMissingConditionalNativeSmokeLog
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-native-smoke-log.ps1") -LogPath $fakeMissingConditionalNativeSmokeLog } `
      -ExpectedMessage "conditional stage marker"

    $fakeUnavailableConditionalNativeSmokeLog = Join-Path $dryRunRoot "fake-native-smoke-unavailable-conditional.log"
    $unavailableConditionalLines = @()
    for ($index = 0; $index -lt $nativeSmokeLines.Count; $index += 1) {
      if ($nativeSmokeLines[$index] -eq "native smoke shaper availability" -and $index + 1 -lt $nativeSmokeLines.Count) {
        $unavailableConditionalLines += $nativeSmokeLines[$index]
        $unavailableConditionalLines += "0"
        $index += 1
      } elseif ($nativeSmokeLines[$index] -eq "native smoke shaped glyph count") {
        $index += 1
      } else {
        $unavailableConditionalLines += $nativeSmokeLines[$index]
      }
    }
    $unavailableConditionalLines | Set-Content -LiteralPath $fakeUnavailableConditionalNativeSmokeLog
    & (Join-Path $repoRoot "scripts/verify-native-smoke-log.ps1") -LogPath $fakeUnavailableConditionalNativeSmokeLog

    $fakePrefixedSuccessNativeSmokeLog = Join-Path $dryRunRoot "fake-native-smoke-prefixed-success.log"
    (Get-Content -LiteralPath $fakeNativeSmokeLog) `
      -replace "^moui_skia native smoke test passed$", "not_moui_skia native smoke test passed" `
      | Set-Content -LiteralPath $fakePrefixedSuccessNativeSmokeLog
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-native-smoke-log.ps1") -LogPath $fakePrefixedSuccessNativeSmokeLog } `
      -ExpectedMessage "success marker"

    $fakePrefixedStageNativeSmokeLog = Join-Path $dryRunRoot "fake-native-smoke-prefixed-stage.log"
    (Get-Content -LiteralPath $fakeNativeSmokeLog) `
      -replace "^native smoke surface descriptor backend$", "not_native smoke surface descriptor backend" `
      | Set-Content -LiteralPath $fakePrefixedStageNativeSmokeLog
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-native-smoke-log.ps1") -LogPath $fakePrefixedStageNativeSmokeLog } `
      -ExpectedMessage "required stage marker"

    $fakeMissingStageNativeSmokeLog = Join-Path $dryRunRoot "fake-native-smoke-missing-stage.log"
    Set-Content -LiteralPath $fakeMissingStageNativeSmokeLog -Value "moui_skia native smoke test passed"
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-native-smoke-log.ps1") -LogPath $fakeMissingStageNativeSmokeLog } `
      -ExpectedMessage "required stage marker"

    $fakeBadStageValueNativeSmokeLog = Join-Path $dryRunRoot "fake-native-smoke-bad-stage-value.log"
    Set-FakeNativeSmokeLog -Path $fakeBadStageValueNativeSmokeLog
    $badStageValueLines = @(Get-Content -LiteralPath $fakeBadStageValueNativeSmokeLog)
    for ($index = 0; $index -lt $badStageValueLines.Count - 1; $index += 1) {
      if ($badStageValueLines[$index] -eq "native smoke text run resource plan count") {
        $badStageValueLines[$index + 1] = "2"
        break
      }
    }
    $badStageValueLines | Set-Content -LiteralPath $fakeBadStageValueNativeSmokeLog
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-native-smoke-log.ps1") -LogPath $fakeBadStageValueNativeSmokeLog } `
      -ExpectedMessage "unexpected stage marker value"

    $fakeBadNativeSmokeLog = Join-Path $dryRunRoot "fake-native-smoke-missing-marker.log"
    Set-Content -LiteralPath $fakeBadNativeSmokeLog -Value "native smoke stopped before marker"
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-native-smoke-log.ps1") -LogPath $fakeBadNativeSmokeLog } `
      -ExpectedMessage "success marker"

    $fakeGoodAcceptanceLog = Join-Path $dryRunRoot "fake-acceptance-good.log"
    @(
      "Windows real Skia acceptance result:"
      "  smoke_status=0"
      "  native_smoke_marker=passed"
      "  native_pkg_restore=passed"
      "  skia_commit=0123456789abcdef0123456789abcdef01234567"
    ) | Set-Content -LiteralPath $fakeGoodAcceptanceLog
    & (Join-Path $repoRoot "scripts/verify-acceptance-log.ps1") -LogPath $fakeGoodAcceptanceLog
    & (Join-Path $repoRoot "scripts/verify-acceptance-log.ps1") -LogPath $fakeGoodAcceptanceLog -RequireCommit

    $fakePrefixedStatusAcceptanceLog = Join-Path $dryRunRoot "fake-acceptance-prefixed-status.log"
    @(
      "Windows real Skia acceptance result:"
      "  not_smoke_status=0"
      "  native_smoke_marker=passed"
      "  native_pkg_restore=passed"
    ) | Set-Content -LiteralPath $fakePrefixedStatusAcceptanceLog
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-acceptance-log.ps1") -LogPath $fakePrefixedStatusAcceptanceLog } `
      -ExpectedMessage "smoke_status=0"

    $fakePrefixedCommitAcceptanceLog = Join-Path $dryRunRoot "fake-acceptance-prefixed-commit.log"
    @(
      "Windows real Skia acceptance result:"
      "  smoke_status=0"
      "  native_smoke_marker=passed"
      "  native_pkg_restore=passed"
      "  not_skia_commit=0123456789abcdef0123456789abcdef01234567"
    ) | Set-Content -LiteralPath $fakePrefixedCommitAcceptanceLog
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-acceptance-log.ps1") -LogPath $fakePrefixedCommitAcceptanceLog -RequireCommit } `
      -ExpectedMessage "skia_commit"

    $fakePinnedRevision = Join-Path $dryRunRoot "fake-skia-revision.txt"
    Set-Content -LiteralPath $fakePinnedRevision -Value "0123456789abcdef0123456789abcdef01234567"
    & (Join-Path $repoRoot "scripts/verify-skia-revision-pin.ps1") `
      -AcceptanceLog $fakeGoodAcceptanceLog `
      -RevisionFile $fakePinnedRevision

    $fakePinnedByPowerShellRevision = Join-Path $dryRunRoot "fake-skia-revision-pinned-by-powershell.txt"
    & (Join-Path $repoRoot "scripts/pin-skia-revision.ps1") `
      -AcceptanceLog $fakeGoodAcceptanceLog `
      -RevisionFile $fakePinnedByPowerShellRevision
    if ((Get-Content -LiteralPath $fakePinnedByPowerShellRevision -Raw).Trim() -ne "0123456789abcdef0123456789abcdef01234567") {
      throw "PowerShell pin-skia-revision wrote an unexpected revision"
    }
    & (Join-Path $repoRoot "scripts/verify-skia-revision-pin.ps1") `
      -AcceptanceLog $fakeGoodAcceptanceLog `
      -RevisionFile $fakePinnedByPowerShellRevision

    $fakeFloatingRevision = Join-Path $dryRunRoot "fake-floating-skia-revision.txt"
    Set-Content -LiteralPath $fakeFloatingRevision -Value "main"
    & (Join-Path $repoRoot "scripts/verify-skia-revision-pin.ps1") `
      -AcceptanceLog $fakeGoodAcceptanceLog `
      -RevisionFile $fakeFloatingRevision `
      -SkipIfUnpinned
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-skia-revision-pin.ps1") -AcceptanceLog $fakeGoodAcceptanceLog -RevisionFile $fakeFloatingRevision } `
      -ExpectedMessage "not pinned to a full 40-character commit"

    $fakeMismatchedRevision = Join-Path $dryRunRoot "fake-mismatched-skia-revision.txt"
    Set-Content -LiteralPath $fakeMismatchedRevision -Value "fedcba9876543210fedcba9876543210fedcba98"
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-skia-revision-pin.ps1") -AcceptanceLog $fakeGoodAcceptanceLog -RevisionFile $fakeMismatchedRevision } `
      -ExpectedMessage "does not match acceptance commit"

    $fakeNoCommitAcceptanceLog = Join-Path $dryRunRoot "fake-acceptance-no-commit.log"
    @(
      "Windows real Skia acceptance result:"
      "  smoke_status=0"
      "  native_smoke_marker=passed"
      "  native_pkg_restore=passed"
      "  skia_commit=unknown"
    ) | Set-Content -LiteralPath $fakeNoCommitAcceptanceLog
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-acceptance-log.ps1") -LogPath $fakeNoCommitAcceptanceLog -RequireCommit } `
      -ExpectedMessage "full 40-character skia_commit hash"
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/pin-skia-revision.ps1") -AcceptanceLog $fakeNoCommitAcceptanceLog -RevisionFile (Join-Path $dryRunRoot "should-not-pin-no-commit.txt") } `
      -ExpectedMessage "full 40-character skia_commit hash"

    $fakeMissingRestoreAcceptanceLog = Join-Path $dryRunRoot "fake-acceptance-missing-restore.log"
    @(
      "Windows real Skia acceptance result:"
      "  smoke_status=0"
      "  native_smoke_marker=passed"
      "  skia_commit=0123456789abcdef0123456789abcdef01234567"
    ) | Set-Content -LiteralPath $fakeMissingRestoreAcceptanceLog
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-acceptance-log.ps1") -LogPath $fakeMissingRestoreAcceptanceLog } `
      -ExpectedMessage "native_pkg_restore=passed"
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/pin-skia-revision.ps1") -AcceptanceLog $fakeMissingRestoreAcceptanceLog -RevisionFile (Join-Path $dryRunRoot "should-not-pin-missing-restore.txt") } `
      -ExpectedMessage "native_pkg_restore=passed"

    $fakeArtifactDir = Join-Path $dryRunRoot "fake-artifact"
    New-Item -ItemType Directory -Force -Path $fakeArtifactDir | Out-Null
    $fakeArtifactPreflightLog = Join-Path $fakeArtifactDir "windows-real-skia-smoke-preflight.log"
    $fakeArtifactWrapperLog = Join-Path $fakeArtifactDir "windows-real-skia-smoke.log"
    $fakeArtifactNativeLog = Join-Path $fakeArtifactDir "windows-native-smoke-output.log"
    $fakeArtifactAcceptanceLog = Join-Path $fakeArtifactDir "windows-real-skia-acceptance.log"
    Set-Content -LiteralPath $fakeArtifactPreflightLog -Value "Windows Skia dry-run preflight"
    @(
      "Windows Skia smoke environment:"
      "  skia_include=C:/fake/skia"
      "  skia_lib_dir=C:/fake/skia/out/moonbit-smoke"
      "  skia_lib=skia"
      "  skia_commit=0123456789abcdef0123456789abcdef01234567"
      "  library=libskia.a 123 bytes"
      "  stub_cc_flags=-DMOUI_SKIA_HAS_SKIA -IC:/fake/skia"
      "  cc_link_flags=-LC:/fake/skia/out/moonbit-smoke -lskia"
    ) | Set-Content -LiteralPath $fakeArtifactWrapperLog
    Set-FakeNativeSmokeLog -Path $fakeArtifactNativeLog
    @(
      "Windows real Skia acceptance result:"
      "  smoke_status=0"
      "  native_smoke_marker=passed"
      "  native_pkg_restore=passed"
      "  skia_commit=0123456789abcdef0123456789abcdef01234567"
      "  preflight_log=$fakeArtifactPreflightLog"
      "  wrapper_log=$fakeArtifactWrapperLog"
      "  native_log=$fakeArtifactNativeLog"
      "  acceptance_log=$fakeArtifactAcceptanceLog"
    ) | Set-Content -LiteralPath $fakeArtifactAcceptanceLog
    & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") `
      -Platform windows `
      -LogDir $fakeArtifactDir `
      -RequireCommit

    $fakeDryRunArtifactDir = Join-Path $dryRunRoot "fake-artifact-dry-run-wrapper"
    New-Item -ItemType Directory -Force -Path $fakeDryRunArtifactDir | Out-Null
    Copy-Item -LiteralPath $fakeArtifactPreflightLog -Destination (Join-Path $fakeDryRunArtifactDir "windows-real-skia-smoke-preflight.log")
    Copy-Item -LiteralPath $fakeArtifactNativeLog -Destination (Join-Path $fakeDryRunArtifactDir "windows-native-smoke-output.log")
    Copy-Item -LiteralPath $fakeArtifactAcceptanceLog -Destination (Join-Path $fakeDryRunArtifactDir "windows-real-skia-acceptance.log")
    Copy-Item -LiteralPath $fakeArtifactWrapperLog -Destination (Join-Path $fakeDryRunArtifactDir "windows-real-skia-smoke.log")
    Add-Content -LiteralPath (Join-Path $fakeDryRunArtifactDir "windows-real-skia-smoke.log") `
      -Value "dry_run_config=true; real Windows smoke was not run"
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") -Platform windows -LogDir $fakeDryRunArtifactDir -RequireCommit } `
      -ExpectedMessage "artifact wrapper log is from a dry-run configuration"

    $fakeNativeDryRunArtifactDir = Join-Path $dryRunRoot "fake-artifact-dry-run-native"
    New-Item -ItemType Directory -Force -Path $fakeNativeDryRunArtifactDir | Out-Null
    Copy-Item -LiteralPath $fakeArtifactPreflightLog -Destination (Join-Path $fakeNativeDryRunArtifactDir "windows-real-skia-smoke-preflight.log")
    Copy-Item -LiteralPath $fakeArtifactWrapperLog -Destination (Join-Path $fakeNativeDryRunArtifactDir "windows-real-skia-smoke.log")
    Copy-Item -LiteralPath $fakeArtifactAcceptanceLog -Destination (Join-Path $fakeNativeDryRunArtifactDir "windows-real-skia-acceptance.log")
    Copy-Item -LiteralPath $fakeArtifactNativeLog -Destination (Join-Path $fakeNativeDryRunArtifactDir "windows-native-smoke-output.log")
    Add-Content -LiteralPath (Join-Path $fakeNativeDryRunArtifactDir "windows-native-smoke-output.log") `
      -Value "Dry run complete; no build was run."
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") -Platform windows -LogDir $fakeNativeDryRunArtifactDir -RequireCommit } `
      -ExpectedMessage "artifact native smoke log is from a dry-run configuration"

    $fakeAcceptanceDryRunArtifactDir = Join-Path $dryRunRoot "fake-artifact-dry-run-acceptance"
    New-Item -ItemType Directory -Force -Path $fakeAcceptanceDryRunArtifactDir | Out-Null
    Copy-Item -LiteralPath $fakeArtifactPreflightLog -Destination (Join-Path $fakeAcceptanceDryRunArtifactDir "windows-real-skia-smoke-preflight.log")
    Copy-Item -LiteralPath $fakeArtifactWrapperLog -Destination (Join-Path $fakeAcceptanceDryRunArtifactDir "windows-real-skia-smoke.log")
    Copy-Item -LiteralPath $fakeArtifactNativeLog -Destination (Join-Path $fakeAcceptanceDryRunArtifactDir "windows-native-smoke-output.log")
    Copy-Item -LiteralPath $fakeArtifactAcceptanceLog -Destination (Join-Path $fakeAcceptanceDryRunArtifactDir "windows-real-skia-acceptance.log")
    Add-Content -LiteralPath (Join-Path $fakeAcceptanceDryRunArtifactDir "windows-real-skia-acceptance.log") `
      -Value "dry-run=true"
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") -Platform windows -LogDir $fakeAcceptanceDryRunArtifactDir -RequireCommit } `
      -ExpectedMessage "artifact acceptance log is from a dry-run configuration"

    $fakePrefixedWrapperFieldArtifactDir = Join-Path $dryRunRoot "fake-artifact-prefixed-wrapper-field"
    New-Item -ItemType Directory -Force -Path $fakePrefixedWrapperFieldArtifactDir | Out-Null
    Copy-Item -LiteralPath $fakeArtifactPreflightLog -Destination (Join-Path $fakePrefixedWrapperFieldArtifactDir "windows-real-skia-smoke-preflight.log")
    Copy-Item -LiteralPath $fakeArtifactNativeLog -Destination (Join-Path $fakePrefixedWrapperFieldArtifactDir "windows-native-smoke-output.log")
    Copy-Item -LiteralPath $fakeArtifactAcceptanceLog -Destination (Join-Path $fakePrefixedWrapperFieldArtifactDir "windows-real-skia-acceptance.log")
    (Get-Content -LiteralPath $fakeArtifactWrapperLog) `
      -replace "skia_include=", "not_skia_include=" `
      | Set-Content -LiteralPath (Join-Path $fakePrefixedWrapperFieldArtifactDir "windows-real-skia-smoke.log")
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") -Platform windows -LogDir $fakePrefixedWrapperFieldArtifactDir -RequireCommit } `
      -ExpectedMessage "wrapper log is missing required field: skia_include="

    $fakePrefixedAcceptanceReferenceArtifactDir = Join-Path $dryRunRoot "fake-artifact-prefixed-acceptance-reference"
    New-Item -ItemType Directory -Force -Path $fakePrefixedAcceptanceReferenceArtifactDir | Out-Null
    Copy-Item -LiteralPath $fakeArtifactPreflightLog -Destination (Join-Path $fakePrefixedAcceptanceReferenceArtifactDir "windows-real-skia-smoke-preflight.log")
    Copy-Item -LiteralPath $fakeArtifactWrapperLog -Destination (Join-Path $fakePrefixedAcceptanceReferenceArtifactDir "windows-real-skia-smoke.log")
    Copy-Item -LiteralPath $fakeArtifactNativeLog -Destination (Join-Path $fakePrefixedAcceptanceReferenceArtifactDir "windows-native-smoke-output.log")
    (Get-Content -LiteralPath $fakeArtifactAcceptanceLog) `
      -replace "preflight_log=", "not_preflight_log=" `
      | Set-Content -LiteralPath (Join-Path $fakePrefixedAcceptanceReferenceArtifactDir "windows-real-skia-acceptance.log")
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") -Platform windows -LogDir $fakePrefixedAcceptanceReferenceArtifactDir -RequireCommit } `
      -ExpectedMessage "preflight_log="

    $fakeReleaseArtifactDir = Join-Path $dryRunRoot "fake-release-artifact"
    New-FakeReleaseArtifact -Directory $fakeReleaseArtifactDir
    & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") `
      -Platform windows `
      -LogDir $fakeReleaseArtifactDir

    $fakeDynamicReleaseArtifactDir = Join-Path $dryRunRoot "fake-release-artifact-dynamic"
    New-FakeReleaseArtifact `
      -Directory $fakeDynamicReleaseArtifactDir `
      -Package "Skia-dev-6d73578a36-windows-Release-x64-shared.zip" `
      -Sha256 "2a8a54ae44c0370d8b20000e0bc044bf0da14059b76bcfde00256c37fb0ea41c" `
      -LinkMode "dynamic"
    & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") `
      -Platform windows `
      -LogDir $fakeDynamicReleaseArtifactDir

    $fakeReleaseBadShaDir = Join-Path $dryRunRoot "fake-release-artifact-bad-sha"
    New-FakeReleaseArtifact `
      -Directory $fakeReleaseBadShaDir `
      -Sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") -Platform windows -LogDir $fakeReleaseBadShaDir } `
      -ExpectedMessage "SHA256 mismatch"

    $fakeReleaseBadTagDir = Join-Path $dryRunRoot "fake-release-artifact-bad-tag"
    New-FakeReleaseArtifact `
      -Directory $fakeReleaseBadTagDir `
      -Tag "dev-bad"
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") -Platform windows -LogDir $fakeReleaseBadTagDir } `
      -ExpectedMessage "release tag mismatch"

    $fakeReleaseBadCommitDir = Join-Path $dryRunRoot "fake-release-artifact-bad-commit"
    New-FakeReleaseArtifact `
      -Directory $fakeReleaseBadCommitDir `
      -Commit "0123456789abcdef0123456789abcdef01234567"
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") -Platform windows -LogDir $fakeReleaseBadCommitDir } `
      -ExpectedMessage "release commit mismatch"

    $fakeReleaseBadPackageDir = Join-Path $dryRunRoot "fake-release-artifact-bad-package"
    New-FakeReleaseArtifact `
      -Directory $fakeReleaseBadPackageDir `
      -Package "Skia-dev-6d73578a36-windows-Release-not-locked.zip"
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") -Platform windows -LogDir $fakeReleaseBadPackageDir } `
      -ExpectedMessage "SHA256 mismatch"

    $fakeReleaseMismatchedAcceptanceDir = Join-Path $dryRunRoot "fake-release-artifact-mismatched-acceptance"
    New-FakeReleaseArtifact `
      -Directory $fakeReleaseMismatchedAcceptanceDir `
      -AcceptanceTag "dev-bad"
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") -Platform windows -LogDir $fakeReleaseMismatchedAcceptanceDir } `
      -ExpectedMessage "disagree on release release_tag"


    $fakeMacosArtifactDir = Join-Path $dryRunRoot "fake-macos-artifact"
    New-Item -ItemType Directory -Force -Path $fakeMacosArtifactDir | Out-Null
    $fakeMacosPreflightLog = Join-Path $fakeMacosArtifactDir "macos-real-skia-smoke-preflight.log"
    $fakeMacosWrapperLog = Join-Path $fakeMacosArtifactDir "macos-real-skia-smoke.log"
    $fakeMacosNativeLog = Join-Path $fakeMacosArtifactDir "macos-native-smoke-output.log"
    $fakeMacosAcceptanceLog = Join-Path $fakeMacosArtifactDir "macos-real-skia-acceptance.log"
    Set-Content -LiteralPath $fakeMacosPreflightLog -Value "macOS Skia dry-run preflight"
    @(
      "macOS Skia smoke environment:"
      "  skia_include=/fake/skia"
      "  skia_lib_dir=/fake/skia/out/moonbit-smoke"
      "  skia_lib=skia"
      "  skia_commit=0123456789abcdef0123456789abcdef01234567"
      "  library=libskia.a 123 bytes"
      "  stub_cc_flags=-DMOUI_SKIA_HAS_SKIA -I/fake/skia"
      "  cc_link_flags=-L/fake/skia/out/moonbit-smoke -lskia"
    ) | Set-Content -LiteralPath $fakeMacosWrapperLog
    Set-FakeNativeSmokeLog -Path $fakeMacosNativeLog
    @(
      "macOS real Skia acceptance result:"
      "  smoke_status=0"
      "  native_smoke_marker=passed"
      "  native_pkg_restore=passed"
      "  skia_commit=0123456789abcdef0123456789abcdef01234567"
      "  preflight_log=$fakeMacosPreflightLog"
      "  wrapper_log=$fakeMacosWrapperLog"
      "  native_log=$fakeMacosNativeLog"
      "  acceptance_log=$fakeMacosAcceptanceLog"
    ) | Set-Content -LiteralPath $fakeMacosAcceptanceLog
    & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") `
      -Platform macos `
      -LogDir $fakeMacosArtifactDir `
      -RequireCommit

    $fakeMacosMissingPreflightDir = Join-Path $dryRunRoot "fake-macos-artifact-missing-preflight"
    New-Item -ItemType Directory -Force -Path $fakeMacosMissingPreflightDir | Out-Null
    Copy-Item -LiteralPath $fakeMacosWrapperLog -Destination (Join-Path $fakeMacosMissingPreflightDir "macos-real-skia-smoke.log")
    Copy-Item -LiteralPath $fakeMacosNativeLog -Destination (Join-Path $fakeMacosMissingPreflightDir "macos-native-smoke-output.log")
    Copy-Item -LiteralPath $fakeMacosAcceptanceLog -Destination (Join-Path $fakeMacosMissingPreflightDir "macos-real-skia-acceptance.log")
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") -Platform macos -LogDir $fakeMacosMissingPreflightDir -RequireCommit } `
      -ExpectedMessage "missing expected log"
    $fakeBadArtifactDir = Join-Path $dryRunRoot "fake-artifact-missing-wrapper-field"
    New-Item -ItemType Directory -Force -Path $fakeBadArtifactDir | Out-Null
    Copy-Item -LiteralPath $fakeArtifactPreflightLog -Destination (Join-Path $fakeBadArtifactDir "windows-real-skia-smoke-preflight.log")
    Copy-Item -LiteralPath $fakeArtifactNativeLog -Destination (Join-Path $fakeBadArtifactDir "windows-native-smoke-output.log")
    Copy-Item -LiteralPath $fakeArtifactAcceptanceLog -Destination (Join-Path $fakeBadArtifactDir "windows-real-skia-acceptance.log")
    Set-Content -LiteralPath (Join-Path $fakeBadArtifactDir "windows-real-skia-smoke.log") -Value "library=libskia.a 123 bytes"
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") -Platform windows -LogDir $fakeBadArtifactDir -RequireCommit } `
      -ExpectedMessage "wrapper log is missing required field"

    $fakeLinuxArtifactDir = Join-Path $dryRunRoot "fake-linux-source-artifact"
    New-FakeLinuxSourceArtifact -Directory $fakeLinuxArtifactDir
    & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") `
      -Platform linux `
      -LogDir $fakeLinuxArtifactDir `
      -RequireCommit

    $fakeLinuxPrefixedWrapperBuildLogDir = Join-Path $dryRunRoot "fake-linux-prefixed-wrapper-build-log"
    New-FakeLinuxSourceArtifact -Directory $fakeLinuxPrefixedWrapperBuildLogDir
    (Get-Content -LiteralPath (Join-Path $fakeLinuxPrefixedWrapperBuildLogDir "linux-real-skia-smoke.log")) `
      -replace "build_log=", "not_build_log=" `
      | Set-Content -LiteralPath (Join-Path $fakeLinuxPrefixedWrapperBuildLogDir "linux-real-skia-smoke.log")
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") -Platform linux -LogDir $fakeLinuxPrefixedWrapperBuildLogDir -RequireCommit } `
      -ExpectedMessage "build_log="

    $fakeLinuxPrefixedBuildFieldDir = Join-Path $dryRunRoot "fake-linux-prefixed-build-field"
    New-FakeLinuxSourceArtifact -Directory $fakeLinuxPrefixedBuildFieldDir
    (Get-Content -LiteralPath (Join-Path $fakeLinuxPrefixedBuildFieldDir "linux-skia-build.log")) `
      -replace "skia_checkout=", "not_skia_checkout=" `
      | Set-Content -LiteralPath (Join-Path $fakeLinuxPrefixedBuildFieldDir "linux-skia-build.log")
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") -Platform linux -LogDir $fakeLinuxPrefixedBuildFieldDir -RequireCommit } `
      -ExpectedMessage "skia_checkout="

    $fakeLinuxPrefixedAcceptanceBuildLogDir = Join-Path $dryRunRoot "fake-linux-prefixed-acceptance-build-log"
    New-FakeLinuxSourceArtifact -Directory $fakeLinuxPrefixedAcceptanceBuildLogDir
    (Get-Content -LiteralPath (Join-Path $fakeLinuxPrefixedAcceptanceBuildLogDir "linux-real-skia-acceptance.log")) `
      -replace "build_log=", "not_build_log=" `
      | Set-Content -LiteralPath (Join-Path $fakeLinuxPrefixedAcceptanceBuildLogDir "linux-real-skia-acceptance.log")
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") -Platform linux -LogDir $fakeLinuxPrefixedAcceptanceBuildLogDir -RequireCommit } `
      -ExpectedMessage "build_log="

    $fakePlatformStatusDir = Join-Path $dryRunRoot "fake-accepted-platform-status"
    New-Item -ItemType Directory -Force -Path $fakePlatformStatusDir | Out-Null
    $fakePlatformStatus = Join-Path $fakePlatformStatusDir "skia-platform-status.json"
    $fakePlatformStatusRevision = Join-Path $fakePlatformStatusDir "skia-revision.txt"
    Copy-Item -LiteralPath (Join-Path $repoRoot "skia-platform-status.json") -Destination $fakePlatformStatus
    & (Join-Path $repoRoot "scripts/linux-accept-artifact-and-pin.ps1") `
      -LogDir $fakeLinuxArtifactDir `
      -RevisionFile $fakePlatformStatusRevision `
      -AcceptPlatformStatus `
      -StatusFile $fakePlatformStatus `
      -ArtifactLabel "fake-linux-source-artifact"
    if ((Get-Content -LiteralPath $fakePlatformStatusRevision -Raw).Trim() -ne "0123456789abcdef0123456789abcdef01234567") {
      throw "PowerShell Linux artifact-and-pin wrote an unexpected revision"
    }
    $acceptedStatus = Get-Content -LiteralPath $fakePlatformStatus -Raw | ConvertFrom-Json
    if (!$acceptedStatus.platforms.linux.accepted -or
      $acceptedStatus.platforms.linux.accepted_artifact -ne "fake-linux-source-artifact" -or
      $acceptedStatus.platforms.linux.accepted_commit -ne "0123456789abcdef0123456789abcdef01234567" -or
      $acceptedStatus.platforms.linux.accepted_provider -ne "source" -or
      $acceptedStatus.platforms.linux.accepted_version -ne "0123456789abcdef0123456789abcdef01234567") {
      throw "accept-platform-status did not mark Linux accepted with the expected artifact"
    }

    & (Join-Path $repoRoot "scripts/verify-platform-status.ps1") `
      -StatusFile $fakePlatformStatus `
      -RevisionFile $fakePlatformStatusRevision

    $fakeAcceptanceStatePatch = Join-Path $dryRunRoot "fake-linux-acceptance-state.patch"
    $fakeStatePatchRoot = Join-Path $dryRunRoot "fake-state-patch-worktree"
    New-Item -ItemType Directory -Force -Path $fakeStatePatchRoot | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot "skia-platform-status.json") -Destination (Join-Path $fakeStatePatchRoot "skia-platform-status.json")
    Copy-Item -LiteralPath (Join-Path $repoRoot "skia-revision.txt") -Destination (Join-Path $fakeStatePatchRoot "skia-revision.txt")
    git -C $fakeStatePatchRoot init | Out-Null
    git -C $fakeStatePatchRoot config core.autocrlf false
    git -C $fakeStatePatchRoot add skia-revision.txt skia-platform-status.json
    git -C $fakeStatePatchRoot -c user.email=moui-skia@example.invalid -c user.name=moui-skia commit -m "baseline" | Out-Null
    Copy-Item -LiteralPath $fakePlatformStatus -Destination (Join-Path $fakeStatePatchRoot "skia-platform-status.json") -Force
    Copy-Item -LiteralPath $fakePlatformStatusRevision -Destination (Join-Path $fakeStatePatchRoot "skia-revision.txt") -Force
    git -C $fakeStatePatchRoot -c core.autocrlf=false diff --output=$fakeAcceptanceStatePatch -- skia-revision.txt skia-platform-status.json
    $fakePatchText = [System.IO.File]::ReadAllText($fakeAcceptanceStatePatch).Replace("`r`n", "`n")
    [System.IO.File]::WriteAllText($fakeAcceptanceStatePatch, $fakePatchText, [System.Text.UTF8Encoding]::new($false))
    & (Join-Path $repoRoot "scripts/verify-acceptance-state-patch.ps1") `
      -PatchFile $fakeAcceptanceStatePatch

    $fakeBadAcceptanceStatePatch = Join-Path $dryRunRoot "fake-linux-acceptance-state-bad.patch"
    (Get-Content -LiteralPath $fakeAcceptanceStatePatch) `
      -replace 'skia-revision\.txt', 'README.md' `
      | Set-Content -LiteralPath $fakeBadAcceptanceStatePatch
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-acceptance-state-patch.ps1") -PatchFile $fakeBadAcceptanceStatePatch } `
      -ExpectedMessage "unexpected file"

    $fakeFloatingPlatformStatus = Join-Path $dryRunRoot "fake-floating-skia-platform-status.json"
    Copy-Item -LiteralPath (Join-Path $repoRoot "skia-platform-status.json") -Destination $fakeFloatingPlatformStatus
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/accept-platform-status.ps1") -Platform linux -LogDir $fakeLinuxArtifactDir -StatusFile $fakeFloatingPlatformStatus -RevisionFile (Join-Path $repoRoot "skia-revision.txt") -ArtifactLabel "should-not-accept-floating-revision" } `
      -ExpectedMessage "Skia revision is not pinned"

    $fakeLinuxMissingPreflightDir = Join-Path $dryRunRoot "fake-linux-missing-preflight"
    New-FakeLinuxSourceArtifact -Directory $fakeLinuxMissingPreflightDir
    Remove-Item -LiteralPath (Join-Path $fakeLinuxMissingPreflightDir "linux-real-skia-smoke-preflight.log")
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") -Platform linux -LogDir $fakeLinuxMissingPreflightDir -RequireCommit } `
      -ExpectedMessage "missing expected log"

    $fakeLinuxMissingWrapperBuildLogDir = Join-Path $dryRunRoot "fake-linux-missing-wrapper-build-log"
    New-FakeLinuxSourceArtifact -Directory $fakeLinuxMissingWrapperBuildLogDir -OmitWrapperBuildLog
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") -Platform linux -LogDir $fakeLinuxMissingWrapperBuildLogDir -RequireCommit } `
      -ExpectedMessage "build_log="
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/linux-accept-artifact-and-pin.ps1") -LogDir $fakeLinuxMissingWrapperBuildLogDir -RevisionFile (Join-Path $dryRunRoot "should-not-pin-bad-linux-artifact.txt") } `
      -ExpectedMessage "build_log="

    $fakeLinuxMissingAcceptanceBuildLogDir = Join-Path $dryRunRoot "fake-linux-missing-acceptance-build-log"
    New-FakeLinuxSourceArtifact -Directory $fakeLinuxMissingAcceptanceBuildLogDir -OmitAcceptanceBuildLog
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") -Platform linux -LogDir $fakeLinuxMissingAcceptanceBuildLogDir -RequireCommit } `
      -ExpectedMessage "build_log="

    $fakeLinuxMismatchedAcceptanceCommitDir = Join-Path $dryRunRoot "fake-linux-mismatched-acceptance-commit"
    New-FakeLinuxSourceArtifact `
      -Directory $fakeLinuxMismatchedAcceptanceCommitDir `
      -AcceptanceCommit "fedcba9876543210fedcba9876543210fedcba98"
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") -Platform linux -LogDir $fakeLinuxMismatchedAcceptanceCommitDir -RequireCommit } `
      -ExpectedMessage "wrapper and acceptance logs disagree"

    $fakeLinuxMismatchedBuildCommitDir = Join-Path $dryRunRoot "fake-linux-mismatched-build-commit"
    New-FakeLinuxSourceArtifact `
      -Directory $fakeLinuxMismatchedBuildCommitDir `
      -BuildCommit "fedcba9876543210fedcba9876543210fedcba98"
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") -Platform linux -LogDir $fakeLinuxMismatchedBuildCommitDir -RequireCommit } `
      -ExpectedMessage "build and wrapper logs disagree"

    $fakeMissingCiGateStatus = Join-Path $dryRunRoot "fake-platform-status-missing-ci-gate.json"
    $missingCiGateStatus = Get-Content -LiteralPath (Join-Path $repoRoot "skia-platform-status.json") -Raw | ConvertFrom-Json
    $missingCiGateStatus.ci_gates = @($missingCiGateStatus.ci_gates | Where-Object { $_.id -ne "native.ffi-borrows" })
    $missingCiGateStatus |
      ConvertTo-Json -Depth 20 |
      Set-Content -LiteralPath $fakeMissingCiGateStatus
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-platform-status.ps1") -StatusFile $fakeMissingCiGateStatus } `
      -ExpectedMessage "CI gate coverage is missing ids"

    $fakeMissingCiScriptStatus = Join-Path $dryRunRoot "fake-platform-status-missing-ci-script.json"
    $missingCiScriptStatus = Get-Content -LiteralPath (Join-Path $repoRoot "skia-platform-status.json") -Raw | ConvertFrom-Json
    foreach ($gate in $missingCiScriptStatus.ci_gates) {
      if ($gate.id -eq "native.ffi-borrows") {
        $gate.powershell_command = ".\scripts\missing-native-ffi-borrows.ps1"
      }
    }
    $missingCiScriptStatus |
      ConvertTo-Json -Depth 20 |
      Set-Content -LiteralPath $fakeMissingCiScriptStatus
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-platform-status.ps1") -StatusFile $fakeMissingCiScriptStatus } `
      -ExpectedMessage "CI gate references missing verifier script"

    $fakeUnwiredCiGateStatus = Join-Path $dryRunRoot "fake-platform-status-unwired-ci-gate.json"
    $unwiredCiGateStatus = Get-Content -LiteralPath (Join-Path $repoRoot "skia-platform-status.json") -Raw | ConvertFrom-Json
    foreach ($gate in $unwiredCiGateStatus.ci_gates) {
      if ($gate.id -eq "native.ffi-borrows") {
        $gate.powershell_command = ".\scripts\verify-native-ffi-borrows.ps1 -" + "Unwired"
      }
    }
    $unwiredCiGateStatus |
      ConvertTo-Json -Depth 20 |
      Set-Content -LiteralPath $fakeUnwiredCiGateStatus
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-platform-status.ps1") -StatusFile $fakeUnwiredCiGateStatus } `
      -ExpectedMessage "CI gate evidence is missing command wiring"

    $fakeMissingCapabilityAreaStatus = Join-Path $dryRunRoot "fake-platform-status-missing-capability-area.json"
    $missingCapabilityAreaStatus = Get-Content -LiteralPath (Join-Path $repoRoot "skia-platform-status.json") -Raw | ConvertFrom-Json
    foreach ($capability in @($missingCapabilityAreaStatus.native_smoke_capabilities)) {
      if ($capability.id -like "bitmap.*") {
        $capability.area = "Image"
      }
    }
    $missingCapabilityAreaStatus |
      ConvertTo-Json -Depth 20 |
      Set-Content -LiteralPath $fakeMissingCapabilityAreaStatus
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-platform-status.ps1") -StatusFile $fakeMissingCapabilityAreaStatus } `
      -ExpectedMessage "native smoke capability coverage is missing areas: Bitmap"

    $fakeMissingConditionalCapabilityStatus = Join-Path $dryRunRoot "fake-platform-status-missing-conditional-capability.json"
    $missingConditionalCapabilityStatus = Get-Content -LiteralPath (Join-Path $repoRoot "skia-platform-status.json") -Raw | ConvertFrom-Json
    $missingConditionalCapabilityStatus.native_smoke_conditional_capabilities = @(
      $missingConditionalCapabilityStatus.native_smoke_conditional_capabilities |
        Where-Object { $_.id -ne "text.shaped-glyph-count" }
    )
    $missingConditionalCapabilityStatus |
      ConvertTo-Json -Depth 20 |
      Set-Content -LiteralPath $fakeMissingConditionalCapabilityStatus
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-platform-status.ps1") -StatusFile $fakeMissingConditionalCapabilityStatus } `
      -ExpectedMessage "native smoke conditional capability coverage is missing ids"

    $fakeBadConditionalConditionStatus = Join-Path $dryRunRoot "fake-platform-status-bad-conditional-condition.json"
    $badConditionalConditionStatus = Get-Content -LiteralPath (Join-Path $repoRoot "skia-platform-status.json") -Raw | ConvertFrom-Json
    foreach ($capability in @($badConditionalConditionStatus.native_smoke_conditional_capabilities)) {
      if ($capability.id -eq "text.shaped-glyph-count") {
        $capability.when_marker = "native smoke unknown optional marker"
      }
    }
    $badConditionalConditionStatus |
      ConvertTo-Json -Depth 20 |
      Set-Content -LiteralPath $fakeBadConditionalConditionStatus
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-platform-status.ps1") -StatusFile $fakeBadConditionalConditionStatus } `
      -ExpectedMessage "unknown condition marker"

    $fakeMissingArtifactLogStatus = Join-Path $dryRunRoot "fake-platform-status-missing-artifact-log.json"
    $missingArtifactLogStatus = Get-Content -LiteralPath (Join-Path $repoRoot "skia-platform-status.json") -Raw | ConvertFrom-Json
    $missingArtifactLogStatus.platforms.linux.required_artifact_logs = @(
      $missingArtifactLogStatus.platforms.linux.required_artifact_logs |
        Where-Object { $_ -ne "linux-native-smoke-output.log" }
    )
    $missingArtifactLogStatus |
      ConvertTo-Json -Depth 20 |
      Set-Content -LiteralPath $fakeMissingArtifactLogStatus
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-platform-status.ps1") -StatusFile $fakeMissingArtifactLogStatus } `
      -ExpectedMessage "platform status required_artifact_logs do not match expected contract: linux"

    $fakeStatusDoc = Join-Path $dryRunRoot "fake-platform-status-doc.md"
    @(
      "## Current Matrix"
      ""
      "| Platform | Current state | What exists | Missing before accepted |"
      "| --- | --- | --- | --- |"
      "| Linux | Ready, not accepted yet | fake | fake |"
      "| macOS | Ready, not accepted yet | fake | fake |"
      "| Windows | Ready, not accepted yet | fake | fake |"
      ""
      "## Next Section"
    ) | Set-Content -LiteralPath $fakeStatusDoc
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-platform-status.ps1") -StatusDoc $fakeStatusDoc } `
      -ExpectedMessage "platform status Markdown matrix does not mark accepted platform"

    & (Join-Path $repoRoot "scripts/verify-platform-status.ps1")
  } finally {
    $resolvedDryRunRoot = Resolve-Path -LiteralPath $dryRunRoot -ErrorAction SilentlyContinue
    if ($resolvedDryRunRoot) {
      $resolvedRepoRoot = (Resolve-Path -LiteralPath $repoRoot).Path
      if ($resolvedDryRunRoot.Path.StartsWith($resolvedRepoRoot)) {
        Remove-Item -LiteralPath $resolvedDryRunRoot.Path -Recurse -Force
        $dryRunParent = Split-Path -Parent $resolvedDryRunRoot.Path
        if ((Split-Path -Leaf $dryRunParent) -eq ".skia-dry-run" -and !(Get-ChildItem -LiteralPath $dryRunParent -Force -ErrorAction SilentlyContinue)) {
          Remove-Item -LiteralPath $dryRunParent -Force
        }
      } else {
        throw "refusing to remove dry-run directory outside workspace: $($resolvedDryRunRoot.Path)"
      }
    }
  }
} finally {
  Pop-Location
}
