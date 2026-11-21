param(
  [string] $SkiaRoot = $env:MOUI_SKIA_SKIA_ROOT,
  [string] $SkiaInclude = $env:MOUI_SKIA_SKIA_INCLUDE,
  [string] $SkiaZip = $env:MOUI_SKIA_SKIA_ZIP,
  [string] $SkiaLibDir = $env:MOUI_SKIA_SKIA_LIB_DIR,
  [string] $VcVarsAll = $env:VCVARSALL,
  [string] $ClangClPath = $env:MOUI_SKIA_CLANG_CL,
  [string] $VcArch = "x64",
  [string] $SkiaProvider = $env:MOUI_SKIA_SKIA_PROVIDER,
  [string] $SkiaLinkMode = $(if ($env:MOUI_SKIA_LINK_MODE) { $env:MOUI_SKIA_LINK_MODE } else { "static" }),
  [string] $ReleaseOwner = $env:MOUI_SKIA_RELEASE_OWNER,
  [string] $ReleaseRepo = $env:MOUI_SKIA_RELEASE_REPO,
  [string] $ReleaseTag = $env:MOUI_SKIA_RELEASE_TAG,
  [string] $ReleaseUrl = $env:MOUI_SKIA_RELEASE_URL,
  [string] $JetBrainsTag = $env:MOUI_SKIA_JETBRAINS_TAG,
  [string] $SkiaCommit = $env:MOUI_SKIA_SKIA_COMMIT,
  [string] $SkiaPackage = $env:MOUI_SKIA_SKIA_PACKAGE,
  [string] $SkiaPackageSha256 = $env:MOUI_SKIA_SKIA_PACKAGE_SHA256,
  [switch] $EnableSkParagraph,
  [switch] $RequireSkParagraph,
  [string] $ExtraCcFlags = $env:MOUI_SKIA_EXTRA_CC_FLAGS,
  [string] $ExtraLinkFlags = $env:MOUI_SKIA_EXTRA_LINK_FLAGS,
  [string] $SmokeLog = "",
  [switch] $RunRendererSmoke,
  [switch] $RunTextEmojiSmoke,
  [string] $RendererLog = "",
  [string] $TextEmojiLog = "",
  [switch] $DryRunConfig,
  [switch] $ForceExtract
)

$ErrorActionPreference = "Stop"

if ($null -ne [Environment]::GetEnvironmentVariable("MOUI_SKIA_SKIA_LINK_MODE") -or
    $null -ne [Environment]::GetEnvironmentVariable("MOUI_SKIA_MACOS_LINK_MODE")) {
  throw "MOUI_SKIA_SKIA_LINK_MODE and MOUI_SKIA_MACOS_LINK_MODE are no longer supported; use MOUI_SKIA_LINK_MODE=dynamic|static|auto."
}

$normalizedSkiaLinkMode = $SkiaLinkMode.Trim().ToLowerInvariant()
if ($normalizedSkiaLinkMode -notin @("static", "dynamic", "auto")) {
  throw "unsupported SkiaLinkMode: $SkiaLinkMode"
}

$mouiSkiaRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $mouiSkiaRoot
. (Join-Path $PSScriptRoot "windows-msvc-skia-paths.ps1")

function Test-TruthyEnv {
  param([string] $Value)

  if ([string]::IsNullOrWhiteSpace($Value)) {
    return $false
  }
  return $Value.Trim().ToLowerInvariant() -in @("1", "true", "yes", "on")
}

function Resolve-StaticSkiaLib {
  param([Parameter(Mandatory = $true)][string] $LibDir)

  $candidate = Join-Path $LibDir "skia.lib"
  if (Test-Path -LiteralPath $candidate -PathType Leaf) {
    return $candidate
  }

  throw "skia.lib was not found in $LibDir"
}

function Resolve-DynamicSkiaImportLib {
  param([Parameter(Mandatory = $true)][string] $LibDir)

  $candidates = @(
    (Join-Path $LibDir "skia.dll.lib"),
    (Join-Path $LibDir "skia.lib")
  )
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      return $candidate
    }
  }

  throw "Skia dynamic import library was not found in $LibDir; expected skia.dll.lib or skia.lib"
}

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

$ClangClPath = Get-MouiSkiaClangClCompilerPath -ExplicitPath $ClangClPath

