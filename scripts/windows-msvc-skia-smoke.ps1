param(
  [string] $SkiaRoot = $env:SKIA_MBT_SKIA_ROOT,
  [string] $SkiaInclude = $env:SKIA_MBT_SKIA_INCLUDE,
  [string] $SkiaZip = $env:SKIA_MBT_SKIA_ZIP,
  [string] $SkiaLibDir = $env:SKIA_MBT_SKIA_LIB_DIR,
  [string] $VcVarsAll = $env:VCVARSALL,
  [string] $VcArch = "x64",
  [string] $SkiaProvider = $env:SKIA_MBT_SKIA_PROVIDER,
  [string] $JetBrainsTag = $env:SKIA_MBT_JETBRAINS_TAG,
  [string] $SkiaCommit = $env:SKIA_MBT_SKIA_COMMIT,
  [string] $SkiaPackage = $env:SKIA_MBT_SKIA_PACKAGE,
  [string] $SkiaPackageSha256 = $env:SKIA_MBT_SKIA_PACKAGE_SHA256,
  [string] $ExtraCcFlags = $env:SKIA_MBT_EXTRA_CC_FLAGS,
  [string] $ExtraLinkFlags = $env:SKIA_MBT_EXTRA_LINK_FLAGS,
  [string] $SmokeLog = "",
  [switch] $DryRunConfig,
  [switch] $ForceExtract
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$nativePkg = Join-Path $repoRoot "native/moon.pkg"
$backupPkg = "$nativePkg.smoke.bak"
$smokePkg = Join-Path $repoRoot "scripts/native_smoke/moon.pkg"
$smokeBackupPkg = "$smokePkg.smoke.bak"
$defaultCacheRoot = Join-Path $repoRoot ".skia-cache/windows-msvc/aseprite/Skia-Windows-Release-x64"
$defaultZip = Join-Path $env:USERPROFILE "Downloads/Skia-Windows-Release-x64.zip"

function Resolve-VcVarsAll {
  param(
    [string] $Path
  )

  if (![string]::IsNullOrWhiteSpace($Path)) {
    return $Path
  }

  $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
  if (Test-Path -LiteralPath $vswhere -PathType Leaf) {
    $installPath = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath) -join ""
    if (![string]::IsNullOrWhiteSpace($installPath)) {
      return (Join-Path $installPath "VC\Auxiliary\Build\vcvarsall.bat")
    }
  }

  $candidates = @(
    "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat",
    "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat",
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvarsall.bat",
    "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvarsall.bat"
  )
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      return $candidate
    }
  }

  return $candidates[0]
}

$VcVarsAll = Resolve-VcVarsAll -Path $VcVarsAll
if (!(Test-Path -LiteralPath $VcVarsAll -PathType Leaf)) {
  throw "vcvarsall.bat was not found: $VcVarsAll"
}

if ([string]::IsNullOrWhiteSpace($SkiaRoot)) {
  if (Test-Path -LiteralPath $defaultCacheRoot -PathType Container) {
    $SkiaRoot = $defaultCacheRoot
  } elseif (![string]::IsNullOrWhiteSpace($SkiaZip)) {
    $SkiaRoot = $defaultCacheRoot
  } elseif (Test-Path -LiteralPath $defaultZip -PathType Leaf) {
    $SkiaZip = $defaultZip
    $SkiaRoot = $defaultCacheRoot
  } else {
    throw "SkiaRoot is required; pass -SkiaRoot, set SKIA_MBT_SKIA_ROOT, or place Skia-Windows-Release-x64.zip in Downloads."
  }
}

if (!(Test-Path -LiteralPath $SkiaRoot -PathType Container)) {
  if ([string]::IsNullOrWhiteSpace($SkiaZip)) {
    throw "Skia root is missing and no SkiaZip was provided: $SkiaRoot"
  }
  if (!(Test-Path -LiteralPath $SkiaZip -PathType Leaf)) {
    throw "Skia zip was not found: $SkiaZip"
  }
  $extractParent = Split-Path -Parent $SkiaRoot
  New-Item -ItemType Directory -Force -Path $extractParent | Out-Null
  Write-Host "Extracting Skia zip to $extractParent"
  Expand-Archive -LiteralPath $SkiaZip -DestinationPath $extractParent -Force:$ForceExtract
}

$resolvedRoot = (Resolve-Path -LiteralPath $SkiaRoot).Path
$resolvedIncludeRoot = $resolvedRoot
if (![string]::IsNullOrWhiteSpace($SkiaInclude)) {
  $resolvedIncludeRoot = (Resolve-Path -LiteralPath $SkiaInclude).Path
}
$headerPath = Join-Path $resolvedIncludeRoot "include/core/SkSurface.h"
if (!(Test-Path -LiteralPath $headerPath -PathType Leaf)) {
  throw "Skia include root does not look like a Skia checkout/root: $resolvedIncludeRoot"
}

