[CmdletBinding()]
param(
  [string]$Arch = "x64",
  [string]$VcpkgRoot = "",
  [string]$WgpuNativeRoot = "",
  [switch]$SkipZlibCheck
)

$ErrorActionPreference = "Stop"

$scriptDir = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
  $PSScriptRoot
} else {
  Split-Path -Parent $MyInvocation.MyCommand.Path
}
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
$mouiScript = Join-Path $repoRoot "moui\scripts\windows\msvc_env.ps1"
if (-not (Test-Path -LiteralPath $mouiScript)) {
  throw "Published MSVC helper is missing: $mouiScript"
}

. $mouiScript @PSBoundParameters