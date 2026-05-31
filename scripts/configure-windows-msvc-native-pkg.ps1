param(
  [string] $SkiaRoot = $env:SKIA_MBT_SKIA_ROOT,
  [string] $SkiaInclude = $env:SKIA_MBT_SKIA_INCLUDE,
  [string] $SkiaZip = $env:SKIA_MBT_SKIA_ZIP,
  [string] $SkiaLibDir = $env:SKIA_MBT_SKIA_LIB_DIR,
  [string] $ExtraCcFlags = $env:SKIA_MBT_EXTRA_CC_FLAGS,
  [string] $ExtraLinkFlags = $env:SKIA_MBT_EXTRA_LINK_FLAGS,
  [string] $Output = "native/moon.pkg",
  [switch] $Write,
  [switch] $Check,
  [switch] $ForceExtract
)

$ErrorActionPreference = "Stop"

if ($Write -and $Check) {
  throw "-Write and -Check cannot be used together"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$defaultCacheRoot = Join-Path $repoRoot ".skia-cache/windows-msvc/aseprite/Skia-Windows-Release-x64"
$defaultZip = Join-Path $env:USERPROFILE "Downloads/Skia-Windows-Release-x64.zip"

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

if ([System.IO.Path]::IsPathRooted($Output)) {
  $resolvedOutput = $Output
} else {
  $resolvedOutput = Join-Path $repoRoot $Output
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

$generatedConfig = @"
import {
  "wzzc-dev/skia_mbt" @skia,
}

options(
  "native-stub": [
    "skia_stub_common.cpp",
    "skia_stub_surface_image_data.cpp",
    "skia_stub_canvas.cpp",
    "skia_stub_path.cpp",
    "skia_stub_text_font.cpp",
    "skia_stub_shader_filter.cpp",
  ],
  link: {
    "native": {
      "stub-cc-flags": "$ccFlags",
      "cc-link-flags": "$linkFlags",
    },
  },
  targets: {
    "handles_native.mbt": [ "native", "llvm" ],
    "availability_native.mbt": [ "native", "llvm" ],
    "surface_image_data_native.mbt": [ "native", "llvm" ],
    "canvas_native.mbt": [ "native", "llvm" ],
    "path_native.mbt": [ "native", "llvm" ],
    "text_font_native.mbt": [ "native", "llvm" ],
    "shader_filter_native.mbt": [ "native", "llvm" ],
    "handles_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "availability_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "surface_image_data_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "canvas_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "path_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "text_font_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "shader_filter_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
  },
)
"@

if ($Check) {
  if (!(Test-Path -LiteralPath $resolvedOutput -PathType Leaf)) {
    throw "native package file is missing: $resolvedOutput"
  }
  $actual = Get-Content -LiteralPath $resolvedOutput -Raw
  if ($actual.TrimEnd() -ne $generatedConfig.TrimEnd()) {
    throw "native package file does not match generated Windows MSVC Skia link config: $resolvedOutput"
  }
  Write-Host "Verified $resolvedOutput matches generated Windows MSVC Skia link config."
  exit 0
}

if ($Write) {
  $outputDir = Split-Path -Parent $resolvedOutput
  if ($outputDir.Length -gt 0) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
  }
  Set-Content -LiteralPath $resolvedOutput -Value $generatedConfig -NoNewline
  Write-Host "Wrote Windows MSVC Skia link config to $resolvedOutput"
  exit 0
}

Write-Output $generatedConfig
