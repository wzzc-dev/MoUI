param(
  [string] $SkiaRoot = $env:MOUI_SKIA_SKIA_ROOT,
  [string] $SkiaZip = $env:MOUI_SKIA_SKIA_ZIP,
  [string] $SkiaLibDir = $env:MOUI_SKIA_SKIA_LIB_DIR,
  [ValidateSet("static", "dynamic", "auto")]
  [string] $SkiaLinkMode = $(if ($env:MOUI_SKIA_LINK_MODE) { $env:MOUI_SKIA_LINK_MODE } else { "static" }),
  [string] $VcVarsAll = $(if ($env:VCVARSALL) { $env:VCVARSALL } else { "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" }),
  [string] $VcArch = "x64",
  [string] $ExtraCcFlags = $env:MOUI_SKIA_EXTRA_CC_FLAGS,
  [string] $ExtraLinkFlags = $env:MOUI_SKIA_EXTRA_LINK_FLAGS,
  [switch] $BuildOnly,
  [switch] $Trace,
  [switch] $ForceExtract
)

$ErrorActionPreference = "Stop"

if ($null -ne [Environment]::GetEnvironmentVariable("MOUI_SKIA_SKIA_LINK_MODE") -or
    $null -ne [Environment]::GetEnvironmentVariable("MOUI_SKIA_MACOS_LINK_MODE")) {
  throw "MOUI_SKIA_SKIA_LINK_MODE and MOUI_SKIA_MACOS_LINK_MODE are no longer supported; use MOUI_SKIA_LINK_MODE=dynamic|static|auto."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$nativePkg = Join-Path $repoRoot "native/moon.pkg"
$trianglePkg = Join-Path $repoRoot "examples/triangle_window/moon.pkg"
$nativeBackup = "$nativePkg.triangle.bak"
$triangleBackup = "$trianglePkg.triangle.bak"
. (Join-Path $PSScriptRoot "windows-msvc-skia-paths.ps1")

function Resolve-SkiaMsvcLibrary {
  param(
    [Parameter(Mandatory = $true)][string] $LibDir,
    [Parameter(Mandatory = $true)][string] $LinkMode
  )

  $staticLib = Join-Path $LibDir "skia.lib"
  $dynamicImportLib = Join-Path $LibDir "skia.dll.lib"
  $dynamicDll = Join-Path $LibDir "skia.dll"
  $resolvedLinkMode = $LinkMode.Trim().ToLowerInvariant()
  if ($resolvedLinkMode -eq "auto") {
    if ((Test-Path -LiteralPath $dynamicDll -PathType Leaf) -and
        (Test-Path -LiteralPath $dynamicImportLib -PathType Leaf)) {
      $resolvedLinkMode = "dynamic"
    } else {
      $resolvedLinkMode = "static"
    }
  }

  if ($resolvedLinkMode -eq "dynamic") {
    if (!(Test-Path -LiteralPath $dynamicDll -PathType Leaf)) {
      throw "MOUI_SKIA_LINK_MODE=dynamic requested, but skia.dll was not found in $LibDir"
    }
    if (Test-Path -LiteralPath $dynamicImportLib -PathType Leaf) {
      return $dynamicImportLib
    }
    if (Test-Path -LiteralPath $staticLib -PathType Leaf) {
      return $staticLib
    }
    throw "MOUI_SKIA_LINK_MODE=dynamic requested, but skia.dll.lib or skia.lib was not found in $LibDir"
  }

  if (Test-Path -LiteralPath $staticLib -PathType Leaf) {
    return $staticLib
  }

  throw "MOUI_SKIA_LINK_MODE=static requested, but skia.lib was not found in $LibDir"
}

if (!(Test-Path -LiteralPath $VcVarsAll -PathType Leaf)) {
  throw "vcvarsall.bat was not found: $VcVarsAll"
}

$resolvedPaths = Resolve-MouiSkiaMsvcPaths `
  -RepoRoot $repoRoot `
  -SkiaRoot $SkiaRoot `
  -SkiaZip $SkiaZip `
  -SkiaLibDir $SkiaLibDir `
  -ForceExtract:$ForceExtract
$resolvedRoot = $resolvedPaths.Root
$resolvedLibDir = $resolvedPaths.LibDir
$skiaLib = Resolve-SkiaMsvcLibrary -LibDir $resolvedLibDir -LinkMode $SkiaLinkMode

if (Test-Path -LiteralPath $nativeBackup) {
  throw "native/moon.pkg triangle backup already exists: $nativeBackup. Resolve the stale backup before running."
}
if (Test-Path -LiteralPath $triangleBackup) {
  throw "examples/triangle_window/moon.pkg triangle backup already exists: $triangleBackup. Resolve the stale backup before running."
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
$linkFlags = ($orderedPackageLibs + $systemLibs) -join " "
if (![string]::IsNullOrWhiteSpace($ExtraLinkFlags)) {
  $linkFlags = "$linkFlags $ExtraLinkFlags"
}

$originalNative = Get-Content -LiteralPath $nativePkg -Raw
$originalTriangle = Get-Content -LiteralPath $trianglePkg -Raw

try {
  Set-Content -LiteralPath $nativeBackup -Value $originalNative -NoNewline
  Set-Content -LiteralPath $triangleBackup -Value $originalTriangle -NoNewline

  & (Join-Path $repoRoot "scripts/configure-windows-msvc-native-pkg.ps1") `
    -SkiaRoot $resolvedRoot `
    -SkiaLibDir $resolvedLibDir `
    -SkiaLinkMode $SkiaLinkMode `
    -ExtraCcFlags $ExtraCcFlags `
    -ExtraLinkFlags $ExtraLinkFlags `
    -Output $nativePkg `
    -Write | Out-Null

  @"
import {
  "moonbitlang/core/env",
  "wzzc-dev/moui_skia" @skia,
  "wzzc-dev/moui_skia/native",
  "wzzc-dev/window/core",
  "wzzc-dev/window/dpi",
  "wzzc-dev/window/windows",
}

supported_targets = "native"

options(
  "is-main": true,
  link: {
    "native": {
      "cc-link-flags": "$linkFlags",
    },
  },
  targets: {
    "main.mbt": [ "native" ],
    "win32_present.mbt": [ "native" ],
  },
)
"@ | Set-Content -LiteralPath $trianglePkg -NoNewline

  $cmdFile = Join-Path ([System.IO.Path]::GetTempPath()) "moui-skia-triangle-$PID.cmd"
  $traceLine = if ($Trace) { "set MOUI_SKIA_TRIANGLE_TRACE=1" } else { "rem MOUI_SKIA_TRIANGLE_TRACE not enabled" }
  $runLine = if ($BuildOnly) { "exit /b 0" } else { "moon run .\cmd\triangle_window --target native" }
  $cmdContent = @"
@echo off
setlocal
call "$VcVarsAll" $VcArch
if errorlevel 1 exit /b %errorlevel%
set CC=cl
set CXX=cl
set PATH=$resolvedLibDir;%PATH%
cd /d "$repoRoot"
moon build .\cmd\triangle_window --target native
if errorlevel 1 exit /b %errorlevel%
$traceLine
$runLine
exit /b %errorlevel%
"@
  Set-Content -LiteralPath $cmdFile -Value $cmdContent -NoNewline -Encoding ASCII
  & cmd.exe /d /c $cmdFile
  $status = $LASTEXITCODE
  Remove-Item -LiteralPath $cmdFile -ErrorAction SilentlyContinue
  if ($status -ne 0) {
    throw "MoonBit Skia triangle command failed with exit code $status"
  }
} finally {
  Set-Content -LiteralPath $nativePkg -Value $originalNative -NoNewline
  Set-Content -LiteralPath $trianglePkg -Value $originalTriangle -NoNewline
  Remove-Item -LiteralPath $nativeBackup -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $triangleBackup -ErrorAction SilentlyContinue
}
