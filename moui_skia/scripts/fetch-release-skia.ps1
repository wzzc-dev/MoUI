param(
  [ValidateSet("auto", "macos", "linux", "windows", "android", "ios", "iosSim", "tvos", "tvosSim", "wasm")]
  [string] $Platform = "auto",

  [ValidateSet("auto", "arm64", "x64", "riscv64")]
  [string] $Arch = "auto",

  [ValidateSet("Release", "Debug")]
  [string] $Config = "Release",

  [ValidateSet("static", "dynamic", "auto")]
  [string] $LinkMode = $(if ($env:MOUI_SKIA_SKIA_LINK_MODE) { $env:MOUI_SKIA_SKIA_LINK_MODE } else { "static" }),

  [string] $Tag = "",

  [string] $CacheDir = ".skia-cache/release",

  [switch] $DryRunConfig,

  [switch] $PrintEnv,

  [switch] $Force
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot "skia-provider-lock.json"

function Resolve-RepoPath {
  param([Parameter(Mandatory = $true)][string] $Path)
  if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
  return Join-Path $repoRoot $Path
}

function Get-HostPlatform {
  if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)) { return "macos" }
  if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)) { return "linux" }
  if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) { return "windows" }
  throw "cannot auto-detect Skia release platform"
}

function Get-HostArch {
  switch ([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString().ToLowerInvariant()) {
    "arm64" { return "arm64" }
    "x64" { return "x64" }
    "amd64" { return "x64" }
    default { throw "cannot auto-detect Skia release architecture: $([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture)" }
  }
}

function Get-JsonPropertyValue {
  param([Parameter(Mandatory = $true)][object] $Object, [Parameter(Mandatory = $true)][string] $Name)
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}

function Find-HeaderRoot {
  param([Parameter(Mandatory = $true)][string] $Root)
  if (!(Test-Path -LiteralPath $Root -PathType Container)) { return $null }
  $header = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter "SkSurface.h" -ErrorAction SilentlyContinue |
    Where-Object { ($_.FullName -replace "\\", "/") -like "*/include/core/SkSurface.h" } |
    Select-Object -First 1
  if (!$header) { return $null }
  $full = $header.FullName -replace "\\", "/"
  return $full.Substring(0, $full.Length - "/include/core/SkSurface.h".Length)
}

function Find-LibDir {
  param(
    [Parameter(Mandatory = $true)][string] $Root,
    [Parameter(Mandatory = $true)][object] $LibraryNames
  )
  if (!(Test-Path -LiteralPath $Root -PathType Container)) { return $null }
  $names = @($LibraryNames) + @("libskia.a", "libskia.so", "libskia.dylib", "skia.lib")
  foreach ($name in $names) {
    $lib = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($lib) { return ($lib.DirectoryName -replace "\\", "/") }
  }
  return $null
}

function Download-File {
  param([Parameter(Mandatory = $true)][string] $Url, [Parameter(Mandatory = $true)][string] $Output)
  $parent = Split-Path -Parent $Output
  if ($parent.Length -gt 0) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  Invoke-WebRequest -Uri $Url -OutFile $Output
}

function Expand-ZipArchive {
  param([Parameter(Mandatory = $true)][string] $Archive, [Parameter(Mandatory = $true)][string] $Destination)
  New-Item -ItemType Directory -Force -Path $Destination | Out-Null
  Expand-Archive -LiteralPath $Archive -DestinationPath $Destination -Force
}

function Get-Sha256Hex {
  param([Parameter(Mandatory = $true)][string] $Path)
  if (Get-Command Get-FileHash -ErrorAction SilentlyContinue) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
  }

  $stream = [System.IO.File]::OpenRead($Path)
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  try {
    $hashBytes = $sha256.ComputeHash($stream)
    return ([System.BitConverter]::ToString($hashBytes) -replace "-", "").ToLowerInvariant()
  } finally {
    $sha256.Dispose()
    $stream.Dispose()
  }
}

