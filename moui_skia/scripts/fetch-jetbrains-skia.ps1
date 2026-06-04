param(
  [ValidateSet("auto", "macos", "linux", "windows", "android", "ios", "iosSim", "tvos", "tvosSim", "wasm")]
  [string] $Platform = "auto",

  [ValidateSet("auto", "arm64", "x64", "riscv64")]
  [string] $Arch = "auto",

  [ValidateSet("Release", "Debug")]
  [string] $Config = "Release",

  [ValidateSet("static", "dynamic", "auto")]
  [string] $LinkMode = $(if ($env:MOUI_SKIA_SKIA_LINK_MODE) { $env:MOUI_SKIA_SKIA_LINK_MODE } elseif ($env:MOUI_SKIA_MACOS_LINK_MODE) { $env:MOUI_SKIA_MACOS_LINK_MODE } else { "static" }),

  [string] $Tag = "",

  [string] $CacheDir = ".skia-cache/release",

  [switch] $DryRunConfig,

  [switch] $PrintEnv,

  [switch] $Force
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot "skia-provider-lock.json"
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$lockedTag = $manifest.providers.release.tag
if (![string]::IsNullOrWhiteSpace($Tag) -and $Tag -ne $lockedTag) {
  [Console]::Error.WriteLine("fetch-jetbrains-skia.ps1 is a compatibility wrapper; requested legacy tag $Tag, using locked release tag $lockedTag")
}

$arguments = @{
  Platform = $Platform
  Arch = $Arch
  Config = $Config
  LinkMode = $LinkMode
  Tag = $lockedTag
  CacheDir = $CacheDir
}
if ($DryRunConfig) { $arguments["DryRunConfig"] = $true }
if ($PrintEnv) { $arguments["PrintEnv"] = $true }
if ($Force) { $arguments["Force"] = $true }

& (Join-Path $repoRoot "scripts/fetch-release-skia.ps1") @arguments
