param(
  [string] $BuildScript = "build.js",
  [string] $ExamplesDir = "examples"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

function Resolve-RepoPath {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path
  )

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return $Path
  }

  return Join-Path $repoRoot $Path
}

$resolvedBuildScript = Resolve-RepoPath $BuildScript
$resolvedExamplesDir = Resolve-RepoPath $ExamplesDir

if (!(Test-Path -LiteralPath $resolvedBuildScript -PathType Leaf)) {
  throw "build script is missing: $resolvedBuildScript"
}
if (!(Test-Path -LiteralPath $resolvedExamplesDir -PathType Container)) {
  throw "examples directory is missing: $resolvedExamplesDir"
}

$requiredExampleVars = @{
  "triangle_window_macos/moon.pkg" = "MOUI_SKIA_EXAMPLE_MACOS_WINDOW_LINK_FLAGS"
  "macos_hello_triangle/moon.pkg" = "MOUI_SKIA_EXAMPLE_MACOS_METAL_WINDOW_LINK_FLAGS"
}
$requiredMouiLinkPackages = @(
  "moui/tests/skia_renderer_smoke/native/moon.pkg",
  "examples/showcase/macos_skia/moon.pkg",
  "examples/markdown_editor/macos_skia/moon.pkg",
  "examples/mo_workbench/macos_skia/moon.pkg",
  "examples/showcase/linux_skia/moon.pkg",
  "examples/markdown_editor/linux_skia/moon.pkg",
  "examples/showcase/windows_skia/moon.pkg",
  "examples/markdown_editor/windows_skia/moon.pkg"
)
$forbiddenExamplePatterns = @(
  "\.skia-cache",
  "\bm\d+-[0-9a-f]{8,}\b",
  "package/out"
)

$buildText = Get-Content -LiteralPath $resolvedBuildScript -Raw
foreach ($variable in $requiredExampleVars.Values) {
  $count = ([regex]::Matches($buildText, [regex]::Escape($variable))).Count
  if ($count -lt 2) {
    throw "build script does not emit $variable in both fallback and configured paths"
  }
}
if ($buildText -notmatch "macosExampleLinkFlags") {
  throw "build script is missing macOS example link flag helper"
}
foreach ($framework in @("QuartzCore", "AppKit", "Metal", "CoreVideo", "IOSurface")) {
  if ($buildText -notmatch [regex]::Escape($framework)) {
    throw "build script is missing macOS example framework: $framework"
  }
}

foreach ($relativePkg in $requiredExampleVars.Keys) {
  $variable = $requiredExampleVars[$relativePkg]
  $pkgPath = Join-Path $resolvedExamplesDir $relativePkg
  if (!(Test-Path -LiteralPath $pkgPath -PathType Leaf)) {
    throw "example moon.pkg is missing: $pkgPath"
  }
  $expected = '"cc-link-flags": "${build.' + $variable + '}"'
  $pkgText = Get-Content -LiteralPath $pkgPath -Raw
  $compactText = $pkgText -replace "\s+", ""
  $compactExpected = $expected -replace "\s+", ""
  if (!$compactText.Contains($compactExpected)) {
    throw "example moon.pkg does not use build variable ${variable}: $pkgPath"
  }
}

foreach ($pkg in Get-ChildItem -LiteralPath $resolvedExamplesDir -Filter "moon.pkg" -Recurse -File) {
  $pkgText = Get-Content -LiteralPath $pkg.FullName -Raw
  foreach ($pattern in $forbiddenExamplePatterns) {
    if ($pkgText -match $pattern) {
      throw "example moon.pkg contains hardcoded Skia provider path text: $($pkg.FullName)"
    }
  }
}

$maybeMouiRoot = Split-Path -Parent $repoRoot
if ((Test-Path -LiteralPath (Join-Path $maybeMouiRoot "moui") -PathType Container) -and
    (Test-Path -LiteralPath (Join-Path $maybeMouiRoot "examples") -PathType Container)) {
  foreach ($relativePkg in $requiredMouiLinkPackages) {
    $pkgPath = Join-Path $maybeMouiRoot $relativePkg
    if (!(Test-Path -LiteralPath $pkgPath -PathType Leaf)) {
      throw "MoUI Skia entry moon.pkg is missing: $pkgPath"
    }
    $pkgText = Get-Content -LiteralPath $pkgPath -Raw
    if ($pkgText -notmatch "MOUI_SKIA_CC_LINK_FLAGS") {
      throw "MoUI Skia entry moon.pkg does not use MOUI_SKIA_CC_LINK_FLAGS: $pkgPath"
    }
    foreach ($pattern in $forbiddenExamplePatterns) {
      if ($pkgText -match $pattern) {
        throw "MoUI Skia entry moon.pkg contains hardcoded Skia provider path text: $pkgPath"
      }
    }
  }
}

Write-Host "Verified example link configuration in $resolvedExamplesDir"
