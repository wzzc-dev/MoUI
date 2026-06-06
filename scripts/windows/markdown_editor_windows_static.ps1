[CmdletBinding()]
param(
  [switch]$BuildOnly,
  [string]$Msys2Root = "C:\msys64",
  [string]$WgpuNativeRoot = ""
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

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
$useExplicitWgpuNativeRoot = -not [string]::IsNullOrWhiteSpace($WgpuNativeRoot)

$ucrtBin = Join-Path $Msys2Root "ucrt64\bin"
$vulkanDll = Join-Path $ucrtBin "vulkan-1.dll"
$winpthreadDll = Join-Path $ucrtBin "libwinpthread-1.dll"
$exampleExe = Join-Path $repoRoot "_build\native\debug\build\examples\markdown_editor\windows_wgpu\windows_wgpu.exe"

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
  Write-Host "==> MSYS2 UCRT64: $ucrtBin"
  if ($useExplicitWgpuNativeRoot) {
    Write-Host "==> WGPU native root: $WgpuNativeRoot"
  } else {
    Write-Host "==> WGPU native root: managed by wgpu_mbt prebuild"
  }
  Write-Host "==> Building examples/markdown_editor/windows_wgpu for native target"

  & moon build examples/markdown_editor/windows_wgpu --target native
  if ($LASTEXITCODE -ne 0) {
    throw "moon build failed with exit code $LASTEXITCODE"
  }

  if ($BuildOnly) {
    Write-Host "==> Build succeeded."
    return
  }

  Require-Path $exampleExe "Built executable not found: $exampleExe"

  Write-Host "==> Launching $exampleExe"
  & $exampleExe
  if ($LASTEXITCODE -ne 0) {
    throw "windows_wgpu exited with code $LASTEXITCODE"
  }
}
finally {
  Pop-Location
}
