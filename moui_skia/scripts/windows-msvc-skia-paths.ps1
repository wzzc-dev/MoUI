function Get-MouiSkiaDefaultMsvcCacheRoot {
  param([Parameter(Mandatory = $true)][string] $RepoRoot)
  return Join-Path $RepoRoot ".skia-cache/windows-msvc/aseprite/Skia-Windows-Release-x64"
}

function Get-MouiSkiaDefaultMsvcZip {
  param([string] $UserProfile)

  if ([string]::IsNullOrWhiteSpace($UserProfile)) {
    return ""
  }
  $downloads = Join-Path $UserProfile "Downloads"
  if (!(Test-Path -LiteralPath $downloads -PathType Container)) {
    return ""
  }

  $legacyZip = Join-Path $downloads "Skia-Windows-Release-x64.zip"
  if (Test-Path -LiteralPath $legacyZip -PathType Leaf) {
    return $legacyZip
  }

  $matches = @()
  foreach ($pattern in @("Skia-*-windows-Release-x64-shared.zip", "Skia-*-windows-Release-x64.zip")) {
    $matches += @(
      Get-ChildItem -LiteralPath $downloads -File -Filter $pattern -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
    )
  }
  if ($matches.Count -gt 0) {
    return $matches[0].FullName
  }
  return ""
}

function Get-MouiSkiaMsvcCacheRootForZip {
  param(
    [Parameter(Mandatory = $true)][string] $RepoRoot,
    [string] $SkiaZip
  )

  if ([string]::IsNullOrWhiteSpace($SkiaZip)) {
    return Get-MouiSkiaDefaultMsvcCacheRoot -RepoRoot $RepoRoot
  }

  $baseName = [System.IO.Path]::GetFileNameWithoutExtension($SkiaZip)
  if ($baseName -eq "Skia-Windows-Release-x64") {
    return Get-MouiSkiaDefaultMsvcCacheRoot -RepoRoot $RepoRoot
  }
  return Join-Path (Join-Path $RepoRoot ".skia-cache/windows-msvc") $baseName
}

function Find-MouiSkiaHeaderRoot {
  param([Parameter(Mandatory = $true)][string] $Root)

  if (!(Test-Path -LiteralPath $Root -PathType Container)) {
    return $null
  }

  $directHeader = Join-Path $Root "include/core/SkSurface.h"
  if (Test-Path -LiteralPath $directHeader -PathType Leaf) {
    return (Resolve-Path -LiteralPath $Root).Path
  }

  $header = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter "SkSurface.h" -ErrorAction SilentlyContinue |
    Where-Object { ($_.FullName -replace "\\", "/").EndsWith("/include/core/SkSurface.h") } |
    Select-Object -First 1
  if (!$header) {
    return $null
  }

  $full = $header.FullName -replace "\\", "/"
  return $full.Substring(0, $full.Length - "/include/core/SkSurface.h".Length)
}

function Test-MouiSkiaMsvcLibDir {
  param([Parameter(Mandatory = $true)][string] $LibDir)

  return (
    (Test-Path -LiteralPath (Join-Path $LibDir "skia.lib") -PathType Leaf) -or
    (Test-Path -LiteralPath (Join-Path $LibDir "skia.dll.lib") -PathType Leaf)
  )
}

function Find-MouiSkiaMsvcLibDir {
  param([Parameter(Mandatory = $true)][string] $Root)

  if (!(Test-Path -LiteralPath $Root -PathType Container)) {
    return $null
  }

  $candidateDirs = @(
    (Join-Path $Root "out/Release-x64"),
    (Join-Path $Root "out/Release-windows-x64"),
    (Join-Path $Root "out/Release-windows-x64-shared"),
    (Join-Path $Root "out/Debug-x64"),
    (Join-Path $Root "out/Debug-windows-x64"),
    (Join-Path $Root "out/Debug-windows-x64-shared")
  )
  foreach ($candidate in $candidateDirs) {
    if ((Test-Path -LiteralPath $candidate -PathType Container) -and
      (Test-MouiSkiaMsvcLibDir -LibDir $candidate)) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }

  foreach ($name in @("skia.lib", "skia.dll.lib")) {
    $lib = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $name -ErrorAction SilentlyContinue |
      Select-Object -First 1
    if ($lib) {
      return $lib.DirectoryName
    }
  }
  return $null
}

