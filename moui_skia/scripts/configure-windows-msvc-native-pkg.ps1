param(
  [string] $SkiaRoot = $env:MOUI_SKIA_SKIA_ROOT,
  [string] $SkiaInclude = $env:MOUI_SKIA_SKIA_INCLUDE,
  [string] $SkiaZip = $env:MOUI_SKIA_SKIA_ZIP,
  [string] $SkiaLibDir = $env:MOUI_SKIA_SKIA_LIB_DIR,
  [ValidateSet("static", "dynamic", "auto")]
  [string] $SkiaLinkMode = $(if ($env:MOUI_SKIA_LINK_MODE) { $env:MOUI_SKIA_LINK_MODE } else { "static" }),
  [switch] $EnableSkParagraph,
  [switch] $RequireSkParagraph,
  [string] $ExtraCcFlags = $env:MOUI_SKIA_EXTRA_CC_FLAGS,
  [string] $ExtraLinkFlags = $env:MOUI_SKIA_EXTRA_LINK_FLAGS,
  [string] $Output = "native/moon.pkg",
  [switch] $Write,
  [switch] $Check,
  [switch] $ForceExtract
)

$ErrorActionPreference = "Stop"

if ($null -ne [Environment]::GetEnvironmentVariable("MOUI_SKIA_SKIA_LINK_MODE") -or
    $null -ne [Environment]::GetEnvironmentVariable("MOUI_SKIA_MACOS_LINK_MODE")) {
  throw "MOUI_SKIA_SKIA_LINK_MODE and MOUI_SKIA_MACOS_LINK_MODE are no longer supported; use MOUI_SKIA_LINK_MODE=dynamic|static|auto."
}

if ($Write -and $Check) {
  throw "-Write and -Check cannot be used together"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "windows-msvc-skia-paths.ps1")

function Test-TruthyEnv {
  param([string] $Value)

  if ([string]::IsNullOrWhiteSpace($Value)) {
    return $false
  }
  return $Value.Trim().ToLowerInvariant() -in @("1", "true", "yes", "on")
}

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
$skiaLib = Resolve-SkiaMsvcLibrary -LibDir $resolvedLibDir -LinkMode $SkiaLinkMode
$skparagraphEnabled = $EnableSkParagraph.IsPresent -or
  $RequireSkParagraph.IsPresent -or
  (Test-TruthyEnv -Value $env:MOUI_SKIA_ENABLE_SKPARAGRAPH) -or
  (Test-TruthyEnv -Value $env:MOUI_SKIA_REQUIRE_SKPARAGRAPH)
$skparagraphRequired = $RequireSkParagraph.IsPresent -or
  (Test-TruthyEnv -Value $env:MOUI_SKIA_REQUIRE_SKPARAGRAPH)

$paragraphHeaders = @(
  (Join-Path $resolvedIncludeRoot "modules/skparagraph/include/Paragraph.h"),
  (Join-Path $resolvedIncludeRoot "modules/skparagraph/include/ParagraphBuilder.h"),
  (Join-Path $resolvedIncludeRoot "modules/skparagraph/include/ParagraphStyle.h"),
  (Join-Path $resolvedIncludeRoot "modules/skparagraph/include/TextStyle.h"),
  (Join-Path $resolvedIncludeRoot "modules/skparagraph/include/FontCollection.h")
)
$paragraphLibs = @("skparagraph", "skshaper", "skunicode_icu", "skunicode_core")
if ($skparagraphRequired) {
  foreach ($paragraphHeader in $paragraphHeaders) {
    if (!(Test-Path -LiteralPath $paragraphHeader -PathType Leaf)) {
      throw "MOUI_SKIA_REQUIRE_SKPARAGRAPH requested, but header was missing: $paragraphHeader"
    }
  }
  foreach ($paragraphLib in $paragraphLibs) {
    $candidates = @(
      (Join-Path $resolvedLibDir "$paragraphLib.lib"),
      (Join-Path $resolvedLibDir "$paragraphLib.dll.lib")
    )
    $found = $false
    foreach ($candidate in $candidates) {
      if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $found = $true
      }
    }
    if (!$found) {
      throw "MOUI_SKIA_REQUIRE_SKPARAGRAPH requested, but $paragraphLib.lib or $paragraphLib.dll.lib was not found in $resolvedLibDir"
    }
  }
}

if ([System.IO.Path]::IsPathRooted($Output)) {
  $resolvedOutput = $Output
} else {
  $resolvedOutput = Join-Path $repoRoot $Output
}

$includePath = $resolvedIncludeRoot -replace "\\", "/"
$libPath = $resolvedLibDir -replace "\\", "/"

$ccFlags = "/DMOUI_SKIA_HAS_SKIA /std:c++20 /EHsc /I$includePath"
if ($skparagraphEnabled) {
  $ccFlags = "$ccFlags /DMOUI_SKIA_HAS_SKPARAGRAPH /DMOUI_SKIA_HAS_SKSHAPER"
}
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
    "skia_stub_paragraph.cpp",
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
    "skia_native.mbt": [ "native", "llvm" ],
    "availability_native.mbt": [ "native", "llvm" ],
    "surface_image_data_native.mbt": [ "native", "llvm" ],
    "canvas_native.mbt": [ "native", "llvm" ],
    "path_native.mbt": [ "native", "llvm" ],
    "text_font_native.mbt": [ "native", "llvm" ],
    "paragraph_native.mbt": [ "native", "llvm" ],
    "shader_filter_native.mbt": [ "native", "llvm" ],
    "shader_filter_ffi_wbtest.mbt": [ "native", "llvm" ],
    "handles_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "skia_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "availability_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "surface_image_data_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "canvas_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "path_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "text_font_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "paragraph_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
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
