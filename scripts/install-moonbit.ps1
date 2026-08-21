[CmdletBinding()]
param(
    [string]$Version,
    [string]$ToolchainFile = ".moonbit-toolchain"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Version)) {
    $toolchainPath = Join-Path (Split-Path $PSScriptRoot -Parent) $ToolchainFile
    if (-not (Test-Path $toolchainPath)) {
        throw "Toolchain file not found: $toolchainPath"
    }
    $toolchain = Get-Content -LiteralPath $toolchainPath -Raw | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace($toolchain.moonc)) {
        throw "Toolchain file is missing a valid moonc version: $toolchainPath"
    }
    $Version = $toolchain.moonc
}

Write-Host "Installing MoonBit toolchain $Version" -ForegroundColor Cyan

$env:MOONBIT_INSTALL_VERSION = $Version
Invoke-RestMethod https://cli.moonbitlang.com/install/powershell.ps1 | Invoke-Expression

$moonBin = Join-Path $env:USERPROFILE ".moon\bin\moon.exe"
if (-not (Test-Path $moonBin)) {
    throw "moon.exe not found at $moonBin"
}

$installedVersion = & $moonBin version --all | Out-String
Write-Host "Installed: $($installedVersion.Trim())"

# Strip 'v' prefix and URL-encoded chars for comparison
$normalizedInstalled = $installedVersion -replace 'v','' -replace '%2B','+'
if (!$normalizedInstalled.Contains($Version)) {
    $baseVersion = ($Version -replace '\+.*$','')
    if (!$installedVersion.Contains($baseVersion)) {
        throw "Installed MoonBit version does not match $Version"
    }
}

$binPath = Join-Path $env:USERPROFILE ".moon\bin"
$env:PATH = "$binPath;$env:PATH"

Write-Host "MoonBit toolchain installed successfully." -ForegroundColor Green
Write-Host "Binary location: $binPath"
