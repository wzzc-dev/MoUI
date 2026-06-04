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

Write-Host "Verified example link configuration in $resolvedExamplesDir"
