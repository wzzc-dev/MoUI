param(
  [string] $Manifest = "native/ownership.json",
  [string] $Header = "",
  [string] $Source = "",
  [string] $Handles = "",
  [string] $Types = ""
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

function Read-RequiredText {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path,
    [Parameter(Mandatory = $true)]
    [string] $Label
  )

  if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "$Label is missing: $Path"
  }
  return Get-Content -LiteralPath $Path -Raw
}

function Find-BracedBody {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Text,
    [Parameter(Mandatory = $true)]
    [string] $Pattern,
    [Parameter(Mandatory = $true)]
    [string] $Label
  )

  $match = [regex]::Match($Text, "$Pattern\s*\{", [System.Text.RegularExpressions.RegexOptions]::Singleline)
  if (!$match.Success) {
    throw "missing $Label"
  }

  $index = $match.Index + $match.Length
  $depth = 1
  while ($index -lt $Text.Length) {
    $char = $Text[$index]
    if ($char -eq "{") {
      $depth += 1
    } elseif ($char -eq "}") {
      $depth -= 1
      if ($depth -eq 0) {
        return $Text.Substring($match.Index + $match.Length, $index - ($match.Index + $match.Length))
      }
    }
    $index += 1
  }

  throw "unterminated $Label"
}

function Assert-Matches {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Text,
    [Parameter(Mandatory = $true)]
    [string] $Pattern,
    [Parameter(Mandatory = $true)]
    [string] $Message
  )

  if ($Text -notmatch $Pattern) {
    throw $Message
  }
}

function Assert-Contains {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Text,
    [Parameter(Mandatory = $true)]
    [string] $Needle,
    [Parameter(Mandatory = $true)]
    [string] $Message
  )

  if (!$Text.Contains($Needle)) {
    throw $Message
  }
}

function Assert-Unique {
  param(
    [Parameter(Mandatory = $true)]
    [array] $Entries,
    [Parameter(Mandatory = $true)]
    [string] $Key,
    [Parameter(Mandatory = $true)]
    [string] $Label
  )

  $seen = @{}
  foreach ($entry in $Entries) {
    $value = "$($entry.$Key)".Trim()
    if ([string]::IsNullOrWhiteSpace($value)) {
      throw "$Label entry is missing $Key"
    }
    if ($seen.ContainsKey($value)) {
      throw "duplicate $Label ${Key}: $value"
    }
    $seen[$value] = $true
  }
}

function Get-MoonBitTypeBody {
  param(
    [Parameter(Mandatory = $true)]
    [string] $TypeText,
    [Parameter(Mandatory = $true)]
    [string] $TypeName
  )

  return Find-BracedBody `
    -Text $TypeText `
    -Pattern "\bpub\(all\)\s+struct\s+$([regex]::Escape($TypeName))\s*" `
    -Label "MoonBit wrapper type $TypeName"
}

function Get-CStructBody {
  param(
    [Parameter(Mandatory = $true)]
    [string] $HeaderText,
    [Parameter(Mandatory = $true)]
    [string] $StructName
  )

  return Find-BracedBody `
    -Text $HeaderText `
    -Pattern "\bstruct\s+$([regex]::Escape($StructName))\s*" `
    -Label "C++ wrapper struct $StructName"
}

$resolvedManifest = Resolve-RepoPath $Manifest
$manifestText = Read-RequiredText -Path $resolvedManifest -Label "native ownership manifest"
$manifestData = $manifestText | ConvertFrom-Json

if ($manifestData.schema_version -ne 1) {
  throw "unsupported native ownership schema_version: $($manifestData.schema_version)"
}

$resolvedHeader = if ($Header) { Resolve-RepoPath $Header } else { Resolve-RepoPath $manifestData.native_header }
$resolvedSource = if ($Source) { Resolve-RepoPath $Source } else { Resolve-RepoPath $manifestData.native_source }
if ($Handles) {
  $resolvedHandleFiles = @(Resolve-RepoPath $Handles)
} elseif ($manifestData.moonbit_handle_files) {
  $resolvedHandleFiles = @($manifestData.moonbit_handle_files | ForEach-Object { Resolve-RepoPath $_ })
} else {
  $resolvedHandleFiles = @(Resolve-RepoPath $manifestData.moonbit_handle_file)
}
$resolvedTypes = if ($Types) { Resolve-RepoPath $Types } else { Resolve-RepoPath $manifestData.moonbit_type_file }

