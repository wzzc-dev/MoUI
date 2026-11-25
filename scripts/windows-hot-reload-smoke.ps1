# Windows native dev hot-reload smoke (manual / hosted CI).
#
# Default (`-Run`) builds the generated bridge host and counter plugin, then
# drives `moui dev --hot`: edit the app, wait for a new generation to load into
# the same host process, force a compile error and confirm the previous
# generation stays interactive, then fix it and confirm recovery. The counter
# source is restored in `finally` even when a leg fails.
#
# `-Offscreen` runs the same bridge host without an HWND through the dev-only
# CPU offscreen entry (`MOUI_HOT_OFFSCREEN=1`), so the smoke can run on hosted
# CI. It drives the rich probe app and the shared widget package through seven
# legs: offscreen host startup, rich frame vocabulary with advancing ticks, a
# synthetic `MOUI_HOT_INJECT_FILE` click, an app edit (generation 2, state
# preserved), an imported-widget edit (generation 3), a compile error that
# keeps generation 3 live, and recovery (generation 4). Generation polling,
# synthetic input and frame ticking all run on the offscreen loop; no window
# message loop exists. The default windowed path is unchanged.
#
# Run from a Developer Command Prompt (vcvarsall x64) so moon, cl.exe/lib.exe
# and link.exe share one MSVC environment:
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/windows-hot-reload-smoke.ps1 -Run
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/windows-hot-reload-smoke.ps1 -Run -Offscreen
#
# Environment:
#   MOUI_HOT_SMOKE_TIMEOUT  seconds to wait per leg (default 240)
#   MOUI_HOT_LINKER         MSVC linker override (default link.exe)
#   MOUI_SKIA_RENDERER      defaults to skia-raster
#
# Evidence: artifacts/windows-hot-reload/smoke.log (+ smoke.err.log); the
# offscreen run also writes events.jsonl beside them.

[CmdletBinding()]
param(
  [switch]$Run,
  [switch]$Offscreen
)

$ErrorActionPreference = "Stop"

if (-not $Run) {
  Write-Error "usage: scripts/windows-hot-reload-smoke.ps1 -Run [-Offscreen]"
  exit 2
}

if ($env:OS -ne "Windows_NT") {
  Write-Error "windows-hot-reload smoke failed: this smoke is Windows-only"
  exit 2
}

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$evidenceDir = "artifacts/windows-hot-reload"
New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null
$log = Join-Path $evidenceDir "smoke.log"
$errLog = Join-Path $evidenceDir "smoke.err.log"
$injectFile = Join-Path (Resolve-Path $evidenceDir) "events.jsonl"
Set-Content -Path $log -Value "" -NoNewline
Set-Content -Path $errLog -Value "" -NoNewline
if ($Offscreen) {
  Set-Content -Path $injectFile -Value "" -NoNewline
}

$script:currentLeg = "startup"
$timeout = if ($env:MOUI_HOT_SMOKE_TIMEOUT) { [int]$env:MOUI_HOT_SMOKE_TIMEOUT } else { 240 }
$runner = $null
$hostPid = $null

function LastLogLine {
  $line = "<none>"
  foreach ($path in @($log, $errLog)) {
    if (Test-Path $path) {
      $lines = @(Get-Content -Path $path -ErrorAction SilentlyContinue | Where-Object { $_ -ne "" })
      if ($lines.Count -gt 0) { $line = [string]$lines[$lines.Count - 1] }
    }
  }
  return $line
}

function LastFrameLine {
  $lines = @(Get-Content -Path $log -ErrorAction SilentlyContinue |
    Where-Object { $_ -match "moui-devhost: frame " })
  if ($lines.Count -gt 0) { return [string]$lines[$lines.Count - 1] }
  return "<none>"
}

function Fail([string]$Message) {
  throw ("windows-hot-reload smoke failed [" + $script:currentLeg + "]: " + $Message +
    "; last matching frame: " + (LastFrameLine) + "; last log line: " + (LastLogLine))
}

foreach ($tool in @("node", "moon")) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    Fail "missing tool: $tool (run inside a Developer Command Prompt)"
  }
}
$linker = if ($env:MOUI_HOT_LINKER) { $env:MOUI_HOT_LINKER } else { "link.exe" }
if (-not (Get-Command $linker -ErrorAction SilentlyContinue)) {
  Fail "missing $linker (run inside a Developer Command Prompt / vcvarsall x64)"
}

$app = if ($Offscreen) { "examples/hot_reload_probe/app/app.mbt" } else { "examples/counter/app/app.mbt" }
$widgets = if ($Offscreen) { "examples/hot_reload_widgets/widgets/widgets.mbt" } else { $null }
if (-not (Test-Path $app)) { Fail "app source missing: $app" }