$resolvedPaths = Resolve-MouiSkiaMsvcPaths `
  -RepoRoot $mouiSkiaRoot `
  -SkiaRoot $SkiaRoot `
  -SkiaInclude $SkiaInclude `
  -SkiaZip $SkiaZip `
  -SkiaLibDir $SkiaLibDir `
  -ForceExtract:$ForceExtract
$resolvedRoot = $resolvedPaths.Root
$resolvedIncludeRoot = $resolvedPaths.IncludeRoot
$resolvedLibDir = $resolvedPaths.LibDir
$skiaDll = Join-Path $resolvedLibDir "skia.dll"
$resolvedSkiaLinkMode = $normalizedSkiaLinkMode
if ($resolvedSkiaLinkMode -eq "auto") {
  if (Test-Path -LiteralPath $skiaDll -PathType Leaf) {
    $resolvedSkiaLinkMode = "dynamic"
  } else {
    $resolvedSkiaLinkMode = "static"
  }
}
if ($resolvedSkiaLinkMode -eq "dynamic" -and !(Test-Path -LiteralPath $skiaDll -PathType Leaf)) {
  throw "Requested dynamic Skia link mode, but skia.dll was not found in $resolvedLibDir"
}
$skiaLib = if ($resolvedSkiaLinkMode -eq "dynamic") {
  Resolve-DynamicSkiaImportLib -LibDir $resolvedLibDir
} else {
  Resolve-StaticSkiaLib -LibDir $resolvedLibDir
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
$paragraphHeadersStatus = "unchecked"
$paragraphLibrariesStatus = "unchecked"
if ($skparagraphEnabled) {
  $paragraphHeadersStatus = "available"
  foreach ($paragraphHeader in $paragraphHeaders) {
    if (!(Test-Path -LiteralPath $paragraphHeader -PathType Leaf)) {
      $paragraphHeadersStatus = "missing"
    }
  }
  $paragraphLibrariesStatus = "available"
  foreach ($paragraphLib in $paragraphLibs) {
    $candidates = @(
      (Join-Path $resolvedLibDir "$paragraphLib.lib"),
      (Join-Path $resolvedLibDir "$paragraphLib.dll.lib")
    )
    $found = $false
    foreach ($candidate in $candidates) {
      if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $found = $true
        break
      }
    }
    if (!$found) {
      $paragraphLibrariesStatus = "missing"
      break
    }
  }
  if ($skparagraphRequired -and $paragraphHeadersStatus -ne "available") {
    throw "MOUI_SKIA_REQUIRE_SKPARAGRAPH requested, but one or more SkParagraph headers are missing under $resolvedIncludeRoot"
  }
  if ($skparagraphRequired -and $paragraphLibrariesStatus -ne "available") {
    throw "MOUI_SKIA_REQUIRE_SKPARAGRAPH requested, but one or more SkParagraph libraries are missing in $resolvedLibDir"
  }
  if ($paragraphHeadersStatus -ne "available" -or $paragraphLibrariesStatus -ne "available") {
    Write-Warning "SkParagraph headers or libraries are unavailable; disabling SkParagraph support"
    $skparagraphEnabled = $false
  }
}

$resolvedSmokeLog = ""
if ($SmokeLog.Trim().Length -gt 0) {
  if ([System.IO.Path]::IsPathRooted($SmokeLog)) {
    $resolvedSmokeLog = $SmokeLog
  } else {
    $resolvedSmokeLog = Join-Path $repoRoot $SmokeLog
  }
}

$resolvedRendererLog = ""
if ($RendererLog.Trim().Length -gt 0) {
  if ([System.IO.Path]::IsPathRooted($RendererLog)) {
    $resolvedRendererLog = $RendererLog
  } else {
    $resolvedRendererLog = Join-Path $repoRoot $RendererLog
  }
}

