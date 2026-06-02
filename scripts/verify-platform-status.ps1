param(
  [string] $StatusFile = "skia-platform-status.json",
  [string] $RevisionFile = "skia-revision.txt",
  [string] $ProviderLock = "skia-provider-lock.json",
  [string] $StatusDoc = "SKIA_PLATFORM_STATUS.md"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$statusDocExplicit = $PSBoundParameters.ContainsKey("StatusDoc")

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

$resolvedStatusFile = Resolve-RepoPath $StatusFile
$resolvedRevisionFile = Resolve-RepoPath $RevisionFile
$resolvedProviderLock = Resolve-RepoPath $ProviderLock
$resolvedStatusDoc = Resolve-RepoPath $StatusDoc

if (!(Test-Path -LiteralPath $resolvedStatusFile -PathType Leaf)) {
  throw "Skia platform status file is missing: $resolvedStatusFile"
}

if (!(Test-Path -LiteralPath $resolvedRevisionFile -PathType Leaf)) {
  throw "Skia revision file is missing: $resolvedRevisionFile"
}

$status = Get-Content -LiteralPath $resolvedStatusFile -Raw | ConvertFrom-Json
$revision = (Get-Content -LiteralPath $resolvedRevisionFile | Where-Object {
    $line = $_.Trim()
    $line -ne "" -and !$line.StartsWith("#")
  } | Select-Object -First 1).Trim()

$providerLockData = $null
if (Test-Path -LiteralPath $resolvedProviderLock -PathType Leaf) {
  $providerLockData = Get-Content -LiteralPath $resolvedProviderLock -Raw | ConvertFrom-Json
}
$jetbrainsCommit = ""
$jetbrainsTag = ""
if ($providerLockData -and $providerLockData.providers.jetbrains) {
  $jetbrainsCommit = $providerLockData.providers.jetbrains.commit.ToLowerInvariant()
  $jetbrainsTag = $providerLockData.providers.jetbrains.tag
}

if ($status.schema_version -notin @(1, 2, 3, 4)) {
  throw "unsupported Skia platform status schema_version: $($status.schema_version)"
}

if ($status.schema_version -ge 4) {
  $gates = @($status.ci_gates)
  if ($gates.Count -eq 0) {
    throw "schema v4 platform status is missing ci_gates list"
  }

  $requiredGateIds = @(
    "moonbit.fmt-check",
    "moonbit.check-test",
    "moonbit.all-target-check",
    "native.smoke-build",
    "native.smoke-capability-sync",
    "native.capability-contract",
    "native.ownership",
    "native.ffi-borrows",
    "native.fallback-parity",
    "platform.status",
    "artifact.native-smoke-log",
    "artifact.real-skia"
  )
  $seenGateIds = @{}
  $seenGateCommands = @{}
  $seenGateAreas = @{}

  if ($null -eq $status.ci_gate_evidence_files) {
    throw "schema v4 platform status is missing ci_gate_evidence_files list"
  }
  $evidenceFiles = @($status.ci_gate_evidence_files)
  if ($evidenceFiles.Count -eq 0) {
    throw "schema v4 platform status is missing ci_gate_evidence_files list"
  }
  $requiredEvidenceFiles = @(
    ".github/workflows/fallback.yml",
    ".github/workflows/linux-real-skia-smoke.yml",
    ".github/workflows/macos-real-skia-smoke.yml",
    ".github/workflows/windows-real-skia-smoke.yml",
    ".github/workflows/real-skia-acceptance.yml",
    "scripts/check-fallback.ps1"
  )
  $seenEvidenceFiles = @{}
  $evidenceParts = @()

  function Normalize-RepoRelativePath {
    param(
      [Parameter(Mandatory = $true)]
      [string] $Path
    )

    $normalized = $Path.Trim().Replace("\", "/")
    while ($normalized.StartsWith("./")) {
      $normalized = $normalized.Substring(2)
    }
    if ([string]::IsNullOrWhiteSpace($normalized)) {
      throw "CI gate evidence file is missing path"
    }
    $pathParts = @($normalized -split "/" | Where-Object { $_ -ne "" })
    if ([System.IO.Path]::IsPathRooted($normalized) -or ($pathParts -contains "..")) {
      throw "CI gate evidence file must be repo-relative: $Path"
    }
    return $normalized
  }

  foreach ($evidenceFile in $evidenceFiles) {
    $evidencePath = Normalize-RepoRelativePath "$evidenceFile"
    if ($seenEvidenceFiles.ContainsKey($evidencePath)) {
      throw "duplicate CI gate evidence file: $evidencePath"
    }
    $resolvedEvidencePath = Join-Path $repoRoot $evidencePath
    if (!(Test-Path -LiteralPath $resolvedEvidencePath -PathType Leaf)) {
      throw "CI gate evidence file is missing: $evidencePath"
    }
    $seenEvidenceFiles[$evidencePath] = $true
    $evidenceParts += (Get-Content -LiteralPath $resolvedEvidencePath -Raw)
  }

  $missingEvidenceFiles = @($requiredEvidenceFiles | Where-Object { !$seenEvidenceFiles.ContainsKey($_) })
  if ($missingEvidenceFiles.Count -gt 0) {
    throw "CI gate evidence is missing files: $($missingEvidenceFiles -join ', ')"
  }

  $evidenceCorpus = ($evidenceParts -join "`n").Replace("\", "/")
  $evidenceCompact = $evidenceCorpus -replace "\s+", " "

  function Get-CiGateScriptPaths {
    param(
      [string] $Command
    )

    $normalized = $Command.Replace("\", "/")
    foreach ($token in ($normalized -split "[\s;&|]+")) {
      $scriptPath = $token.Trim().Trim("'", '"')
      while ($scriptPath.StartsWith("./")) {
        $scriptPath = $scriptPath.Substring(2)
      }
      if ($scriptPath.StartsWith("scripts/") -and ($scriptPath.EndsWith(".sh") -or $scriptPath.EndsWith(".ps1"))) {
        $scriptPath
      }
    }
  }

  function Get-CiGateEvidenceTerms {
    param(
      [string] $Command
    )

    $scriptPaths = @(Get-CiGateScriptPaths $Command)
    if ($scriptPaths.Count -gt 0) {
      $terms = @($scriptPaths)
      $normalized = $Command.Replace("\", "/")
      foreach ($token in ($normalized -split "[\s;&|]+")) {
        $option = $token.Trim().Trim("'", '"')
        if ($option.StartsWith("-") -and $option -ne "-n") {
          $terms += $option
        }
      }
      return $terms
    }
    $terms = @()
    $normalized = $Command.Replace("\", "/")
    foreach ($part in ($normalized -split "\s*(?:&&|;|\|\|?|\n)\s*")) {
      $term = ($part.Trim() -replace "\s+", " ")
      if (![string]::IsNullOrWhiteSpace($term)) {
        $terms += $term
      }
    }
    return $terms
  }

  foreach ($gate in $gates) {
    $gateId = "$($gate.id)".Trim()
    $area = "$($gate.area)".Trim()
    $unixCommand = "$($gate.unix_command)".Trim()
    $powershellCommand = "$($gate.powershell_command)".Trim()
    if ([string]::IsNullOrWhiteSpace($gateId)) {
      throw "CI gate is missing id"
    }
    if ([string]::IsNullOrWhiteSpace($area)) {
      throw "CI gate is missing area: $gateId"
    }
    if ([string]::IsNullOrWhiteSpace($unixCommand) -and [string]::IsNullOrWhiteSpace($powershellCommand)) {
      throw "CI gate is missing verifier command: $gateId"
    }
    if ($seenGateIds.ContainsKey($gateId)) {
      throw "duplicate CI gate id: $gateId"
    }
    foreach ($command in @($unixCommand, $powershellCommand)) {
      if (![string]::IsNullOrWhiteSpace($command)) {
        $commandKey = "$area`n$command"
        if ($seenGateCommands.ContainsKey($commandKey)) {
          throw "duplicate CI gate command: $command"
        }
        $seenGateCommands[$commandKey] = $true
        foreach ($scriptPath in Get-CiGateScriptPaths $command) {
          $resolvedScriptPath = Join-Path $repoRoot $scriptPath
          if (!(Test-Path -LiteralPath $resolvedScriptPath -PathType Leaf)) {
            throw "CI gate references missing verifier script: ${gateId}: $scriptPath"
          }
        }
        foreach ($evidenceTerm in Get-CiGateEvidenceTerms $command) {
          if (!$evidenceCorpus.Contains($evidenceTerm) -and !$evidenceCompact.Contains($evidenceTerm)) {
            throw "CI gate evidence is missing command wiring: ${gateId}: $evidenceTerm"
          }
        }
      }
    }
    $seenGateIds[$gateId] = $true
    $seenGateAreas[$area] = $true
  }
  $missingGateIds = @($requiredGateIds | Where-Object { !$seenGateIds.ContainsKey($_) })
  if ($missingGateIds.Count -gt 0) {
    throw "CI gate coverage is missing ids: $($missingGateIds -join ', ')"
  }
  $requiredGateAreas = @("MoonBit", "NativeSmoke", "FFI", "PlatformStatus", "Artifact")
  $missingGateAreas = @($requiredGateAreas | Where-Object { !$seenGateAreas.ContainsKey($_) })
  if ($missingGateAreas.Count -gt 0) {
    throw "CI gate coverage is missing areas: $($missingGateAreas -join ', ')"
  }
}

if ($status.schema_version -ge 3) {
  $capabilities = @($status.native_smoke_capabilities)
  if ($capabilities.Count -eq 0) {
    throw "schema v3 platform status is missing native_smoke_capabilities list"
  }

  $requiredCapabilityIds = @(
    "surface.descriptor",
    "surface.target-factory-raster",
    "surface.target-factory-unsupported",
    "canvas.state",
    "canvas.clip",
    "canvas.non-finite-direct-geometry-skipped",
    "canvas.non-finite-paint-layer-sanitized",
    "canvas.image-sampling-scalars-sanitized",
    "canvas.command-replay",
    "canvas.replay-status-contract",
    "canvas.replay-deferred-present",
    "canvas.replay-transforms",
    "canvas.empty-path-replay-cache-resources",
    "canvas.empty-path-replay-path-resources",
    "canvas.empty-path-replay-cache-misses",
    "canvas.empty-path-replay-cache-hits",
    "canvas.non-finite-path-replay-skipped",
    "canvas.non-finite-path-replay-path-resources",
    "canvas.non-finite-path-replay-cache-resources",
    "canvas.non-finite-path-replay-cache-misses",
    "canvas.non-finite-path-replay-cache-hits",
    "pipeline.shaped-glyph-run-command",
    "pipeline.shader-cache-resources",
    "pipeline.shader-cache-misses",
    "pipeline.shader-cache-hits",
    "pipeline.path-cache-resources",
    "pipeline.path-cache-misses",
    "pipeline.path-cache-hits",
    "pipeline.text-run-cache-resources",
    "pipeline.text-run-cache-misses",
    "pipeline.text-run-cache-hits",
    "pipeline.font-cache-resources",
    "pipeline.font-cache-misses",
    "pipeline.font-cache-hits",
    "pipeline.color-filter-cache-resources",
    "pipeline.color-filter-cache-misses",
    "pipeline.color-filter-cache-hits",
    "pipeline.image-filter-cache-resources",
    "pipeline.image-filter-cache-misses",
    "pipeline.image-filter-cache-hits",
    "pipeline.mask-filter-cache-resources",
    "pipeline.mask-filter-cache-misses",
    "pipeline.mask-filter-cache-hits",
    "pipeline.resource-plan",
    "pipeline.frame-resource-plan",
    "pipeline.frame-validation",
    "pipeline.frame-cacheable-subplan",
    "pipeline.frame-uncacheable-subplan",
    "pipeline.frame-unbalanced-validation",
    "pipeline.target-identity-validation",
    "pipeline.target-resource-binding",
    "pipeline.frame-present",
    "pipeline.frame-submission-resource-plan",
    "pipeline.frame-submission-cacheable-subplan",
    "pipeline.frame-submission-uncacheable-subplan",
    "pipeline.frame-submission-preflight-missing",
    "pipeline.frame-submission-preflight-cached",
    "pipeline.frame-submission-cache-resources",
    "pipeline.frame-finalization-resource-plan",
    "pipeline.frame-finalization-cacheable-subplan",
    "pipeline.frame-finalization-uncacheable-subplan",
    "pipeline.frame-finalization-preflight-missing",
    "pipeline.frame-finalization-preflight-cached",
    "pipeline.frame-finalization-cache-resources",
    "pipeline.frame-missing-present-validation",
    "pipeline.frame-missing-finalization-validation",
    "pipeline.frame-touched-bounds",
    "pipeline.frame-cache-resources",
    "pipeline.native-replay-resource-stats-caches",
    "pipeline.native-replay-resource-stats-resources",
    "pipeline.resource-cache",
    "pipeline.resource-cache-preflight-missing",
    "pipeline.resource-cache-preflight-cached",
    "pipeline.resource-cache-plan-coverage",
    "pipeline.resource-cache-eviction",
    "pipeline.resource-cache-hits",
    "pipeline.resource-cache-misses",
    "pipeline.resource-cache-byte-size",
    "gpu.context-resource-plan",
    "gpu.context-key-variation",
    "gpu.frame-context-validation",
    "gpu.present-resource-plan",
    "gpu.finalization-resource-plan",
    "gpu.frame-finalization-resource-plan",
    "gpu.frame-finalization-gpu-resources",
    "gpu.frame-submission-resource-plan",
    "gpu.frame-submission-gpu-resources",
    "surface.target-resource-plan",
    "surface.target-cache-resources",
    "surface.window-target-resource-plan",
    "surface.window-physical-width",
    "surface.window-frame-pacing",
    "surface.window-present-mode-key",
    "surface.finalization-resource-plan",
    "surface.finalization-key",
    "surface.flush-and-submit",
    "shader.draw",
    "shader.resource-plan",
    "shader.linear-gradient-validation",
    "shader.linear-gradient-finite-validation",
    "shader.radial-gradient-validation",
    "shader-filter.invalid-descriptor-resources",
    "shader-filter.invalid-replay-skipped",
    "shader-filter.invalid-replay-cache-resources",
    "shader-filter.invalid-replay-cache-misses",
    "shader-filter.invalid-replay-filter-resources",
    "filter.layer",
    "filter.finite-validation",
    "filter.non-finite-handle-validation",
    "filter.resource-plan",
    "path.geometry",
    "path.non-finite-from-value-rejected",
    "path.non-finite-add-skipped",
    "path.non-finite-direct-mutations-skipped",
    "surface.readback",
    "surface.readback-height",
    "surface.readback-row-bytes",
    "surface.bounded-readback",
    "surface.bounded-readback-height",
    "surface.bounded-snapshot",
    "surface.bounded-snapshot-height",
    "surface.bounds-rejected",
    "image.encode-png",
    "image.encode-parameters-sanitized",
    "image.decode",
    "image.decode-height",
    "image.render-command-replay",
    "image.render-command-count",
    "image.render-command-resource-plan",
    "image.render-command-cache-resources",
    "image.render-command-cache-misses",
    "image.render-command-cache-hits",
    "image.empty-descriptor-command-plan",
    "image.empty-descriptor-replay-skipped",
    "image.empty-descriptor-cache-misses",
    "codec.metadata",
    "codec.width",
    "codec.height",
    "bitmap.decode-readback",
    "bitmap.decode-readback-height",
    "text.font-spacing",
    "text.non-finite-font-scalars-sanitized",
    "text.font-resource-plan",
    "text.text-run-resource-plan",
    "text.text-run-range",
    "text.text-run-empty-range-resource-plan",
    "text.text-run-empty-range-skipped",
    "text.text-run-empty-range-cache-resources",
    "text.measured-run-resource-plan",
    "text.measured-run-key",
    "text.invalid-measured-run-resource-plan",
    "text.invalid-measured-run-uncacheable",
    "text.shaped-glyph-run-resource-plan",
    "text.shaped-glyph-run-key",
    "text.invalid-shaped-glyph-resource-plan",
    "text.invalid-shaped-glyph-command-plan",
    "text.invalid-shaped-glyph-replay-skipped",
    "text.measure",
    "text.glyph-count",
    "text.glyph-id",
    "text.glyph-width",
    "text.glyph-position",
    "text.glyph-x-position",
    "text.glyph-bounds",
    "text.bounds",
    "text.shaper-availability",
    "text.default-typeface-availability",
    "fontmgr.family-count",
    "fontmgr.family-name",
    "fontmgr.typeface-family",
    "fontmgr.character-fallback",
    "fontmgr.invalid-fallback-request-resource-plan",
    "fontmgr.fallback-key",
    "fontmgr.fallback-family-name",
    "fontmgr.fallback-match-key",
    "fontmgr.fallback-match-resource-plan",
    "fontmgr.fallback-resolution-key",
    "fontmgr.fallback-resolution-resource-plan",
    "fontmgr.invalid-fallback-match-resource-plan",
    "fontmgr.invalid-fallback-resolution-resource-plan",
    "fontmgr.fallback-resolution-bridge",
    "fontmgr.fallback-resolution-bridge-cache-resources",
    "fontmgr.fallback-resource-plan",
    "fontmgr.fallback-font-resource-plan"
  )
  $seenIds = @{}
  $seenMarkers = @{}
  $seenAreas = @{}
  foreach ($capability in $capabilities) {
    $capabilityId = "$($capability.id)".Trim()
    $area = "$($capability.area)".Trim()
    $marker = "$($capability.marker)".Trim()
    if ([string]::IsNullOrWhiteSpace($capabilityId)) {
      throw "native smoke capability is missing id"
    }
    if ([string]::IsNullOrWhiteSpace($area)) {
      throw "native smoke capability is missing area: $capabilityId"
    }
    if ([string]::IsNullOrWhiteSpace($marker)) {
      throw "native smoke capability is missing marker: $capabilityId"
    }
    if ($seenIds.ContainsKey($capabilityId)) {
      throw "duplicate native smoke capability id: $capabilityId"
    }
    if ($seenMarkers.ContainsKey($marker)) {
      throw "duplicate native smoke capability marker: $marker"
    }
    $seenIds[$capabilityId] = $true
    $seenMarkers[$marker] = $true
    $seenAreas[$area] = $true
  }
  $missingIds = @($requiredCapabilityIds | Where-Object { !$seenIds.ContainsKey($_) })
  if ($missingIds.Count -gt 0) {
    throw "native smoke capability coverage is missing ids: $($missingIds -join ', ')"
  }
  $requiredAreas = @(
    "Surface",
    "Canvas",
    "Pipeline",
    "GPU",
    "Shader",
    "Filter",
    "Path",
    "Image",
    "Codec",
    "Bitmap",
    "Text",
    "FontMgr"
  )
  $missingAreas = @($requiredAreas | Where-Object { !$seenAreas.ContainsKey($_) })
  if ($missingAreas.Count -gt 0) {
    throw "native smoke capability coverage is missing areas: $($missingAreas -join ', ')"
  }
  if ($status.schema_version -ge 4) {
    $conditionalCapabilities = @()
    if ($null -ne $status.native_smoke_conditional_capabilities) {
      $conditionalCapabilities = @($status.native_smoke_conditional_capabilities)
    }
    if ($conditionalCapabilities.Count -eq 0) {
      throw "schema v4 platform status is missing native_smoke_conditional_capabilities list"
    }
    $requiredConditionalCapabilities = @{
      "text.shaped-glyph-count" = @{
        Area = "Text"
        Marker = "native smoke shaped glyph count"
        WhenMarker = "native smoke shaper availability"
        WhenValue = "1"
      }
      "text.native-shaped-glyph-run-resource-plan" = @{
        Area = "Text"
        Marker = "native smoke shaped glyph run native resource plan count"
        WhenMarker = "native smoke shaper availability"
        WhenValue = "1"
      }
      "text.shaped-glyph-descriptor-bridge" = @{
        Area = "Text"
        Marker = "native smoke shaped glyph descriptor bridge"
        WhenMarker = "native smoke shaper availability"
        WhenValue = "1"
      }
      "text.shaped-glyph-descriptor-bridge-cache-resources" = @{
        Area = "Text"
        Marker = "native smoke shaped glyph descriptor bridge cache resources"
        WhenMarker = "native smoke shaper availability"
        WhenValue = "1"
      }
    }
    $seenConditionalIds = @{}
    $seenConditionalMarkers = @{}
    foreach ($conditional in $conditionalCapabilities) {
      $conditionalId = "$($conditional.id)".Trim()
      $area = "$($conditional.area)".Trim()
      $marker = "$($conditional.marker)".Trim()
      $whenMarker = "$($conditional.when_marker)".Trim()
      $whenValue = "$($conditional.when_value)".Trim()
      if ([string]::IsNullOrWhiteSpace($conditionalId)) {
        throw "native smoke conditional capability is missing id"
      }
      if ([string]::IsNullOrWhiteSpace($area)) {
        throw "native smoke conditional capability is missing area: $conditionalId"
      }
      if ([string]::IsNullOrWhiteSpace($marker)) {
        throw "native smoke conditional capability is missing marker: $conditionalId"
      }
      if ([string]::IsNullOrWhiteSpace($whenMarker)) {
        throw "native smoke conditional capability is missing when_marker: $conditionalId"
      }
      if ([string]::IsNullOrWhiteSpace($whenValue)) {
        throw "native smoke conditional capability is missing when_value: $conditionalId"
      }
      if ($seenConditionalIds.ContainsKey($conditionalId)) {
        throw "duplicate native smoke conditional capability id: $conditionalId"
      }
      if ($seenMarkers.ContainsKey($marker) -or $seenConditionalMarkers.ContainsKey($marker)) {
        throw "duplicate native smoke conditional capability marker: $marker"
      }
      if (!$seenMarkers.ContainsKey($whenMarker)) {
        throw "native smoke conditional capability references unknown condition marker: ${conditionalId}: $whenMarker"
      }
      if ($requiredConditionalCapabilities.ContainsKey($conditionalId)) {
        $required = $requiredConditionalCapabilities[$conditionalId]
        if ($area -ne $required.Area) {
          throw "native smoke conditional capability mismatch: ${conditionalId}: area"
        }
        if ($marker -ne $required.Marker) {
          throw "native smoke conditional capability mismatch: ${conditionalId}: marker"
        }
        if ($whenMarker -ne $required.WhenMarker) {
          throw "native smoke conditional capability mismatch: ${conditionalId}: when_marker"
        }
        if ($whenValue -ne $required.WhenValue) {
          throw "native smoke conditional capability mismatch: ${conditionalId}: when_value"
        }
      }
      $seenConditionalIds[$conditionalId] = $true
      $seenConditionalMarkers[$marker] = $true
    }
    $missingConditionalIds = @($requiredConditionalCapabilities.Keys | Where-Object { !$seenConditionalIds.ContainsKey($_) })
    if ($missingConditionalIds.Count -gt 0) {
      throw "native smoke conditional capability coverage is missing ids: $($missingConditionalIds -join ', ')"
    }

    $expectedValues = @($status.native_smoke_expected_values)
    if ($expectedValues.Count -eq 0) {
      throw "schema v4 platform status is missing native_smoke_expected_values list"
    }
    $requiredExpectedValues = @{
      "native smoke canvas clip device width" = "4"
      "native smoke canvas state restored" = "1"
      "native smoke non-finite canvas direct geometry skipped" = "1"
      "native smoke non-finite canvas paint layer sanitized" = "1"
      "native smoke image sampling scalars sanitized" = "1"
      "native smoke canvas replay commands" = "29"
      "native smoke render frame replay commands" = "29"
      "native smoke render frame replay complete" = "1"
      "native smoke canvas replay status contract" = "3"
      "native smoke canvas replay deferred present" = "1"
      "native smoke canvas replay transforms" = "6"
      "native smoke canvas replay state stats" = "4"
      "native smoke canvas replay resource declarations" = "4"
      "native smoke canvas replay image resources" = "0"
      "native smoke canvas replay shader resources" = "4"
      "native smoke canvas replay filter resources" = "6"
      "native smoke canvas replay path resources" = "2"
      "native smoke canvas replay text resources" = "9"
      "native smoke canvas replay rrect path clips" = "2"
      "native smoke canvas replay clip path cache resources" = "1"
      "native smoke empty path replay path cache resources" = "0"
      "native smoke empty path replay path resources" = "3"
      "native smoke empty path replay path cache misses" = "0"
      "native smoke empty path replay path cache hits" = "0"
      "native smoke non-finite path replay skipped" = "2"
      "native smoke non-finite path replay path resources" = "2"
      "native smoke non-finite path replay path cache resources" = "0"
      "native smoke non-finite path replay path cache misses" = "0"
      "native smoke non-finite path replay path cache hits" = "0"
      "native smoke canvas replay color paint fills" = "2"
      "native smoke canvas replay paint fill clipped" = "1"
      "native smoke canvas replay paint shader fills" = "1"
      "native smoke canvas replay paint shader cache resources" = "1"
      "native smoke render frame replay rejected skipped" = "26"
      "native smoke surface render frame commands" = "29"
      "native smoke surface render frame finalized" = "1"
      "native smoke surface render frame finalization frame index" = "7"
      "native smoke surface render frame finalization resource plan count" = "16"
      "native smoke surface render frame finalization cacheable count" = "15"
      "native smoke surface render frame finalization uncacheable count" = "1"
      "native smoke surface render frame cache resources" = "9"
      "native smoke native replay resource stats caches" = "9"
      "native smoke native replay resource stats resources" = "9"
      "native smoke surface render frame mismatch rejected" = "1"
      "native smoke render shaped glyph run command replay" = "1"
      "native smoke render shader cache resources" = "1"
      "native smoke render shader cache misses" = "1"
      "native smoke render shader cache hits" = "2"
      "native smoke render path cache resources" = "2"
      "native smoke render path cache misses" = "2"
      "native smoke render path cache hits" = "0"
      "native smoke render text run cache resources" = "1"
      "native smoke render text run cache misses" = "1"
      "native smoke render text run cache hits" = "0"
      "native smoke render font cache resources" = "1"
      "native smoke render font cache misses" = "1"
      "native smoke render font cache hits" = "0"
      "native smoke render typeface cache resources" = "1"
      "native smoke render typeface cache misses" = "1"
      "native smoke render typeface cache hits" = "0"
      "native smoke render color filter cache resources" = "1"
      "native smoke render color filter cache misses" = "1"
      "native smoke render color filter cache hits" = "0"
      "native smoke render image filter cache resources" = "1"
      "native smoke render image filter cache misses" = "1"
      "native smoke render image filter cache hits" = "0"
      "native smoke render mask filter cache resources" = "1"
      "native smoke render mask filter cache misses" = "1"
      "native smoke render mask filter cache hits" = "0"
      "native smoke render resource plan count" = "15"
      "native smoke render frame resource plan count" = "15"
      "native smoke render frame validation status" = "1"
      "native smoke render frame cacheable subplan count" = "15"
      "native smoke render frame uncacheable subplan count" = "0"
      "native smoke render frame unbalanced validation" = "1"
      "native smoke render target identity validation" = "1"
      "native smoke render target resource binding" = "1"
      "native smoke render frame present count" = "1"
      "native smoke render frame submission resource plan count" = "2"
      "native smoke render frame submission cacheable subplan count" = "1"
      "native smoke render frame submission uncacheable subplan count" = "1"
      "native smoke render frame submission preflight missing count" = "1"
      "native smoke render frame submission preflight cached count" = "1"
      "native smoke render frame submission cache resources" = "1"
      "native smoke render frame finalization resource plan count" = "2"
      "native smoke render frame finalization cacheable subplan count" = "1"
      "native smoke render frame finalization uncacheable subplan count" = "1"
      "native smoke render frame finalization preflight missing count" = "1"
      "native smoke render frame finalization preflight cached count" = "1"
      "native smoke render frame finalization cache resources" = "1"
      "native smoke render frame missing present validation" = "1"
      "native smoke render frame missing finalization validation" = "1"
      "native smoke render frame touched bounds width" = "4"
      "native smoke render frame cache resources" = "15"
      "native smoke render resource cache inserts" = "15"
      "native smoke render resource cache preflight missing count" = "15"
      "native smoke render resource cache preflight cached count" = "15"
      "native smoke render resource cache plan coverage" = "1"
      "native smoke render resource cache evictions" = "1"
      "native smoke render resource cache hits" = "1"
      "native smoke render resource cache misses" = "0"
      "native smoke render resource cache byte size" = "8"
      "native smoke gpu context resource plan count" = "2"
      "native smoke gpu context key variation" = "1"
      "native smoke gpu frame context validation" = "1"
      "native smoke gpu finalization resource plan count" = "3"
      "native smoke gpu frame finalization resource plan count" = "3"
      "native smoke gpu frame finalization gpu resource count" = "3"
      "native smoke gpu frame submission resource plan count" = "3"
      "native smoke gpu frame submission gpu resource count" = "3"
      "native smoke surface target resource plan count" = "2"
      "native smoke surface target cache resources" = "2"
      "native smoke window target resource plan count" = "1"
      "native smoke window physical width" = "16"
      "native smoke window frame pacing" = "2"
      "native smoke window present mode key variation" = "1"
      "native smoke surface finalization resource plan count" = "2"
      "native smoke surface finalization key variation" = "1"
      "native smoke surface flush-and-submit" = "1"
      "native smoke readback width" = "32"
      "native smoke readback height" = "32"
      "native smoke readback row_bytes" = "128"
      "native smoke bounded readback width" = "4"
      "native smoke bounded readback height" = "4"
      "native smoke bounded snapshot width" = "4"
      "native smoke bounded snapshot height" = "4"
      "native smoke surface bounds rejected" = "1"
      "native smoke image encode parameters sanitized" = "1"
      "native smoke filter layer count" = "1"
      "native smoke path verbs" = "9"
      "native smoke non-finite path from-value rejected" = "1"
      "native smoke non-finite path add skipped" = "2"
      "native smoke non-finite path direct mutations skipped" = "7"
      "native smoke decoded image width" = "32"
      "native smoke decoded image height" = "32"
      "native smoke render image command replay" = "1"
      "native smoke render image command count" = "3"
      "native smoke render image resource plan count" = "2"
      "native smoke render image cache resources" = "1"
      "native smoke render image cache misses" = "1"
      "native smoke render image cache hits" = "1"
      "native smoke render image decode failure resource plan count" = "2"
      "native smoke render image decode failure skipped" = "2"
      "native smoke render image decode failure cache resources" = "0"
      "native smoke render image decode failure cache misses" = "2"
      "native smoke empty image descriptor command plan count" = "1"
      "native smoke empty image descriptor replay skipped" = "2"
      "native smoke empty image descriptor cache misses" = "0"
      "native smoke codec width" = "32"
      "native smoke codec height" = "32"
      "native smoke decoded bitmap width" = "32"
      "native smoke decoded bitmap height" = "32"
      "native smoke shader draws" = "3"
      "native smoke shader resource plan count" = "3"
      "native smoke shader linear gradient validation" = "1"
      "native smoke shader linear gradient finite validation" = "1"
      "native smoke shader radial gradient validation" = "1"
      "native smoke invalid shader filter descriptor resources" = "4"
      "native smoke invalid shader filter replay skipped" = "2"
      "native smoke invalid shader filter replay cache resources" = "0"
      "native smoke invalid shader filter replay cache misses" = "0"
      "native smoke invalid shader filter replay filter resources" = "3"
      "native smoke filter resource plan count" = "3"
      "native smoke filter finite validation" = "1"
      "native smoke filter non-finite handle validation" = "1"
      "native smoke text run resource plan count" = "3"
      "native smoke text run range byte size" = "4"
      "native smoke text run empty range resource plan count" = "2"
      "native smoke text run empty range skipped" = "1"
      "native smoke text run empty range cache resources" = "0"
      "native smoke measured text resource plan count" = "5"
      "native smoke measured text key variation" = "1"
      "native smoke invalid measured text resource plan count" = "1"
      "native smoke invalid measured text uncacheable count" = "1"
      "native smoke shaped glyph run resource plan count" = "6"
      "native smoke shaped glyph run key variation" = "1"
      "native smoke invalid shaped glyph resource plan count" = "1"
      "native smoke invalid shaped glyph command plan count" = "1"
      "native smoke invalid shaped glyph replay skipped" = "1"
      "native smoke non-finite font scalars sanitized" = "1"
      "native smoke font resource plan count" = "1"
      "native smoke invalid fallback request resource plan count" = "1"
      "native smoke font fallback key variation" = "1"
      "native smoke font fallback match key variation" = "1"
      "native smoke font fallback match resource plan count" = "2"
      "native smoke font fallback resolution key variation" = "1"
      "native smoke font fallback resolution resource plan count" = "4"
      "native smoke invalid fallback match resource plan count" = "1"
      "native smoke invalid fallback resolution resource plan count" = "1"
      "native smoke font fallback resolution bridge" = "1"
      "native smoke font fallback resolution bridge cache resources" = "4"
      "native smoke font fallback resource plan count" = "1"
      "native smoke font fallback font resource plan count" = "2"
    }
    $seenExpectedMarkers = @{}
    foreach ($expected in $expectedValues) {
      $expectedId = "$($expected.id)".Trim()
      $marker = "$($expected.marker)".Trim()
      $value = "$($expected.value)".Trim()
      if ([string]::IsNullOrWhiteSpace($expectedId)) {
        throw "native smoke expected value is missing id"
      }
      if (!$seenIds.ContainsKey($expectedId)) {
        throw "native smoke expected value references unknown capability id: $expectedId"
      }
      if ([string]::IsNullOrWhiteSpace($marker)) {
        throw "native smoke expected value is missing marker: $expectedId"
      }
      if (!$seenMarkers.ContainsKey($marker)) {
        throw "native smoke expected value references unknown marker: $marker"
      }
      if ([string]::IsNullOrWhiteSpace($value)) {
        throw "native smoke expected value is missing value: $marker"
      }
      if ($seenExpectedMarkers.ContainsKey($marker)) {
        throw "duplicate native smoke expected value marker: $marker"
      }
      $seenExpectedMarkers[$marker] = $value
    }
    foreach ($marker in $requiredExpectedValues.Keys) {
      if (!$seenExpectedMarkers.ContainsKey($marker)) {
        throw "native smoke expected value coverage is missing marker: $marker"
      }
      if ($seenExpectedMarkers[$marker] -ne $requiredExpectedValues[$marker]) {
        throw "native smoke expected value mismatch: ${marker}: expected $($requiredExpectedValues[$marker])"
      }
    }
  }
}

if ($status.revision_file -ne (Split-Path -Leaf $resolvedRevisionFile)) {
  throw "status revision_file does not match requested revision file: status=$($status.revision_file) revision=$(Split-Path -Leaf $resolvedRevisionFile)"
}

if (!$revision) {
  throw "Skia revision file does not contain a revision"
}

$platforms = @("linux", "macos", "windows")
foreach ($platform in $platforms) {
  if (!$status.platforms.PSObject.Properties.Name.Contains($platform)) {
    throw "platform status is missing required platform: $platform"
  }
}

$acceptedPlatforms = @()
$expectedArtifactLogs = @{
  linux = @(
    "linux-real-skia-smoke-preflight.log",
    "linux-real-skia-smoke.log",
    "linux-native-smoke-output.log",
    "linux-real-skia-acceptance.log"
  )
  macos = @(
    "macos-real-skia-smoke-preflight.log",
    "macos-real-skia-smoke.log",
    "macos-native-smoke-output.log",
    "macos-real-skia-acceptance.log"
  )
  windows = @(
    "windows-real-skia-smoke-preflight.log",
    "windows-real-skia-smoke.log",
    "windows-native-smoke-output.log",
    "windows-real-skia-acceptance.log"
  )
}
$expectedVerifiers = @{
  linux = "scripts/verify-real-skia-artifact.sh --platform linux --log-dir logs"
  macos = "scripts/verify-real-skia-artifact.sh --platform macos --log-dir logs"
  windows = "scripts/verify-real-skia-artifact.ps1 -Platform windows -LogDir logs"
}
foreach ($platform in $platforms) {
  $entry = $status.platforms.$platform
  if ($null -eq $entry.accepted) {
    throw "platform status is missing accepted flag: $platform"
  }
  if ([string]::IsNullOrWhiteSpace($entry.state)) {
    throw "platform status is missing state: $platform"
  }
  if ($null -eq $entry.required_artifact_logs) {
    throw "platform status required_artifact_logs do not match expected contract: $platform"
  }
  $requiredArtifactLogs = @($entry.required_artifact_logs)
  $expectedLogs = @($expectedArtifactLogs[$platform])
  if ($requiredArtifactLogs.Count -ne $expectedLogs.Count) {
    throw "platform status required_artifact_logs do not match expected contract: $platform"
  }
  for ($i = 0; $i -lt $expectedLogs.Count; $i += 1) {
    if ($requiredArtifactLogs[$i] -ne $expectedLogs[$i]) {
      throw "platform status required_artifact_logs do not match expected contract: $platform"
    }
  }
  if ($entry.required_verifier -ne $expectedVerifiers[$platform]) {
    throw "platform status required_verifier does not match expected verifier: $platform"
  }
  if ([string]::IsNullOrWhiteSpace($entry.next_step)) {
    throw "platform status is missing next step: $platform"
  }

  if ($entry.accepted) {
    $acceptedPlatforms += $platform
    if ([string]::IsNullOrWhiteSpace($entry.accepted_artifact)) {
      throw "accepted platform is missing accepted_artifact: $platform"
    }
    if ($entry.accepted_commit -notmatch '^[0-9a-fA-F]{40}$') {
      throw "accepted platform is missing accepted_commit: $platform"
    }
    $acceptedProvider = if ($status.schema_version -ge 2) { $entry.accepted_provider } else { "source" }
    $acceptedVersion = if ($status.schema_version -ge 2) { $entry.accepted_version } else { $revision }
    if ($acceptedProvider -notin @("source", "jetbrains")) {
      throw "accepted platform has unsupported accepted_provider: $platform"
    }
    if ([string]::IsNullOrWhiteSpace($acceptedVersion)) {
      throw "accepted platform is missing accepted_version: $platform"
    }
    Add-Member -InputObject $entry -NotePropertyName __accepted_provider -NotePropertyValue $acceptedProvider -Force
    Add-Member -InputObject $entry -NotePropertyName __accepted_version -NotePropertyValue $acceptedVersion -Force
  } elseif ($null -ne $entry.accepted_artifact) {
    throw "unaccepted platform must not record accepted_artifact: $platform"
  } elseif ($null -ne $entry.accepted_commit) {
    throw "unaccepted platform must not record accepted_commit: $platform"
  }
  if (!$entry.accepted -and $status.schema_version -ge 2 -and $null -ne $entry.accepted_provider) {
    throw "unaccepted platform must not record accepted_provider: $platform"
  }
  if (!$entry.accepted -and $status.schema_version -ge 2 -and $null -ne $entry.accepted_version) {
    throw "unaccepted platform must not record accepted_version: $platform"
  }
}

$sourceAcceptedPlatforms = @($acceptedPlatforms | Where-Object { $status.platforms.$_.__accepted_provider -eq "source" })
if ($revision -eq "main" -and $sourceAcceptedPlatforms.Count -gt 0) {
  throw "source platforms cannot be accepted while skia-revision.txt is still main: $($sourceAcceptedPlatforms -join ', ')"
}

if ($revision -ne "main" -and $revision -notmatch '^[0-9a-fA-F]{40}$') {
  throw "Skia revision must be main or a full 40-character commit: $revision"
}

foreach ($platform in $acceptedPlatforms) {
  $acceptedCommit = $status.platforms.$platform.accepted_commit.ToLowerInvariant()
  $acceptedProvider = $status.platforms.$platform.__accepted_provider
  $acceptedVersion = $status.platforms.$platform.__accepted_version
  if ($acceptedProvider -eq "source" -and $acceptedCommit -ne $revision.ToLowerInvariant()) {
    throw "accepted platform commit does not match pinned revision: platform=$platform accepted_commit=$acceptedCommit revision=$revision"
  }
  if ($acceptedProvider -eq "source" -and $acceptedVersion -ne $revision) {
    throw "accepted source platform version does not match pinned revision: platform=$platform accepted_version=$acceptedVersion revision=$revision"
  }
  if ($acceptedProvider -eq "jetbrains") {
    if ([string]::IsNullOrWhiteSpace($jetbrainsCommit) -or [string]::IsNullOrWhiteSpace($jetbrainsTag)) {
      throw "JetBrains provider lock is missing tag or commit"
    }
    if ($acceptedCommit -ne $jetbrainsCommit) {
      throw "accepted JetBrains platform commit does not match provider lock: platform=$platform accepted_commit=$acceptedCommit jetbrains_commit=$jetbrainsCommit"
    }
    if ($acceptedVersion -ne $jetbrainsTag) {
      throw "accepted JetBrains platform version does not match provider lock tag: platform=$platform accepted_version=$acceptedVersion jetbrains_tag=$jetbrainsTag"
    }
  }
}

if (!$status.platforms.linux.first_acceptance_platform) {
  throw "Linux must remain the first acceptance platform until the initial source-built pin is established"
}

if (!$status.platforms.linux.source_build) {
  throw "Linux status must keep source_build=true for first acceptance"
}

if ($status.platforms.windows.source_build) {
  throw "Windows status must not claim source_build=true until a repeatable Windows Skia build path exists"
}

$defaultStatusPath = Join-Path $repoRoot "skia-platform-status.json"
$shouldCheckStatusDoc = $statusDocExplicit
if (!$shouldCheckStatusDoc) {
  $resolvedDefaultStatusPath = (Resolve-Path -LiteralPath $defaultStatusPath).Path
  $actualStatusPath = (Resolve-Path -LiteralPath $resolvedStatusFile).Path
  $shouldCheckStatusDoc = $actualStatusPath -eq $resolvedDefaultStatusPath
}
if ($shouldCheckStatusDoc) {
  if (!(Test-Path -LiteralPath $resolvedStatusDoc -PathType Leaf)) {
    throw "Skia platform status Markdown file is missing: $resolvedStatusDoc"
  }

  $platformNames = @{
    linux = "Linux"
    macos = "macOS"
    windows = "Windows"
  }
  $rows = @{}
  $inCurrentMatrix = $false
  foreach ($line in Get-Content -LiteralPath $resolvedStatusDoc) {
    $stripped = $line.Trim()
    if ($stripped -eq "## Current Matrix") {
      $inCurrentMatrix = $true
      continue
    }
    if ($inCurrentMatrix -and $stripped.StartsWith("## ")) {
      break
    }
    if (!$inCurrentMatrix -or !$stripped.StartsWith("|")) {
      continue
    }
    $cells = @($stripped.Trim("|").Split("|") | ForEach-Object { $_.Trim() })
    if ($cells.Count -ge 4) {
      foreach ($platform in $platformNames.Keys) {
        if ($cells[0] -eq $platformNames[$platform]) {
          $rows[$platform] = $cells
        }
      }
    }
  }

  foreach ($platform in $platformNames.Keys) {
    $displayName = $platformNames[$platform]
    if (!$rows.ContainsKey($platform)) {
      throw "platform status Markdown matrix is missing row: $displayName"
    }
    $entry = $status.platforms.$platform
    $rowCells = @($rows[$platform])
    $stateCell = $rowCells[1].ToLowerInvariant()
    $rowText = (@($rowCells[1..($rowCells.Count - 1)]) -join " ").ToLowerInvariant()
    if ($entry.accepted) {
      if (!$stateCell.Contains("accepted") -or $stateCell.Contains("not accepted")) {
        throw "platform status Markdown matrix does not mark accepted platform: $displayName"
      }
      $acceptedProvider = "$($entry.__accepted_provider)"
      $acceptedVersion = "$($entry.__accepted_version)"
      if (![string]::IsNullOrWhiteSpace($acceptedProvider) -and !$rowText.Contains($acceptedProvider.ToLowerInvariant())) {
        throw "platform status Markdown matrix is missing accepted provider: ${displayName}: $acceptedProvider"
      }
      if (![string]::IsNullOrWhiteSpace($acceptedVersion) -and !$rowText.Contains($acceptedVersion.ToLowerInvariant())) {
        throw "platform status Markdown matrix is missing accepted version: ${displayName}: $acceptedVersion"
      }
    } elseif (!$stateCell.Contains("not accepted")) {
      throw "platform status Markdown matrix does not mark unaccepted platform: $displayName"
    }
  }
}

Write-Host "Verified Skia platform status in $resolvedStatusFile with revision $revision."
