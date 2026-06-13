[CmdletBinding()]
param(
  [string]$VcpkgRoot = "",
  [switch]$InstallZlib,
  [switch]$InstallWebView2,
  [string]$WebView2SdkRoot = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
. (Join-Path $scriptDir "webview2_sdk.ps1")

function Require-Command {
  param(
    [string]$Name,
    [string]$InstallHint
  )

  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $command) {
    throw "$Name was not found. $InstallHint"
  }
  return $command.Source
}

function Find-VsWhere {
  $candidate = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
  if (Test-Path -LiteralPath $candidate) {
    return $candidate
  }
  throw "vswhere.exe was not found. Install Visual Studio Build Tools with: winget install --id Microsoft.VisualStudio.2022.BuildTools -e"
}

function Find-VcpkgToolRoot {
  param(
    [string]$ExplicitRoot,
    [string]$VisualStudioRoot
  )

  if (-not [string]::IsNullOrWhiteSpace($ExplicitRoot)) {
    return (Resolve-Path -LiteralPath $ExplicitRoot).Path
  }
  if (-not [string]::IsNullOrWhiteSpace($env:VCPKG_ROOT)) {
    return (Resolve-Path -LiteralPath $env:VCPKG_ROOT).Path
  }
  if (-not [string]::IsNullOrWhiteSpace($env:VCPKG_INSTALLATION_ROOT)) {
    return (Resolve-Path -LiteralPath $env:VCPKG_INSTALLATION_ROOT).Path
  }
  if ((Test-Path -LiteralPath "C:\vcpkg") -and (Test-Path -LiteralPath "C:\vcpkg\vcpkg.exe")) {
    return (Resolve-Path -LiteralPath "C:\vcpkg").Path
  }
  if (-not [string]::IsNullOrWhiteSpace($VisualStudioRoot)) {
    $vsBundledRoot = Join-Path $VisualStudioRoot "VC\vcpkg"
    if ((Test-Path -LiteralPath $vsBundledRoot) -and (Test-Path -LiteralPath (Join-Path $vsBundledRoot "vcpkg.exe"))) {
      return (Resolve-Path -LiteralPath $vsBundledRoot).Path
    }
  }
  $command = Get-Command vcpkg -ErrorAction SilentlyContinue
  if ($command) {
    return (Split-Path -Parent $command.Source)
  }
  return ""
}

function Find-ZlibTripletRoot {
  param([string]$Root)

  if ([string]::IsNullOrWhiteSpace($Root) -or -not (Test-Path -LiteralPath $Root)) {
    return ""
  }

  foreach ($relative in @("installed\x64-windows", "vcpkg_installed\x64-windows")) {
    $tripletRoot = Join-Path $Root $relative
    $zlibHeader = Join-Path $tripletRoot "include\zlib.h"
    $zlibImportLibs = @(
      (Join-Path $tripletRoot "lib\z.lib"),
      (Join-Path $tripletRoot "lib\zlib.lib")
    )
    $hasImportLib = $zlibImportLibs | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ((Test-Path -LiteralPath $zlibHeader) -and $hasImportLib) {
      return (Resolve-Path -LiteralPath $tripletRoot).Path
    }
  }

  return ""
}