if (!(Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
  throw "Skia release provider manifest is missing: $manifestPath"
}

$resolvedPlatform = $Platform
if ($resolvedPlatform -eq "auto") { $resolvedPlatform = Get-HostPlatform }

$resolvedArch = $Arch
if ($resolvedPlatform -eq "wasm") {
  if ($resolvedArch -ne "auto") { throw "-Platform wasm only supports -Arch auto with the wasm manifest asset" }
  $resolvedArch = "wasm"
} elseif ($resolvedArch -eq "auto") {
  $resolvedArch = Get-HostArch
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$provider = $manifest.providers.release
if (!$provider) { throw "skia-provider-lock.json is missing providers.release" }
if ([string]::IsNullOrWhiteSpace($Tag)) { $Tag = $provider.tag }
if ($provider.tag -ne $Tag) { throw "manifest only locks release tag $($provider.tag), requested $Tag" }

$platformAssets = Get-JsonPropertyValue -Object $provider.assets -Name $resolvedPlatform
if (!$platformAssets) { throw "manifest has no release assets for platform=$resolvedPlatform" }
$configAssets = Get-JsonPropertyValue -Object $platformAssets -Name $Config
if (!$configAssets) { throw "manifest has no release assets for platform=$resolvedPlatform config=$Config" }
$archAssets = Get-JsonPropertyValue -Object $configAssets -Name $resolvedArch
if (!$archAssets) { throw "manifest has no release asset for platform=$resolvedPlatform config=$Config arch=$resolvedArch" }

$resolvedLinkMode = $LinkMode
if ($resolvedLinkMode -eq "auto") {
  $resolvedLinkMode = if (Get-JsonPropertyValue -Object $archAssets -Name "dynamic") { "dynamic" } else { "static" }
}
$asset = Get-JsonPropertyValue -Object $archAssets -Name $resolvedLinkMode
if (!$asset) { throw "manifest has no $resolvedLinkMode release asset for platform=$resolvedPlatform config=$Config arch=$resolvedArch" }

$assetName = $asset.name
$assetSha256 = $asset.sha256.ToLowerInvariant()
$assetSize = $asset.size
$assetUrl = $asset.url
$sourceName = if ($provider.source_archive.name) { $provider.source_archive.name } else { "$($provider.owner)-$($provider.repo)-$Tag-source.zip" }
$sourceUrl = if ($provider.source_archive.url) { $provider.source_archive.url } else { "https://github.com/$($provider.owner)/$($provider.repo)/archive/refs/tags/$Tag.zip" }
$libraryNames = @($asset.library_names)
$extraCcFlags = Get-JsonPropertyValue -Object $provider.default_extra_cc_flags -Name $resolvedPlatform
if ($null -eq $extraCcFlags) { $extraCcFlags = "" }
$extraLinkFlags = Get-JsonPropertyValue -Object $provider.default_extra_link_flags -Name $resolvedPlatform
if ($null -eq $extraLinkFlags) { $extraLinkFlags = "" }

$resolvedCacheDir = Resolve-RepoPath $CacheDir
$tagDir = Join-Path $resolvedCacheDir $Tag
$entryDir = Join-Path $tagDir "$resolvedPlatform-$Config-$resolvedArch-$resolvedLinkMode"
$packageZip = Join-Path $entryDir $assetName
$packageDir = Join-Path $entryDir "package"
$sourceDir = Join-Path $tagDir "source"
$sourceZip = Join-Path $tagDir $sourceName

if (!$DryRunConfig) {
  if ($Force -or !(Test-Path -LiteralPath $packageDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $entryDir | Out-Null
    if ($Force -or !(Test-Path -LiteralPath $packageZip -PathType Leaf)) {
      [Console]::Error.WriteLine("Downloading Skia release asset: $assetName")
      Download-File -Url $assetUrl -Output $packageZip
    }
    $actualSha256 = Get-Sha256Hex -Path $packageZip
    if ($actualSha256 -ne $assetSha256) {
      throw "Skia release asset SHA256 mismatch: $packageZip expected=$assetSha256 actual=$actualSha256"
    }
    Expand-ZipArchive -Archive $packageZip -Destination $packageDir
  }
}

$skiaInclude = Find-HeaderRoot -Root $packageDir
$includeSource = "package"
if (!$skiaInclude) {
  $includeSource = "source"
  if (!$DryRunConfig) {
    if ($Force -or !(Test-Path -LiteralPath $sourceDir -PathType Container)) {
      New-Item -ItemType Directory -Force -Path $tagDir | Out-Null
      if ($Force -or !(Test-Path -LiteralPath $sourceZip -PathType Leaf)) {
        [Console]::Error.WriteLine("Downloading Skia release source archive for headers: $Tag")
        Download-File -Url $sourceUrl -Output $sourceZip
      }
      Expand-ZipArchive -Archive $sourceZip -Destination $sourceDir
    }
    $skiaInclude = Find-HeaderRoot -Root $sourceDir
    if (!$skiaInclude) { throw "Skia headers were not found in package or source archive for tag $Tag" }
  } else {
    $skiaInclude = $sourceDir -replace "\\", "/"
  }
}

$skiaLibDir = Find-LibDir -Root $packageDir -LibraryNames $libraryNames
if (!$skiaLibDir) {
  if ($DryRunConfig) {
    $skiaLibDir = $packageDir -replace "\\", "/"
  } else {
    throw "Skia library for platform=$resolvedPlatform link_mode=$resolvedLinkMode was not found in $packageDir"
  }
}

$skiaInclude = $skiaInclude -replace "\\", "/"
$skiaLibDir = $skiaLibDir -replace "\\", "/"
$skiaRoot = $skiaInclude
$libDirNormalized = $skiaLibDir.TrimEnd("/").ToLowerInvariant()
if ($libDirNormalized.EndsWith("/out/$Config-$resolvedArch".ToLowerInvariant())) {
  $trimLength = ("/out/$Config-$resolvedArch").Length
  $skiaRoot = $skiaLibDir.Substring(0, $skiaLibDir.Length - $trimLength)
}

if ($PrintEnv) {
  @(
    "MOUI_SKIA_PROVIDER=release"
    "MOUI_SKIA_SKIA_PROVIDER=release"
    "MOUI_SKIA_RELEASE_OWNER=$($provider.owner)"
    "MOUI_SKIA_RELEASE_REPO=$($provider.repo)"
    "MOUI_SKIA_RELEASE_TAG=$Tag"
    "MOUI_SKIA_RELEASE_URL=$($provider.release_url)"
    "MOUI_SKIA_SKIA_ROOT=$skiaRoot"
    "MOUI_SKIA_SKIA_COMMIT=$($provider.commit)"
    "MOUI_SKIA_SKIA_PACKAGE=$assetName"
    "MOUI_SKIA_SKIA_PACKAGE_SHA256=$assetSha256"
    "MOUI_SKIA_SKIA_LINK_MODE=$resolvedLinkMode"
    "MOUI_SKIA_SKIA_INCLUDE=$skiaInclude"
    "MOUI_SKIA_SKIA_LIB_DIR=$skiaLibDir"
    "MOUI_SKIA_SKIA_LIB=skia"
    "MOUI_SKIA_EXTRA_CC_FLAGS=$extraCcFlags"
    "MOUI_SKIA_EXTRA_LINK_FLAGS=$extraLinkFlags"
  ) | Write-Output
  exit 0
}

@(
  "Skia release provider:"
  "  skia_provider=release"
  "  release_owner=$($provider.owner)"
  "  release_repo=$($provider.repo)"
  "  release_tag=$Tag"
  "  release_url=$($provider.release_url)"
  "  skia_commit=$($provider.commit)"
  "  skia_package=$assetName"
  "  skia_package_sha256=$assetSha256"
  "  skia_package_size=$assetSize"
  "  skia_package_url=$assetUrl"
  "  skia_link_mode=$resolvedLinkMode"
  "  platform=$resolvedPlatform"
  "  config=$Config"
  "  arch=$resolvedArch"
  "  cache_dir=$entryDir"
  "  include_source=$includeSource"
  "  skia_root=$skiaRoot"
  "  skia_include=$skiaInclude"
  "  skia_lib_dir=$skiaLibDir"
  "  skia_lib=skia"
  "  extra_cc_flags=$extraCcFlags"
  "  extra_link_flags=$extraLinkFlags"
) | Write-Output

if ($DryRunConfig) {
  Write-Output "Dry run complete; Skia release asset was not downloaded or extracted."
}
