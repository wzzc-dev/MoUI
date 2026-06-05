[CmdletBinding()]
param(
  [string]$Arch = "x64",
  [string]$VcpkgRoot = "",
  [string]$WgpuNativeRoot = "",
  [switch]$SkipZlibCheck
)

$ErrorActionPreference = "Stop"

$scriptDir = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
  $PSScriptRoot
} else {
  Split-Path -Parent $MyInvocation.MyCommand.Path
}
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path

function Find-VsWhere {
  $candidate = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
  if (Test-Path -LiteralPath $candidate) {
    return $candidate
  }
  throw "vswhere.exe was not found. Install Visual Studio Build Tools with: winget install --id Microsoft.VisualStudio.2022.BuildTools -e"
}

function Find-VcVarsAll {
  $vswhere = Find-VsWhere
  $installPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  if ([string]::IsNullOrWhiteSpace($installPath)) {
    throw "Visual Studio C++ build tools were not found. Install them with: winget install --id Microsoft.VisualStudio.2022.BuildTools -e"
  }
  $vcvars = Join-Path $installPath "VC\Auxiliary\Build\vcvarsall.bat"
  if (-not (Test-Path -LiteralPath $vcvars)) {
    throw "vcvarsall.bat was not found: $vcvars"
  }
  return $vcvars
}

function Import-CmdEnvironment {
  param([string]$Command)

  $lines = & cmd.exe /c "$Command >nul && set"
  if ($LASTEXITCODE -ne 0) {
    throw "failed to import MSVC environment with command: $Command"
  }
  $pathValue = ""
  foreach ($line in $lines) {
    $index = $line.IndexOf("=")
    if ($index -le 0) {
      continue
    }
    $name = $line.Substring(0, $index)
    $value = $line.Substring($index + 1)
    if ($name -ieq "Path") {
      if ([string]::IsNullOrWhiteSpace($pathValue) -or $value.Contains("VC\Tools\MSVC")) {
        $pathValue = $value
      }
      continue
    }
    [Environment]::SetEnvironmentVariable($name, $value, "Process")
  }
  if (-not [string]::IsNullOrWhiteSpace($pathValue)) {
    [Environment]::SetEnvironmentVariable("Path", $pathValue, "Process")
    [Environment]::SetEnvironmentVariable("PATH", $pathValue, "Process")
  }
}

function Find-VcpkgRoot {
  $candidates = @()
  $workspaceVcpkgRoot = Join-Path $repoRoot ".tools\vcpkg-msvc"
  foreach ($candidate in @($VcpkgRoot, $env:MOUI_MSVC_VCPKG_ROOT, $workspaceVcpkgRoot, $env:VCPKG_INSTALLATION_ROOT, "C:\vcpkg")) {
    if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
      $candidates += (Resolve-Path -LiteralPath $candidate).Path
    }
  }
  $command = Get-Command vcpkg -ErrorAction SilentlyContinue
  if ($command) {
    $commandPath = if (-not [string]::IsNullOrWhiteSpace($command.Source)) { $command.Source } else { $command.Path }
    if (-not [string]::IsNullOrWhiteSpace($commandPath)) {
      $candidates += (Split-Path -Parent $commandPath)
    }
  }
  if (-not [string]::IsNullOrWhiteSpace($env:VCPKG_ROOT) -and
      (Test-Path -LiteralPath $env:VCPKG_ROOT) -and
      (Test-Path -LiteralPath (Join-Path $env:VCPKG_ROOT "vcpkg.exe"))) {
    $candidates += (Resolve-Path -LiteralPath $env:VCPKG_ROOT).Path
  }

  $uniqueCandidates = @($candidates | Select-Object -Unique)
  foreach ($candidate in $uniqueCandidates) {
    foreach ($relative in @("", "installed\x64-windows", "vcpkg_installed\x64-windows")) {
      $tripletRoot = if ([string]::IsNullOrWhiteSpace($relative)) { $candidate } else { Join-Path $candidate $relative }
      $zlibHeader = Join-Path $tripletRoot "include\zlib.h"
      $zlibImportLibs = @(
        (Join-Path $tripletRoot "lib\z.lib"),
        (Join-Path $tripletRoot "lib\zlib.lib")
      )
      $zlibImportLib = $zlibImportLibs | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
      if ((Test-Path -LiteralPath $zlibHeader) -and $zlibImportLib) {
        return [pscustomobject]@{
          Root = $candidate
          TripletRoot = (Resolve-Path -LiteralPath $tripletRoot).Path
          ImportLibName = (Split-Path -Leaf $zlibImportLib)
        }
      }
    }
  }

  if ($SkipZlibCheck -and $uniqueCandidates.Count -gt 0) {
    $fallbackRoot = $uniqueCandidates[0]
    return [pscustomobject]@{
      Root = $fallbackRoot
      TripletRoot = Join-Path $fallbackRoot "installed\x64-windows"
      ImportLibName = "z.lib"
    }
  }

  throw "zlib:x64-windows was not found. Run scripts\windows\setup_msvc_deps.ps1 -InstallZlib; VS bundled vcpkg may require manifest mode."
}

function Add-PathPrefix {
  param(
    [string]$Name,
    [string]$Value
  )

  $current = [Environment]::GetEnvironmentVariable($Name, "Process")
  if ([string]::IsNullOrWhiteSpace($current)) {
    [Environment]::SetEnvironmentVariable($Name, $Value, "Process")
  } else {
    [Environment]::SetEnvironmentVariable($Name, "$Value;$current", "Process")
  }
}