if ([string]::IsNullOrWhiteSpace($SkiaLibDir)) {
  $SkiaLibDir = Join-Path $resolvedRoot "out/Release-x64"
}
$resolvedLibDir = (Resolve-Path -LiteralPath $SkiaLibDir).Path
$skiaLib = Join-Path $resolvedLibDir "skia.lib"
if (!(Test-Path -LiteralPath $skiaLib -PathType Leaf)) {
  throw "skia.lib was not found in $resolvedLibDir"
}

if (Test-Path -LiteralPath $backupPkg) {
  throw "native/moon.pkg smoke backup already exists: $backupPkg. Resolve the stale backup before running smoke."
}
if (Test-Path -LiteralPath $smokeBackupPkg) {
  throw "scripts/native_smoke/moon.pkg smoke backup already exists: $smokeBackupPkg. Resolve the stale backup before running smoke."
}

$resolvedSmokeLog = ""
if ($SmokeLog.Trim().Length -gt 0) {
  if ([System.IO.Path]::IsPathRooted($SmokeLog)) {
    $resolvedSmokeLog = $SmokeLog
  } else {
    $resolvedSmokeLog = Join-Path $repoRoot $SmokeLog
  }
}

$includePath = $resolvedIncludeRoot -replace "\\", "/"
$libPath = $resolvedLibDir -replace "\\", "/"
$ccFlags = "/DSKIA_MBT_HAS_SKIA /std:c++20 /EHsc /I$includePath"
if (![string]::IsNullOrWhiteSpace($ExtraCcFlags)) {
  $ccFlags = "$ccFlags $ExtraCcFlags"
}

$packageLibs = Get-ChildItem -LiteralPath $resolvedLibDir -Filter "*.lib" |
  Sort-Object Name |
  ForEach-Object { $_.FullName -replace "\\", "/" }
$skiaLibFlag = $skiaLib -replace "\\", "/"
$orderedPackageLibs = @($skiaLibFlag) + ($packageLibs | Where-Object { $_ -ne $skiaLibFlag })
$systemLibs = @(
  "user32.lib",
  "gdi32.lib",
  "ole32.lib",
  "opengl32.lib",
  "usp10.lib",
  "fontsub.lib",
  "imm32.lib",
  "winmm.lib",
  "version.lib",
  "dwrite.lib",
  "d2d1.lib",
  "dxgi.lib",
  "advapi32.lib",
  "shell32.lib"
)
$linkItems = $orderedPackageLibs + $systemLibs
$linkFlags = $linkItems -join " "
if (![string]::IsNullOrWhiteSpace($ExtraLinkFlags)) {
  $linkFlags = "$linkFlags $ExtraLinkFlags"
}

Write-Output "Windows MSVC Skia smoke environment:"
$moonVersion = ""
if (Get-Command moon -ErrorAction SilentlyContinue) {
  $moonVersion = (& moon version 2>$null | Select-Object -First 1) -join ""
}
Write-Output "  moon=$moonVersion"
Write-Output "  vcvarsall=$VcVarsAll"
Write-Output "  vc_arch=$VcArch"
Write-Output "  skia_root=$resolvedRoot"
Write-Output "  skia_include=$includePath"
Write-Output "  skia_lib_dir=$libPath"
Write-Output "  skia_lib=skia"
if (![string]::IsNullOrWhiteSpace($SkiaProvider)) {
  Write-Output "  skia_provider=$SkiaProvider"
}
if (![string]::IsNullOrWhiteSpace($JetBrainsTag)) {
  Write-Output "  jetbrains_tag=$JetBrainsTag"
}
if (![string]::IsNullOrWhiteSpace($SkiaCommit)) {
  Write-Output "  skia_commit=$SkiaCommit"
} elseif ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath (Join-Path $resolvedIncludeRoot ".git"))) {
  $skiaCommit = (& git -C $resolvedIncludeRoot rev-parse HEAD 2>$null | Select-Object -First 1) -join ""
  if ($skiaCommit.Trim().Length -gt 0) {
    Write-Output "  skia_commit=$skiaCommit"
  }
}
if (![string]::IsNullOrWhiteSpace($SkiaPackage)) {
  Write-Output "  skia_package=$SkiaPackage"
}
if (![string]::IsNullOrWhiteSpace($SkiaPackageSha256)) {
  Write-Output "  skia_package_sha256=$SkiaPackageSha256"
}
$item = Get-Item -LiteralPath $skiaLib
Write-Output "  library=$($item.Name) $($item.Length) bytes"
Write-Output "  stub_cc_flags=$ccFlags"
Write-Output "  cc_link_flags=$linkFlags"
if ($resolvedSmokeLog.Length -gt 0) {
  Write-Output "  smoke_log=$resolvedSmokeLog"
}

