# Windows native dev hot-reload smoke (manual / matching-host).
#
# Builds the generated bridge host and counter plugin, then drives
# `moui dev --hot`: edit the app, wait for a new generation to load into the
# same host process, force a compile error and confirm the previous generation
# stays interactive, then fix it and confirm recovery. The counter source is
# restored in `finally` even when a leg fails.
#
# Run from a Developer Command Prompt (vcvarsall x64) so moon, cl.exe/lib.exe
# and link.exe share one MSVC environment:
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/windows-hot-reload-smoke.ps1 -Run
#
# Environment:
#   MOUI_HOT_SMOKE_TIMEOUT  seconds to wait per leg (default 240)
#   MOUI_HOT_LINKER         MSVC linker override (default link.exe)
#   MOUI_SKIA_RENDERER      defaults to skia-raster
#
# Evidence: artifacts/windows-hot-reload/smoke.log (+ smoke.err.log)
#
# This is a manual gate: the Windows platform-evidence workflow has a real
# windows-2022 runner, but running an interactive HWND/Skia smoke there is not
# part of its current steps, matching how the Linux hot smoke stays manual.

[CmdletBinding()]
param(
  [switch]$Run
)

$ErrorActionPreference = "Stop"

if (-not $Run) {
  Write-Error "usage: scripts/windows-hot-reload-smoke.ps1 -Run"
  exit 2
}

function Fail([string]$Message) {
  throw "windows-hot-reload smoke failed: $Message"
}

if ($env:OS -ne "Windows_NT") {
  Fail "this smoke is Windows-only"
}

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

foreach ($tool in @("node", "moon")) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    Fail "missing tool: $tool (run inside a Developer Command Prompt)"
  }
}
$linker = if ($env:MOUI_HOT_LINKER) { $env:MOUI_HOT_LINKER } else { "link.exe" }
if (-not (Get-Command $linker -ErrorAction SilentlyContinue)) {
  Fail "missing $linker (run inside a Developer Command Prompt / vcvarsall x64)"
}

$app = "examples/counter/app/app.mbt"
if (-not (Test-Path $app)) { Fail "counter app source missing: $app" }
$appText = [System.IO.File]::ReadAllText((Resolve-Path $app))
if ($appText -notmatch 'text\("MoUI Counter"\)') {
  Fail "counter source no longer has the expected title literal"
}
if ($appText -notmatch 'count: model.count \+ 1') {
  Fail "counter source no longer has the expected increment arm"
}

$evidenceDir = "artifacts/windows-hot-reload"
New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null
$log = Join-Path $evidenceDir "smoke.log"
$errLog = Join-Path $evidenceDir "smoke.err.log"
Set-Content -Path $log -Value "" -NoNewline
Set-Content -Path $errLog -Value "" -NoNewline

$backup = Join-Path ([System.IO.Path]::GetTempPath()) ("moui-hot-smoke-" + [guid]::NewGuid().ToString("N") + ".mbt")
Copy-Item $app $backup
$timeout = if ($env:MOUI_HOT_SMOKE_TIMEOUT) { [int]$env:MOUI_HOT_SMOKE_TIMEOUT } else { 240 }
$runner = $null
$hostPid = $null

function ReadLogs {
  $text = ""
  foreach ($path in @($log, $errLog)) {
    if (Test-Path $path) {
      try { $text += (Get-Content -Path $path -Raw -ErrorAction Stop) } catch { }
    }
  }
  return $text
}

function WaitForLog([string]$Pattern, [string]$Label, [int]$Seconds = $timeout) {
  $deadline = (Get-Date).AddSeconds($Seconds)
  while ((Get-Date) -lt $deadline) {
    if ((ReadLogs) -match [regex]::Escape($Pattern)) { return }
    if ($runner -and $runner.HasExited) { Fail "dev runner exited while waiting for $Label" }
    Start-Sleep -Milliseconds 500
  }
  Fail "timed out waiting for $Label (pattern: $Pattern)"
}

function WaitForStatus([string]$Phase, [int]$Generation, [string]$Label, [int]$Seconds = $timeout) {
  $deadline = (Get-Date).AddSeconds($Seconds)
  $statusPath = ".moui/dev-status.json"
  while ((Get-Date) -lt $deadline) {
    if (Test-Path $statusPath) {
      $status = Get-Content -Path $statusPath -Raw -ErrorAction SilentlyContinue
      if ($status -match ('"phase":\s*"' + [regex]::Escape($Phase) + '"') -and
          $status -match ('"generation":\s*' + $Generation)) {
        return
      }
    }
    if ($runner -and $runner.HasExited) { Fail "dev runner exited while waiting for $Label" }
    Start-Sleep -Milliseconds 500
  }
  Fail "timed out waiting for $Label"
}

