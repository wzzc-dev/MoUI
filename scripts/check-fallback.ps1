param(
  [switch] $SkipInfo
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$nativePkg = Join-Path $repoRoot "native/moon.pkg"
$smokePkg = Join-Path $repoRoot "scripts/native_smoke/moon.pkg"

function Assert-NativePkgUnchanged {
  param(
    [Parameter(Mandatory = $true)]
    [string] $ExpectedHash,
    [Parameter(Mandatory = $true)]
    [string] $ExpectedSmokeHash
  )

  $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $nativePkg).Hash
  if ($actualHash -ne $ExpectedHash) {
    throw "native/moon.pkg changed during fallback validation"
  }
  $actualSmokeHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $smokePkg).Hash
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
    & $Command
    throw "command unexpectedly succeeded"
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
  foreach ($capability in @($status.native_smoke_capabilities)) {
    $marker = "$($capability.marker)".Trim()
    if (![string]::IsNullOrWhiteSpace($marker)) {
      $lines += $marker
      if ($expectedValues.ContainsKey($marker)) {
        $lines += $expectedValues[$marker]
      } else {
        $lines += "1"
      }
    }
  }
  $lines += "skia_mbt native smoke test passed"
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
    "  stub_cc_flags=-DSKIA_MBT_HAS_SKIA -IC:/fake/skia"
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

