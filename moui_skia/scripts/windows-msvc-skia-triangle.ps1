param(
  [string] $SkiaRoot = $env:MOUI_SKIA_SKIA_ROOT,
  [string] $SkiaZip = $env:MOUI_SKIA_SKIA_ZIP,
  [string] $SkiaLibDir = $env:MOUI_SKIA_SKIA_LIB_DIR,
  [ValidateSet("static", "dynamic", "auto")]
  [string] $SkiaLinkMode = $(if ($env:MOUI_SKIA_LINK_MODE) { $env:MOUI_SKIA_LINK_MODE } else { "static" }),
  [string] $VcVarsAll = $(if ($env:VCVARSALL) { $env:VCVARSALL } else { "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" }),
  [string] $VcArch = "x64",
  [string] $ClangClPath = $env:MOUI_SKIA_CLANG_CL,
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

$ClangClPath = Get-MouiSkiaClangClCompilerPath -ExplicitPath $ClangClPath

$resolvedPaths = Resolve-MouiSkiaMsvcPaths `
  -RepoRoot $repoRoot `
  -SkiaRoot $SkiaRoot `
  -SkiaZip $SkiaZip `
  -SkiaLibDir $SkiaLibDir `
  -ForceExtract:$ForceExtract
$resolvedRoot = $resolvedPaths.Root
$resolvedIncludeRoot = $resolvedPaths.IncludeRoot
$resolvedLibDir = $resolvedPaths.LibDir
$null = Resolve-SkiaMsvcLibrary -LibDir $resolvedLibDir -LinkMode $SkiaLinkMode
$resolvedSkiaLinkMode = $SkiaLinkMode.Trim().ToLowerInvariant()
if ($resolvedSkiaLinkMode -eq "auto") {
  if ((Test-Path -LiteralPath (Join-Path $resolvedLibDir "skia.dll") -PathType Leaf) -and
      (Test-Path -LiteralPath (Join-Path $resolvedLibDir "skia.dll.lib") -PathType Leaf)) {
    $resolvedSkiaLinkMode = "dynamic"
  } else {
    $resolvedSkiaLinkMode = "static"
  }
}

# The moui_skia prebuild (build.mbtx) owns the C++ stub compile flags and the
# native link flags; native/moon.pkg and the example package stay on their
# plain form. Export the resolved contract instead of rewriting package files.
$env:MOUI_SKIA_PLATFORM = "windows"
$env:MOUI_SKIA_SKIA_INCLUDE = $resolvedIncludeRoot
$env:MOUI_SKIA_SKIA_LIB_DIR = $resolvedLibDir
$env:MOUI_SKIA_LINK_MODE = $resolvedSkiaLinkMode
$env:MOUI_SKIA_EXTRA_CC_FLAGS = $ExtraCcFlags
$env:MOUI_SKIA_EXTRA_LINK_FLAGS = $ExtraLinkFlags
# The triangle exercises the CPU raster path; keep the prebuild from adding D3D
# flags and libraries that the old direct link did not use.
$env:MOUI_SKIA_ENABLE_GPU_D3D12 = "0"
$env:MOUI_SKIA_ENABLE_GPU_D3D = "0"
Remove-Item Env:\MOUI_SKIA_DISABLE_PREBUILD_SKIA -ErrorAction SilentlyContinue
$env:MOUI_SKIA_ENABLE_PREBUILD_SKIA = "1"

$cmdFile = Join-Path ([System.IO.Path]::GetTempPath()) "moui-skia-triangle-$PID.cmd"
$traceLine = if ($Trace) { "set MOUI_SKIA_TRIANGLE_TRACE=1" } else { "rem MOUI_SKIA_TRIANGLE_TRACE not enabled" }
$runLine = if ($BuildOnly) { "exit /b 0" } else { "moon run .\examples\triangle_window --target native" }
$cmdContent = @"
@echo off
setlocal
call "$VcVarsAll" $VcArch
if errorlevel 1 exit /b %errorlevel%
set "MOON_CC=$ClangClPath"
set CC=cl
set CXX=cl
set PATH=$resolvedLibDir;%PATH%
cd /d "$repoRoot"
moon build .\examples\triangle_window --target native
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