if ($Offscreen) {
  if (-not (Test-Path $widgets)) { Fail "shared widget source missing: $widgets" }
  $appText = [System.IO.File]::ReadAllText((Resolve-Path $app))
  if ($appText -notmatch 'text\("Hot Reload Probe"\)') {
    Fail "probe source no longer has the expected title literal"
  }
  if ($appText -notmatch 'count: model\.count \+ 1') {
    Fail "probe source no longer has the expected increment arm"
  }
  $widgetsText = [System.IO.File]::ReadAllText((Resolve-Path $widgets))
  if ($widgetsText -notmatch '"shared alpha"') {
    Fail "shared widget source no longer has the expected label literal"
  }
} else {
  $appText = [System.IO.File]::ReadAllText((Resolve-Path $app))
  if ($appText -notmatch 'text\("MoUI Counter"\)') {
    Fail "counter source no longer has the expected title literal"
  }
  if ($appText -notmatch 'count: model.count \+ 1') {
    Fail "counter source no longer has the expected increment arm"
  }
}

$appBackup = Join-Path ([System.IO.Path]::GetTempPath()) ("moui-hot-smoke-" + [guid]::NewGuid().ToString("N") + ".mbt")
Copy-Item $app $appBackup
$widgetsBackup = $null
if ($widgets) {
  $widgetsBackup = Join-Path ([System.IO.Path]::GetTempPath()) ("moui-hot-smoke-widgets-" + [guid]::NewGuid().ToString("N") + ".mbt")
  Copy-Item $widgets $widgetsBackup
}

$savedOffscreen = $env:MOUI_HOT_OFFSCREEN
$savedInject = $env:MOUI_HOT_INJECT_FILE
$savedTrace = $env:MOUI_HOT_FRAME_TRACE_INTERVAL

function ReadLogs {
  $text = ""
  foreach ($path in @($log, $errLog)) {
    if (Test-Path $path) {
      try { $text += (Get-Content -Path $path -Raw -ErrorAction Stop) + "`n" } catch { }
    }
  }
  return $text
}

function WaitForLog([string]$Pattern, [string]$Label, [int]$Seconds = $timeout) {
  $deadline = (Get-Date).AddSeconds($Seconds)
  while ((Get-Date) -lt $deadline) {
    if ((ReadLogs) -match [regex]::Escape($Pattern)) { return }
    if ($runner -and $runner.HasExited) { Fail "$Label`: dev runner exited while waiting for pattern: $Pattern" }
    Start-Sleep -Milliseconds 500
  }
  Fail "$Label`: timed out waiting for pattern: $Pattern"
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
    if ($runner -and $runner.HasExited) { Fail "$Label`: dev runner exited while waiting for $Phase generation $Generation" }
    Start-Sleep -Milliseconds 500
  }
  Fail "$Label`: timed out waiting for $Phase generation $Generation"
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

function LogLineCount {
  if (-not (Test-Path $log)) { return 0 }
  return @(Get-Content -Path $log -ErrorAction SilentlyContinue).Count
}

function FindLogLine([string]$Pattern) {
  $lines = @(Get-Content -Path $log -ErrorAction SilentlyContinue)
  for ($index = $lines.Count - 1; $index -ge 0; $index--) {
    if ($lines[$index] -match [regex]::Escape($Pattern)) { return $index + 1 }
  }
  Fail "host log does not contain: $Pattern"
}

function WaitForFrameAfter {
  param(
    [int]$StartLine,
    [string]$Label,
    [int]$Seconds = $timeout,
    [string[]]$Needles
  )
  $deadline = (Get-Date).AddSeconds($Seconds)
  $lastFrame = ""
  while ((Get-Date) -lt $deadline) {
    $frames = @(Get-Content -Path $log -ErrorAction SilentlyContinue |
      Select-Object -Skip ($StartLine - 1) |
      Where-Object { $_ -match "unsupported=0" -and $_ -match "texts=\[" })
    if ($frames.Count -gt 0) {
      $lastFrame = [string]$frames[$frames.Count - 1]
      $matched = $true
      foreach ($needle in $Needles) {
        if ($lastFrame -notmatch [regex]::Escape($needle)) { $matched = $false }
      }
      if ($matched) { return $lastFrame }
    }
    if ($runner -and $runner.HasExited) {
      Fail "$Label`: dev runner exited; last matching frame: $lastFrame"
    }
    Start-Sleep -Milliseconds 500
  }
  Fail "$Label`: timed out; last matching frame: $lastFrame"
}

