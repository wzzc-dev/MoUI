[CmdletBinding()]
param(
  [string]$Arch = "x64",
  [string]$VcpkgRoot = "",
  [string]$WgpuNativeRoot = "",
  [switch]$SkipZlibCheck
)

$ErrorActionPreference = "Stop"

$script:MouiMsvcScriptDir = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
  $PSScriptRoot
} else {
  Split-Path -Parent $MyInvocation.MyCommand.Path
}

#region Helpers — workspace and Visual Studio

function Get-MouiMsvcWorkspaceRoot {
  param([string]$MouiPackageDir)

  if (-not [string]::IsNullOrWhiteSpace($env:MOUI_MSVC_WORKSPACE_ROOT)) {
    return (Resolve-Path -LiteralPath $env:MOUI_MSVC_WORKSPACE_ROOT).Path
  }

  $dir = (Get-Location).Path
  while (-not [string]::IsNullOrWhiteSpace($dir)) {
    if ((Test-Path -LiteralPath (Join-Path $dir "moon.work")) -or
        (Test-Path -LiteralPath (Join-Path $dir "moon.mod"))) {
      return (Resolve-Path -LiteralPath $dir).Path
    }
    $parent = Split-Path -Parent $dir
    if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $dir) {
      break
    }
    $dir = $parent
  }

  return (Resolve-Path -LiteralPath $MouiPackageDir).Path
}