function FindHostPid {
  $deadline = (Get-Date).AddSeconds(10)
  while ((Get-Date) -lt $deadline) {
    $children = Get-CimInstance Win32_Process -Filter "ParentProcessId=$($runner.Id)" |
      Where-Object { $_.Name -eq "host.exe" }
    if ($children) { return [int]$children[0].ProcessId }
    Start-Sleep -Milliseconds 250
  }
  Fail "could not find the dev host child process"
}

function HostAlive([int]$Pid) {
  return $null -ne (Get-Process -Id $Pid -ErrorAction SilentlyContinue)
}

function ReloadCloseCount {
  $count = 0
  foreach ($path in @($log, $errLog)) {
    if (Test-Path $path) {
      $count += @((Get-Content -Path $path -ErrorAction SilentlyContinue) |
        Select-String -SimpleMatch "reload-old FreeLibrary=1").Count
    }
  }
  return [int]$count
}

function ReplaceApp([string]$Pattern, [string]$Replacement) {
  $text = [System.IO.File]::ReadAllText((Resolve-Path $app))
  $next = [regex]::Replace($text, $Pattern, $Replacement)
  if ($next -eq $text) { Fail "counter source edit did not change: $Pattern" }
  [System.IO.File]::WriteAllText((Resolve-Path $app), $next)
}

try {
  $env:MOUI_SKIA_RENDERER = if ($env:MOUI_SKIA_RENDERER) { $env:MOUI_SKIA_RENDERER } else { "skia-raster" }
  $env:MOUI_HOT_DEBUG = "1"
  $runner = Start-Process -FilePath "node" `
    -ArgumentList @("scripts/moui-dev.mjs", "--package", "examples/counter", "--hot", "--interval-ms", "250") `
    -PassThru -NoNewWindow -RedirectStandardOutput $log -RedirectStandardError $errLog

  WaitForLog "hot plugin ready (generation 1" "first plugin generation"
  WaitForLog "moui windowing backend:" "host window"
  $hostPid = FindHostPid
  if (-not (HostAlive $hostPid)) { Fail "hot host is not running" }
  Write-Output "generation 1 loaded; host pid=$hostPid"

  # 1. A source edit swaps the plugin inside the same host process.
  ReplaceApp 'text\("MoUI Counter"\)' 'text("MoUI Counter smoke")'
  WaitForStatus "running" 2 "generation 2 reload"
  WaitForLog "reload-old FreeLibrary=1 rc=0 images=1" "Windows image unmap"
  if ((FindHostPid) -ne $hostPid) { Fail "host pid changed across a reload" }
  Write-Output "generation 2 loaded; host pid retained"

  # 2. A compile error keeps the previous generation live and the host running.
  $closedBefore = ReloadCloseCount
  ReplaceApp 'count: model\.count \+ 1' 'count: model.count + hot_smoke_missing_symbol'
  WaitForStatus "error" 2 "build error"
  Start-Sleep -Seconds 1
  if (-not (HostAlive $hostPid)) { Fail "host exited on a build error" }
  $closedAfter = ReloadCloseCount
  if ($closedAfter -ne $closedBefore) { Fail "host swapped a generation after a failed build" }
  Write-Output "build error kept generation 2 live"

  # 3. Fixing the source recovers with another in-place swap.
  ReplaceApp 'count: model\.count \+ hot_smoke_missing_symbol' 'count: model.count + 1'
  WaitForStatus "running" 3 "generation 3 recovery"
  if ((ReloadCloseCount) -le $closedAfter) { Fail "generation 3 did not close the previous image" }
  if ((FindHostPid) -ne $hostPid) { Fail "host pid changed during recovery" }
  Write-Output "generation 3 recovered; host pid retained"

  Write-Output "windows-hot-reload smoke passed"
}
finally {
  if ($runner -and -not $runner.HasExited) {
    try { taskkill /PID $runner.Id /T /F | Out-Null } catch { }
  }
  if ($hostPid) {
    try { Stop-Process -Id $hostPid -Force -ErrorAction SilentlyContinue } catch { }
  }
  Copy-Item $backup $app -Force
  Remove-Item $backup -Force -ErrorAction SilentlyContinue
}
