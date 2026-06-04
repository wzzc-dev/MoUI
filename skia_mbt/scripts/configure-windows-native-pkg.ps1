param(
  [string] $SkiaInclude = $env:SKIA_MBT_SKIA_INCLUDE,
  [string] $SkiaLibDir = $env:SKIA_MBT_SKIA_LIB_DIR,
  [string] $SkiaLib = $(if ($env:SKIA_MBT_SKIA_LIB) { $env:SKIA_MBT_SKIA_LIB } else { "skia" }),
  [string] $ExtraCcFlags = $env:SKIA_MBT_EXTRA_CC_FLAGS,
  [string] $ExtraLinkFlags = $env:SKIA_MBT_EXTRA_LINK_FLAGS,
  [string] $Output = "native/moon.pkg",
  [switch] $Write,
  [switch] $Check
)

$ErrorActionPreference = "Stop"

if ($Write -and $Check) {
  throw "-Write and -Check cannot be used together"
}
if ([string]::IsNullOrWhiteSpace($SkiaInclude) -or [string]::IsNullOrWhiteSpace($SkiaLibDir)) {
  throw "SkiaInclude and SkiaLibDir are required; pass -SkiaInclude/-SkiaLibDir or set SKIA_MBT_SKIA_INCLUDE/SKIA_MBT_SKIA_LIB_DIR"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([System.IO.Path]::IsPathRooted($Output)) {
  $resolvedOutput = $Output
} else {
  $resolvedOutput = Join-Path $repoRoot $Output
}

$resolvedInclude = (Resolve-Path -LiteralPath $SkiaInclude).Path
$resolvedLibDir = (Resolve-Path -LiteralPath $SkiaLibDir).Path
$includePath = $resolvedInclude -replace "\\", "/"
$libPath = $resolvedLibDir -replace "\\", "/"

$headerPath = Join-Path $resolvedInclude "include/core/SkSurface.h"
if (!(Test-Path -LiteralPath $headerPath)) {
  throw "Skia include path does not look like a Skia checkout/root: $resolvedInclude"
}

$staticLib = Join-Path $resolvedLibDir "lib$SkiaLib.a"
$dllImportLib = Join-Path $resolvedLibDir "$SkiaLib.lib"
if (!(Test-Path -LiteralPath $staticLib) -and !(Test-Path -LiteralPath $dllImportLib)) {
  throw "MinGW-compatible lib$SkiaLib.a or $SkiaLib.lib was not found in $resolvedLibDir"
}

$ccFlags = "-DSKIA_MBT_HAS_SKIA -I$includePath"
if (![string]::IsNullOrWhiteSpace($ExtraCcFlags)) {
  $ccFlags = "$ccFlags $ExtraCcFlags"
}

$linkFlags = "-L$libPath -l$SkiaLib"
if (![string]::IsNullOrWhiteSpace($ExtraLinkFlags)) {
  $linkFlags = "$linkFlags $ExtraLinkFlags"
}

$generatedConfig = @"
import {
  "wzzc-dev/skia_mbt" @skia,
}

options(
  "native-stub": [
    "skia_stub.cpp",
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
    throw "native package file does not match generated Windows Skia link config: $resolvedOutput"
  }
  Write-Host "Verified $resolvedOutput matches generated Windows Skia link config."
  exit 0
}

if ($Write) {
  $outputDir = Split-Path -Parent $resolvedOutput
  if ($outputDir.Length -gt 0) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
  }
  Set-Content -LiteralPath $resolvedOutput -Value $generatedConfig -NoNewline
  Write-Host "Wrote Windows Skia link config to $resolvedOutput"
  exit 0
}

Write-Output $generatedConfig
