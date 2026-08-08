param(
  [string] $SkiaInclude = $env:MOUI_SKIA_SKIA_INCLUDE,

  [string] $SkiaLibDir = $env:MOUI_SKIA_SKIA_LIB_DIR,

  [string] $SkiaLib = $(if ($env:MOUI_SKIA_SKIA_LIB) { $env:MOUI_SKIA_SKIA_LIB } else { "skia" }),
  [string] $ExtraCcFlags = $env:MOUI_SKIA_EXTRA_CC_FLAGS,
  [string] $ExtraLinkFlags = $env:MOUI_SKIA_EXTRA_LINK_FLAGS,
  [string] $SmokeLog = "",
  [string] $RendererLog = "",
  [string] $TextEmojiLog = "",
  [switch] $RunRendererSmoke,
  [switch] $RunTextEmojiSmoke,
  [switch] $DryRunConfig
)

$ErrorActionPreference = "Stop"

if ($null -ne [Environment]::GetEnvironmentVariable("MOUI_SKIA_SKIA_LINK_MODE") -or
    $null -ne [Environment]::GetEnvironmentVariable("MOUI_SKIA_MACOS_LINK_MODE")) {
  throw "MOUI_SKIA_SKIA_LINK_MODE and MOUI_SKIA_MACOS_LINK_MODE are no longer supported; use MOUI_SKIA_LINK_MODE=dynamic|static|auto."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$nativePkg = Join-Path $repoRoot "native/moon.pkg"
$backupPkg = "$nativePkg.smoke.bak"
$smokePkg = Join-Path $repoRoot "scripts/native_smoke/moon.pkg"
$smokeBackupPkg = "$smokePkg.smoke.bak"
$rendererPkg = Join-Path $repoRoot "moui_tests/skia_renderer_smoke/native/moon.pkg"
$rendererPkgBackup = "$rendererPkg.smoke.bak"
$textEmojiPkg = Join-Path $repoRoot "moui_tests/skia_text_emoji_smoke/native/moon.pkg"
$textEmojiPkgBackup = "$textEmojiPkg.smoke.bak"

if ([string]::IsNullOrWhiteSpace($SkiaInclude) -or [string]::IsNullOrWhiteSpace($SkiaLibDir)) {
  throw "SkiaInclude and SkiaLibDir are required; pass -SkiaInclude/-SkiaLibDir or set MOUI_SKIA_SKIA_INCLUDE/MOUI_SKIA_SKIA_LIB_DIR"
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

$ccFlags = "-DMOUI_SKIA_HAS_SKIA -I$includePath"
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
  "wzzc-dev/moui_skia" @skia,
  "wzzc-dev/moui_skia/native" @native,
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
      $smokeExe = Join-Path (Get-Location) "_build/native/debug/build/moui_skia_native_smoke.exe"
      if (!(Test-Path -LiteralPath $smokeExe)) {
        throw "native smoke executable was not produced at $smokeExe"
      }
      if ($resolvedSmokeLog.Length -eq 0) {
        $resolvedSmokeLog = Join-Path ([System.IO.Path]::GetTempPath()) "moui-skia-native-smoke-$PID.log"
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
      if (!(Select-String -LiteralPath $resolvedSmokeLog -SimpleMatch "moui_skia native smoke test passed" -Quiet)) {
        throw "native smoke executable did not print the expected success marker"
      }
      Write-Host "Verified native smoke success marker."

      if ($RunRendererSmoke) {
        $originalRendererPkg = Get-Content -LiteralPath $rendererPkg -Raw
        Set-Content -LiteralPath $rendererPkgBackup -Value $originalRendererPkg -NoNewline
        Write-Host "Backed up moui_tests/skia_renderer_smoke/native/moon.pkg to $rendererPkgBackup."
        @"
import {
  "moonbitlang/core/encoding/base64",
  "moonbitlang/core/env",
  "moonbitlang/x/fs",
  "wzzc-dev/moui_skia/native" @skia_native,
  "wzzc-dev/moui/core",
  "wzzc-dev/moui/render",
  "wzzc-dev/moui/render/common" @render_common,
  "wzzc-dev/moui_skia_renderer" @skia_renderer,
}

supported_targets = "native"

options(
  "is-main": true,
  link: {
    "native": {
      "cc-link-flags": "$linkFlags",
    },
  },
  targets: { "main.mbt": [ "native" ] },
)
"@ | Set-Content -LiteralPath $rendererPkg -NoNewline
        Write-Host "Wrote temporary moui_tests/skia_renderer_smoke/native/moon.pkg with Windows Skia link flags."

        $oldErrorActionPreference2 = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
          $env:MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM = "1"
          $env:MOUI_SKIA_DISABLE_PREBUILD_SKIA = "1"
          moon build moui_tests/skia_renderer_smoke/native --target native 2>&1 | ForEach-Object { Write-Host $_ }
          $rendererBuildStatus = $LASTEXITCODE
        } finally {
          $ErrorActionPreference = $oldErrorActionPreference2
        }
        if ($rendererBuildStatus -ne 0) {
          throw "moon build moui_tests/skia_renderer_smoke/native failed with exit code $rendererBuildStatus"
        }
        $rendererExe = Join-Path $repoRoot "_build/native/debug/build/wzzc-dev/moui_tests/skia_renderer_smoke/native/native.exe"
        if (!(Test-Path -LiteralPath $rendererExe)) {
          throw "MoUI Skia renderer smoke executable was not produced at $rendererExe"
        }
        if ($resolvedRendererLog.Length -eq 0) {
          $resolvedRendererLog = Join-Path ([System.IO.Path]::GetTempPath()) "moui-skia-renderer-smoke-$PID.log"
        } else {
          $rendererLogDir = Split-Path -Parent $resolvedRendererLog
          if ($rendererLogDir.Length -gt 0) {
            New-Item -ItemType Directory -Force -Path $rendererLogDir | Out-Null
          }
        }
        Set-Content -LiteralPath $resolvedRendererLog -Value "" -NoNewline
        Write-Host "Running MoUI Skia renderer smoke executable: $rendererExe"
        & $rendererExe 2>&1 | Tee-Object -FilePath $resolvedRendererLog
        $rendererStatus = $LASTEXITCODE
        if ($rendererStatus -ne 0) {
          throw "MoUI Skia renderer smoke executable failed with exit code $rendererStatus"
        }
        if (!(Select-String -LiteralPath $resolvedRendererLog -SimpleMatch "MoUI Skia renderer smoke passed" -Quiet)) {
          throw "MoUI Skia renderer smoke did not print the expected success marker"
        }
        Write-Host "Verified MoUI Skia renderer smoke success marker."
        if (!(Select-String -LiteralPath $resolvedRendererLog -SimpleMatch "MoUI Skia async image second-frame smoke passed" -Quiet)) {
          throw "MoUI Skia renderer smoke did not report async image second-frame repaint"
        }
        Write-Host "Verified MoUI Skia async image second-frame marker."
        if (!(Select-String -LiteralPath $resolvedRendererLog -SimpleMatch "MoUI Skia async image deferred-completion smoke passed" -Quiet)) {
          throw "MoUI Skia renderer smoke did not report async image deferred-completion marker"
        }
        Write-Host "Verified MoUI Skia async image deferred-completion marker."

        Set-Content -LiteralPath $rendererPkg -Value $originalRendererPkg -NoNewline
        Remove-Item -LiteralPath $rendererPkgBackup -ErrorAction SilentlyContinue
        Write-Host "Restored moui_tests/skia_renderer_smoke/native/moon.pkg after renderer smoke."
      }

      if ($RunTextEmojiSmoke) {
        $originalTextEmojiPkg = Get-Content -LiteralPath $textEmojiPkg -Raw
        Set-Content -LiteralPath $textEmojiPkgBackup -Value $originalTextEmojiPkg -NoNewline
        Write-Host "Backed up moui_tests/skia_text_emoji_smoke/native/moon.pkg to $textEmojiPkgBackup."
        @"
import {
  "wzzc-dev/moui_skia/native" @skia_native,
  "wzzc-dev/moui/backend/common" @window_host,
  "wzzc-dev/moui/core",
  "wzzc-dev/moui/runtime",
  "wzzc-dev/moui_skia_renderer" @skia_renderer,
  "wzzc-dev/moui/views",
}

supported_targets = "native"

options(
  "is-main": true,
  link: {
    "native": {
      "cc-link-flags": "$linkFlags",
    },
  },
  targets: { "main.mbt": [ "native" ] },
)
"@ | Set-Content -LiteralPath $textEmojiPkg -NoNewline
        Write-Host "Wrote temporary moui_tests/skia_text_emoji_smoke/native/moon.pkg with Windows Skia link flags."

        $oldErrorActionPreference3 = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
          $env:MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM = "1"
          $env:MOUI_SKIA_DISABLE_PREBUILD_SKIA = "1"
          moon build moui_tests/skia_text_emoji_smoke/native --target native 2>&1 | ForEach-Object { Write-Host $_ }
          $textEmojiBuildStatus = $LASTEXITCODE
        } finally {
          $ErrorActionPreference = $oldErrorActionPreference3
        }
        if ($textEmojiBuildStatus -ne 0) {
          throw "moon build moui_tests/skia_text_emoji_smoke/native failed with exit code $textEmojiBuildStatus"
        }
        $textEmojiExe = Join-Path $repoRoot "_build/native/debug/build/wzzc-dev/moui_tests/skia_text_emoji_smoke/native/native.exe"
        if (!(Test-Path -LiteralPath $textEmojiExe)) {
          throw "MoUI Skia text/emoji smoke executable was not produced at $textEmojiExe"
        }
        if ($resolvedTextEmojiLog.Length -eq 0) {
          $resolvedTextEmojiLog = Join-Path ([System.IO.Path]::GetTempPath()) "moui-skia-text-emoji-smoke-$PID.log"
        } else {
          $textEmojiLogDir = Split-Path -Parent $resolvedTextEmojiLog
          if ($textEmojiLogDir.Length -gt 0) {
            New-Item -ItemType Directory -Force -Path $textEmojiLogDir | Out-Null
          }
        }
        Set-Content -LiteralPath $resolvedTextEmojiLog -Value "" -NoNewline
        Write-Host "Running MoUI Skia text/emoji smoke executable: $textEmojiExe"
        & $textEmojiExe 2>&1 | Tee-Object -FilePath $resolvedTextEmojiLog
        $textEmojiStatus = $LASTEXITCODE
        if ($textEmojiStatus -ne 0) {
          throw "MoUI Skia text/emoji smoke executable failed with exit code $textEmojiStatus"
        }
        if (!(Select-String -LiteralPath $resolvedTextEmojiLog -SimpleMatch "MoUI Skia text/emoji smoke passed" -Quiet)) {
          throw "MoUI Skia text/emoji smoke did not print the expected success marker"
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

        Set-Content -LiteralPath $textEmojiPkg -Value $originalTextEmojiPkg -NoNewline
        Remove-Item -LiteralPath $textEmojiPkgBackup -ErrorAction SilentlyContinue
        Write-Host "Restored moui_tests/skia_text_emoji_smoke/native/moon.pkg after text/emoji smoke."
      }
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
