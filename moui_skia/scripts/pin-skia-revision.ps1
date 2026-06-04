param(
  [string] $AcceptanceLog = "logs/linux-real-skia-smoke/linux-real-skia-acceptance.log",

  [string] $RevisionFile = "skia-revision.txt"
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

if (!(Test-Path -LiteralPath $resolvedAcceptanceLog -PathType Leaf)) {
  throw "acceptance log was not found: $resolvedAcceptanceLog"
}

& (Join-Path $PSScriptRoot "verify-acceptance-log.ps1") `
  -LogPath $resolvedAcceptanceLog `
  -RequireCommit

$acceptanceContent = Get-Content -LiteralPath $resolvedAcceptanceLog -Raw
$matches = [regex]::Matches($acceptanceContent, '(?m)^\s*skia_commit=([0-9a-fA-F]{40})\s*$')
if ($matches.Count -eq 0) {
  throw "no full 40-character skia_commit=<hash> entry was found in $resolvedAcceptanceLog"
}

$skiaCommit = $matches[$matches.Count - 1].Groups[1].Value.ToLowerInvariant()
Set-Content -LiteralPath $resolvedRevisionFile -Value $skiaCommit
Write-Host "Pinned $resolvedRevisionFile to $skiaCommit"
