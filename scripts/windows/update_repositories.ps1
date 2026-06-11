[CmdletBinding()]
param(
  [switch]$FetchOnly,
  [switch]$SkipRoot,
  [switch]$SkipSubmodules,
  [switch]$SkipLocalRepos
)

$ErrorActionPreference = "Stop"

function Require-Command {
  param([string]$Name)

  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "$Name is required in PATH."
  }
}

function Invoke-Git {
  param(
    [string]$RepoPath,
    [string[]]$Arguments
  )

  Write-Host "==> git -C $RepoPath $($Arguments -join ' ')"
  & git -C $RepoPath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "git failed with exit code $LASTEXITCODE in $RepoPath"
  }
}

function Get-GitOutput {
  param(
    [string]$RepoPath,
    [string[]]$Arguments
  )

  $output = & git -C $RepoPath @Arguments
  if ($LASTEXITCODE -ne 0) {
    return ""
  }

  return ($output -join "`n").Trim()
}

function Test-GitSuccess {
  param(
    [string]$RepoPath,
    [string[]]$Arguments
  )

  & git -C $RepoPath @Arguments *> $null
  return ($LASTEXITCODE -eq 0)
}

function Assert-CleanWorktree {
  param([string]$RepoPath)

  $status = Get-GitOutput -RepoPath $RepoPath -Arguments @("status", "--porcelain")
  if (-not [string]::IsNullOrWhiteSpace($status)) {
    throw "$RepoPath has local changes. Commit, stash, or discard them before updating dependencies."
  }
}

function Update-GitRepository {
  param(
    [string]$RepoPath,
    [switch]$AllRemotes
  )

  if ($AllRemotes) {
    Invoke-Git -RepoPath $RepoPath -Arguments @("fetch", "--all", "--prune")
  } else {
    Invoke-Git -RepoPath $RepoPath -Arguments @("fetch", "--prune")
  }

  if ($FetchOnly) {
    return
  }

  $branch = (& git -C $RepoPath branch --show-current).Trim()
  if ([string]::IsNullOrWhiteSpace($branch)) {
    Write-Host "==> $RepoPath is detached; fetched remotes but skipped pull."
    return
  }

  & git -C $RepoPath rev-parse --abbrev-ref "$branch@{upstream}" *> $null
  if ($LASTEXITCODE -eq 0) {
    Invoke-Git -RepoPath $RepoPath -Arguments @("pull", "--ff-only")
  } else {
    Invoke-Git -RepoPath $RepoPath -Arguments @("pull", "--ff-only", "origin", $branch)
  }
}

Require-Command "git"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path

Write-Host "==> repo root: $repoRoot"

if (-not $SkipRoot) {
  Update-GitRepository $repoRoot
}

if (-not $SkipSubmodules) {
  if ($FetchOnly) {
    Invoke-Git -RepoPath $repoRoot -Arguments @("submodule", "foreach", "--recursive", "git fetch --prune")
  } else {
    Invoke-Git -RepoPath $repoRoot -Arguments @("submodule", "update", "--init", "--recursive")
  }
}

if (-not $SkipLocalRepos) {
  Write-Host "==> No local dependency repositories are updated; run moon update for registry packages such as wzzc-dev/window@0.5.1-0.1.4."
}

Write-Host "==> Repository update complete."