$headerText = Read-RequiredText -Path $resolvedHeader -Label "native ownership header"
$sourceText = Read-RequiredText -Path $resolvedSource -Label "native ownership source"
$typesText = Read-RequiredText -Path $resolvedTypes -Label "MoonBit native type file"

$externalWrappers = @($manifestData.external_wrappers)
if ($externalWrappers.Count -eq 0) {
  throw "native ownership manifest is missing external_wrappers"
}
$regularObjects = @($manifestData.regular_objects)
$allEntries = @($externalWrappers + $regularObjects)

foreach ($key in @("name", "moonbit_handle", "moonbit_type", "wrapper_struct")) {
  Assert-Unique -Entries $allEntries -Key $key -Label "native ownership"
}
Assert-Unique -Entries $externalWrappers -Key "factory" -Label "external wrapper"
Assert-Unique -Entries $externalWrappers -Key "finalizer" -Label "external wrapper"

$manifestHandles = @{}
foreach ($entry in $allEntries) {
  $manifestHandles[$entry.moonbit_handle] = $true
}
foreach ($resolvedHandles in $resolvedHandleFiles) {
  $handlesText = Read-RequiredText -Path $resolvedHandles -Label "MoonBit native handle file"
  $declaredHandles = @{}
  [regex]::Matches($handlesText, "\bpriv\s+type\s+([A-Za-z_][A-Za-z0-9_]*Handle)\b") | ForEach-Object {
    $declaredHandles[$_.Groups[1].Value] = $true
  }
  $missingHandles = @($manifestHandles.Keys | Where-Object { !$declaredHandles.ContainsKey($_) } | Sort-Object)
  if ($missingHandles.Count -gt 0) {
    throw "ownership manifest references missing MoonBit handles in ${resolvedHandles}: $($missingHandles -join ', ')"
  }
  $extraHandles = @($declaredHandles.Keys | Where-Object { !$manifestHandles.ContainsKey($_) } | Sort-Object)
  if ($extraHandles.Count -gt 0) {
    throw "MoonBit handles in ${resolvedHandles} are missing from ownership manifest: $($extraHandles -join ', ')"
  }
}

$foundFactoryPairs = @{}
[regex]::Matches(
  $sourceText,
  "\b(MoonbitSkia[A-Za-z0-9_]+)\s*\*\s*(moonbit_skia_make_[A-Za-z0-9_]+_wrapper)\s*\("
) | ForEach-Object {
  $foundFactoryPairs[$_.Groups[2].Value] = $true
}
$expectedFactories = @{}
foreach ($entry in $externalWrappers) {
  $expectedFactories[$entry.factory] = $true
}
$missingFactories = @($expectedFactories.Keys | Where-Object { !$foundFactoryPairs.ContainsKey($_) } | Sort-Object)
if ($missingFactories.Count -gt 0) {
  throw "ownership manifest references missing external wrapper factories: $($missingFactories -join ', ')"
}
$extraFactories = @($foundFactoryPairs.Keys | Where-Object { !$expectedFactories.ContainsKey($_) } | Sort-Object)
if ($extraFactories.Count -gt 0) {
  throw "external wrapper factories are missing from ownership manifest: $($extraFactories -join ', ')"
}

$foundFinalizers = @{}
[regex]::Matches($sourceText, "\bstatic\s+void\s+(moonbit_skia_[A-Za-z0-9_]+_finalize)\s*\(") | ForEach-Object {
  $foundFinalizers[$_.Groups[1].Value] = $true
}
$expectedFinalizers = @{}
foreach ($entry in $externalWrappers) {
  $expectedFinalizers[$entry.finalizer] = $true
}
$missingFinalizers = @($expectedFinalizers.Keys | Where-Object { !$foundFinalizers.ContainsKey($_) } | Sort-Object)
if ($missingFinalizers.Count -gt 0) {
  throw "ownership manifest references missing finalizers: $($missingFinalizers -join ', ')"
}
$extraFinalizers = @($foundFinalizers.Keys | Where-Object { !$expectedFinalizers.ContainsKey($_) } | Sort-Object)
if ($extraFinalizers.Count -gt 0) {
  throw "native finalizers are missing from ownership manifest: $($extraFinalizers -join ', ')"
}

