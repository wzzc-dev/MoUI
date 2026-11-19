param(
  [ValidateSet("auto", "macos", "linux", "windows", "android", "harmonyos", "ios", "iosSim", "tvos", "tvosSim", "wasm")]
  [string] $Platform = "auto",

  [ValidateSet("auto", "arm64", "x64", "riscv64")]
  [string] $Arch = "auto",

  [ValidateSet("Release", "Debug")]
  [string] $Config = "Release",

  [ValidateSet("static", "dynamic", "auto")]
  [string] $LinkMode = $(if ($env:MOUI_SKIA_LINK_MODE) { $env:MOUI_SKIA_LINK_MODE } else { "static" }),

  [string] $Tag = "",

  [string] $CacheDir = ".skia-cache/release",

  [string] $Mirror = $(if ($env:MOUI_SKIA_MIRROR) { $env:MOUI_SKIA_MIRROR } else { "auto" }),

  [switch] $NoMirror,

  [switch] $DryRunConfig,

  [switch] $PrintEnv,

  [switch] $Force
)

$ErrorActionPreference = "Stop"

if ($null -ne [Environment]::GetEnvironmentVariable("MOUI_SKIA_SKIA_LINK_MODE") -or
    $null -ne [Environment]::GetEnvironmentVariable("MOUI_SKIA_MACOS_LINK_MODE")) {
  throw "MOUI_SKIA_SKIA_LINK_MODE and MOUI_SKIA_MACOS_LINK_MODE are no longer supported; use MOUI_SKIA_LINK_MODE=dynamic|static|auto."
}

$mirrorMode = if ($NoMirror) { "off" } else { $Mirror }
if ([string]::IsNullOrWhiteSpace($mirrorMode)) {
  throw "-Mirror requires a mirror name (or use -NoMirror)."
}
$script:downloadSource = ""
$packageMirror = ""
$stubMirror = ""

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

function Get-MirrorCandidates {
  param(
    [Parameter(Mandatory = $true)][object] $Provider,
    [Parameter(Mandatory = $true)][string] $Scope,
    [Parameter(Mandatory = $true)][string] $ArtifactName
  )
  $candidates = @()
  if ([string]::IsNullOrWhiteSpace($ArtifactName)) { return $candidates }
  $mirrors = Get-JsonPropertyValue -Object $Provider -Name "mirrors"
  if (!$mirrors) { return $candidates }
  foreach ($mirror in @($mirrors)) {
    if ((Get-JsonPropertyValue -Object $mirror -Name "scope") -ne $Scope) { continue }
    $baseUrl = Get-JsonPropertyValue -Object $mirror -Name "base_url"
    $name = Get-JsonPropertyValue -Object $mirror -Name "name"
    if ([string]::IsNullOrWhiteSpace($baseUrl) -or [string]::IsNullOrWhiteSpace($name)) { continue }
    $platforms = Get-JsonPropertyValue -Object $mirror -Name "platforms"
    if ($platforms -and (@($platforms) -notcontains $resolvedPlatform)) { continue }
    $configs = Get-JsonPropertyValue -Object $mirror -Name "configs"
    if ($configs -and (@($configs) -notcontains $Config)) { continue }
    $arches = Get-JsonPropertyValue -Object $mirror -Name "arches"
    if ($arches -and (@($arches) -notcontains $resolvedArch)) { continue }
    $linkModes = Get-JsonPropertyValue -Object $mirror -Name "link_modes"
    if ($linkModes -and (@($linkModes) -notcontains $resolvedLinkMode)) { continue }
    $candidates += [pscustomobject]@{
      Name = $name
      Url  = ($baseUrl.Replace("{tag}", $Tag) + $ArtifactName)
    }
  }
  return $candidates
}