function Resolve-MouiSkiaMsvcPaths {
  param(
    [Parameter(Mandatory = $true)][string] $RepoRoot,
    [string] $SkiaRoot,
    [string] $SkiaInclude,
    [string] $SkiaZip,
    [string] $SkiaLibDir,
    [switch] $ForceExtract
  )

  $defaultCacheRoot = Get-MouiSkiaDefaultMsvcCacheRoot -RepoRoot $RepoRoot
  if ([string]::IsNullOrWhiteSpace($SkiaRoot)) {
    if (![string]::IsNullOrWhiteSpace($SkiaZip)) {
      $SkiaRoot = Get-MouiSkiaMsvcCacheRootForZip -RepoRoot $RepoRoot -SkiaZip $SkiaZip
    } elseif (Test-Path -LiteralPath $defaultCacheRoot -PathType Container) {
      $SkiaRoot = $defaultCacheRoot
    } else {
      $SkiaZip = Get-MouiSkiaDefaultMsvcZip -UserProfile $env:USERPROFILE
      if (![string]::IsNullOrWhiteSpace($SkiaZip)) {
        $SkiaRoot = Get-MouiSkiaMsvcCacheRootForZip -RepoRoot $RepoRoot -SkiaZip $SkiaZip
      } else {
        throw "SkiaRoot is required; pass -SkiaRoot, set MOUI_SKIA_SKIA_ROOT, pass -SkiaZip, or place a Windows Skia release zip in Downloads."
      }
    }
  }

  if (!(Test-Path -LiteralPath $SkiaRoot -PathType Container)) {
    if ([string]::IsNullOrWhiteSpace($SkiaZip)) {
      throw "Skia root is missing and no SkiaZip was provided: $SkiaRoot"
    }
    if (!(Test-Path -LiteralPath $SkiaZip -PathType Leaf)) {
      throw "Skia zip was not found: $SkiaZip"
    }
    New-Item -ItemType Directory -Force -Path $SkiaRoot | Out-Null
    Write-Host "Extracting Skia zip to $SkiaRoot"
    Expand-Archive -LiteralPath $SkiaZip -DestinationPath $SkiaRoot -Force:$ForceExtract
  }

  $resolvedRoot = (Resolve-Path -LiteralPath $SkiaRoot).Path
  $discoveredRoot = Find-MouiSkiaHeaderRoot -Root $resolvedRoot
  if ($discoveredRoot) {
    $resolvedRoot = $discoveredRoot
  } elseif ([string]::IsNullOrWhiteSpace($SkiaInclude)) {
    throw "SkiaRoot does not contain include/core/SkSurface.h: $resolvedRoot"
  }

  $resolvedIncludeRoot = $resolvedRoot
  if (![string]::IsNullOrWhiteSpace($SkiaInclude)) {
    $resolvedIncludeRoot = (Resolve-Path -LiteralPath $SkiaInclude).Path
    $includeHeaderRoot = Find-MouiSkiaHeaderRoot -Root $resolvedIncludeRoot
    if ($includeHeaderRoot) {
      $resolvedIncludeRoot = $includeHeaderRoot
    }
  }
  $headerPath = Join-Path $resolvedIncludeRoot "include/core/SkSurface.h"
  if (!(Test-Path -LiteralPath $headerPath -PathType Leaf)) {
    throw "Skia include root does not look like a Skia checkout/root: $resolvedIncludeRoot"
  }

  $resolvedLibDir = ""
  if (![string]::IsNullOrWhiteSpace($SkiaLibDir)) {
    $resolvedLibDir = (Resolve-Path -LiteralPath $SkiaLibDir).Path
  } else {
    $resolvedLibDir = Find-MouiSkiaMsvcLibDir -Root $resolvedRoot
    if (!$resolvedLibDir) {
      throw "Skia MSVC library directory was not found under $resolvedRoot; expected skia.lib or skia.dll.lib"
    }
  }

  [PSCustomObject]@{
    Root = $resolvedRoot
    IncludeRoot = $resolvedIncludeRoot
    LibDir = $resolvedLibDir
  }
}
