[CmdletBinding()]
param(
  [string]$WgpuNativeRoot = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path

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

$resolvedRoot = Ensure-WgpuNativeRoot $WgpuNativeRoot
Write-Host "==> WGPU native root: $resolvedRoot"
Write-Host "==> WGPU native release metadata: $(Join-Path $resolvedRoot 'wgpu-native-meta\wgpu-native-git-tag')"
