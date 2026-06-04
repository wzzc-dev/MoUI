param(
  [string] $NativeDir = "native"
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

function Split-TopLevel {
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string] $Text
  )

  $parts = @()
  $start = 0
  $bracketDepth = 0
  $parenDepth = 0
  for ($index = 0; $index -lt $Text.Length; $index += 1) {
    $char = $Text[$index]
    if ($char -eq "[") {
      $bracketDepth += 1
    } elseif ($char -eq "]" -and $bracketDepth -gt 0) {
      $bracketDepth -= 1
    } elseif ($char -eq "(") {
      $parenDepth += 1
    } elseif ($char -eq ")" -and $parenDepth -gt 0) {
      $parenDepth -= 1
    } elseif ($char -eq "," -and $bracketDepth -eq 0 -and $parenDepth -eq 0) {
      $parts += $Text.Substring($start, $index - $start).Trim()
      $start = $index + 1
    }
  }

  $tail = $Text.Substring($start).Trim()
  if ($tail) {
    $parts += $tail
  }
  return $parts
}

function Find-MatchingParen {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Text,
    [Parameter(Mandatory = $true)]
    [int] $OpenIndex
  )

  $depth = 0
  for ($index = $OpenIndex; $index -lt $Text.Length; $index += 1) {
    $char = $Text[$index]
    if ($char -eq "(") {
      $depth += 1
    } elseif ($char -eq ")") {
      $depth -= 1
      if ($depth -eq 0) {
        return $index
      }
    }
  }

  throw "unterminated extern parameter list"
}

function Test-NonPrimitiveType {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Type
  )

  $primitiveTypes = @{
    "Bool" = $true
    "Byte" = $true
    "Char" = $true
    "Double" = $true
    "Float" = $true
    "Int" = $true
    "Int16" = $true
    "Int64" = $true
    "Int8" = $true
    "UInt" = $true
    "UInt16" = $true
    "UInt64" = $true
    "UInt8" = $true
    "Unit" = $true
  }
  $normalized = ($Type -replace "\s+", "").TrimEnd("?")
  return !$primitiveTypes.ContainsKey($normalized)
}

function Test-ExternBlock {
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string] $Block,
    [Parameter(Mandatory = $true)]
    [string] $Path
  )

  $externMatch = [regex]::Match($Block, '(?:pub\s+)?extern\s+"[Cc]"\s+fn\s+([A-Za-z_][A-Za-z0-9_]*)')
  if (!$externMatch.Success) {
    return
  }

  $fnName = $externMatch.Groups[1].Value
  $openIndex = $Block.IndexOf("(", $externMatch.Index + $externMatch.Length)
  if ($openIndex -lt 0) {
    throw "${Path}: missing parameter list for $fnName"
  }
  $closeIndex = Find-MatchingParen -Text $Block -OpenIndex $openIndex
  $paramText = $Block.Substring($openIndex + 1, $closeIndex - $openIndex - 1)
  $params = @{}
  foreach ($part in Split-TopLevel -Text $paramText) {
    if (!$part) {
      continue
    }
    $paramMatch = [regex]::Match($part, '^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.+)$', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (!$paramMatch.Success) {
      throw "${Path}: could not parse parameter in ${fnName}: $part"
    }
    $name = $paramMatch.Groups[1].Value
    $type = $paramMatch.Groups[2].Value.Trim()
    if ($params.ContainsKey($name)) {
      throw "${Path}: duplicate parameter $name in $fnName"
    }
    $params[$name] = $type
  }

  $prefix = $Block.Substring(0, $externMatch.Index)
  $annotations = @{}
  $duplicateAnnotations = @{}
  [regex]::Matches($prefix, '#(borrow|owned)\(([^)]*)\)') | ForEach-Object {
    $kind = $_.Groups[1].Value
    foreach ($rawName in $_.Groups[2].Value.Split(",")) {
      $name = $rawName.Trim()
      if (!$name) {
        continue
      }
      if ($annotations.ContainsKey($name)) {
        $duplicateAnnotations[$name] = $true
      }
      $annotations[$name] = $kind
    }
  }
  if ($duplicateAnnotations.Count -gt 0) {
    throw "${Path}: duplicate FFI ownership annotation(s) in ${fnName}: $($duplicateAnnotations.Keys -join ', ')"
  }

  $paramNames = @{}
  foreach ($name in $params.Keys) {
    $paramNames[$name] = $true
  }
  $unknownAnnotations = @($annotations.Keys | Where-Object { !$paramNames.ContainsKey($_) } | Sort-Object)
  if ($unknownAnnotations.Count -gt 0) {
    throw "${Path}: ${fnName} annotates unknown parameter(s): $($unknownAnnotations -join ', ')"
  }

  $nonPrimitive = @{}
  $primitive = @{}
  foreach ($name in $params.Keys) {
    if (Test-NonPrimitiveType -Type $params[$name]) {
      $nonPrimitive[$name] = $true
    } else {
      $primitive[$name] = $true
    }
  }

  $missing = @($nonPrimitive.Keys | Where-Object { !$annotations.ContainsKey($_) } | Sort-Object)
  if ($missing.Count -gt 0) {
    throw "${Path}: ${fnName} is missing #borrow/#owned for non-primitive parameter(s): $($missing -join ', ')"
  }

  $unnecessary = @($primitive.Keys | Where-Object { $annotations.ContainsKey($_) } | Sort-Object)
  if ($unnecessary.Count -gt 0) {
    throw "${Path}: ${fnName} annotates primitive parameter(s): $($unnecessary -join ', ')"
  }
}

$resolvedNativeDir = Resolve-RepoPath $NativeDir
if (!(Test-Path -LiteralPath $resolvedNativeDir -PathType Container)) {
  throw "native package directory is missing: $resolvedNativeDir"
}

$files = @(Get-ChildItem -LiteralPath $resolvedNativeDir -Filter "*_native.mbt" -File | Sort-Object FullName)
if ($files.Count -eq 0) {
  throw "native package directory has no *_native.mbt files: $resolvedNativeDir"
}

foreach ($file in $files) {
  $text = Get-Content -LiteralPath $file.FullName -Raw
  foreach ($block in [regex]::Split($text, "(?m)^///\|")) {
    Test-ExternBlock -Block $block -Path $file.FullName
  }
}

Write-Host "Verified native FFI borrow annotations in $resolvedNativeDir"
