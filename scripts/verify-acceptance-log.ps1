param(
  [Parameter(Mandatory = $true)]
  [string] $LogPath,

  [switch] $RequireCommit
)

$ErrorActionPreference = "Stop"

if (!(Test-Path -LiteralPath $LogPath)) {
  throw "acceptance log is missing: $LogPath"
}

$content = Get-Content -LiteralPath $LogPath -Raw

foreach ($field in @("smoke_status=0", "native_smoke_marker=passed", "native_pkg_restore=passed")) {
  if (!$content.Contains($field)) {
    throw "acceptance log is missing required field: $field"
  }
}

if ($RequireCommit -and $content -notmatch 'skia_commit=[0-9a-fA-F]{40}\s*(\r?\n|$)') {
  throw "acceptance log is missing a full 40-character skia_commit hash"
}

Write-Host "Verified real Skia acceptance log in $LogPath."