$allowedOwnership = @("owned_delete", "sk_refcnt", "borrowed_with_refcnt_owner")

foreach ($entry in $externalWrappers) {
  $name = $entry.name
  $handle = $entry.moonbit_handle
  $typeName = $entry.moonbit_type
  $structName = $entry.wrapper_struct
  $field = $entry.field
  $factory = $entry.factory
  $finalizer = $entry.finalizer
  $ownership = $entry.ownership

  if ($ownership -notin $allowedOwnership) {
    throw "$name has unsupported ownership kind: $ownership"
  }

  $typeBody = Get-MoonBitTypeBody -TypeText $typesText -TypeName $typeName
  Assert-Matches `
    -Text $typeBody `
    -Pattern "\bpriv\s+handle\s*:\s*$([regex]::Escape($handle))\b" `
    -Message "$typeName does not store $handle"
  if ($ownership -eq "borrowed_with_refcnt_owner") {
    if (!$entry.moonbit_owner_field -or !$entry.owner_type) {
      throw "$name borrowed owner contract is missing moonbit_owner_field/owner_type"
    }
    Assert-Matches `
      -Text $typeBody `
      -Pattern "\bpriv\s+$([regex]::Escape($entry.moonbit_owner_field))\s*:\s*$([regex]::Escape($entry.owner_type))\?" `
      -Message "$typeName does not retain optional owner $($entry.moonbit_owner_field): $($entry.owner_type)?"
  }

  $cBody = Get-CStructBody -HeaderText $headerText -StructName $structName
  Assert-Matches `
    -Text $cBody `
    -Pattern "\b$([regex]::Escape($field))\s*;" `
    -Message "$structName is missing field $field"
  if ($ownership -eq "borrowed_with_refcnt_owner") {
    if (!$entry.owner_field) {
      throw "$name borrowed owner contract is missing owner_field"
    }
    Assert-Matches `
      -Text $cBody `
      -Pattern "\b$([regex]::Escape($entry.owner_field))\s*;" `
      -Message "$structName is missing owner field $($entry.owner_field)"
  }

  $factoryBody = Find-BracedBody `
    -Text $sourceText `
    -Pattern "\b$([regex]::Escape($factory))\b[^{}]*" `
    -Label "factory $factory"
  Assert-Contains -Text $factoryBody -Needle "moonbit_make_external_object" -Message "$factory must allocate a MoonBit external object"
  Assert-Contains -Text $factoryBody -Needle $finalizer -Message "$factory does not register finalizer $finalizer"
  Assert-Contains -Text $factoryBody -Needle "sizeof($structName)" -Message "$factory does not allocate sizeof($structName)"
  Assert-Matches `
    -Text $factoryBody `
    -Pattern "wrapper->$([regex]::Escape($field))\s*=" `
    -Message "$factory does not initialize $field"

  $finalizerBody = Find-BracedBody `
    -Text $sourceText `
    -Pattern "\bstatic\s+void\s+$([regex]::Escape($finalizer))\s*\([^)]*\)" `
    -Label "finalizer $finalizer"
  Assert-Contains -Text $finalizerBody -Needle "static_cast<$structName*>" -Message "$finalizer does not cast to $structName"
  Assert-Matches `
    -Text $finalizerBody `
    -Pattern "wrapper->$([regex]::Escape($field))\s*=\s*nullptr\s*;" `
    -Message "$finalizer does not clear $field"

  if ($ownership -eq "owned_delete") {
    Assert-Contains -Text $finalizerBody -Needle "delete wrapper->$field;" -Message "$finalizer must delete owned $field"
  } elseif ($ownership -eq "sk_refcnt") {
    Assert-Contains -Text $finalizerBody -Needle "wrapper->$field->unref();" -Message "$finalizer must unref $field"
  } elseif ($ownership -eq "borrowed_with_refcnt_owner") {
    $ownerField = $entry.owner_field
    Assert-Contains -Text $factoryBody -Needle "wrapper->$ownerField->ref();" -Message "$factory must ref owner field $ownerField"
    Assert-Contains -Text $finalizerBody -Needle "wrapper->$ownerField->unref();" -Message "$finalizer must unref owner field $ownerField"
    Assert-Matches `
      -Text $finalizerBody `
      -Pattern "wrapper->$([regex]::Escape($ownerField))\s*=\s*nullptr\s*;" `
      -Message "$finalizer does not clear owner field $ownerField"
    if ($finalizerBody -match "\bdelete\s+wrapper->$([regex]::Escape($field))\s*;") {
      throw "$finalizer must not delete borrowed field $field"
    }
  }
}

foreach ($entry in $regularObjects) {
  $name = $entry.name
  $handle = $entry.moonbit_handle
  $typeName = $entry.moonbit_type
  $structName = $entry.wrapper_struct
  $factory = $entry.factory
  if ($entry.allocation -ne "moonbit_malloc") {
    throw "$name regular object uses unsupported allocation: $($entry.allocation)"
  }
  $pointerFieldCount = [int] $entry.pointer_field_count
  if ($null -eq $entry.pointer_field_count -or $pointerFieldCount -lt 0) {
    throw "$name regular object is missing non-negative pointer_field_count"
  }
  if ($null -eq $entry.pointer_fields) {
    throw "$name regular object is missing pointer_fields list"
  }
  $pointerFields = @($entry.pointer_fields)
  foreach ($pointerField in $pointerFields) {
    if (-not ($pointerField -is [string]) -or [string]::IsNullOrWhiteSpace($pointerField)) {
      throw "$name regular object is missing pointer_fields list"
    }
  }
  if ($pointerFields.Count -ne $pointerFieldCount) {
    throw "$name regular object pointer_fields length does not match pointer_field_count=$pointerFieldCount"
  }

  $typeBody = Get-MoonBitTypeBody -TypeText $typesText -TypeName $typeName
  Assert-Matches `
    -Text $typeBody `
    -Pattern "\bpriv\s+handle\s*:\s*$([regex]::Escape($handle))\b" `
    -Message "$typeName does not store $handle"
  $cBody = Get-CStructBody -HeaderText $headerText -StructName $structName
  $actualPointerFields = @(
    [regex]::Matches($cBody, "\*\s+([A-Za-z_][A-Za-z0-9_]*)\s*;") |
      ForEach-Object { $_.Groups[1].Value }
  )
  $actualPointerFieldCount = $actualPointerFields.Count
  if ($actualPointerFieldCount -ne $pointerFieldCount) {
    throw "$name regular object pointer_field_count mismatch: manifest=$pointerFieldCount struct=$actualPointerFieldCount"
  }
  if (($actualPointerFields -join ",") -ne ($pointerFields -join ",")) {
    throw "$name regular object pointer_fields mismatch: manifest=$($pointerFields -join ',') struct=$($actualPointerFields -join ',')"
  }
  $factoryBody = Find-BracedBody `
    -Text $sourceText `
    -Pattern "\b$([regex]::Escape($factory))\b[^{}]*" `
    -Label "regular object factory $factory"
  Assert-Contains -Text $factoryBody -Needle "moonbit_malloc" -Message "$factory must use moonbit_malloc"
  Assert-Contains `
    -Text $factoryBody `
    -Needle "moonbit_skia_regular_object_header" `
    -Message "$factory must initialize a regular object header"
  Assert-Matches `
    -Text $factoryBody `
    -Pattern "moonbit_skia_regular_object_header\s*\([^;]*,\s*$pointerFieldCount\s*,\s*0\s*\)" `
    -Message "$factory must encode pointer_field_count=$pointerFieldCount in its object header"
  if ($pointerFieldCount -gt 0) {
    $firstPointerField = $pointerFields[0]
    Assert-Contains `
      -Text $factoryBody `
      -Needle "offsetof($structName, $firstPointerField)" `
      -Message "$factory must encode pointer-field offset with offsetof($structName, $firstPointerField)"
  }
  foreach ($pointerField in $pointerFields) {
    Assert-Matches `
      -Text $factoryBody `
      -Pattern "\b[A-Za-z_][A-Za-z0-9_]*->$([regex]::Escape($pointerField))\s*=" `
      -Message "$factory must initialize pointer field $pointerField"
  }
  if ($factoryBody.Contains("moonbit_make_external_object")) {
    throw "$factory must not allocate a MoonBit external object"
  }
}

Write-Host "Verified native ownership manifest: $resolvedManifest"
