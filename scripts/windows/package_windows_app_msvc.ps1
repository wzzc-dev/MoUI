[CmdletBinding()]
param(
  [string]$Package = "examples/showcase/windows_skia",
  [string]$AppName = "",
  [string]$DistDir = "dist\windows-msvc",
  [switch]$NoBuild,
  [string]$VcpkgRoot = "",
  [string]$WgpuNativeRoot = "",
  [switch]$EnableWebView2,
  [string]$WebView2SdkRoot = "",
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
  $usesWgpuRenderer = $pkg.Contains("wzzc-dev/moui_wgpu_renderer")
  return $usesWgpuRenderer
}

function Find-ZlibRuntimeDll {
  $tripletRoot = $env:MOUI_MSVC_ZLIB_TRIPLET_ROOT
  if ([string]::IsNullOrWhiteSpace($tripletRoot)) {
    throw "MOUI_MSVC_ZLIB_TRIPLET_ROOT is not set; msvc_env.ps1 did not configure zlib."
  }
  $binDir = Join-Path $tripletRoot "bin"
  foreach ($name in @("z.dll", "zlib1.dll", "zlib.dll")) {
    $candidate = Join-Path $binDir $name
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }
  $matches = Get-ChildItem -LiteralPath $binDir -Filter "zlib*.dll" -ErrorAction SilentlyContinue
  if ($matches.Count -gt 0) {
    return $matches[0].FullName
  }
  throw "Could not find zlib runtime DLL under $binDir"
}

function Test-PackageUsesSkia {
  param([string]$PackagePath)

  $pkgPath = Join-Path $repoRoot (Join-Path (Convert-PackagePath $PackagePath) "moon.pkg")
  if (-not (Test-Path -LiteralPath $pkgPath)) {
    return $false
  }
  $pkg = Get-Content -LiteralPath $pkgPath -Raw
  return $pkg.Contains("wzzc-dev/moui_skia_renderer")
}

function Find-SkiaIcuDataFile {
  # The Skia ICU data table ships inside the release Skia package and must sit
  # next to the executable: Skia's SkLoadICU only searches the exe/module
  # directories (it ignores the ICU_DATA environment variable).
  $skiaScript = Join-Path $repoRoot "moui_skia\scripts\fetch-release-skia.ps1"
  if (-not (Test-Path -LiteralPath $skiaScript)) {
    return $null
  }
  $cacheDir = Join-Path $repoRoot "moui_skia\.skia-cache\release"
  $envLines = & $skiaScript -Platform windows -Arch auto -Config Release -LinkMode static -CacheDir $cacheDir -PrintEnv 2>$null
  $libDir = $envLines | ForEach-Object {
    if ($_ -match '^MOUI_SKIA_SKIA_LIB_DIR=(.*)$') { $Matches[1] }
  } | Select-Object -Last 1
  if ([string]::IsNullOrWhiteSpace($libDir)) {
    return $null
  }
  $icuData = Join-Path $libDir "icudtl.dat"
  if (Test-Path -LiteralPath $icuData) {
    return $icuData
  }
  return $null
}

function Copy-SkiaIcuData {
  param([string]$DestinationDir)

  if (-not (Test-PackageUsesSkia $Package)) {
    return
  }
  $icuData = Find-SkiaIcuDataFile
  if ($null -eq $icuData) {
    Write-Warning "Skia icudtl.dat was not found under moui_skia\.skia-cache; SkParagraph text layout will not work in the packaged app."
    return
  }
  $destination = Join-Path $DestinationDir "icudtl.dat"
  Remove-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue
  New-Item -ItemType HardLink -Path $destination -Target $icuData -ErrorAction SilentlyContinue | Out-Null
  if (-not (Test-Path -LiteralPath $destination)) {
    Copy-Item -LiteralPath $icuData -Destination $destination
  }
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
. (Join-Path $scriptDir "webview2_sdk.ps1")

$packageLeaf = Split-Path -Leaf (Convert-PackagePath $Package)
$packageParent = Split-Path -Leaf (Split-Path -Parent (Convert-PackagePath $Package))
if ([string]::IsNullOrWhiteSpace($AppName)) {
  $AppName = $packageParent
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
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  throw "Node.js is required to validate the package manifest."
}

$packageBuildDir = Join-Path $repoRoot ("_build\native\debug\build\" + (Convert-PackagePath $Package))
$builtExe = Join-Path $packageBuildDir "$packageLeaf.exe"
$appDir = Join-Path $repoRoot (Join-Path $DistDir $AppName)
$appExe = Join-Path $appDir "$AppName.exe"
$manifestPath = Join-Path $appDir "moui-package.json"
$wgpuAppRoot = Join-Path $appDir "wgpu-native"
$runCmdPath = Join-Path $appDir "run.cmd"

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
  if (-not $NoBuild) {
    & moon build $Package --target native
    if ($LASTEXITCODE -ne 0) {
      throw "moon build failed with exit code $LASTEXITCODE"
    }
  }

  Require-Path $builtExe "Built executable not found: $builtExe"

  if (Test-Path -LiteralPath $appDir) {
    Assert-ChildPath (Join-Path $repoRoot $DistDir) $appDir
    Remove-Item -LiteralPath $appDir -Recurse -Force
  }
  New-Item -ItemType Directory -Path $appDir | Out-Null

  Copy-Item -LiteralPath $builtExe -Destination $appExe
  if ($usesWgpu) {
    Copy-Item -LiteralPath $resolvedWgpuRoot -Destination $wgpuAppRoot -Recurse
  }

  $zlibRuntime = Find-ZlibRuntimeDll
  $zlibRuntimeName = Split-Path -Leaf $zlibRuntime
  Copy-Item -LiteralPath $zlibRuntime -Destination (Join-Path $appDir $zlibRuntimeName)

  Copy-SkiaIcuData $appDir

  if ($usesWgpu) {
    $runCmd = @(
      "@echo off",
      "setlocal",
      'set "MBT_WGPU_NATIVE_ROOT=%~dp0wgpu-native"',
      'set "PATH=%~dp0;%~dp0wgpu-native\lib;%PATH%"',
      '"%~dp0' + $AppName + '.exe" %*',
      "exit /b %ERRORLEVEL%"
    )
  } else {
    $runCmd = @(
      "@echo off",
      "setlocal",
      'set "PATH=%~dp0;%PATH%"',
      '"%~dp0' + $AppName + '.exe" %*',
      "exit /b %ERRORLEVEL%"
    )
  }
  Set-Content -LiteralPath $runCmdPath -Value $runCmd -Encoding ASCII

  $runtimeFiles = @(
    "run.cmd",
    $zlibRuntimeName
  )
  if ($usesWgpu) {
    $runtimeFiles = @(
      "run.cmd",
      "wgpu-native\lib\wgpu_native.dll",
      $zlibRuntimeName
    )
  }
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
    runtimeFiles = $runtimeFiles
  }
  if ($webView2) {
    $manifest.externalRuntimeDependencies = @("Microsoft Edge WebView2 Evergreen Runtime")
  }
  $manifest = $manifest | ConvertTo-Json -Depth 4
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
