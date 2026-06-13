$ErrorActionPreference = "Stop"

$webView2ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$webView2RepoRoot = (Resolve-Path (Join-Path $webView2ScriptDir "..\..")).Path
$webView2LockPath = Join-Path $webView2ScriptDir "webview2-sdk-lock.json"

function Require-WebView2Path {
  param(
    [string]$PathValue,
    [string]$Message
  )

  if (-not (Test-Path -LiteralPath $PathValue)) {
    throw $Message
  }
}

function Assert-WebView2ChildPath {
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

function Get-WebView2SdkLock {
  Require-WebView2Path $webView2LockPath "Missing WebView2 SDK lock file: $webView2LockPath"
  $lock = Get-Content -Raw -LiteralPath $webView2LockPath | ConvertFrom-Json
  foreach ($field in @("package", "version", "url", "sha256")) {
    if (-not ($lock.PSObject.Properties.Name -contains $field) -or [string]::IsNullOrWhiteSpace($lock.$field)) {
      throw "WebView2 SDK lock file is missing '$field': $webView2LockPath"
    }
  }
  return $lock
}

function Get-WebView2SdkPaths {
  param([string]$SdkRoot)

  $root = (Resolve-Path -LiteralPath $SdkRoot).Path
  $includeDir = Join-Path $root "build\native\include"
  $staticLib = Join-Path $root "build\native\x64\WebView2LoaderStatic.lib"
  return [pscustomobject]@{
    Root = $root
    IncludeDir = $includeDir
    StaticLib = $staticLib
  }
}

function Test-WebView2SdkRoot {
  param([string]$SdkRoot)

  if ([string]::IsNullOrWhiteSpace($SdkRoot) -or -not (Test-Path -LiteralPath $SdkRoot)) {
    return $false
  }
  $paths = Get-WebView2SdkPaths $SdkRoot
  return (
    (Test-Path -LiteralPath (Join-Path $paths.IncludeDir "WebView2.h")) -and
    (Test-Path -LiteralPath $paths.StaticLib)
  )
}

function Validate-WebView2SdkRoot {
  param([string]$SdkRoot)

  $paths = Get-WebView2SdkPaths $SdkRoot
  Require-WebView2Path (Join-Path $paths.IncludeDir "WebView2.h") "Missing WebView2 SDK header: $(Join-Path $paths.IncludeDir 'WebView2.h')"
  Require-WebView2Path $paths.StaticLib "Missing WebView2 static loader library: $($paths.StaticLib)"
  return $paths
}

function Quote-WebView2LinkArg {
  param([string]$Value)

  if ($Value -match '^[A-Za-z0-9_./:\\-]+$') {
    return $Value
  }
  return '"' + ($Value -replace '"', '\"') + '"'
}

function Convert-WebView2BuildPath {
  param([string]$Value)

  return $Value.Replace('\', '/')
}

function Install-WebView2Sdk {
  param([object]$Lock)

  $toolsRoot = Join-Path $webView2RepoRoot ".tools\webview2"
  $downloadRoot = Join-Path $toolsRoot "downloads"
  $extractRoot = Join-Path $toolsRoot "$($Lock.package).$($Lock.version)"
  if (Test-WebView2SdkRoot $extractRoot) {
    return (Validate-WebView2SdkRoot $extractRoot)
  }

  New-Item -ItemType Directory -Path $downloadRoot -Force | Out-Null
  $nupkgPath = Join-Path $downloadRoot "$($Lock.package).$($Lock.version).nupkg"
  $zipPath = Join-Path $downloadRoot "$($Lock.package).$($Lock.version).zip"
  Write-Host "==> Downloading WebView2 SDK $($Lock.version)"
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest -UseBasicParsing -Uri $Lock.url -OutFile $nupkgPath
  $actualSha = (Get-FileHash -Algorithm SHA256 -LiteralPath $nupkgPath).Hash.ToUpperInvariant()
  $expectedSha = ([string]$Lock.sha256).ToUpperInvariant()
  if ($actualSha -ne $expectedSha) {
    throw "WebView2 SDK sha256 mismatch: expected $expectedSha, got $actualSha"
  }

  $tmpExtract = Join-Path $toolsRoot "extract-$([Guid]::NewGuid().ToString('N'))"
  Copy-Item -LiteralPath $nupkgPath -Destination $zipPath -Force
  Expand-Archive -LiteralPath $zipPath -DestinationPath $tmpExtract -Force
  $paths = Validate-WebView2SdkRoot $tmpExtract
  if (Test-Path -LiteralPath $extractRoot) {
    Assert-WebView2ChildPath $toolsRoot $extractRoot
    Remove-Item -LiteralPath $extractRoot -Recurse -Force
  }
  Move-Item -LiteralPath $tmpExtract -Destination $extractRoot
  return (Validate-WebView2SdkRoot $extractRoot)
}

function Ensure-WebView2Sdk {
  param([string]$ExplicitRoot = "")

  if (-not [string]::IsNullOrWhiteSpace($ExplicitRoot)) {
    return (Validate-WebView2SdkRoot ((Resolve-Path -LiteralPath $ExplicitRoot).Path))
  }

  $lock = Get-WebView2SdkLock
  $defaultRoot = Join-Path $webView2RepoRoot ".tools\webview2\$($lock.package).$($lock.version)"
  if (Test-WebView2SdkRoot $defaultRoot) {
    return (Validate-WebView2SdkRoot $defaultRoot)
  }
  return (Install-WebView2Sdk $lock)
}

function Enable-WebView2BuildEnvironment {
  param([string]$SdkRoot = "")

  $paths = Ensure-WebView2Sdk $SdkRoot
  $env:MOUI_WINDOWS_ENABLE_WEBVIEW2 = "1"
  $includeDir = Convert-WebView2BuildPath $paths.IncludeDir
  $staticLib = Convert-WebView2BuildPath $paths.StaticLib
  $env:MOUI_WINDOWS_WEBVIEW2_INCLUDE = $includeDir
  $env:MOUI_WINDOWS_WEBVIEW2_LINK_FLAGS = "$(Quote-WebView2LinkArg $staticLib) version.lib"
  Write-Host "==> WebView2 SDK root: $($paths.Root)"
  Write-Host "==> WebView2 static loader: $($paths.StaticLib)"
  Write-Host "==> WebView2 runtime: Evergreen Runtime is required on the target machine"
  return $paths
}
