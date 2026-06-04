param(
  [string] $SkiaInclude = $env:SKIA_MBT_SKIA_INCLUDE,

  [string] $SkiaLibDir = $env:SKIA_MBT_SKIA_LIB_DIR,

  [string] $SkiaLib = $(if ($env:SKIA_MBT_SKIA_LIB) { $env:SKIA_MBT_SKIA_LIB } else { "skia" }),
  [string] $ExtraCcFlags = $env:SKIA_MBT_EXTRA_CC_FLAGS,
  [string] $ExtraLinkFlags = $env:SKIA_MBT_EXTRA_LINK_FLAGS,
  [string] $SmokeLog = "",
  [switch] $DryRunConfig
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$nativePkg = Join-Path $repoRoot "native/moon.pkg"
$backupPkg = "$nativePkg.smoke.bak"
$smokePkg = Join-Path $repoRoot "scripts/native_smoke/moon.pkg"
$smokeBackupPkg = "$smokePkg.smoke.bak"

if ([string]::IsNullOrWhiteSpace($SkiaInclude) -or [string]::IsNullOrWhiteSpace($SkiaLibDir)) {
  throw "SkiaInclude and SkiaLibDir are required; pass -SkiaInclude/-SkiaLibDir or set SKIA_MBT_SKIA_INCLUDE/SKIA_MBT_SKIA_LIB_DIR"
}
if (Test-Path -LiteralPath $backupPkg) {
  throw "native/moon.pkg smoke backup already exists: $backupPkg. Resolve the stale backup before running smoke."
}
if (Test-Path -LiteralPath $smokeBackupPkg) {
  throw "scripts/native_smoke/moon.pkg smoke backup already exists: $smokeBackupPkg. Resolve the stale backup before running smoke."
}

$includePath = (Resolve-Path -LiteralPath $SkiaInclude).Path -replace "\\", "/"
$libPath = (Resolve-Path -LiteralPath $SkiaLibDir).Path -replace "\\", "/"

$headerPath = Join-Path (Resolve-Path -LiteralPath $SkiaInclude).Path "include/core/SkSurface.h"
if (!(Test-Path -LiteralPath $headerPath)) {
  throw "Skia include path does not look like a Skia checkout/root: $SkiaInclude"
}

$resolvedLibDir = (Resolve-Path -LiteralPath $SkiaLibDir).Path
$staticLib = Join-Path $resolvedLibDir "lib$SkiaLib.a"
$dllImportLib = Join-Path $resolvedLibDir "$SkiaLib.lib"
if (!(Test-Path -LiteralPath $staticLib) -and !(Test-Path -LiteralPath $dllImportLib)) {
  throw "MinGW-compatible lib$SkiaLib.a or $SkiaLib.lib was not found in $SkiaLibDir"
}

$resolvedSmokeLog = ""
if ($SmokeLog.Trim().Length -gt 0) {
  if ([System.IO.Path]::IsPathRooted($SmokeLog)) {
    $resolvedSmokeLog = $SmokeLog
  } else {
    $resolvedSmokeLog = Join-Path $repoRoot $SmokeLog
  }
}

$ccFlags = "-DSKIA_MBT_HAS_SKIA -I$includePath"
if ($ExtraCcFlags.Trim().Length -gt 0) {
  $ccFlags = "$ccFlags $ExtraCcFlags"
}

$linkFlags = "-L$libPath -l$SkiaLib"
if ($ExtraLinkFlags.Trim().Length -gt 0) {
  $linkFlags = "$linkFlags $ExtraLinkFlags"
}
if ($linkFlags -notmatch '(^|\s)-lstdc\+\+(\s|$)') {
  $linkFlags = "$linkFlags -lstdc++"
}

Write-Host "Windows Skia smoke environment:"
$moonVersion = ""
if (Get-Command moon -ErrorAction SilentlyContinue) {
  $moonVersion = (& moon version 2>$null | Select-Object -First 1) -join ""
}
Write-Host "  moon=$moonVersion"
$cxx = if ($env:CXX) { $env:CXX } else { "g++" }
$cxxVersion = ""
if (Get-Command $cxx -ErrorAction SilentlyContinue) {
  $cxxVersion = (& $cxx --version 2>$null | Select-Object -First 1) -join ""
}
Write-Host "  cxx=$cxxVersion"
Write-Host "  skia_include=$includePath"
Write-Host "  skia_lib_dir=$libPath"
Write-Host "  skia_lib=$SkiaLib"
if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath (Join-Path (Resolve-Path -LiteralPath $SkiaInclude).Path ".git"))) {
  $skiaCommit = (& git -C (Resolve-Path -LiteralPath $SkiaInclude).Path rev-parse HEAD 2>$null | Select-Object -First 1) -join ""
  if ($skiaCommit.Trim().Length -gt 0) {
    Write-Host "  skia_commit=$skiaCommit"
  }
}
foreach ($library in @($staticLib, $dllImportLib)) {
  if (Test-Path -LiteralPath $library) {
    $item = Get-Item -LiteralPath $library
    Write-Host "  library=$($item.Name) $($item.Length) bytes"
  }
}
Write-Host "  stub_cc_flags=$ccFlags"
Write-Host "  cc_link_flags=$linkFlags"
if ($resolvedSmokeLog.Length -gt 0) {
  Write-Host "  smoke_log=$resolvedSmokeLog"
}

