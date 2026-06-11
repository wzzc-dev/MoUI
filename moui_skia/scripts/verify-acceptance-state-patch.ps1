param(
  [string] $PatchFile = "logs/linux-acceptance-state.patch",
  [string] $StatusFile = "skia-platform-status.json",
  [string] $RevisionFile = "skia-revision.txt"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $repoRoot
$toolPackage = "tools/moui_skia/verify_acceptance_state_patch"
$toolDir = Join-Path $workspaceRoot $toolPackage

if (!(Test-Path -LiteralPath $toolDir -PathType Container)) {
  $splitRepoToolDir = Join-Path $repoRoot $toolPackage
  if (Test-Path -LiteralPath $splitRepoToolDir -PathType Container) {
    $workspaceRoot = $repoRoot
    $toolDir = $splitRepoToolDir
  }
}

if (!(Test-Path -LiteralPath $toolDir -PathType Container)) {
  throw "MoonBit acceptance state patch tool is missing: $toolDir"
}

$toolExe = Join-Path $workspaceRoot "_build/native/debug/build/wzzc-dev/moui_tools/moui_skia/verify_acceptance_state_patch/verify_acceptance_state_patch.exe"

Push-Location $workspaceRoot
try {
  moon build $toolPackage --target native
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
} finally {
  Pop-Location
}

function Invoke-AcceptanceStatePatchTool {
  param(
    [Parameter(Mandatory = $true)]
    [string[]] $ToolArgs
  )

  $exitCode = 0
  Push-Location $workspaceRoot
  try {
    & $toolExe @ToolArgs
    $exitCode = $LASTEXITCODE
  } finally {
    Pop-Location
  }
  if ($exitCode -ne 0) {
    exit $exitCode
  }
}

function Invoke-CheckedScript {
  param(
    [Parameter(Mandatory = $true)]
    [scriptblock] $Command
  )

  $global:LASTEXITCODE = 0
  & $Command
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    exit $exitCode
  }
}

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

function Convert-FileToLf {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path
  )

  $text = [System.IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
  [System.IO.File]::WriteAllText($Path, $text, [System.Text.UTF8Encoding]::new($false))
}

$resolvedPatchFile = Resolve-RepoPath $PatchFile
$resolvedStatusFile = Resolve-RepoPath $StatusFile
$resolvedRevisionFile = Resolve-RepoPath $RevisionFile

Invoke-AcceptanceStatePatchTool -ToolArgs @(
  "--repo-root", $repoRoot,
  "--patch-file", $PatchFile,
  "--status-file", $StatusFile,
  "--revision-file", $RevisionFile
)

$tempRoot = [System.IO.Path]::GetTempPath()
$tempDir = Join-Path $tempRoot ("skia-acceptance-state-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

try {
  Copy-Item -LiteralPath $resolvedStatusFile -Destination (Join-Path $tempDir "skia-platform-status.json")
  Copy-Item -LiteralPath $resolvedRevisionFile -Destination (Join-Path $tempDir "skia-revision.txt")
  Convert-FileToLf -Path (Join-Path $tempDir "skia-platform-status.json")
  Convert-FileToLf -Path (Join-Path $tempDir "skia-revision.txt")

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
  Invoke-CheckedScript {
    & (Join-Path $PSScriptRoot "verify-platform-status.ps1") `
      -StatusFile $patchedStatusFile `
      -RevisionFile $patchedRevisionFile
  }

  Invoke-AcceptanceStatePatchTool -ToolArgs @(
    "--repo-root", $repoRoot,
    "--skip-input-state",
    "--patched-status-file", $patchedStatusFile
  )
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
