param(
  [string] $SkiaRoot = $env:MOUI_SKIA_SKIA_ROOT,
  [string] $SkiaInclude = $env:MOUI_SKIA_SKIA_INCLUDE,
  [string] $SkiaZip = $env:MOUI_SKIA_SKIA_ZIP,
  [string] $SkiaLibDir = $env:MOUI_SKIA_SKIA_LIB_DIR,
  [string] $ExtraCcFlags = $env:MOUI_SKIA_EXTRA_CC_FLAGS,
  [string] $ExtraLinkFlags = $env:MOUI_SKIA_EXTRA_LINK_FLAGS,
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
. (Join-Path $PSScriptRoot "windows-msvc-skia-paths.ps1")

function Resolve-SkiaMsvcLibrary {
  param([Parameter(Mandatory = $true)][string] $LibDir)

  $candidates = @(
    (Join-Path $LibDir "skia.lib"),
    (Join-Path $LibDir "skia.dll.lib")
  )
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      return $candidate
    }
  }

  throw "Skia MSVC library was not found in $LibDir; expected skia.lib or skia.dll.lib"
}

$resolvedPaths = Resolve-MouiSkiaMsvcPaths `
  -RepoRoot $repoRoot `
  -SkiaRoot $SkiaRoot `
  -SkiaInclude $SkiaInclude `
  -SkiaZip $SkiaZip `
  -SkiaLibDir $SkiaLibDir `
  -ForceExtract:$ForceExtract
$resolvedRoot = $resolvedPaths.Root
$resolvedIncludeRoot = $resolvedPaths.IncludeRoot
$resolvedLibDir = $resolvedPaths.LibDir
$skiaLib = Resolve-SkiaMsvcLibrary -LibDir $resolvedLibDir

if ([System.IO.Path]::IsPathRooted($Output)) {
  $resolvedOutput = $Output
} else {
  $resolvedOutput = Join-Path $repoRoot $Output
}

$includePath = $resolvedIncludeRoot -replace "\\", "/"
$libPath = $resolvedLibDir -replace "\\", "/"

$ccFlags = "/DMOUI_SKIA_HAS_SKIA /std:c++20 /EHsc /I$includePath"
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
  "wzzc-dev/moui_skia" @skia,
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
