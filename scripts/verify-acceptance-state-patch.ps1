param(
  [string] $PatchFile = "logs/linux-acceptance-state.patch",
  [string] $StatusFile = "skia-platform-status.json",
  [string] $RevisionFile = "skia-revision.txt"
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

$resolvedPatchFile = Resolve-RepoPath $PatchFile
$resolvedStatusFile = Resolve-RepoPath $StatusFile
$resolvedRevisionFile = Resolve-RepoPath $RevisionFile

if (!(Test-Path -LiteralPath $resolvedPatchFile -PathType Leaf)) {
  throw "acceptance state patch is missing: $resolvedPatchFile"
}
if (!(Test-Path -LiteralPath $resolvedStatusFile -PathType Leaf)) {
  throw "Skia platform status file is missing: $resolvedStatusFile"
}
if (!(Test-Path -LiteralPath $resolvedRevisionFile -PathType Leaf)) {
  throw "Skia revision file is missing: $resolvedRevisionFile"
}
if ((Get-Item -LiteralPath $resolvedPatchFile).Length -eq 0) {
  throw "acceptance state patch is empty: $resolvedPatchFile"
}

$allowedFiles = @("skia-revision.txt", "skia-platform-status.json")
$diffFiles = New-Object System.Collections.Generic.HashSet[string]
foreach ($line in Get-Content -LiteralPath $resolvedPatchFile) {
  if ($line -match '^diff --git a/(.+) b/(.+)$') {
    $oldPath = $Matches[1]
    $newPath = $Matches[2]
    if ($oldPath -ne $newPath) {
      throw "acceptance state patch must not rename files: $oldPath -> $newPath"
    }
    if ($allowedFiles -notcontains $oldPath) {
      throw "acceptance state patch touches unexpected file: $oldPath"
    }
    [void] $diffFiles.Add($oldPath)
  }
}

if ($diffFiles.Count -eq 0) {
  throw "acceptance state patch does not contain git file diffs: $resolvedPatchFile"
}
if (!$diffFiles.Contains("skia-platform-status.json")) {
  throw "acceptance state patch must update skia-platform-status.json"
}

$tempRoot = [System.IO.Path]::GetTempPath()
$tempDir = Join-Path $tempRoot ("skia-acceptance-state-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

try {
  Copy-Item -LiteralPath $resolvedStatusFile -Destination (Join-Path $tempDir "skia-platform-status.json")
  Copy-Item -LiteralPath $resolvedRevisionFile -Destination (Join-Path $tempDir "skia-revision.txt")

  git -C $tempDir -c core.autocrlf=false apply --check $resolvedPatchFile
  if ($LASTEXITCODE -ne 0) {
    throw "acceptance state patch failed git apply --check"
  }
  git -C $tempDir -c core.autocrlf=false apply $resolvedPatchFile
  if ($LASTEXITCODE -ne 0) {
    throw "acceptance state patch failed git apply"
  }

  $patchedStatusFile = Join-Path $tempDir "skia-platform-status.json"
  $patchedRevisionFile = Join-Path $tempDir "skia-revision.txt"
  & (Join-Path $PSScriptRoot "verify-platform-status.ps1") `
    -StatusFile $patchedStatusFile `
    -RevisionFile $patchedRevisionFile

  $status = Get-Content -LiteralPath $patchedStatusFile -Raw | ConvertFrom-Json
  if (!$status.platforms.linux.accepted) {
    throw "acceptance state patch does not mark Linux accepted"
  }
  if ($status.platforms.linux.accepted_commit -notmatch '^[0-9a-fA-F]{40}$') {
    throw "acceptance state patch does not record a Linux accepted_commit"
  }
} finally {
  $resolvedTempDir = Resolve-Path -LiteralPath $tempDir -ErrorAction SilentlyContinue
  if ($resolvedTempDir) {
    $resolvedTempRoot = (Resolve-Path -LiteralPath $tempRoot).Path
    if ($resolvedTempDir.Path.StartsWith($resolvedTempRoot)) {
      Remove-Item -LiteralPath $resolvedTempDir.Path -Recurse -Force
    } else {
      throw "refusing to remove temp directory outside temp root: $($resolvedTempDir.Path)"
    }
  }
}

Write-Host "Verified Linux acceptance state patch in $resolvedPatchFile."
