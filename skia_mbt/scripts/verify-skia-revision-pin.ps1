param(
  [Parameter(Mandatory = $true)]
  [string] $AcceptanceLog,

  [string] $RevisionFile = "skia-revision.txt",

  [switch] $SkipIfUnpinned
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([System.IO.Path]::IsPathRooted($AcceptanceLog)) {
  $resolvedAcceptanceLog = $AcceptanceLog
} else {
  $resolvedAcceptanceLog = Join-Path $repoRoot $AcceptanceLog
}
if ([System.IO.Path]::IsPathRooted($RevisionFile)) {
  $resolvedRevisionFile = $RevisionFile
} else {
  $resolvedRevisionFile = Join-Path $repoRoot $RevisionFile
}

if (!(Test-Path -LiteralPath $resolvedRevisionFile -PathType Leaf)) {
  throw "Skia revision file is missing: $resolvedRevisionFile"
}

$pinnedRevision = ""
foreach ($line in Get-Content -LiteralPath $resolvedRevisionFile) {
  $trimmed = $line.Trim()
  if ($trimmed.Length -gt 0 -and !$trimmed.StartsWith("#")) {
    $pinnedRevision = $trimmed.ToLowerInvariant()
    break
  }
}

if ($pinnedRevision -notmatch '^[0-9a-f]{40}$') {
  if ($pinnedRevision.Length -eq 0) {
    $pinnedRevision = "<empty>"
  }
  if ($SkipIfUnpinned) {
    Write-Host "Skipping Skia revision pin check because revision is not pinned: $pinnedRevision"
    exit 0
  }
  throw "Skia revision is not pinned to a full 40-character commit: $pinnedRevision"
}

& (Join-Path $PSScriptRoot "verify-acceptance-log.ps1") -LogPath $resolvedAcceptanceLog -RequireCommit

$acceptanceContent = Get-Content -LiteralPath $resolvedAcceptanceLog -Raw
$matches = [regex]::Matches($acceptanceContent, '(?m)^\s*skia_commit=([0-9a-fA-F]{40})\s*$')
if ($matches.Count -eq 0) {
  throw "acceptance log is missing a full 40-character skia_commit hash"
}
$acceptedCommit = $matches[$matches.Count - 1].Groups[1].Value.ToLowerInvariant()

if ($pinnedRevision -ne $acceptedCommit) {
  throw "Skia revision pin does not match acceptance commit: pinned_revision=$pinnedRevision acceptance_commit=$acceptedCommit"
}

Write-Host "Verified skia-revision.txt matches accepted Skia commit $acceptedCommit."