function Get-VcVarsAllPath {
  $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
  if (-not (Test-Path -LiteralPath $vswhere)) {
    throw "vswhere.exe was not found. Install Visual Studio Build Tools with: winget install --id Microsoft.VisualStudio.2022.BuildTools -e"
  }

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

function Import-VcVarsEnvironment {
  param(
    [string]$VcVarsAll,
    [string]$Architecture
  )

  $command = "call `"$VcVarsAll`" $Architecture"
  $lines = & cmd.exe /c "$command >nul && set"
  if ($LASTEXITCODE -ne 0) {
    throw "failed to import MSVC environment with command: $command"
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

#endregion

#region Helpers — vcpkg / zlib

function Get-ZlibVcpkgLayout {
  param(
    [string]$WorkspaceRoot,
    [string]$ExplicitVcpkgRoot,
    [switch]$AllowMissingZlib
  )

  $candidates = @()
  $workspaceVcpkg = Join-Path $WorkspaceRoot ".tools\vcpkg-msvc"
  foreach ($candidate in @($ExplicitVcpkgRoot, $env:MOUI_MSVC_VCPKG_ROOT, $workspaceVcpkg, $env:VCPKG_INSTALLATION_ROOT, "C:\vcpkg")) {
    if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
      $candidates += (Resolve-Path -LiteralPath $candidate).Path
    }
  }

  $vcpkgCmd = Get-Command vcpkg -ErrorAction SilentlyContinue
  if ($vcpkgCmd) {
    $commandPath = if (-not [string]::IsNullOrWhiteSpace($vcpkgCmd.Source)) { $vcpkgCmd.Source } else { $vcpkgCmd.Path }
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
  foreach ($root in $uniqueCandidates) {
    foreach ($relative in @("", "installed\x64-windows", "vcpkg_installed\x64-windows")) {
      $tripletRoot = if ([string]::IsNullOrWhiteSpace($relative)) { $root } else { Join-Path $root $relative }
      $zlibHeader = Join-Path $tripletRoot "include\zlib.h"
      $importLibs = @(
        (Join-Path $tripletRoot "lib\z.lib"),
        (Join-Path $tripletRoot "lib\zlib.lib")
      )
      $importLib = $importLibs | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
      if ((Test-Path -LiteralPath $zlibHeader) -and $importLib) {
        return [pscustomobject]@{
          Root = $root
          TripletRoot = (Resolve-Path -LiteralPath $tripletRoot).Path
          ImportLibName = (Split-Path -Leaf $importLib)
        }
      }
    }
  }

  if ($AllowMissingZlib -and $uniqueCandidates.Count -gt 0) {
    $fallbackRoot = $uniqueCandidates[0]
    return [pscustomobject]@{
      Root = $fallbackRoot
      TripletRoot = Join-Path $fallbackRoot "installed\x64-windows"
      ImportLibName = "z.lib"
    }
  }

  throw "zlib:x64-windows was not found. Install zlib with vcpkg (e.g. .tools\vcpkg-msvc under your project root) or pass -VcpkgRoot; VS bundled vcpkg may require manifest mode."
}

function Add-ProcessEnvPathPrefix {
  param(
    [string]$Name,
    [string]$Prefix
  )

  if ([string]::IsNullOrWhiteSpace($Prefix)) {
    return
  }
  $current = [Environment]::GetEnvironmentVariable($Name, "Process")
  if ([string]::IsNullOrWhiteSpace($current)) {
    [Environment]::SetEnvironmentVariable($Name, $Prefix, "Process")
  } else {
    [Environment]::SetEnvironmentVariable($Name, "$Prefix;$current", "Process")
  }
}

function Apply-ZlibProcessPaths {
  param([pscustomobject]$Layout)

  $triplet = $Layout.TripletRoot
  Add-ProcessEnvPathPrefix "INCLUDE" (Join-Path $triplet "include")
  Add-ProcessEnvPathPrefix "LIB" (Join-Path $triplet "lib")
  Add-ProcessEnvPathPrefix "PATH" (Join-Path $triplet "bin")
}

function Test-ZlibArtifacts {
  param([pscustomobject]$Layout)

  $include = Join-Path $Layout.TripletRoot "include\zlib.h"
  $lib = Join-Path $Layout.TripletRoot "lib\$($Layout.ImportLibName)"
  if (-not (Test-Path -LiteralPath $include) -or -not (Test-Path -LiteralPath $lib)) {
    throw "zlib:x64-windows was not found under $($Layout.TripletRoot). Install zlib with vcpkg or pass -VcpkgRoot."
  }
}

#endregion

#region Helpers — MoonBit toolchain and WGPU

function Get-MsvcClCompilerPath {
  $cl = (& where.exe cl.exe 2>$null | Select-Object -First 1)
  if ([string]::IsNullOrWhiteSpace($cl)) {
    throw "cl.exe is not available after importing vcvarsall.bat"
  }
  return $cl.Trim()
}

function Get-WgpuNativeRoot {
  param(
    [string]$WorkspaceRoot,
    [string]$ExplicitRoot
  )

  if (-not [string]::IsNullOrWhiteSpace($ExplicitRoot)) {
    $root = (Resolve-Path -LiteralPath $ExplicitRoot).Path
    $dllPath = Join-Path $root "lib\wgpu_native.dll"
    $tagPath = Join-Path $root "wgpu-native-meta\wgpu-native-git-tag"
    if (-not (Test-Path -LiteralPath $dllPath) -or -not (Test-Path -LiteralPath $tagPath)) {
      throw "Invalid WGPU native root: $root. Expected lib\wgpu_native.dll and wgpu-native-meta\wgpu-native-git-tag."
    }
    return $root
  }

  $defaultRoot = Join-Path $WorkspaceRoot ".tools\wgpu-native\wgpu-windows-x86_64-msvc-release"
  $defaultDll = Join-Path $defaultRoot "lib\wgpu_native.dll"
  $defaultTag = Join-Path $defaultRoot "wgpu-native-meta\wgpu-native-git-tag"
  if ((Test-Path -LiteralPath $defaultDll) -and (Test-Path -LiteralPath $defaultTag)) {
    return (Resolve-Path -LiteralPath $defaultRoot).Path
  }

  return ""
}

function Add-MsvcClFlag {
  param([string]$Flag)

  if ([string]::IsNullOrWhiteSpace($Flag)) {
    return
  }
  if ([string]::IsNullOrWhiteSpace($env:CL)) {
    $env:CL = $Flag
    return
  }
  if ($env:CL -notmatch [regex]::Escape($Flag)) {
    $env:CL = "$Flag $($env:CL)"
  }
}

function Enable-MsvcC11Atomics {
  Add-MsvcClFlag "/experimental:c11atomics"
  Add-MsvcClFlag "/wd4005"
  Add-MsvcClFlag "/DMOONBIT_FFI_EXPORT="
}

function Enable-MsvcGlobalC11ModeForCOnlyStubs {
  Add-MsvcClFlag "/std:c11"
}

function Set-MoonBitMsvcEnvironment {
  param(
    [string]$ClPath,
    [pscustomobject]$ZlibLayout,
    [string]$WgpuRoot
  )

  $zlibLib = $ZlibLayout.ImportLibName
  $env:CC = $ClPath
  $env:CXX = $ClPath
  $env:MBT_WGPU_LINK_MODE = "dynamic"
  # /std:c11 is required for <stdatomic.h>: /experimental:c11atomics alone does
  # not define __STDC_VERSION__, so wgpu_mbt's C stubs still hit
  # "C atomics require C11 or later" without it (msvc: vcruntime_c11_stdatomic.h).
  # /utf-8 keeps UTF-8 vendored sources from tripping C4819 on GBK code pages.
  $env:CL = "/DNOMINMAX /experimental:c11atomics /std:c11 /utf-8 /wd4005 /DMOONBIT_FFI_EXPORT="
  $env:LINK = "comdlg32.lib shell32.lib advapi32.lib ole32.lib user32.lib gdi32.lib dwrite.lib d2d1.lib $zlibLib /SUBSYSTEM:WINDOWS /ENTRY:mainCRTStartup"
  $env:MOUI_MSVC_VCPKG_ROOT = $ZlibLayout.Root
  $env:MOUI_MSVC_ZLIB_TRIPLET_ROOT = $ZlibLayout.TripletRoot
  $env:MOUI_MSVC_ZLIB_IMPORT_LIB = $zlibLib

  if (-not [string]::IsNullOrWhiteSpace($WgpuRoot)) {
    $env:MBT_WGPU_NATIVE_ROOT = $WgpuRoot
  } else {
    Remove-Item Env:MBT_WGPU_NATIVE_ROOT -ErrorAction SilentlyContinue
  }
  Remove-Item Env:MBT_WGPU_NATIVE_LIB -ErrorAction SilentlyContinue
  Remove-Item Env:MBT_WGPU_VULKAN_LIB -ErrorAction SilentlyContinue
}

function Write-MouiMsvcSummary {
  param(
    [string]$WorkspaceRoot,
    [string]$VcVarsAll,
    [pscustomobject]$ZlibLayout,
    [string]$WgpuRoot
  )

  Write-Host "==> MSVC environment ready"
  Write-Host "==> workspace root: $WorkspaceRoot"
  Write-Host "==> vcvarsall: $VcVarsAll"
  Write-Host "==> vcpkg root: $($ZlibLayout.Root)"
  Write-Host "==> zlib triplet root: $($ZlibLayout.TripletRoot)"
  Write-Host "==> zlib import lib: $($ZlibLayout.ImportLibName)"
  if (-not [string]::IsNullOrWhiteSpace($WgpuRoot)) {
    Write-Host "==> WGPU native root: $WgpuRoot"
  } else {
    Write-Host "==> WGPU native root: not set; bundle WGPU under .tools\wgpu-native or pass -WgpuNativeRoot"
  }
  Write-Host "==> CC: $env:CC"
  Write-Host "==> CXX: $env:CXX"
  Write-Host "==> MBT_WGPU_LINK_MODE: $env:MBT_WGPU_LINK_MODE"
}

#endregion

#region Main

$mouiPackageDir = Join-Path $script:MouiMsvcScriptDir "..\.."
$workspaceRoot = Get-MouiMsvcWorkspaceRoot -MouiPackageDir $mouiPackageDir

$vcvars = Get-VcVarsAllPath
Import-VcVarsEnvironment -VcVarsAll $vcvars -Architecture $Arch

$zlibLayout = Get-ZlibVcpkgLayout -WorkspaceRoot $workspaceRoot -ExplicitVcpkgRoot $VcpkgRoot -AllowMissingZlib:$SkipZlibCheck
if (-not $SkipZlibCheck) {
  Test-ZlibArtifacts -Layout $zlibLayout
}
Apply-ZlibProcessPaths -Layout $zlibLayout

$clPath = Get-MsvcClCompilerPath
$wgpuRoot = Get-WgpuNativeRoot -WorkspaceRoot $workspaceRoot -ExplicitRoot $WgpuNativeRoot
Set-MoonBitMsvcEnvironment -ClPath $clPath -ZlibLayout $zlibLayout -WgpuRoot $wgpuRoot
Write-MouiMsvcSummary -WorkspaceRoot $workspaceRoot -VcVarsAll $vcvars -ZlibLayout $zlibLayout -WgpuRoot $wgpuRoot

#endregion