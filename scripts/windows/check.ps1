<#
.SYNOPSIS
  Windows PowerShell entry point for MoUI repository check profiles.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\windows\check.ps1 -Profile Pr
#>
[CmdletBinding()]
param(
  [ValidateSet("Pr", "Daily", "Platform", "Theme", "Full")]
  [string]$Profile = "Pr",
  [switch]$DryRun,
  [switch]$Json,
  [switch]$List,
  [switch]$SkipSubmoduleInit
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
Set-Location $repoRoot

$profileArg = $Profile.ToLowerInvariant()
$argsList = @("scripts/check.mjs", "--profile", $profileArg)
if ($DryRun) { $argsList += "--dry-run" }
if ($Json) { $argsList += "--json" }
if ($List) { $argsList += "--list" }
if ($SkipSubmoduleInit) { $argsList += "--skip-submodule-init" }

& node @argsList
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