function New-FakeJetBrainsArtifact {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Directory,
    [string] $Commit = "8967a2e80c71be363146da2395f503cab5f5fb9c",
    [string] $Tag = "m148-8967a2e80c",
    [string] $Package = "Skia-m148-8967a2e80c-windows-Release-x64.zip",
    [string] $Sha256 = "1927edce6567785870558bfc5e84fac99af45cbe91eb62f260025bc1cf7aa5df"
  )

  New-Item -ItemType Directory -Force -Path $Directory | Out-Null
  $preflightLog = Join-Path $Directory "windows-real-skia-smoke-preflight.log"
  $wrapperLog = Join-Path $Directory "windows-real-skia-smoke.log"
  $nativeLog = Join-Path $Directory "windows-native-smoke-output.log"
  $acceptanceLog = Join-Path $Directory "windows-real-skia-acceptance.log"

  "JetBrains Skia provider dry run" | Set-Content -LiteralPath $preflightLog
  @(
    "Windows MSVC Skia smoke environment:"
    "  skia_include=C:/fake/skia"
    "  skia_lib_dir=C:/fake/skia/out/Release-x64"
    "  skia_lib=skia"
    "  skia_provider=jetbrains"
    "  jetbrains_tag=$Tag"
    "  skia_commit=$Commit"
    "  skia_package=$Package"
    "  skia_package_sha256=$Sha256"
    "  library=skia.lib 123 bytes"
    "  stub_cc_flags=/DSKIA_MBT_HAS_SKIA /IC:/fake/skia"
    "  cc_link_flags=C:/fake/skia/out/Release-x64/skia.lib user32.lib"
  ) | Set-Content -LiteralPath $wrapperLog
  Set-FakeNativeSmokeLog -Path $nativeLog
  @(
    "Windows MSVC real Skia acceptance result:"
    "  smoke_status=0"
    "  native_smoke_marker=passed"
    "  native_pkg_restore=passed"
    "  skia_provider=jetbrains"
    "  jetbrains_tag=$Tag"
    "  skia_commit=$Commit"
    "  skia_package=$Package"
    "  skia_package_sha256=$Sha256"
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
  & (Join-Path $repoRoot "scripts/verify-native-smoke-capabilities.ps1")
  Assert-WorkflowUsesHashtableSplatting -Path (Join-Path $repoRoot ".github/workflows/windows-real-skia-smoke.yml")
  Assert-WorkflowUsesHashtableSplatting -Path (Join-Path $repoRoot ".github/workflows/real-skia-acceptance.yml")

  Push-Location (Join-Path $repoRoot "scripts/native_smoke")
  try {
    moon check
    moon build --target native
  } finally {
    Pop-Location
  }

  $beforeNativePkgHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $nativePkg).Hash
  $beforeSmokePkgHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $smokePkg).Hash
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
      -ExtraCcFlags "-DSKIA_MBT_FAKE_CONFIG_CC" `
      -ExtraLinkFlags "-lskia_fake_config_dep" `
      -Output $fakeWindowsNativePkg `
      -Write
    & (Join-Path $repoRoot "scripts/configure-windows-native-pkg.ps1") `
      -SkiaInclude $fakeSkiaInclude `
      -SkiaLibDir $fakeSkiaLibDir `
      -ExtraCcFlags "-DSKIA_MBT_FAKE_CONFIG_CC" `
      -ExtraLinkFlags "-lskia_fake_config_dep" `
      -Output $fakeWindowsNativePkg `
      -Check
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/configure-windows-native-pkg.ps1") -SkiaInclude $fakeSkiaInclude -SkiaLibDir $fakeSkiaLibDir -Output $fakeWindowsNativePkg -Check } `
      -ExpectedMessage "does not match generated Windows Skia link config"

    $env:SKIA_MBT_SKIA_INCLUDE = $fakeSkiaInclude
    $env:SKIA_MBT_SKIA_LIB_DIR = $fakeSkiaLibDir
    $env:SKIA_MBT_EXTRA_CC_FLAGS = "-DSKIA_MBT_FAKE_ENV_CC"
    $env:SKIA_MBT_EXTRA_LINK_FLAGS = "-lskia_fake_env_dep"
    try {
      & (Join-Path $repoRoot "scripts/windows-skia-smoke.ps1") -DryRunConfig
    } finally {
      Remove-Item Env:SKIA_MBT_SKIA_INCLUDE -ErrorAction SilentlyContinue
      Remove-Item Env:SKIA_MBT_SKIA_LIB_DIR -ErrorAction SilentlyContinue
      Remove-Item Env:SKIA_MBT_EXTRA_CC_FLAGS -ErrorAction SilentlyContinue
      Remove-Item Env:SKIA_MBT_EXTRA_LINK_FLAGS -ErrorAction SilentlyContinue
    }

    Assert-NativePkgUnchanged -ExpectedHash $beforeNativePkgHash -ExpectedSmokeHash $beforeSmokePkgHash

    $fetchDryRunEnv = & (Join-Path $repoRoot "scripts/fetch-jetbrains-skia.ps1") `
      -Platform windows `
      -Arch x64 `
      -Config Release `
      -CacheDir (Join-Path $dryRunRoot "jetbrains-cache") `
      -DryRunConfig `
      -PrintEnv
    if (($fetchDryRunEnv -join "`n") -notlike "*SKIA_MBT_SKIA_PACKAGE=Skia-m148-8967a2e80c-windows-Release-x64.zip*" -or
      ($fetchDryRunEnv -join "`n") -notlike "*SKIA_MBT_SKIA_PACKAGE_SHA256=1927edce6567785870558bfc5e84fac99af45cbe91eb62f260025bc1cf7aa5df*") {
      throw "fetch-jetbrains-skia.ps1 did not map Windows x64 Release to the locked package"
    }

    $fakeJetBrainsCache = Join-Path $dryRunRoot "jetbrains-cache"
    $fakeJetBrainsPackage = Join-Path $fakeJetBrainsCache "m148-8967a2e80c/windows-Release-x64/package/fake"
    New-Item -ItemType Directory -Force -Path (Join-Path $fakeJetBrainsPackage "include/core") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $fakeJetBrainsPackage "out/Release-x64") | Out-Null
    New-Item -ItemType File -Force -Path (Join-Path $fakeJetBrainsPackage "include/core/SkSurface.h") | Out-Null
    New-Item -ItemType File -Force -Path (Join-Path $fakeJetBrainsPackage "out/Release-x64/skia.lib") | Out-Null
    $env:SKIA_MBT_ALLOW_FAKE_JETBRAINS_ZIP = "1"
    try {
      $fakeFetchEnv = & (Join-Path $repoRoot "scripts/fetch-jetbrains-skia.ps1") `
        -Platform windows `
        -Arch x64 `
        -Config Release `
        -CacheDir $fakeJetBrainsCache `
        -PrintEnv
    } finally {
      Remove-Item Env:SKIA_MBT_ALLOW_FAKE_JETBRAINS_ZIP -ErrorAction SilentlyContinue
    }
    if (($fakeFetchEnv -join "`n") -notlike "*SKIA_MBT_SKIA_INCLUDE=*" -or
      ($fakeFetchEnv -join "`n") -notlike "*SKIA_MBT_SKIA_LIB_DIR=*") {
      throw "fetch-jetbrains-skia.ps1 did not resolve fake package include/lib paths"
    }

    $fakeJetBrainsNoHeaders = Join-Path $fakeJetBrainsCache "m148-8967a2e80c/windows-Release-arm64/package/fake"
    New-Item -ItemType Directory -Force -Path (Join-Path $fakeJetBrainsNoHeaders "out/Release-arm64") | Out-Null
    New-Item -ItemType File -Force -Path (Join-Path $fakeJetBrainsNoHeaders "out/Release-arm64/skia.lib") | Out-Null
    $fakeJetBrainsSource = Join-Path $fakeJetBrainsCache "m148-8967a2e80c/source/JetBrains-skia-m148-8967a2e80c"
    New-Item -ItemType Directory -Force -Path (Join-Path $fakeJetBrainsSource "include/core") | Out-Null
    New-Item -ItemType File -Force -Path (Join-Path $fakeJetBrainsSource "include/core/SkSurface.h") | Out-Null
    $fallbackFetchEnv = & (Join-Path $repoRoot "scripts/fetch-jetbrains-skia.ps1") `
      -Platform windows `
      -Arch arm64 `
      -Config Release `
      -CacheDir $fakeJetBrainsCache `
      -PrintEnv
    if (($fallbackFetchEnv -join "`n") -notlike "*jetbrains-cache/m148-8967a2e80c/source/*") {
      throw "fetch-jetbrains-skia.ps1 did not fall back to source headers"
    }

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

    $fakeMissingStageNativeSmokeLog = Join-Path $dryRunRoot "fake-native-smoke-missing-stage.log"
    Set-Content -LiteralPath $fakeMissingStageNativeSmokeLog -Value "skia_mbt native smoke test passed"
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
      "  stub_cc_flags=-DSKIA_MBT_HAS_SKIA -IC:/fake/skia"
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

    $fakeJetBrainsArtifactDir = Join-Path $dryRunRoot "fake-jetbrains-artifact"
    New-FakeJetBrainsArtifact -Directory $fakeJetBrainsArtifactDir
    & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") `
      -Platform windows `
      -LogDir $fakeJetBrainsArtifactDir

    $fakeJetBrainsBadShaDir = Join-Path $dryRunRoot "fake-jetbrains-artifact-bad-sha"
    New-FakeJetBrainsArtifact `
      -Directory $fakeJetBrainsBadShaDir `
      -Sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-real-skia-artifact.ps1") -Platform windows -LogDir $fakeJetBrainsBadShaDir } `
      -ExpectedMessage "SHA256 mismatch"


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
      "  stub_cc_flags=-DSKIA_MBT_HAS_SKIA -I/fake/skia"
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
    git -C $fakeStatePatchRoot -c user.email=skia-mbt@example.invalid -c user.name=skia-mbt commit -m "baseline" | Out-Null
    Copy-Item -LiteralPath $fakePlatformStatus -Destination (Join-Path $fakeStatePatchRoot "skia-platform-status.json") -Force
    Copy-Item -LiteralPath $fakePlatformStatusRevision -Destination (Join-Path $fakeStatePatchRoot "skia-revision.txt") -Force
    git -C $fakeStatePatchRoot -c core.autocrlf=false diff --output=$fakeAcceptanceStatePatch -- skia-revision.txt skia-platform-status.json
    $fakePatchText = [System.IO.File]::ReadAllText($fakeAcceptanceStatePatch).Replace("`r`n", "`n")
    [System.IO.File]::WriteAllText($fakeAcceptanceStatePatch, $fakePatchText, [System.Text.UTF8Encoding]::new($false))
    & (Join-Path $repoRoot "scripts/verify-acceptance-state-patch.ps1") `
      -PatchFile $fakeAcceptanceStatePatch

    $fakeBadAcceptanceStatePatch = Join-Path $dryRunRoot "fake-linux-acceptance-state-bad.patch"
    (Get-Content -LiteralPath $fakeAcceptanceStatePatch) `
      -replace 'skia-revision\.txt', 'README.mbt.md' `
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
      -ExpectedMessage "source build log"

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
      if ($capability.id -eq "bitmap.decode-readback") {
        $capability.area = "Image"
      }
    }
    $missingCapabilityAreaStatus |
      ConvertTo-Json -Depth 20 |
      Set-Content -LiteralPath $fakeMissingCapabilityAreaStatus
    Assert-CommandFailsWith `
      -Command { & (Join-Path $repoRoot "scripts/verify-platform-status.ps1") -StatusFile $fakeMissingCapabilityAreaStatus } `
      -ExpectedMessage "native smoke capability coverage is missing areas: Bitmap"

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
