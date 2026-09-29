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

# The MoonBit CLI unconditionally injects /std:c11 for every MSVC-classified
# stub compile (moonutil compiler_flags/msvc.rs). cl.exe rejects /std:c11
# combined with the /std:c++20 that the Skia stubs require (D8016), so the
# Windows helpers pin an absolute clang-cl.exe instead. clang-cl is classified
# as Msvc by the CLI, accepts both flags in one command line, and pairs with its
# sibling llvm-lib.exe as the archiver (moon resolves llvm-lib next to the path
# given in MOON_CC; MOON_AR is ignored for MSVC toolchains).
function Get-MsvcClangClCompilerPath {
  $candidates = @()

  $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
  if (Test-Path -LiteralPath $vswhere) {
    $installPath = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath) -join ""
    if (-not [string]::IsNullOrWhiteSpace($installPath)) {
      $candidates += (Join-Path $installPath "VC\Tools\Llvm\x64\bin\clang-cl.exe")
      $llvmRoot = Join-Path $installPath "VC\Tools\Llvm"
      if (Test-Path -LiteralPath $llvmRoot) {
        $found = Get-ChildItem -LiteralPath $llvmRoot -Filter "clang-cl.exe" -Recurse -File -ErrorAction SilentlyContinue |
          Sort-Object FullName -Descending |
          Select-Object -First 1
        if ($null -ne $found) {
          $candidates += $found.FullName
        }
      }
    }
  }

  $onPath = (& where.exe clang-cl.exe 2>$null | Select-Object -First 1)
  if (-not [string]::IsNullOrWhiteSpace($onPath)) {
    $candidates += $onPath.Trim()
  }

  foreach ($candidate in $candidates) {
    if ([string]::IsNullOrWhiteSpace($candidate) -or -not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
      continue
    }
    $resolved = (Resolve-Path -LiteralPath $candidate).Path
    $llvmLib = Join-Path (Split-Path -Parent $resolved) "llvm-lib.exe"
    if (-not (Test-Path -LiteralPath $llvmLib -PathType Leaf)) {
      continue
    }
    return $resolved
  }

  throw "clang-cl.exe with a sibling llvm-lib.exe was not found. Install Visual Studio's C++ Clang tools (Microsoft.VisualStudio.Component.VC.Llvm.Clang) or put clang-cl.exe and llvm-lib.exe on PATH."
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
    [string]$ClangClPath,
    [pscustomobject]$ZlibLayout,
    [string]$WgpuRoot
  )

  $zlibLib = $ZlibLayout.ImportLibName
  # MOON_CC is the MoonBit CLI's native compiler override and must be an
  # absolute, path-like path so the CLI skips its own VS discovery; MOON_AR is
  # ignored for MSVC toolchains, so moon pairs the MOON_CC path with its sibling
  # llvm-lib.exe automatically.
  $env:MOON_CC = $ClangClPath
  $env:CC = $ClPath
  $env:CXX = $ClPath
  $env:MBT_WGPU_LINK_MODE = "dynamic"
  # /experimental:c11atomics alone does not define __STDC_VERSION__, so the
  # wgpu_mbt C stubs (<stdatomic.h>) additionally need /std:c11. The MoonBit CLI
  # also injects /std:c11 into every MSVC stub compile, while the Skia stub flag
  # flags pin /std:c++20. cl.exe rejects that combination (D8016); MOON_CC points
  # at clang-cl.exe, which accepts both. Consumers that need the C11 mode for
  # direct cl invocations call Enable-MsvcGlobalC11ModeForCOnlyStubs after
  # sourcing this script. /utf-8 keeps UTF-8 vendored sources from tripping
  # C4819 on GBK code pages.
  $env:CL = "/DNOMINMAX /experimental:c11atomics /utf-8 /wd4005 /DMOONBIT_FFI_EXPORT="
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
  Write-Host "==> MOON_CC: $env:MOON_CC"
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
$clangClPath = Get-MsvcClangClCompilerPath
$wgpuRoot = Get-WgpuNativeRoot -WorkspaceRoot $workspaceRoot -ExplicitRoot $WgpuNativeRoot
Set-MoonBitMsvcEnvironment -ClPath $clPath -ClangClPath $clangClPath -ZlibLayout $zlibLayout -WgpuRoot $wgpuRoot
Write-MouiMsvcSummary -WorkspaceRoot $workspaceRoot -VcVarsAll $vcvars -ZlibLayout $zlibLayout -WgpuRoot $wgpuRoot

#endregion