function Get-CandidateOrder {
  param(
    [string] $PrimaryUrl = "",
    [object[]] $MirrorCandidates = @(),
    [Parameter(Mandatory = $true)][string] $Mode
  )
  $preferred = @()
  $others = @()
  $matched = $false
  if ($Mode -ne "off") {
    foreach ($candidate in $MirrorCandidates) {
      if ($Mode -eq "auto") {
        $others += $candidate
      } elseif ($candidate.Name -eq $Mode -or $candidate.Name.StartsWith("$Mode-")) {
        $preferred += $candidate
        $matched = $true
      } else {
        $others += $candidate
      }
    }
  }
  if ($Mode -ne "auto" -and $Mode -ne "off" -and !$matched) {
    [Console]::Error.WriteLine("note: mirror $Mode does not serve this artifact; using the primary host and the remaining mirrors")
  }
  $ordered = @()
  if ($Mode -ne "off" -and $preferred.Count -gt 0) { $ordered += $preferred }
  if (![string]::IsNullOrWhiteSpace($PrimaryUrl)) { $ordered += [pscustomobject]@{ Name = "primary"; Url = $PrimaryUrl } }
  if ($others.Count -gt 0) { $ordered += $others }
  return $ordered
}

function Get-CandidateNames {
  param([object[]] $Candidates = @())
  return (($Candidates | ForEach-Object { $_.Name }) -join ",")
}

function Download-Artifact {
  param(
    [Parameter(Mandatory = $true)][string] $Label,
    [Parameter(Mandatory = $true)][string] $Output,
    [string] $ExpectedSha256 = "",
    [string] $ExpectedSize = "",
    [string] $PrimaryUrl = "",
    [object[]] $MirrorCandidates = @()
  )
  $script:downloadSource = ""
  $candidates = Get-CandidateOrder -PrimaryUrl $PrimaryUrl -MirrorCandidates $MirrorCandidates -Mode $mirrorMode
  if ($candidates.Count -eq 0) {
    [Console]::Error.WriteLine("no download candidate is recorded for $Label")
    return $false
  }
  $first = $true
  foreach ($candidate in $candidates) {
    if (!$first -and (Test-Path -LiteralPath $Output -PathType Leaf)) { Remove-Item -LiteralPath $Output -Force }
    $first = $false
    [Console]::Error.WriteLine("  candidate=$($candidate.Name)")
    try {
      Download-File -Url $candidate.Url -Output $Output
    } catch {
      [Console]::Error.WriteLine("download failed from $($candidate.Url): $($_.Exception.Message); trying the next candidate")
      if (Test-Path -LiteralPath $Output -PathType Leaf) { Remove-Item -LiteralPath $Output -Force }
      continue
    }
    $actualSha256 = Get-Sha256Hex -Path $Output
    if ($ExpectedSha256 -and $actualSha256 -ne $ExpectedSha256.ToLowerInvariant()) {
      [Console]::Error.WriteLine("SHA256 mismatch from $($candidate.Url) expected=$ExpectedSha256 actual=$actualSha256")
      Remove-Item -LiteralPath $Output -Force
      continue
    }
    if ($ExpectedSize) {
      $actualSize = (Get-Item -LiteralPath $Output).Length
      if ("$actualSize" -ne "$ExpectedSize") {
        [Console]::Error.WriteLine("size mismatch from $($candidate.Url) expected=$ExpectedSize actual=$actualSize")
        Remove-Item -LiteralPath $Output -Force
        continue
      }
    }
    $script:downloadSource = $candidate.Name
    [Console]::Error.WriteLine("  verified_from=$($candidate.Name)")
    return $true
  }
  [Console]::Error.WriteLine("could not download $Label from any recorded source")
  return $false
}

