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
  [switch] $EnableSkParagraph,
  [switch] $RequireSkParagraph,
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
$textPkg = Join-Path $repoRoot "examples/text_window/moon.pkg"
$nativeBackup = "$nativePkg.text.bak"
$textBackup = "$textPkg.text.bak"
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
$resolvedIncludeRoot = $resolvedPaths.IncludeRoot
$resolvedLibDir = $resolvedPaths.LibDir
$skiaLib = Resolve-SkiaMsvcLibrary -LibDir $resolvedLibDir -LinkMode $SkiaLinkMode
$resolvedSkiaLinkMode = $SkiaLinkMode.Trim().ToLowerInvariant()
if ($resolvedSkiaLinkMode -eq "auto") {
  if ((Test-Path -LiteralPath (Join-Path $resolvedLibDir "skia.dll") -PathType Leaf) -and
      (Test-Path -LiteralPath (Join-Path $resolvedLibDir "skia.dll.lib") -PathType Leaf)) {
    $resolvedSkiaLinkMode = "dynamic"
  } else {
    $resolvedSkiaLinkMode = "static"
  }
}
$skparagraphEnabled = $true
$skparagraphRequired = $RequireSkParagraph.IsPresent -or
  (Test-TruthyEnv -Value $env:MOUI_SKIA_REQUIRE_SKPARAGRAPH)
$paragraphHeaders = @(
  (Join-Path $resolvedIncludeRoot "modules/skparagraph/include/Paragraph.h"),
  (Join-Path $resolvedIncludeRoot "modules/skparagraph/include/ParagraphBuilder.h"),
  (Join-Path $resolvedIncludeRoot "modules/skparagraph/include/ParagraphStyle.h"),
  (Join-Path $resolvedIncludeRoot "modules/skparagraph/include/TextStyle.h"),
  (Join-Path $resolvedIncludeRoot "modules/skparagraph/include/FontCollection.h")
)
$paragraphLibs = @("skparagraph", "skshaper", "skunicode_core", "skunicode_icu")
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

if (Test-Path -LiteralPath $nativeBackup) {
  throw "native/moon.pkg text backup already exists: $nativeBackup. Resolve the stale backup before running."
}
if (Test-Path -LiteralPath $textBackup) {
  throw "examples/text_window/moon.pkg text backup already exists: $textBackup. Resolve the stale backup before running."
}

$packageLibs = Get-MsvcLinkLibraries -LibDir $resolvedLibDir -LinkMode $resolvedSkiaLinkMode
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
$originalText = Get-Content -LiteralPath $textPkg -Raw

try {
  Set-Content -LiteralPath $nativeBackup -Value $originalNative -NoNewline
  Set-Content -LiteralPath $textBackup -Value $originalText -NoNewline

  & (Join-Path $repoRoot "scripts/configure-windows-msvc-native-pkg.ps1") `
    -SkiaRoot $resolvedRoot `
    -SkiaLibDir $resolvedLibDir `
    -SkiaLinkMode $SkiaLinkMode `
    -EnableSkParagraph:$skparagraphEnabled `
    -RequireSkParagraph:$skparagraphRequired `
    -ExtraCcFlags $ExtraCcFlags `
    -ExtraLinkFlags $ExtraLinkFlags `
    -Output $nativePkg `
    -Write | Out-Null

  @"
import {
  "moonbitlang/core/encoding/utf8",
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
"@ | Set-Content -LiteralPath $textPkg -NoNewline

  $cmdFile = Join-Path ([System.IO.Path]::GetTempPath()) "moui-skia-text-$PID.cmd"
  $traceLine = if ($Trace) { "set MOUI_SKIA_TEXT_TRACE=1" } else { "rem MOUI_SKIA_TEXT_TRACE not enabled" }
  $runLine = if ($BuildOnly) { "exit /b 0" } else { "moon run .\cmd\text_window --target native" }
  $cmdContent = @"
@echo off
setlocal
call "$VcVarsAll" $VcArch
if errorlevel 1 exit /b %errorlevel%
set CC=cl
set CXX=cl
set PATH=$resolvedLibDir;%PATH%
cd /d "$repoRoot"
moon build .\cmd\text_window --target native
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
    throw "MoonBit Skia text command failed with exit code $status"
  }
} finally {
  Set-Content -LiteralPath $nativePkg -Value $originalNative -NoNewline
  Set-Content -LiteralPath $textPkg -Value $originalText -NoNewline
  Remove-Item -LiteralPath $nativeBackup -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $textBackup -ErrorAction SilentlyContinue
}