function AssertKinds([string]$Line) {
  if ($Line -match "kinds=([^ ]*)") {
    $kinds = $Matches[1]
  } else {
    Fail "frame trace has no kinds= field: $Line"
  }
  foreach ($kind in @("draw_text", "draw_image", "draw_shadow", "push_clip", "pop_clip", "fill_rect",
      "fill_rounded_rect", "fill_rounded_rect_brush", "stroke_rounded_rect_brush",
      "push_rounded_clip", "pop_rounded_clip")) {
    if (",$kinds," -notlike "*,$kind,*") {
      Fail "frame trace is missing command kind: $kind (line: $Line)"
    }
  }
}

function LastTick {
  $matches = [regex]::Matches((ReadLogs), "Ticks: ([0-9]+)")
  if ($matches.Count -eq 0) { return 0 }
  return [int]$matches[$matches.Count - 1].Groups[1].Value
}

function ReplaceApp([string]$Pattern, [string]$Replacement) {
  ReplaceFileText $app $Pattern $Replacement "app"
}

function ReplaceFileText([string]$Path, [string]$Pattern, [string]$Replacement, [string]$Label) {
  $text = [System.IO.File]::ReadAllText((Resolve-Path $Path))
  $next = [regex]::Replace($text, $Pattern, $Replacement)
  if ($next -eq $text) { Fail "$Label source edit did not change: $Pattern" }
  [System.IO.File]::WriteAllText((Resolve-Path $Path), $next)
}