function Enable-MsvcC11Atomics {
  if ($env:CL -notmatch '(^|\s)/std:c11(\s|$)') {
    $env:CL = "/std:c11 $env:CL".Trim()
  }
}

function Resolve-WgpuNativeRoot {
  param([string]$ExplicitRoot)

  if (-not [string]::IsNullOrWhiteSpace($ExplicitRoot)) {
    $root = (Resolve-Path -LiteralPath $ExplicitRoot).Path
    $dllPath = Join-Path $root "lib\wgpu_native.dll"
    $tagPath = Join-Path $root "wgpu-native-meta\wgpu-native-git-tag"
    if (-not (Test-Path -LiteralPath $dllPath) -or -not (Test-Path -LiteralPath $tagPath)) {
      throw "Invalid WGPU native root: $root. Expected lib\wgpu_native.dll and wgpu-native-meta\wgpu-native-git-tag."
    }
    return $root
  }

  $defaultRoot = Join-Path $repoRoot ".tools\wgpu-native\wgpu-windows-x86_64-msvc-release"
  $defaultDll = Join-Path $defaultRoot "lib\wgpu_native.dll"
  $defaultTag = Join-Path $defaultRoot "wgpu-native-meta\wgpu-native-git-tag"
  if ((Test-Path -LiteralPath $defaultDll) -and (Test-Path -LiteralPath $defaultTag)) {
    return (Resolve-Path -LiteralPath $defaultRoot).Path
  }

  return ""
}

$vcvars = Find-VcVarsAll
Import-CmdEnvironment "call `"$vcvars`" $Arch"

$vcpkgInfo = Find-VcpkgRoot
$resolvedVcpkgRoot = $vcpkgInfo.Root
$vcpkgInstalled = $vcpkgInfo.TripletRoot
$zlibImportLibName = $vcpkgInfo.ImportLibName
$zlibInclude = Join-Path $vcpkgInstalled "include"
$zlibLib = Join-Path $vcpkgInstalled "lib"
$zlibBin = Join-Path $vcpkgInstalled "bin"

if (-not $SkipZlibCheck) {
  $zlibHeader = Join-Path $zlibInclude "zlib.h"
  $zlibImportLib = Join-Path $zlibLib $zlibImportLibName
  if (-not (Test-Path -LiteralPath $zlibHeader) -or -not (Test-Path -LiteralPath $zlibImportLib)) {
    throw "zlib:x64-windows was not found under $vcpkgInstalled. Run scripts\windows\setup_msvc_deps.ps1 -InstallZlib."
  }
}

if (Test-Path -LiteralPath $zlibInclude) {
  Add-PathPrefix "INCLUDE" $zlibInclude
}
if (Test-Path -LiteralPath $zlibLib) {
  Add-PathPrefix "LIB" $zlibLib
}
if (Test-Path -LiteralPath $zlibBin) {
  Add-PathPrefix "PATH" $zlibBin
}

$compilerWrapper = Join-Path $scriptDir "msvc_cl.cmd"
$env:CC = $compilerWrapper
$env:CXX = $compilerWrapper
$env:MBT_WGPU_LINK_MODE = "dynamic"
$env:CL = "/experimental:c11atomics /wd4005 /DMOONBIT_FFI_EXPORT="
$env:LINK = "comdlg32.lib shell32.lib advapi32.lib ole32.lib user32.lib gdi32.lib dwrite.lib d2d1.lib $zlibImportLibName /SUBSYSTEM:WINDOWS /ENTRY:mainCRTStartup"
$env:MOUI_MSVC_VCPKG_ROOT = $resolvedVcpkgRoot
$env:MOUI_MSVC_ZLIB_TRIPLET_ROOT = $vcpkgInstalled
$env:MOUI_MSVC_ZLIB_IMPORT_LIB = $zlibImportLibName

$resolvedWgpuNativeRoot = Resolve-WgpuNativeRoot $WgpuNativeRoot
if (-not [string]::IsNullOrWhiteSpace($resolvedWgpuNativeRoot)) {
  $env:MBT_WGPU_NATIVE_ROOT = $resolvedWgpuNativeRoot
} else {
  Remove-Item Env:MBT_WGPU_NATIVE_ROOT -ErrorAction SilentlyContinue
}
Remove-Item Env:MBT_WGPU_NATIVE_LIB -ErrorAction SilentlyContinue
Remove-Item Env:MBT_WGPU_VULKAN_LIB -ErrorAction SilentlyContinue

& where.exe cl.exe | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "cl.exe is not available after importing vcvarsall.bat"
}

Write-Host "==> MSVC environment ready"
Write-Host "==> vcvarsall: $vcvars"
Write-Host "==> vcpkg root: $resolvedVcpkgRoot"
Write-Host "==> zlib triplet root: $vcpkgInstalled"
Write-Host "==> zlib import lib: $zlibImportLibName"
if (-not [string]::IsNullOrWhiteSpace($resolvedWgpuNativeRoot)) {
  Write-Host "==> WGPU native root: $resolvedWgpuNativeRoot"
} else {
  Write-Host "==> WGPU native root: not set; run build_windows_msvc.ps1 once or pass -WgpuNativeRoot"
}
Write-Host "==> CC: $env:CC"
Write-Host "==> CXX: $env:CXX"
Write-Host "==> MBT_WGPU_LINK_MODE: $env:MBT_WGPU_LINK_MODE"
