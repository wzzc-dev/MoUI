param(
  [string] $SkiaInclude = $env:MOUI_SKIA_SKIA_INCLUDE,
  [string] $SkiaLibDir = $env:MOUI_SKIA_SKIA_LIB_DIR,
  [string] $SkiaLib = $(if ($env:MOUI_SKIA_SKIA_LIB) { $env:MOUI_SKIA_SKIA_LIB } else { "skia" }),
  [string] $ExtraCcFlags = $env:MOUI_SKIA_EXTRA_CC_FLAGS,
  [string] $ExtraLinkFlags = $env:MOUI_SKIA_EXTRA_LINK_FLAGS,
  [string] $Output = "native/moon.pkg",
  [switch] $Write,
  [switch] $Check
)

$ErrorActionPreference = "Stop"

if ($Write -and $Check) {
  throw "-Write and -Check cannot be used together"
}
if ([string]::IsNullOrWhiteSpace($SkiaInclude) -or [string]::IsNullOrWhiteSpace($SkiaLibDir)) {
  throw "SkiaInclude and SkiaLibDir are required; pass -SkiaInclude/-SkiaLibDir or set MOUI_SKIA_SKIA_INCLUDE/MOUI_SKIA_SKIA_LIB_DIR"
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

$ccFlags = "-DMOUI_SKIA_HAS_SKIA -I$includePath"
if (![string]::IsNullOrWhiteSpace($ExtraCcFlags)) {
  $ccFlags = "$ccFlags $ExtraCcFlags"
}

$linkFlags = "-L$libPath -l$SkiaLib"
if (![string]::IsNullOrWhiteSpace($ExtraLinkFlags)) {
  $linkFlags = "$linkFlags $ExtraLinkFlags"
}

$envBlock = @"
`$env:MOUI_SKIA_SKIA_INCLUDE = "$includePath"
`$env:MOUI_SKIA_SKIA_LIB_DIR = "$libPath"
`$env:MOUI_SKIA_EXTRA_CC_FLAGS = "$ExtraCcFlags"
`$env:MOUI_SKIA_EXTRA_LINK_FLAGS = "$ExtraLinkFlags"
"@

# The Skia C++ stub is no longer `native-stub` material: the CLI injects
# `/std:c11` for MSVC stub compiles, which clashes with Skia's `/std:c++20`
# (D8016). The moui_skia prebuild (`build.mbtx`) compiles and links the stub, so
# this helper only resolves the environment that prebuild consumes.
if ($Check) {
  if (!(Test-Path -LiteralPath $resolvedOutput -PathType Leaf)) {
    throw "native package file is missing: $resolvedOutput"
  }
  $actual = Get-Content -LiteralPath $resolvedOutput -Raw
  if ($actual -match '"native-stub"|"stub-cc-flags"') {
    throw "native/moon.pkg must not list C++ stub sources or stub-cc-flags (Windows D8016): $resolvedOutput"
  }
  if ($actual -notmatch '\$\{build\.MOUI_SKIA_CC_LINK_FLAGS\}') {
    throw ('native/moon.pkg must carry cc-link-flags = "${build.MOUI_SKIA_CC_LINK_FLAGS}": ' + $resolvedOutput)
  }
  Write-Host "Verified $resolvedOutput is the prebuild-based native package (no C++ stub sources)."
  exit 0
}

if ($Write) {
  throw ("configure-windows-native-pkg.ps1 no longer writes native/moon.pkg: the moui_skia " +
    "prebuild (build.mbtx) now owns the Skia flags and the C++ stub archive. Export the " +
    "variables below and run moon without MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 instead:" +
    [Environment]::NewLine + $envBlock)
}

Write-Output "Resolved Windows Skia configuration for the moui_skia prebuild:"
Write-Output $envBlock
Write-Output "native/moon.pkg is intentionally left unchanged (prebuild-based; no C++ stub sources)."