try {
  $env:MOUI_SKIA_RENDERER = if ($env:MOUI_SKIA_RENDERER) { $env:MOUI_SKIA_RENDERER } else { "skia-raster" }
  $env:MOUI_HOT_DEBUG = "1"
  if ($Offscreen) {
    $env:MOUI_HOT_OFFSCREEN = "1"
    $env:MOUI_HOT_FRAME_TRACE_INTERVAL = if ($env:MOUI_HOT_FRAME_TRACE_INTERVAL) { $env:MOUI_HOT_FRAME_TRACE_INTERVAL } else { "40" }
    $env:MOUI_HOT_INJECT_FILE = $injectFile
    Remove-Item -Path ".moui/dev-state.json" -ErrorAction SilentlyContinue
    Remove-Item -Path ".moui/dev-state-transient.json" -ErrorAction SilentlyContinue
    Remove-Item -Path ".moui/dev-status.json" -ErrorAction SilentlyContinue
    $package = "examples/hot_reload_probe"
  } else {
    Remove-Item Env:MOUI_HOT_OFFSCREEN -ErrorAction SilentlyContinue
    Remove-Item Env:MOUI_HOT_INJECT_FILE -ErrorAction SilentlyContinue
    $package = "examples/counter"
  }
  $runner = Start-Process -FilePath "node" `
    -ArgumentList @("scripts/moui-dev.mjs", "--package", $package, "--hot", "--interval-ms", "250") `
    -PassThru -NoNewWindow -RedirectStandardOutput $log -RedirectStandardError $errLog

  $script:currentLeg = "generation 1 startup"
  WaitForLog "hot plugin ready (generation 1" "first plugin generation"
  if ($Offscreen) {
    # A missing marker means the generated host ignored MOUI_HOT_OFFSCREEN and
    # tried the windowed entry (which cannot work on a hosted runner).
    try {
      WaitForLog "moui-devhost: offscreen surface" "offscreen surface marker" 180
    } catch {
      Fail ("offscreen support missing: MOUI_HOT_OFFSCREEN was not honored by the generated host; " +
        $_.Exception.Message)
    }
    if ((ReadLogs) -match [regex]::Escape("moui windowing backend:")) {
      Fail "offscreen mode opened a window backend"
    }
  } else {
    WaitForLog "moui windowing backend:" "host window"
  }
  $hostPid = FindHostPid
  if (-not (HostAlive $hostPid)) { Fail "hot host is not running" }
  if ($Offscreen) {
    Write-Output "generation 1 loaded offscreen; host pid=$hostPid"
  } else {
    Write-Output "generation 1 loaded; host pid=$hostPid"
  }

  if ($Offscreen) {
    # Leg 2. Rich frame vocabulary: every decoded command paints, no command
    # is unsupported, and the plugin clock advances instead of freezing at 0.
    $script:currentLeg = "leg 2 generation 1 rich frame"
    $richLine = WaitForFrameAfter -StartLine 1 -Label "generation 1 rich frame" -Seconds $timeout `
      -Needles @("Hot Reload Probe", "Count: 0", "Ticks: ", "Shared: shared alpha", "clock ")
    AssertKinds $richLine
    if ((ReadLogs) -match "unsupported=[1-9]") {
      Fail "a hot frame reported unsupported draw commands"
    }
    $tickBefore = LastTick
    $deadline = (Get-Date).AddSeconds(30)
    $tickAfter = $tickBefore
    while ((Get-Date) -lt $deadline) {
      $tickAfter = LastTick
      if ($tickAfter -gt $tickBefore) { break }
      Start-Sleep -Seconds 1
    }
    if ($tickAfter -le $tickBefore) { Fail "app timer ticks did not advance" }
    Write-Output "generation 1 frame vocabulary complete; ticks $tickBefore -> $tickAfter"

    # Leg 3. Inject a click at the probe's tap target. Count is opt-in
    # persisted model state, so it is the value that must survive the swap.
    $script:currentLeg = "leg 3 synthetic click"
    $injectStart = (LogLineCount) + 1
    $injectText = '{"kind":"pointer","phase":"Down","x":260,"y":180,"button":0,"id":1}' + "`n" +
      '{"kind":"pointer","phase":"Up","x":260,"y":180,"button":0,"id":1}' + "`n"
    [System.IO.File]::AppendAllText($injectFile, $injectText, [System.Text.UTF8Encoding]::new($false))
    WaitForFrameAfter -StartLine $injectStart -Label "injected click" -Seconds 60 `
      -Needles @("Count: 1") | Out-Null
    Write-Output "synthetic click reached the plugin (Count: 1)"

    # Leg 4. An app edit swaps the plugin inside the same host process; the
    # previously injected Count: 1 must still be there after generation 2.
    $script:currentLeg = "leg 4 generation 2 app edit"
    $closedBefore = ReloadCloseCount
    ReplaceFileText $app 'text\("Hot Reload Probe"\)' 'text("Hot Reload Probe smoke")' "generation 2"
    WaitForStatus "running" 2 "generation 2 reload"
    WaitForLog "hot plugin ready (generation 2" "generation 2 plugin"
    $gen2Line = FindLogLine "hot plugin ready (generation 2"
    WaitForFrameAfter -StartLine $gen2Line -Label "generation 2 state-preserved frame" -Seconds $timeout `
      -Needles @("Hot Reload Probe smoke", "Count: 1", "Shared: shared alpha") | Out-Null
    WaitForLog "reload-old FreeLibrary=1 rc=0 images=1" "Windows image unmap"
    WaitForLog "renderer caches reset after generation 2" "generation 2 cache reset"
    if ((FindHostPid) -ne $hostPid) { Fail "host pid changed across a reload" }
    if ((ReloadCloseCount) -le $closedBefore) { Fail "generation 2 did not close the previous image" }
    Write-Output "generation 2 loaded; host pid retained; pre-swap Count: 1 preserved"

    # Leg 5. Edit a package the app imports from outside the app module. The
    # watcher must rebuild from the dependency closure.
    $script:currentLeg = "leg 5 generation 3 widget edit"
    $closedBefore = ReloadCloseCount
    ReplaceFileText $widgets '"shared alpha"' '"shared beta"' "generation 3"
    WaitForStatus "running" 3 "generation 3 shared-package reload"
    WaitForLog "hot plugin ready (generation 3" "generation 3 plugin"
    $gen3Line = FindLogLine "hot plugin ready (generation 3"
    WaitForFrameAfter -StartLine $gen3Line -Label "generation 3 shared-widget frame" -Seconds $timeout `
      -Needles @("Hot Reload Probe smoke", "Count: 1", "Shared: shared beta") | Out-Null
    WaitForLog "renderer caches reset after generation 3" "generation 3 cache reset"
    if ((FindHostPid) -ne $hostPid) { Fail "host pid changed on the shared-package reload" }
    if ((ReloadCloseCount) -le $closedBefore) { Fail "generation 3 did not close the previous image" }
    Write-Output "generation 3 loaded from the imported widget package; host pid retained"

    # Leg 6. A compile error keeps generation 3 live and the host running.
    $script:currentLeg = "leg 6 compile error retention"
    $closedBefore = ReloadCloseCount
    ReplaceFileText $app 'count: model\.count \+ 1' 'count: model.count + hot_smoke_missing_symbol' "build error"
    WaitForStatus "error" 3 "build error"
    Start-Sleep -Seconds 1
    if (-not (HostAlive $hostPid)) { Fail "host exited on a build error" }
    if ((ReloadCloseCount) -ne $closedBefore) { Fail "host swapped a generation after a failed build" }
    $errorStart = (LogLineCount) + 1
    WaitForFrameAfter -StartLine $errorStart -Label "generation 3 survives the failed build" -Seconds 30 `
      -Needles @("Shared: shared beta", "Count: 1") | Out-Null
    Write-Output "build error kept generation 3 live with Count: 1"

    # Leg 7. Fixing the source recovers as generation 4 with the model intact.
    $script:currentLeg = "leg 7 generation 4 recovery"
    $closedBefore = ReloadCloseCount
    ReplaceFileText $app 'count: model\.count \+ hot_smoke_missing_symbol' 'count: model.count + 1' "generation 4 recovery"
    WaitForStatus "running" 4 "generation 4 recovery"
    WaitForLog "hot plugin ready (generation 4" "generation 4 plugin"
    $gen4Line = FindLogLine "hot plugin ready (generation 4"
    WaitForFrameAfter -StartLine $gen4Line -Label "generation 4 recovered frame" -Seconds $timeout `
      -Needles @("Hot Reload Probe smoke", "Shared: shared beta", "Count: 1") | Out-Null
    WaitForLog "renderer caches reset after generation 4" "generation 4 cache reset"
    if ((ReloadCloseCount) -le $closedBefore) { Fail "generation 4 did not close the previous image" }
    if ((FindHostPid) -ne $hostPid) { Fail "host pid changed during recovery" }
    Write-Output "generation 4 recovered; host pid retained; Count: 1 preserved"

    Write-Output "windows-hot-reload offscreen smoke passed"
  } else {
    # 1. A source edit swaps the plugin inside the same host process.
    $script:currentLeg = "leg 1 generation 2 reload"
    ReplaceApp 'text\("MoUI Counter"\)' 'text("MoUI Counter smoke")'
    WaitForStatus "running" 2 "generation 2 reload"
    WaitForLog "reload-old FreeLibrary=1 rc=0 images=1" "Windows image unmap"
    if ((FindHostPid) -ne $hostPid) { Fail "host pid changed across a reload" }
    Write-Output "generation 2 loaded; host pid retained"

    # 2. A compile error keeps the previous generation live and the host running.
    $script:currentLeg = "leg 2 compile error retention"
    $closedBefore = ReloadCloseCount
    ReplaceApp 'count: model\.count \+ 1' 'count: model.count + hot_smoke_missing_symbol'
    WaitForStatus "error" 2 "build error"
    Start-Sleep -Seconds 1
    if (-not (HostAlive $hostPid)) { Fail "host exited on a build error" }
    $closedAfter = ReloadCloseCount
    if ($closedAfter -ne $closedBefore) { Fail "host swapped a generation after a failed build" }
    Write-Output "build error kept generation 2 live"

    # 3. Fixing the source recovers with another in-place swap.
    $script:currentLeg = "leg 3 generation 3 recovery"
    ReplaceApp 'count: model\.count \+ hot_smoke_missing_symbol' 'count: model.count + 1'
    WaitForStatus "running" 3 "generation 3 recovery"
    if ((ReloadCloseCount) -le $closedAfter) { Fail "generation 3 did not close the previous image" }
    if ((FindHostPid) -ne $hostPid) { Fail "host pid changed during recovery" }
    Write-Output "generation 3 recovered; host pid retained"

    Write-Output "windows-hot-reload smoke passed"
  }
}
finally {
  if ($runner -and -not $runner.HasExited) {
    try { taskkill /PID $runner.Id /T /F | Out-Null } catch { }
  }
  if ($hostPid) {
    try { Stop-Process -Id $hostPid -Force -ErrorAction SilentlyContinue } catch { }
  }
  Copy-Item $appBackup $app -Force
  Remove-Item $appBackup -Force -ErrorAction SilentlyContinue
  if ($widgetsBackup) {
    Copy-Item $widgetsBackup $widgets -Force
    Remove-Item $widgetsBackup -Force -ErrorAction SilentlyContinue
  }
  if ($null -eq $savedOffscreen) {
    Remove-Item Env:MOUI_HOT_OFFSCREEN -ErrorAction SilentlyContinue
  } else {
    $env:MOUI_HOT_OFFSCREEN = $savedOffscreen
  }
  if ($null -eq $savedInject) {
    Remove-Item Env:MOUI_HOT_INJECT_FILE -ErrorAction SilentlyContinue
  } else {
    $env:MOUI_HOT_INJECT_FILE = $savedInject
  }
  if ($null -eq $savedTrace) {
    Remove-Item Env:MOUI_HOT_FRAME_TRACE_INTERVAL -ErrorAction SilentlyContinue
  } else {
    $env:MOUI_HOT_FRAME_TRACE_INTERVAL = $savedTrace
  }
}