if ($DryRunConfig) {
  Write-Output "Dry run complete; native/moon.pkg was not modified and no build was run."
  exit 0
}

$original = Get-Content -LiteralPath $nativePkg -Raw
$originalSmokePkg = Get-Content -LiteralPath $smokePkg -Raw

try {
  Set-Content -LiteralPath $backupPkg -Value $original -NoNewline
  Write-Host "Backed up native/moon.pkg to $backupPkg."
  Set-Content -LiteralPath $smokeBackupPkg -Value $originalSmokePkg -NoNewline
  Write-Host "Backed up scripts/native_smoke/moon.pkg to $smokeBackupPkg."

  & (Join-Path $repoRoot "scripts/configure-windows-msvc-native-pkg.ps1") `
    -SkiaRoot $resolvedRoot `
    -SkiaInclude $resolvedIncludeRoot `
    -SkiaLibDir $resolvedLibDir `
    -ExtraCcFlags $ExtraCcFlags `
    -ExtraLinkFlags $ExtraLinkFlags `
    -Output $nativePkg `
    -Write | Out-Null
  Write-Host "Wrote temporary native/moon.pkg with Windows MSVC Skia link flags."

  @"
import {
  "wzzc-dev/skia_mbt" @skia,
  "wzzc-dev/skia_mbt/native" @native,
}

options(
  "is-main": true,
  "native-stub": [ "smoke_debug.c" ],
  link: {
    "native": {
      "cc-link-flags": "$linkFlags",
    },
  },
)
"@ | Set-Content -LiteralPath $smokePkg -NoNewline
  Write-Host "Wrote temporary scripts/native_smoke/moon.pkg with Windows MSVC executable link flags."

  Push-Location (Join-Path $repoRoot "scripts/native_smoke")
  try {
    if ($resolvedSmokeLog.Length -eq 0) {
      $resolvedSmokeLog = Join-Path ([System.IO.Path]::GetTempPath()) "skia-mbt-native-msvc-smoke-$PID.log"
    } else {
      $smokeLogDir = Split-Path -Parent $resolvedSmokeLog
      if ($smokeLogDir.Length -gt 0) {
        New-Item -ItemType Directory -Force -Path $smokeLogDir | Out-Null
      }
    }
    $cmdFile = Join-Path ([System.IO.Path]::GetTempPath()) "skia-mbt-msvc-smoke-$PID.cmd"
    $logPath = $resolvedSmokeLog -replace '"', '""'
    $vcPath = $VcVarsAll -replace '"', '""'
    $cmdContent = @"
@echo off
setlocal
call "$vcPath" $VcArch
if errorlevel 1 exit /b %errorlevel%
set CC=cl
set CXX=cl
set PATH=$resolvedLibDir;%PATH%
echo cl version:
cl 2>&1
set SMOKE_EXE=%CD%\_build\native\debug\build\skia_mbt_native_smoke.exe
if exist "%SMOKE_EXE%" del "%SMOKE_EXE%"
echo building native smoke...
moon build --target native
if errorlevel 1 exit /b %errorlevel%
if not exist "%SMOKE_EXE%" (
  echo native smoke executable was not produced: %SMOKE_EXE%
  exit /b 1
)
echo running native smoke executable: %SMOKE_EXE%
"%SMOKE_EXE%" > "$logPath" 2>&1
set SMOKE_STATUS=%errorlevel%
type "$logPath"
exit /b %SMOKE_STATUS%
"@
    Set-Content -LiteralPath $cmdFile -Value $cmdContent -NoNewline -Encoding ASCII
    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
      & cmd.exe /d /c $cmdFile 2>&1 | ForEach-Object { Write-Host $_ }
      $status = $LASTEXITCODE
    } finally {
      $ErrorActionPreference = $oldErrorActionPreference
      Remove-Item -LiteralPath $cmdFile -ErrorAction SilentlyContinue
    }
    if ($status -ne 0) {
      throw "Windows MSVC native smoke failed with exit code $status"
    }
    if (!(Select-String -LiteralPath $resolvedSmokeLog -SimpleMatch "skia_mbt native smoke test passed" -Quiet)) {
      throw "native smoke executable did not print the expected success marker"
    }
    Write-Host "Verified native smoke success marker."
  } finally {
    Pop-Location
  }
} finally {
  Set-Content -LiteralPath $nativePkg -Value $original -NoNewline
  Set-Content -LiteralPath $smokePkg -Value $originalSmokePkg -NoNewline
  Remove-Item -LiteralPath $backupPkg -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $smokeBackupPkg -ErrorAction SilentlyContinue
  Write-Host "Restored native/moon.pkg after Windows MSVC Skia smoke."
  Write-Host "Restored scripts/native_smoke/moon.pkg after Windows MSVC Skia smoke."
}