function Expand-ZipArchive {
  param([Parameter(Mandatory = $true)][string] $Archive, [Parameter(Mandatory = $true)][string] $Destination)
  New-Item -ItemType Directory -Force -Path $Destination | Out-Null
  # Windows runners ship bsdtar; prefer it over Expand-Archive, whose
  # ExtractToDirectory overload breaks on some PowerShell/.NET image updates.
  $tar = Get-Command tar.exe -ErrorAction SilentlyContinue
  if ($null -ne $tar) {
    & $tar.Source -xf $Archive -C $Destination
    if ($LASTEXITCODE -ne 0) {
      throw "tar extraction failed for $Archive (exit $LASTEXITCODE)"
    }
    return
  }
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
$providers = $manifest.providers
$providerKey = "release"
if ($resolvedPlatform -eq "harmonyos" -and (Get-JsonPropertyValue -Object $providers -Name "harmonyos_release")) {
  $providerKey = "harmonyos_release"
}
$provider = Get-JsonPropertyValue -Object $providers -Name $providerKey
if (!$provider) { throw "skia-provider-lock.json is missing providers.$providerKey" }
if ([string]::IsNullOrWhiteSpace($Tag)) { $Tag = $provider.tag }
if ($provider.tag -ne $Tag) { throw "manifest provider $providerKey only locks release tag $($provider.tag), requested $Tag" }

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
$stubEntry = $null
$stubLibraries = Get-JsonPropertyValue -Object $provider -Name "stub_libraries"
if ($stubLibraries) {
  $stubPlatform = Get-JsonPropertyValue -Object $stubLibraries -Name $resolvedPlatform
  if ($stubPlatform) {
    $stubConfig = Get-JsonPropertyValue -Object $stubPlatform -Name $Config
    if ($stubConfig) { $stubEntry = Get-JsonPropertyValue -Object $stubConfig -Name $resolvedArch }
  }
}
$stubName = ""
$stubSha256 = ""
$stubSize = ""
$stubUrl = ""
$stubSourcesSha256 = ""
$stubLibraryNames = @()
if ($stubEntry) {
  $stubName = $stubEntry.name
  $stubSha256 = $stubEntry.sha256.ToLowerInvariant()
  $stubSize = $stubEntry.size
  $stubUrl = $stubEntry.url
  $stubSourcesSha256 = $stubEntry.sources_sha256
  $stubLibraryNames = @($stubEntry.library_names)
}
$extraCcFlags = Get-JsonPropertyValue -Object $provider.default_extra_cc_flags -Name $resolvedPlatform
if ($null -eq $extraCcFlags) { $extraCcFlags = "" }
$extraLinkFlags = Get-JsonPropertyValue -Object $provider.default_extra_link_flags -Name $resolvedPlatform
if ($null -eq $extraLinkFlags) { $extraLinkFlags = "" }
$packageMirrorCandidates = @(Get-MirrorCandidates -Provider $provider -Scope "skia" -ArtifactName $assetName)
$sourceMirrorCandidates = @(Get-MirrorCandidates -Provider $provider -Scope "source" -ArtifactName $sourceName)
$stubMirrorCandidates = @()
if ($stubName) {
  $stubMirrorCandidates = @(Get-MirrorCandidates -Provider $provider -Scope "stub" -ArtifactName $stubName)
}

$resolvedCacheDir = Resolve-RepoPath $CacheDir
$tagDir = Join-Path $resolvedCacheDir $Tag
$entryDir = Join-Path $tagDir "$resolvedPlatform-$Config-$resolvedArch-$resolvedLinkMode"
$packageZip = Join-Path $entryDir $assetName
$packageDir = Join-Path $entryDir "package"
$sourceDir = Join-Path $tagDir "source"
$sourceZip = Join-Path $tagDir $sourceName
$stubEntryDir = Join-Path $tagDir "$resolvedPlatform-$Config-$resolvedArch-stub"
$stubZip = Join-Path $stubEntryDir $stubName
$stubDir = Join-Path $stubEntryDir "package"

if (!$DryRunConfig) {
  if ($Force -or !(Test-Path -LiteralPath $packageDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $entryDir | Out-Null
    if (Test-Path -LiteralPath $packageZip -PathType Leaf) {
      $cachedSha256 = Get-Sha256Hex -Path $packageZip
      if ($cachedSha256 -ne $assetSha256) {
        [Console]::Error.WriteLine("cached Skia release asset SHA256 mismatch; re-downloading: $packageZip expected=$assetSha256 actual=$cachedSha256")
        Remove-Item -LiteralPath $packageZip -Force
      }
    }
    if (!(Test-Path -LiteralPath $packageZip -PathType Leaf)) {
      [Console]::Error.WriteLine("Downloading Skia release asset: $assetName")
      $downloaded = Download-Artifact -Label "Skia release asset $assetName" -Output $packageZip `
        -ExpectedSha256 $assetSha256 -ExpectedSize "$assetSize" `
        -PrimaryUrl $assetUrl -MirrorCandidates $packageMirrorCandidates
      if (!$downloaded) { throw "could not download the Skia release asset: $assetName" }
      if ($script:downloadSource -ne "primary") { $packageMirror = $script:downloadSource }
    }
    Expand-ZipArchive -Archive $packageZip -Destination $packageDir
  }
}

$stubLibPath = ""
if ($stubName) {
  if (!$DryRunConfig) {
    if ($Force -or !(Test-Path -LiteralPath $stubDir -PathType Container)) {
      New-Item -ItemType Directory -Force -Path $stubEntryDir | Out-Null
      if ($Force -or !(Test-Path -LiteralPath $stubZip -PathType Leaf)) {
        [Console]::Error.WriteLine("Downloading Skia stub library asset: $stubName")
        $stubDownloaded = Download-Artifact -Label "Skia stub library asset $stubName" -Output $stubZip `
          -ExpectedSha256 $stubSha256 -ExpectedSize "$stubSize" `
          -PrimaryUrl $stubUrl -MirrorCandidates $stubMirrorCandidates
        if (!$stubDownloaded) { throw "could not download the Skia stub library asset: $stubName" }
        if ($script:downloadSource -ne "primary") { $stubMirror = $script:downloadSource }
      }
      $actualStubSha256 = Get-Sha256Hex -Path $stubZip
      if ($actualStubSha256 -ne $stubSha256) {
        throw "Skia stub library SHA256 mismatch: $stubZip expected=$stubSha256 actual=$actualStubSha256"
      }
      Expand-ZipArchive -Archive $stubZip -Destination $stubDir
    }
  }
  if (Test-Path -LiteralPath $stubDir -PathType Container) {
    $stubLibPath = Find-LibDir -Root $stubDir -LibraryNames $stubLibraryNames
    if (!$stubLibPath) {
      $stubLibPath = Find-LibDir -Root $stubDir -LibraryNames @("libmoui_skia_stub.a", "moui_skia_stub.lib")
    }
  }
} elseif (!$DryRunConfig) {
  [Console]::Error.WriteLine("note: skia-provider-lock.json has no released stub library for platform=$resolvedPlatform config=$Config arch=$resolvedArch; the build compiles native/*.cpp locally instead")
}
$stubLibPath = "$stubLibPath" -replace "\\", "/"
$stubSource = if ($stubLibPath) { "release" } else { "" }

$skiaInclude = Find-HeaderRoot -Root $packageDir
$includeSource = "package"
if (!$skiaInclude) {
  $includeSource = "source"
  if (!$DryRunConfig) {
    if ($Force -or !(Test-Path -LiteralPath $sourceDir -PathType Container)) {
      New-Item -ItemType Directory -Force -Path $tagDir | Out-Null
      if ($Force -or !(Test-Path -LiteralPath $sourceZip -PathType Leaf)) {
        [Console]::Error.WriteLine("Downloading Skia release source archive for headers: $Tag")
        $sourceDownloaded = Download-Artifact -Label "Skia release source archive for headers $Tag" -Output $sourceZip `
          -PrimaryUrl $sourceUrl -MirrorCandidates $sourceMirrorCandidates
        if (!$sourceDownloaded) { throw "could not download the Skia release source archive for $Tag" }
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
foreach ($suffix in @(
    "/out/$Config-$resolvedPlatform-$resolvedArch-shared",
    "/out/$Config-$resolvedPlatform-$resolvedArch",
    "/out/$Config-$resolvedArch-shared",
    "/out/$Config-$resolvedArch"
  )) {
  if ($libDirNormalized.EndsWith($suffix.ToLowerInvariant())) {
    $skiaRoot = $skiaLibDir.Substring(0, $skiaLibDir.Length - $suffix.Length)
    break
  }
}

if ($PrintEnv) {
  @(
    "MOUI_SKIA_PROVIDER=$providerKey"
    "MOUI_SKIA_SKIA_PROVIDER=$providerKey"
    "MOUI_SKIA_RELEASE_OWNER=$($provider.owner)"
    "MOUI_SKIA_RELEASE_REPO=$($provider.repo)"
    "MOUI_SKIA_RELEASE_TAG=$Tag"
    "MOUI_SKIA_RELEASE_URL=$($provider.release_url)"
    "MOUI_SKIA_SKIA_ROOT=$skiaRoot"
    "MOUI_SKIA_SKIA_COMMIT=$($provider.commit)"
    "MOUI_SKIA_SKIA_PACKAGE=$assetName"
    "MOUI_SKIA_SKIA_PACKAGE_SHA256=$assetSha256"
    "MOUI_SKIA_LINK_MODE=$resolvedLinkMode"
    "MOUI_SKIA_SKIA_INCLUDE=$skiaInclude"
    "MOUI_SKIA_SKIA_LIB_DIR=$skiaLibDir"
    "MOUI_SKIA_SKIA_LIB=skia"
    "MOUI_SKIA_EXTRA_CC_FLAGS=$extraCcFlags"
    "MOUI_SKIA_EXTRA_LINK_FLAGS=$extraLinkFlags"
    "MOUI_SKIA_SKIA_PACKAGE_MIRROR=$packageMirror"
    "MOUI_SKIA_STUB_ASSET_MIRROR=$stubMirror"
    "MOUI_SKIA_STUB_LIB=$stubLibPath"
    "MOUI_SKIA_STUB_ASSET_SHA256=$stubSha256"
    "MOUI_SKIA_STUB_SOURCES_SHA256=$stubSourcesSha256"
    "MOUI_SKIA_STUB_SOURCE=$stubSource"
  ) | Write-Output
  exit 0
}

@(
  "Skia release provider:"
  "  skia_provider=$providerKey"
  "  release_owner=$($provider.owner)"
  "  release_repo=$($provider.repo)"
  "  release_tag=$Tag"
  "  release_url=$($provider.release_url)"
  "  skia_commit=$($provider.commit)"
  "  skia_package=$assetName"
  "  skia_package_sha256=$assetSha256"
  "  skia_package_size=$assetSize"
  "  skia_package_url=$assetUrl"
  "  skia_package_candidates=$(Get-CandidateNames -Candidates (Get-CandidateOrder -PrimaryUrl $assetUrl -MirrorCandidates $packageMirrorCandidates -Mode $mirrorMode))"
  "  skia_package_mirror=$packageMirror"
  "  skia_link_mode=$resolvedLinkMode"
  "  mirror_mode=$mirrorMode"
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
  "  stub_asset=$stubName"
  "  stub_asset_candidates=$(Get-CandidateNames -Candidates (Get-CandidateOrder -PrimaryUrl $stubUrl -MirrorCandidates $stubMirrorCandidates -Mode $mirrorMode))"
  "  stub_asset_mirror=$stubMirror"
  "  stub_asset_sha256=$stubSha256"
  "  stub_asset_size=$stubSize"
  "  stub_sources_sha256=$stubSourcesSha256"
  "  stub_lib=$stubLibPath"
) | Write-Output

if ($DryRunConfig) {
  Write-Output "Dry run complete; Skia release asset was not downloaded or extracted."
}