if ($DryRunConfig) {
  Write-Host "Dry run complete; native/moon.pkg was not modified and no build was run."
  exit 0
}

$original = Get-Content -LiteralPath $nativePkg -Raw
$originalSmokePkg = Get-Content -LiteralPath $smokePkg -Raw

try {
  Set-Content -LiteralPath $backupPkg -Value $original -NoNewline
  Write-Host "Backed up native/moon.pkg to $backupPkg."
  Set-Content -LiteralPath $smokeBackupPkg -Value $originalSmokePkg -NoNewline
  Write-Host "Backed up scripts/native_smoke/moon.pkg to $smokeBackupPkg."

  & (Join-Path $repoRoot "scripts/configure-windows-native-pkg.ps1") `
    -SkiaInclude $SkiaInclude `
    -SkiaLibDir $SkiaLibDir `
    -SkiaLib $SkiaLib `
    -ExtraCcFlags $ExtraCcFlags `
    -ExtraLinkFlags $ExtraLinkFlags `
    -Output $nativePkg `
    -Write | Out-Null
  Write-Host "Wrote temporary native/moon.pkg with Windows Skia link flags."

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
  Write-Host "Wrote temporary scripts/native_smoke/moon.pkg with Windows Skia executable link flags."

  Push-Location $repoRoot
  try {
    Push-Location (Join-Path $repoRoot "scripts/native_smoke")
    try {
      $oldErrorActionPreference = $ErrorActionPreference
      $ErrorActionPreference = "Continue"
      try {
        moon build --target native 2>&1 | ForEach-Object { Write-Host $_ }
        $buildStatus = $LASTEXITCODE
      } finally {
        $ErrorActionPreference = $oldErrorActionPreference
      }
      if ($buildStatus -ne 0) {
        throw "moon build --target native failed with exit code $buildStatus"
      }
      $smokeExe = Join-Path (Get-Location) "_build/native/debug/build/skia_mbt_native_smoke.exe"
      if (!(Test-Path -LiteralPath $smokeExe)) {
        throw "native smoke executable was not produced at $smokeExe"
      }
      if ($resolvedSmokeLog.Length -eq 0) {
        $resolvedSmokeLog = Join-Path ([System.IO.Path]::GetTempPath()) "skia-mbt-native-smoke-$PID.log"
      } else {
        $smokeLogDir = Split-Path -Parent $resolvedSmokeLog
        if ($smokeLogDir.Length -gt 0) {
          New-Item -ItemType Directory -Force -Path $smokeLogDir | Out-Null
        }
      }
      Set-Content -LiteralPath $resolvedSmokeLog -Value "" -NoNewline
      Write-Host "Running native smoke executable: $smokeExe"
      $resolvedRuntimeLibDir = (Resolve-Path -LiteralPath $SkiaLibDir).Path
      $candidateBinDir = Join-Path (Split-Path -Parent $resolvedRuntimeLibDir) "bin"
      if (Test-Path -LiteralPath $candidateBinDir -PathType Container) {
        $env:PATH = "$candidateBinDir;$resolvedRuntimeLibDir;$env:PATH"
      } else {
        $env:PATH = "$resolvedRuntimeLibDir;$env:PATH"
      }
      & $smokeExe 2>&1 | Tee-Object -FilePath $resolvedSmokeLog
      $smokeStatus = $LASTEXITCODE
      if ($smokeStatus -ne 0) {
        throw "native smoke executable failed with exit code $smokeStatus"
      }
      if (!(Select-String -LiteralPath $resolvedSmokeLog -SimpleMatch "skia_mbt native smoke test passed" -Quiet)) {
        throw "native smoke executable did not print the expected success marker"
      }
      Write-Host "Verified native smoke success marker."
    } finally {
      Pop-Location
    }
  } finally {
    Pop-Location
  }
} finally {
  Set-Content -LiteralPath $nativePkg -Value $original -NoNewline
  Set-Content -LiteralPath $smokePkg -Value $originalSmokePkg -NoNewline
  Remove-Item -LiteralPath $backupPkg -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $smokeBackupPkg -ErrorAction SilentlyContinue
  Write-Host "Restored native/moon.pkg after Windows Skia smoke."
  Write-Host "Restored scripts/native_smoke/moon.pkg after Windows Skia smoke."
}
