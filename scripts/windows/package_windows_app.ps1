[CmdletBinding()]
param(
  [string]$Package = "examples/showcase/windows_wgpu",
  [string]$AppName = "",
  [string]$DistDir = "dist\windows",
  [switch]$NoBuild,
  [string]$Msys2Root = "C:\msys64",
  [string]$WgpuNativeRoot = "",
  [string]$Version = "0.1.0",
  [string]$BuildNumber = "1"
)

$ErrorActionPreference = "Stop"

function Require-Path {
  param(
    [string]$PathValue,
    [string]$Message
  )

  if (-not (Test-Path -LiteralPath $PathValue)) {
    throw $Message
  }
}

function Convert-PackagePath {
  param([string]$Value)
  return ($Value -replace '/', '\')
}

function Write-Utf8NoBom {
  param(
    [string]$PathValue,
    [string]$Value
  )

  $encoding = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($PathValue, $Value, $encoding)
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
$useExplicitWgpuNativeRoot = -not [string]::IsNullOrWhiteSpace($WgpuNativeRoot)

$packageLeaf = Split-Path -Leaf (Convert-PackagePath $Package)
$packageParent = Split-Path -Leaf (Split-Path -Parent (Convert-PackagePath $Package))
if ([string]::IsNullOrWhiteSpace($AppName)) {
  $AppName = $packageParent
}

$ucrtBin = Join-Path $Msys2Root "ucrt64\bin"
$vulkanDll = Join-Path $ucrtBin "vulkan-1.dll"
$winpthreadDll = Join-Path $ucrtBin "libwinpthread-1.dll"
$packageBuildDir = Join-Path $repoRoot ("_build\native\debug\build\" + (Convert-PackagePath $Package))
$builtExe = Join-Path $packageBuildDir "$packageLeaf.exe"
$appDir = Join-Path $repoRoot (Join-Path $DistDir $AppName)
$appExe = Join-Path $appDir "$AppName.exe"
$manifestPath = Join-Path $appDir "moui-package.json"

Require-Path $ucrtBin "MSYS2 UCRT64 toolchain not found: $ucrtBin"
if ($useExplicitWgpuNativeRoot) {
  $wgpuStaticLib = Join-Path $WgpuNativeRoot "lib\libwgpu_native.a"
  $wgpuTagFile = Join-Path $WgpuNativeRoot "wgpu-native-meta\wgpu-native-git-tag"
  Require-Path $wgpuStaticLib "Missing wgpu static library: $wgpuStaticLib"
  Require-Path $wgpuTagFile "Missing wgpu release metadata: $wgpuTagFile"
}
Require-Path $vulkanDll "Missing Vulkan runtime from MSYS2: $vulkanDll"
Require-Path $winpthreadDll "Missing libwinpthread runtime from MSYS2: $winpthreadDll"

if (-not (Get-Command moon -ErrorAction SilentlyContinue)) {
  throw "MoonBit toolchain is not available in PATH. Install moon and try again."
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  throw "Node.js is required to validate the package manifest."
}

$env:PATH = "$ucrtBin;$env:PATH"
$env:CC = "x86_64-w64-mingw32-gcc"
$env:CXX = "x86_64-w64-mingw32-g++"
if ($useExplicitWgpuNativeRoot) {
  $env:MBT_WGPU_NATIVE_ROOT = $WgpuNativeRoot
} else {
  Remove-Item Env:MBT_WGPU_NATIVE_ROOT -ErrorAction SilentlyContinue
}

Remove-Item Env:MBT_WGPU_LINK_MODE -ErrorAction SilentlyContinue
Remove-Item Env:MBT_WGPU_NATIVE_LIB -ErrorAction SilentlyContinue
Remove-Item Env:MBT_WGPU_VULKAN_LIB -ErrorAction SilentlyContinue

if (-not (Get-Command $env:CC -ErrorAction SilentlyContinue)) {
  throw "Compiler not found after PATH setup: $env:CC"
}

if (-not (Get-Command $env:CXX -ErrorAction SilentlyContinue)) {
  throw "Compiler not found after PATH setup: $env:CXX"
}

Push-Location $repoRoot
try {
  Write-Host "==> repo root: $repoRoot"
  Write-Host "==> package: $Package"
  Write-Host "==> MSYS2 UCRT64: $ucrtBin"
  if ($useExplicitWgpuNativeRoot) {
    Write-Host "==> WGPU native root: $WgpuNativeRoot"
  } else {
    Write-Host "==> WGPU native root: managed by wgpu_mbt prebuild"
  }

  if (-not $NoBuild) {
    & moon build $Package --target native
    if ($LASTEXITCODE -ne 0) {
      throw "moon build failed with exit code $LASTEXITCODE"
    }
  }

  Require-Path $builtExe "Built executable not found: $builtExe"

  if (Test-Path -LiteralPath $appDir) {
    Remove-Item -LiteralPath $appDir -Recurse -Force
  }
  New-Item -ItemType Directory -Path $appDir | Out-Null

  Copy-Item -LiteralPath $builtExe -Destination $appExe
  Copy-Item -LiteralPath $vulkanDll -Destination (Join-Path $appDir "vulkan-1.dll")
  Copy-Item -LiteralPath $winpthreadDll -Destination (Join-Path $appDir "libwinpthread-1.dll")

  $manifest = @{
    schemaVersion = 1
    platform = "windows"
    outputKind = "portable-folder"
    appName = $AppName
    moonPackage = $Package
    version = $Version
    buildNumber = $BuildNumber
    executable = (Split-Path -Leaf $appExe)
    bundleName = $AppName
    runtimeFiles = @("vulkan-1.dll", "libwinpthread-1.dll")
  } | ConvertTo-Json -Depth 4
  Write-Utf8NoBom $manifestPath $manifest

  & node (Join-Path $repoRoot "scripts\validate-package-manifest.mjs") $manifestPath --platform windows
  if ($LASTEXITCODE -ne 0) {
    throw "manifest validation failed with exit code $LASTEXITCODE"
  }

  Write-Host "==> Wrote $appDir"
}
finally {
  Pop-Location
}