$resolvedTextEmojiLog = ""
if ($TextEmojiLog.Trim().Length -gt 0) {
  if ([System.IO.Path]::IsPathRooted($TextEmojiLog)) {
    $resolvedTextEmojiLog = $TextEmojiLog
  } else {
    $resolvedTextEmojiLog = Join-Path $repoRoot $TextEmojiLog
  }
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
  "d3d12.lib",
  "d3dcompiler.lib",
  "dxguid.lib",
  "advapi32.lib",
  "comdlg32.lib",
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
Write-Output "  clang_cl=$ClangClPath"
Write-Output "  vc_arch=$VcArch"
Write-Output "  skia_root=$resolvedRoot"
Write-Output "  skia_include=$includePath"
Write-Output "  skia_lib_dir=$libPath"
Write-Output "  skia_lib=skia"
Write-Output "  skia_link_mode=$resolvedSkiaLinkMode"
if ($skparagraphRequired) {
  Write-Output "  skparagraph=required"
} elseif ($skparagraphEnabled) {
  Write-Output "  skparagraph=enabled"
} else {
  Write-Output "  skparagraph=disabled"
}
if ($skparagraphEnabled) {
  Write-Output "  skparagraph_headers=$paragraphHeadersStatus"
  Write-Output "  skparagraph_libraries=$paragraphLibrariesStatus"
}
if (![string]::IsNullOrWhiteSpace($SkiaProvider)) {
  Write-Output "  skia_provider=$SkiaProvider"
}
if (![string]::IsNullOrWhiteSpace($ReleaseOwner)) {
  Write-Output "  release_owner=$ReleaseOwner"
}
if (![string]::IsNullOrWhiteSpace($ReleaseRepo)) {
  Write-Output "  release_repo=$ReleaseRepo"
}
if (![string]::IsNullOrWhiteSpace($ReleaseTag)) {
  Write-Output "  release_tag=$ReleaseTag"
}
if (![string]::IsNullOrWhiteSpace($ReleaseUrl)) {
  Write-Output "  release_url=$ReleaseUrl"
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
if ($resolvedSkiaLinkMode -eq "dynamic") {
  $dllItem = Get-Item -LiteralPath $skiaDll
  Write-Output "  library=$($dllItem.Name) $($dllItem.Length) bytes"
}
Write-Output "  stub_cc_flags=$ccFlags"
Write-Output "  cc_link_flags=$linkFlags"
if ($resolvedSmokeLog.Length -gt 0) {
  Write-Output "  smoke_log=$resolvedSmokeLog"
}
if ($RunRendererSmoke) {
  Write-Output "  run_renderer_smoke=true"
}
if ($RunTextEmojiSmoke) {
  Write-Output "  run_text_emoji_smoke=true"
}
if ($resolvedRendererLog.Length -gt 0) {
  Write-Output "  renderer_log=$resolvedRendererLog"
}
if ($resolvedTextEmojiLog.Length -gt 0) {
  Write-Output "  text_emoji_log=$resolvedTextEmojiLog"
}

if ($DryRunConfig) {
  Write-Output "Dry run complete; native/moon.pkg was not modified and no build was run."
  exit 0
}

# The moui_skia prebuild (build.mbtx) owns the C++ stub compile flags and the
# native link flags; native/moon.pkg stays on its
# `${build.MOUI_SKIA_CC_LINK_FLAGS}` form. Export the resolved contract instead
# of rewriting package files.
$env:MOUI_SKIA_PLATFORM = "windows"
$env:MOUI_SKIA_SKIA_INCLUDE = $includePath
$env:MOUI_SKIA_SKIA_LIB_DIR = $libPath
$env:MOUI_SKIA_LINK_MODE = $resolvedSkiaLinkMode
$env:MOUI_SKIA_EXTRA_CC_FLAGS = $ExtraCcFlags
$env:MOUI_SKIA_EXTRA_LINK_FLAGS = $ExtraLinkFlags
$env:MOUI_SKIA_ENABLE_SKPARAGRAPH = if ($skparagraphEnabled) { "1" } else { "0" }
$env:MOUI_SKIA_REQUIRE_SKPARAGRAPH = if ($skparagraphRequired) { "1" } else { "0" }
# The smoke exercises the CPU raster path; keep the prebuild from adding D3D
# flags and libraries that the old direct link did not use.
$env:MOUI_SKIA_ENABLE_GPU_D3D12 = "0"
$env:MOUI_SKIA_ENABLE_GPU_D3D = "0"
if (![string]::IsNullOrWhiteSpace($SkiaProvider)) {
  $env:MOUI_SKIA_SKIA_PROVIDER = $SkiaProvider
}
if (![string]::IsNullOrWhiteSpace($ReleaseTag)) {
  $env:MOUI_SKIA_RELEASE_TAG = $ReleaseTag
}
Remove-Item Env:\MOUI_SKIA_DISABLE_PREBUILD_SKIA -ErrorAction SilentlyContinue
$env:MOUI_SKIA_ENABLE_PREBUILD_SKIA = "1"
Write-Host "Exported the moui_skia prebuild Skia contract (no package file was rewritten)."

Push-Location $mouiSkiaRoot
try {
    if ($resolvedSmokeLog.Length -eq 0) {
      $resolvedSmokeLog = Join-Path ([System.IO.Path]::GetTempPath()) "moui-skia-native-msvc-smoke-$PID.log"
    } else {
      $smokeLogDir = Split-Path -Parent $resolvedSmokeLog
      if ($smokeLogDir.Length -gt 0) {
        New-Item -ItemType Directory -Force -Path $smokeLogDir | Out-Null
      }
    }
    $cmdFile = Join-Path ([System.IO.Path]::GetTempPath()) "moui-skia-msvc-smoke-$PID.cmd"
    $logPath = $resolvedSmokeLog -replace '"', '""'
    $errPath = ($resolvedSmokeLog + ".err") -replace '"', '""'
    $vcPath = $VcVarsAll -replace '"', '""'
    $clangClCmdPath = $ClangClPath -replace '"', '""'
    $cmdContent = @"
@echo off
setlocal
call "$vcPath" $VcArch
if errorlevel 1 exit /b %errorlevel%
set "MOON_CC=$clangClCmdPath"
set CC=cl
set CXX=cl
set PATH=$resolvedLibDir;%PATH%
set "WORKSPACE_ROOT=$repoRoot"
echo cl version:
cl 2>&1
set SMOKE_EXE=%WORKSPACE_ROOT%\_build\native\debug\build\wzzc-dev\moui_skia\scripts\native_smoke\native_smoke.exe
if exist "%SMOKE_EXE%" del "%SMOKE_EXE%"
echo building native smoke...
moon build scripts/native_smoke --target native
if errorlevel 1 exit /b %errorlevel%
if not exist "%SMOKE_EXE%" (
  echo native smoke executable was not produced: %SMOKE_EXE%
  exit /b 1
)
echo running native smoke executable: %SMOKE_EXE%
"%SMOKE_EXE%" > "$logPath" 2>"$errPath"
set SMOKE_STATUS=%errorlevel%
type "$logPath"
if exist "$errPath" (
  echo --- native smoke stderr ---
  type "$errPath"
)
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
    if (!(Select-String -LiteralPath $resolvedSmokeLog -SimpleMatch "moui_skia native smoke test passed" -Quiet)) {
      throw "native smoke executable did not print the expected success marker"
    }
    Write-Host "Verified native smoke success marker."
    if ($skparagraphRequired) {
      if (!(Select-String -LiteralPath $resolvedSmokeLog -SimpleMatch "native smoke paragraph available" -Quiet)) {
        throw "native smoke executable did not prove the required SkParagraph path"
      }
      Write-Host "Verified native SkParagraph smoke marker."
    }
  } finally {
    Pop-Location
  }

  if ($RunRendererSmoke) {
    if ($resolvedRendererLog.Length -eq 0) {
        $resolvedRendererLog = Join-Path ([System.IO.Path]::GetTempPath()) "moui-skia-msvc-renderer-smoke-$PID.log"
      } else {
        $rendererLogDir = Split-Path -Parent $resolvedRendererLog
        if ($rendererLogDir.Length -gt 0) {
          New-Item -ItemType Directory -Force -Path $rendererLogDir | Out-Null
        }
      }

      Push-Location $repoRoot
      try {
        $env:MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM = "1"
        $rendererCmdFile = Join-Path ([System.IO.Path]::GetTempPath()) "moui-skia-msvc-renderer-smoke-$PID.cmd"
        $rendererLogPath = $resolvedRendererLog -replace '"', '""'
        $rendererErrPath = ($resolvedRendererLog + ".err") -replace '"', '""'
        $vcPath = $VcVarsAll -replace '"', '""'
        $clangClCmdPath = $ClangClPath -replace '"', '""'
        $rendererCmdContent = @"
@echo off
setlocal
call "$vcPath" $VcArch
if errorlevel 1 exit /b %errorlevel%
set "MOON_CC=$clangClCmdPath"
set CC=cl
set CXX=cl
set PATH=$resolvedLibDir;%PATH%
set "WORKSPACE_ROOT=$repoRoot"
echo building renderer smoke...
moon build moui_tests/skia_renderer_smoke/native --target native
if errorlevel 1 exit /b %errorlevel%
set "RENDERER_EXE=%WORKSPACE_ROOT%\_build\native\debug\build\wzzc-dev\moui_tests\skia_renderer_smoke\native\native.exe"
if not exist "%RENDERER_EXE%" (
  echo renderer smoke executable was not produced: %RENDERER_EXE%
  exit /b 1
)
echo running renderer smoke executable: %RENDERER_EXE%
"%RENDERER_EXE%" > "$rendererLogPath" 2>"$rendererErrPath"
set RENDERER_STATUS=%errorlevel%
type "$rendererLogPath"
if exist "$rendererErrPath" (
  echo --- renderer smoke stderr ---
  type "$rendererErrPath"
)
exit /b %RENDERER_STATUS%
"@
        Set-Content -LiteralPath $rendererCmdFile -Value $rendererCmdContent -NoNewline -Encoding ASCII
        $oldErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
          & cmd.exe /d /c $rendererCmdFile 2>&1 | ForEach-Object { Write-Host $_ }
          $rendererStatus = $LASTEXITCODE
        } finally {
          $ErrorActionPreference = $oldErrorActionPreference
          Remove-Item -LiteralPath $rendererCmdFile -ErrorAction SilentlyContinue
        }
        if ($rendererStatus -ne 0) {
          throw "Windows MSVC renderer smoke failed with exit code $rendererStatus"
        }
        if (!(Select-String -LiteralPath $resolvedRendererLog -SimpleMatch "MoUI Skia renderer smoke passed" -Quiet)) {
          throw "renderer smoke did not print the expected success marker"
        }
        Write-Host "Verified MoUI Skia renderer smoke success marker."
        if (!(Select-String -LiteralPath $resolvedRendererLog -SimpleMatch "MoUI Skia async image second-frame smoke passed" -Quiet)) {
          throw "renderer smoke did not report async image second-frame marker"
        }
        Write-Host "Verified MoUI Skia async image second-frame marker."
        if (!(Select-String -LiteralPath $resolvedRendererLog -SimpleMatch "MoUI Skia async image deferred-completion smoke passed" -Quiet)) {
          throw "renderer smoke did not report async image deferred-completion marker"
        }
        Write-Host "Verified MoUI Skia async image deferred-completion marker."
      } finally {
        Remove-Item Env:\MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM -ErrorAction SilentlyContinue
        Pop-Location
      }
  }

  if ($RunTextEmojiSmoke) {
    if (!$skparagraphEnabled) {
      throw "-RunTextEmojiSmoke requires -EnableSkParagraph or -RequireSkParagraph for SkParagraph bidi/emoji markers"
    }
    if ($resolvedTextEmojiLog.Length -eq 0) {
        $resolvedTextEmojiLog = Join-Path ([System.IO.Path]::GetTempPath()) "moui-skia-msvc-text-emoji-smoke-$PID.log"
      } else {
        $textEmojiLogDir = Split-Path -Parent $resolvedTextEmojiLog
        if ($textEmojiLogDir.Length -gt 0) {
          New-Item -ItemType Directory -Force -Path $textEmojiLogDir | Out-Null
        }
      }

      Push-Location $repoRoot
      try {
        $env:MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM = "1"
        $textEmojiCmdFile = Join-Path ([System.IO.Path]::GetTempPath()) "moui-skia-msvc-text-emoji-smoke-$PID.cmd"
        $textEmojiLogPath = $resolvedTextEmojiLog -replace '"', '""'
        $textEmojiErrPath = ($resolvedTextEmojiLog + ".err") -replace '"', '""'
        $vcPath = $VcVarsAll -replace '"', '""'
        $clangClCmdPath = $ClangClPath -replace '"', '""'
        $textEmojiCmdContent = @"
@echo off
setlocal
call "$vcPath" $VcArch
if errorlevel 1 exit /b %errorlevel%
set "MOON_CC=$clangClCmdPath"
set CC=cl
set CXX=cl
set PATH=$resolvedLibDir;%PATH%
set "WORKSPACE_ROOT=$repoRoot"
echo building text/emoji smoke...
moon build moui_tests/skia_text_emoji_smoke/native --target native
if errorlevel 1 exit /b %errorlevel%
set "TEXT_EMOJI_EXE=%WORKSPACE_ROOT%\_build\native\debug\build\wzzc-dev\moui_tests\skia_text_emoji_smoke\native\native.exe"
if not exist "%TEXT_EMOJI_EXE%" (
  echo text/emoji smoke executable was not produced: %TEXT_EMOJI_EXE%
  exit /b 1
)
echo running text/emoji smoke executable: %TEXT_EMOJI_EXE%
"%TEXT_EMOJI_EXE%" > "$textEmojiLogPath" 2>"$textEmojiErrPath"
set TEXT_EMOJI_STATUS=%errorlevel%
type "$textEmojiLogPath"
if exist "$textEmojiErrPath" (
  echo --- text/emoji smoke stderr ---
  type "$textEmojiErrPath"
)
exit /b %TEXT_EMOJI_STATUS%
"@
        Set-Content -LiteralPath $textEmojiCmdFile -Value $textEmojiCmdContent -NoNewline -Encoding ASCII
        $oldErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
          & cmd.exe /d /c $textEmojiCmdFile 2>&1 | ForEach-Object { Write-Host $_ }
          $textEmojiStatus = $LASTEXITCODE
        } finally {
          $ErrorActionPreference = $oldErrorActionPreference
          Remove-Item -LiteralPath $textEmojiCmdFile -ErrorAction SilentlyContinue
        }
        if ($textEmojiStatus -ne 0) {
          throw "Windows MSVC text/emoji smoke failed with exit code $textEmojiStatus"
        }
        if (!(Select-String -LiteralPath $resolvedTextEmojiLog -SimpleMatch "MoUI Skia text/emoji smoke passed" -Quiet)) {
          throw "text/emoji smoke did not print the expected success marker"
        }
        Write-Host "Verified MoUI Skia text/emoji smoke success marker."

        $textEmojiRequiredMarkers = @(
          "MoUI renderer smoke colorEmojiPixels passed high-saturation-pixels glyph-or-raster font-metadata glyph-metadata fallback-request emoji-hint stable-glyph-key",
          "MoUI renderer smoke zwjGrapheme passed single-grapheme-cluster no-interior-caret",
          "MoUI renderer smoke colorEmojiVariants passed keycap regional-indicator skin-tone-modifier glyph-metadata fallback-request",
          "MoUI renderer smoke paragraphWrapping passed engine=skparagraph native_paragraph_ready=true line-metrics later-line-pixels",
          "MoUI renderer smoke bidiLayout passed engine=skparagraph bidi_visual_order_ready=true visual-order",
          "MoUI renderer smoke bidiLayoutArabic passed engine=skparagraph bidi_visual_order_ready=true visual-order arabic",
          "MoUI renderer smoke bidiLayoutMixed passed engine=skparagraph bidi_visual_order_ready=true visual-order mixed-direction",
          "MoUI renderer smoke selectionRects passed engine=skparagraph selection-rects line-range rect-geometry hit-test",
          "MoUI renderer smoke graphemeEditing passed grapheme-boundaries edit-actions",
          "MoUI renderer smoke imeCandidateAnchor passed candidate-anchor surrounding-text grapheme-boundary utf8-offsets",
          "MoUI renderer smoke imeCompositionVisual passed composition-range composition-cursor preedit-pixels"
        )
        foreach ($marker in $textEmojiRequiredMarkers) {
          if (!(Select-String -LiteralPath $resolvedTextEmojiLog -SimpleMatch $marker -Quiet)) {
            throw "MoUI Skia text/emoji smoke did not print renderer capability marker: $marker"
          }
        }
        Write-Host "Verified MoUI Skia text/emoji renderer capability markers."
      } finally {
        Remove-Item Env:\MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM -ErrorAction SilentlyContinue
        Pop-Location
      }
  }
