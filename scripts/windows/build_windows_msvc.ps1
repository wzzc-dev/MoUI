[CmdletBinding()]
param(
  [string]$Package = "examples/showcase/windows_skia",
  [switch]$BuildOnly,
  [string]$VcpkgRoot = "",
  [string]$WgpuNativeRoot = "",
  [switch]$EnableWebView2,
  [string]$WebView2SdkRoot = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
. (Join-Path $scriptDir "webview2_sdk.ps1")

function Require-Path {
  param(
    [string]$PathValue,
    [string]$Message
  )

  if (-not (Test-Path -LiteralPath $PathValue)) {
    throw $Message
  }
}

function Assert-ChildPath {
  param(
    [string]$Parent,
    [string]$Child
  )

  $resolvedParent = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\') + '\'
  $resolvedChild = [System.IO.Path]::GetFullPath($Child)
  if (-not $resolvedChild.StartsWith($resolvedParent, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to modify path outside ${resolvedParent}: $resolvedChild"
  }
}

function Convert-PackagePath {
  param([string]$Value)
  return ($Value -replace '/', '\')
}

function Ensure-WgpuNativeRoot {
  param([string]$ExplicitRoot)

  if (-not [string]::IsNullOrWhiteSpace($ExplicitRoot)) {
    $root = (Resolve-Path -LiteralPath $ExplicitRoot).Path
    Require-Path (Join-Path $root "lib\wgpu_native.dll") "Missing WGPU dynamic library: $(Join-Path $root 'lib\wgpu_native.dll')"
    Require-Path (Join-Path $root "wgpu-native-meta\wgpu-native-git-tag") "Missing WGPU release metadata under $root"
    return $root
  }

  $assetName = "wgpu-windows-x86_64-msvc-release.zip"
  $releaseTag = "v27.0.4.0"
  $releaseRepo = "gfx-rs/wgpu-native"
  $toolsRoot = Join-Path $repoRoot ".tools\wgpu-native"
  $extractRoot = Join-Path $toolsRoot ($assetName -replace '\.zip$', '')
  $dllPath = Join-Path $extractRoot "lib\wgpu_native.dll"
  $tagPath = Join-Path $extractRoot "wgpu-native-meta\wgpu-native-git-tag"

  if ((Test-Path -LiteralPath $dllPath) -and (Test-Path -LiteralPath $tagPath)) {
    return (Resolve-Path -LiteralPath $extractRoot).Path
  }

  New-Item -ItemType Directory -Path $toolsRoot -Force | Out-Null
  $zipPath = Join-Path $toolsRoot $assetName
  $url = "https://github.com/$releaseRepo/releases/download/$releaseTag/$assetName"
  Write-Host "==> Downloading $url"
  Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zipPath

  if (Test-Path -LiteralPath $extractRoot) {
    Assert-ChildPath $toolsRoot $extractRoot
    Remove-Item -LiteralPath $extractRoot -Recurse -Force
  }
  $tmpExtract = Join-Path $toolsRoot "extract-$([Guid]::NewGuid().ToString('N'))"
  Expand-Archive -Path $zipPath -DestinationPath $tmpExtract -Force
  Move-Item -LiteralPath $tmpExtract -Destination $extractRoot

  Require-Path $dllPath "Missing WGPU dynamic library after extraction: $dllPath"
  Require-Path $tagPath "Missing WGPU release metadata after extraction: $tagPath"
  return (Resolve-Path -LiteralPath $extractRoot).Path
}

function Test-PackageUsesWgpu {
  param([string]$PackagePath)

  $pkgPath = Join-Path $repoRoot (Join-Path (Convert-PackagePath $PackagePath) "moon.pkg")
  Require-Path $pkgPath "Missing MoonBit package manifest: $pkgPath"
  $pkg = Get-Content -LiteralPath $pkgPath -Raw
  $usesWgpuBackend = $pkg.Contains("wzzc-dev/moui/backend/windows/wgpu")
  $usesWgpuRenderer = $pkg.Contains("wzzc-dev/moui/render/wgpu")
  return ($usesWgpuBackend -or $usesWgpuRenderer)
}

$usesWgpu = Test-PackageUsesWgpu $Package
$resolvedWgpuRoot = if ($usesWgpu) { Ensure-WgpuNativeRoot $WgpuNativeRoot } else { "" }
. (Join-Path $scriptDir "msvc_env.ps1") -VcpkgRoot $VcpkgRoot -WgpuNativeRoot $resolvedWgpuRoot
Enable-MsvcC11Atomics
if ($usesWgpu) {
  Enable-MsvcGlobalC11ModeForCOnlyStubs
}
$webView2 = $null
if ($EnableWebView2 -or -not [string]::IsNullOrWhiteSpace($WebView2SdkRoot)) {
  $webView2 = Enable-WebView2BuildEnvironment $WebView2SdkRoot
}

if (-not (Get-Command moon -ErrorAction SilentlyContinue)) {
  throw "MoonBit toolchain is not available in PATH. Install moon and try again."
}

Push-Location $repoRoot
try {
  Write-Host "==> repo root: $repoRoot"
  Write-Host "==> package: $Package"
  if ($usesWgpu) {
    Write-Host "==> renderer route: native WGPU experimental"
    Write-Host "==> WGPU native root: $resolvedWgpuRoot"
  } else {
    Write-Host "==> renderer route: native Skia mainline"
  }
  if ($webView2) {
    Write-Host "==> WebView2 bridge: enabled with static loader; Evergreen Runtime required"
  } else {
    Write-Host "==> WebView2 bridge: fallback unavailable build"
  }
  & moon build $Package --target native
  if ($LASTEXITCODE -ne 0) {
    throw "moon build failed with exit code $LASTEXITCODE"
  }
  if (-not $BuildOnly) {
    Write-Host "==> Build succeeded. Run the executable from _build or package it with package_windows_app_msvc.ps1."
  }
}
finally {
  Pop-Location
}
