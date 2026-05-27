[CmdletBinding()]
param(
  [switch]$FetchOnly,
  [switch]$SkipRoot,
  [switch]$SkipSubmodules,
  [switch]$SkipLocalRepos,
  [string]$WindowRemote = "",
  [string]$WindowUpstream = "https://github.com/moonbit-community/window.git",
  [string]$WindowBranch = "moui-support"
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

function Invoke-GitRoot {
  param(
    [string]$WorkingDirectory,
    [string[]]$Arguments
  )

  Write-Host "==> git -C $WorkingDirectory $($Arguments -join ' ')"
  & git -C $WorkingDirectory @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "git failed with exit code $LASTEXITCODE"
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

function Test-GitRepository {
  param([string]$PathValue)

  if (-not (Test-Path -LiteralPath $PathValue)) {
    return $false
  }

  & git -C $PathValue rev-parse --is-inside-work-tree *> $null
  return ($LASTEXITCODE -eq 0)
}

function Assert-CleanWorktree {
  param([string]$RepoPath)

  $status = Get-GitOutput -RepoPath $RepoPath -Arguments @("status", "--porcelain")
  if (-not [string]::IsNullOrWhiteSpace($status)) {
    throw "$RepoPath has local changes. Commit, stash, or discard them before updating dependencies."
  }
}

function Set-RemoteUrl {
  param(
    [string]$RepoPath,
    [string]$Name,
    [string]$Url
  )

  $current = Get-GitOutput -RepoPath $RepoPath -Arguments @("remote", "get-url", $Name)
  if ([string]::IsNullOrWhiteSpace($current)) {
    Invoke-Git -RepoPath $RepoPath -Arguments @("remote", "add", $Name, $Url)
  } elseif ($current -ne $Url) {
    Invoke-Git -RepoPath $RepoPath -Arguments @("remote", "set-url", $Name, $Url)
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

function Update-WindowDependency {
  param(
    [string]$RepoRoot,
    [string]$LocalReposRoot,
    [string]$Remote,
    [string]$Upstream,
    [string]$Branch
  )

  $windowDir = Join-Path $LocalReposRoot "window"

  Write-Host "==> window remote: $Remote"
  Write-Host "==> window branch: $Branch"

  if (-not (Test-Path -LiteralPath $LocalReposRoot)) {
    New-Item -ItemType Directory -Path $LocalReposRoot | Out-Null
  }

  if (-not (Test-Path -LiteralPath (Join-Path $windowDir ".git"))) {
    Invoke-GitRoot -WorkingDirectory $RepoRoot -Arguments @("clone", $Remote, $windowDir)
  }

  Set-RemoteUrl -RepoPath $windowDir -Name "origin" -Url $Remote
  Set-RemoteUrl -RepoPath $windowDir -Name "upstream" -Url $Upstream
  Invoke-Git -RepoPath $windowDir -Arguments @("fetch", "origin", $Branch, "--prune")
  Invoke-Git -RepoPath $windowDir -Arguments @("fetch", "upstream", "--prune")

  if ($FetchOnly) {
    return
  }

  Assert-CleanWorktree -RepoPath $windowDir

  $currentBranch = Get-GitOutput -RepoPath $windowDir -Arguments @("branch", "--show-current")
  if ($currentBranch -ne $Branch) {
    $hasLocalBranch = Test-GitSuccess -RepoPath $windowDir -Arguments @("show-ref", "--verify", "--quiet", "refs/heads/$Branch")
    if ($hasLocalBranch) {
      Invoke-Git -RepoPath $windowDir -Arguments @("checkout", $Branch)
    } else {
      Invoke-Git -RepoPath $windowDir -Arguments @("checkout", "-B", $Branch, "origin/$Branch")
    }
  }

  Invoke-Git -RepoPath $windowDir -Arguments @("pull", "--ff-only", "origin", $Branch)
}

Require-Command "git"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
$localReposRoot = Join-Path $repoRoot ".local_repos"
$defaultWindowRemoteSsh = "git@github.com:wzzc-dev/window.git"
$defaultWindowRemoteHttps = "https://github.com/wzzc-dev/window.git"

if ([string]::IsNullOrWhiteSpace($WindowRemote)) {
  if (-not [string]::IsNullOrWhiteSpace($env:MOUI_WINDOW_REMOTE)) {
    $WindowRemote = $env:MOUI_WINDOW_REMOTE
  } elseif (-not [string]::IsNullOrWhiteSpace($env:CI)) {
    $WindowRemote = $defaultWindowRemoteHttps
  } else {
    $WindowRemote = $defaultWindowRemoteSsh
  }
}

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
  Update-WindowDependency `
    -RepoRoot $repoRoot `
    -LocalReposRoot $localReposRoot `
    -Remote $WindowRemote `
    -Upstream $WindowUpstream `
    -Branch $WindowBranch

  if (Test-Path -LiteralPath $localReposRoot) {
    $localRepos = Get-ChildItem -LiteralPath $localReposRoot -Directory |
      Where-Object { $_.Name -ne "window" -and (Test-GitRepository $_.FullName) } |
      Sort-Object FullName

    foreach ($localRepo in $localRepos) {
      Update-GitRepository $localRepo.FullName -AllRemotes
    }
  } else {
    Write-Host "==> No .local_repos directory found."
  }
}

Write-Host "==> Repository update complete."