function Find-ZlibRoot {
  param([string[]]$Candidates)

  foreach ($candidate in @($Candidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
    $tripletRoot = Find-ZlibTripletRoot $candidate
    if (-not [string]::IsNullOrWhiteSpace($tripletRoot)) {
      return [pscustomobject]@{
        Root = (Resolve-Path -LiteralPath $candidate).Path
        TripletRoot = $tripletRoot
      }
    }
  }

  return $null
}

function Write-ZlibManifest {
  param([string]$ManifestRoot)

  New-Item -ItemType Directory -Path $ManifestRoot -Force | Out-Null
  $manifestPath = Join-Path $ManifestRoot "vcpkg.json"
  $manifest = [ordered]@{
    name = "moui-msvc-native-deps"
    "version-string" = "0.1.0"
    dependencies = @("zlib")
  } | ConvertTo-Json -Depth 4
  Set-Content -LiteralPath $manifestPath -Value $manifest -Encoding ASCII
}

function Ensure-VcpkgBaseline {
  param([string]$VcpkgExe)

  $manifest = Get-Content -Raw -LiteralPath "vcpkg.json" | ConvertFrom-Json
  if ($manifest.PSObject.Properties.Name -contains "builtin-baseline") {
    return
  }

  Write-Host "==> Resolving vcpkg builtin-baseline"
  & $VcpkgExe x-update-baseline --add-initial-baseline
  if ($LASTEXITCODE -ne 0) {
    throw "vcpkg x-update-baseline failed with exit code $LASTEXITCODE"
  }
}

function Install-ZlibManifestMode {
  param(
    [string]$VcpkgExe,
    [string]$ManifestRoot
  )

  Write-ZlibManifest $ManifestRoot
  $installRoot = Join-Path $ManifestRoot "installed"
  $buildtreesRoot = Join-Path $ManifestRoot "buildtrees"
  $packagesRoot = Join-Path $ManifestRoot "packages"
  $downloadsRoot = Join-Path $ManifestRoot "downloads"

  Push-Location $ManifestRoot
  try {
    Ensure-VcpkgBaseline $VcpkgExe
    Write-Host "==> Installing zlib:x64-windows with vcpkg manifest mode"
    & $VcpkgExe install `
      --triplet x64-windows `
      "--x-install-root=$installRoot" `
      "--x-buildtrees-root=$buildtreesRoot" `
      "--x-packages-root=$packagesRoot" `
      "--downloads-root=$downloadsRoot"
    if ($LASTEXITCODE -ne 0) {
      throw "vcpkg manifest install failed with exit code $LASTEXITCODE"
    }
  }
  finally {
    Pop-Location
  }
}

$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($winget) {
  Write-Host "==> winget: $($winget.Source)"
} else {
  Write-Warning "winget was not found; install Visual Studio Build Tools manually or from https://visualstudio.microsoft.com/downloads/."
}

$vswhere = Find-VsWhere
$vsInstallPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ([string]::IsNullOrWhiteSpace($vsInstallPath)) {
  throw "Visual Studio C++ build tools were not found. Install them with: winget install --id Microsoft.VisualStudio.2022.BuildTools -e"
}
Write-Host "==> Visual Studio C++ tools: $vsInstallPath"

$resolvedVcpkgToolRoot = Find-VcpkgToolRoot -ExplicitRoot $VcpkgRoot -VisualStudioRoot $vsInstallPath
if ([string]::IsNullOrWhiteSpace($resolvedVcpkgToolRoot)) {
  throw "vcpkg was not found. Install vcpkg or pass -VcpkgRoot; then rerun this script with -InstallZlib."
}
Write-Host "==> vcpkg executable root: $resolvedVcpkgToolRoot"

$vcpkgExe = Join-Path $resolvedVcpkgToolRoot "vcpkg.exe"
if (-not (Test-Path -LiteralPath $vcpkgExe)) {
  $vcpkgCommand = Get-Command vcpkg -ErrorAction SilentlyContinue
  if ($vcpkgCommand) {
    $vcpkgExe = $vcpkgCommand.Source
  } else {
    throw "vcpkg.exe was not found under $resolvedVcpkgToolRoot"
  }
}

$workspaceVcpkgRoot = Join-Path $repoRoot ".tools\vcpkg-msvc"
$zlibInfo = Find-ZlibRoot @($VcpkgRoot, $workspaceVcpkgRoot, $env:MOUI_MSVC_VCPKG_ROOT, $env:VCPKG_ROOT, $env:VCPKG_INSTALLATION_ROOT, "C:\vcpkg", $resolvedVcpkgToolRoot)
if ($null -eq $zlibInfo) {
  if ($InstallZlib) {
    Install-ZlibManifestMode -VcpkgExe $vcpkgExe -ManifestRoot $workspaceVcpkgRoot
    $zlibInfo = Find-ZlibRoot @($workspaceVcpkgRoot)
    if ($null -eq $zlibInfo) {
      throw "zlib:x64-windows was installed, but zlib.h and a zlib import library were not found under $workspaceVcpkgRoot"
    }
  } else {
    throw "zlib:x64-windows was not found. Run this script with -InstallZlib. VS bundled vcpkg may require manifest mode instead of direct vcpkg install."
  }
}

Write-Host "==> zlib:x64-windows root: $($zlibInfo.Root)"
Write-Host "==> zlib:x64-windows triplet: $($zlibInfo.TripletRoot)"
if ($InstallWebView2 -or -not [string]::IsNullOrWhiteSpace($WebView2SdkRoot)) {
  $webView2 = Ensure-WebView2Sdk $WebView2SdkRoot
  Write-Host "==> WebView2 SDK root: $($webView2.Root)"
  Write-Host "==> WebView2 static loader: $($webView2.StaticLib)"
}
Write-Host "==> MSVC dependencies are ready"
