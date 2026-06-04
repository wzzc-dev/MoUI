param(
  [string] $NativeDir = "native",
  [string] $PkgPath = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

function Resolve-RepoPath {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path
  )

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return $Path
  }

  return Join-Path $repoRoot $Path
}

function Get-BaseName {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Name,
    [Parameter(Mandatory = $true)]
    [string] $Suffix
  )

  return $Name.Substring(0, $Name.Length - $Suffix.Length)
}

function Assert-TargetList {
  param(
    [Parameter(Mandatory = $true)]
    [hashtable] $TargetEntries,
    [Parameter(Mandatory = $true)]
    [string] $FileName,
    [Parameter(Mandatory = $true)]
    [string[]] $Expected
  )

  if (!$TargetEntries.ContainsKey($FileName)) {
    throw "native moon.pkg is missing target mapping for $FileName"
  }
  $actual = @($TargetEntries[$FileName])
  if ($actual.Count -ne $Expected.Count) {
    throw "native moon.pkg has wrong targets for ${FileName}: expected=$($Expected -join ',') actual=$($actual -join ',')"
  }
  for ($index = 0; $index -lt $Expected.Count; $index += 1) {
    if ($actual[$index] -ne $Expected[$index]) {
      throw "native moon.pkg has wrong targets for ${FileName}: expected=$($Expected -join ',') actual=$($actual -join ',')"
    }
  }
}

$resolvedNativeDir = Resolve-RepoPath $NativeDir
if ([string]::IsNullOrWhiteSpace($PkgPath)) {
  $resolvedPkgPath = Join-Path $resolvedNativeDir "moon.pkg"
} else {
  $resolvedPkgPath = Resolve-RepoPath $PkgPath
}

if (!(Test-Path -LiteralPath $resolvedNativeDir -PathType Container)) {
  throw "native package directory is missing: $resolvedNativeDir"
}
if (!(Test-Path -LiteralPath $resolvedPkgPath -PathType Leaf)) {
  throw "native package moon.pkg is missing: $resolvedPkgPath"
}

$pkgText = Get-Content -LiteralPath $resolvedPkgPath -Raw
$targetEntries = @{}
foreach ($match in [regex]::Matches($pkgText, '"([^"]+\.mbt)"\s*:\s*\[([^\]]*)\]', [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
  $fileName = $match.Groups[1].Value
  if ($targetEntries.ContainsKey($fileName)) {
    throw "duplicate target entry in native moon.pkg: $fileName"
  }
  $targets = @()
  foreach ($targetMatch in [regex]::Matches($match.Groups[2].Value, '"([^"]+)"')) {
    $targets += $targetMatch.Groups[1].Value
  }
  $targetEntries[$fileName] = $targets
}
if ($targetEntries.Count -eq 0) {
  throw "native package moon.pkg has no target entries: $resolvedPkgPath"
}

$nativeFiles = @{}
foreach ($file in Get-ChildItem -LiteralPath $resolvedNativeDir -Filter "*_native.mbt" -File) {
  $nativeFiles[$file.Name] = $true
}
$fallbackFiles = @{}
foreach ($file in Get-ChildItem -LiteralPath $resolvedNativeDir -Filter "*_unavailable.mbt" -File) {
  $fallbackFiles[$file.Name] = $true
}
if ($nativeFiles.Count -eq 0) {
  throw "native package has no *_native.mbt files: $resolvedNativeDir"
}
if ($fallbackFiles.Count -eq 0) {
  throw "native package has no *_unavailable.mbt files: $resolvedNativeDir"
}

$nativeBases = @{}
foreach ($name in $nativeFiles.Keys) {
  $nativeBases[(Get-BaseName -Name $name -Suffix "_native.mbt")] = $true
}
$fallbackBases = @{}
foreach ($name in $fallbackFiles.Keys) {
  $fallbackBases[(Get-BaseName -Name $name -Suffix "_unavailable.mbt")] = $true
}

$missingFallbacks = @($nativeBases.Keys | Where-Object { !$fallbackBases.ContainsKey($_) } | Sort-Object)
if ($missingFallbacks.Count -gt 0) {
  throw "native implementation files are missing unavailable fallbacks: $($missingFallbacks -join ', ')"
}
$missingNative = @($fallbackBases.Keys | Where-Object { !$nativeBases.ContainsKey($_) } | Sort-Object)
if ($missingNative.Count -gt 0) {
  throw "unavailable fallback files are missing native implementations: $($missingNative -join ', ')"
}

$nativeTargets = @("native", "llvm")
$fallbackTargets = @("wasm", "wasm-gc", "js")
foreach ($base in @($nativeBases.Keys | Sort-Object)) {
  Assert-TargetList -TargetEntries $targetEntries -FileName "${base}_native.mbt" -Expected $nativeTargets
  Assert-TargetList -TargetEntries $targetEntries -FileName "${base}_unavailable.mbt" -Expected $fallbackTargets
}

$targetSpecificEntries = @{}
foreach ($name in $targetEntries.Keys) {
  if ($name.EndsWith("_native.mbt") -or $name.EndsWith("_unavailable.mbt")) {
    $targetSpecificEntries[$name] = $true
  }
}

$missingFiles = @(
  $targetSpecificEntries.Keys |
    Where-Object { !(Test-Path -LiteralPath (Join-Path $resolvedNativeDir $_) -PathType Leaf) } |
    Sort-Object
)
if ($missingFiles.Count -gt 0) {
  throw "native moon.pkg target entries reference missing files: $($missingFiles -join ', ')"
}

$unpairedEntries = @(
  $targetSpecificEntries.Keys |
    Where-Object { !$nativeFiles.ContainsKey($_) -and !$fallbackFiles.ContainsKey($_) } |
    Sort-Object
)
if ($unpairedEntries.Count -gt 0) {
  throw "native moon.pkg target entries are not native/fallback implementation files: $($unpairedEntries -join ', ')"
}

Write-Host "Verified native fallback parity in $resolvedNativeDir"
