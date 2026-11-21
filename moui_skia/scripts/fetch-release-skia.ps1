param(
  [ValidateSet("auto", "macos", "linux", "windows", "android", "harmonyos", "ios", "iosSim", "tvos", "tvosSim", "wasm")]
  [string] $Platform = "auto",

  [ValidateSet("auto", "arm64", "x64", "riscv64")]
  [string] $Arch = "auto",

  [ValidateSet("Release", "Debug")]
  [string] $Config = "Release",

  [ValidateSet("static", "dynamic", "auto")]
  [string] $LinkMode = $(if ($env:MOUI_SKIA_LINK_MODE) { $env:MOUI_SKIA_LINK_MODE } else { "static" }),

  [string] $Tag = "",

  [string] $CacheDir = ".skia-cache/release",

  [string] $Mirror = $(if ($env:MOUI_SKIA_MIRROR) { $env:MOUI_SKIA_MIRROR } else { "auto" }),

  [switch] $NoMirror,

  [string] $Progress = $(if ($env:MOUI_SKIA_PROGRESS) { $env:MOUI_SKIA_PROGRESS } else { "auto" }),

  [switch] $NoProgress,

  [switch] $ListMirrors,

  [switch] $Probe,

  [string] $ProbeMode = $(if ($env:MOUI_SKIA_PROBE) { $env:MOUI_SKIA_PROBE } else { "auto" }),

  [switch] $NoProbe,

  [switch] $AutoProbe,

  [switch] $DryRunConfig,

  [switch] $PrintEnv,

  [switch] $Force
)

$ErrorActionPreference = "Stop"

if ($null -ne [Environment]::GetEnvironmentVariable("MOUI_SKIA_SKIA_LINK_MODE") -or
    $null -ne [Environment]::GetEnvironmentVariable("MOUI_SKIA_MACOS_LINK_MODE")) {
  throw "MOUI_SKIA_SKIA_LINK_MODE and MOUI_SKIA_MACOS_LINK_MODE are no longer supported; use MOUI_SKIA_LINK_MODE=dynamic|static|auto."
}

$mirrorMode = if ($NoMirror) { "off" } else { $Mirror }
if ([string]::IsNullOrWhiteSpace($mirrorMode)) {
  throw "-Mirror requires a mirror name (or use -NoMirror)."
}
$script:downloadSource = ""
$packageMirror = ""
$stubMirror = ""

$progressMode = if ($NoProgress) { "off" } else { $Progress }
if ([string]::IsNullOrWhiteSpace($progressMode)) {
  $progressMode = "auto"
}
if (@("auto", "off", "stderr", "tty") -notcontains $progressMode) {
  throw "unsupported -Progress mode: $progressMode (use auto|off|stderr|tty)"
}
$probeMode = if ($NoProbe) { "off" } elseif ($AutoProbe) { "auto" } else { $ProbeMode }
if ([string]::IsNullOrWhiteSpace($probeMode)) {
  $probeMode = "auto"
}
if (@("auto", "off") -notcontains $probeMode) {
  throw "unsupported -ProbeMode mode: $probeMode (use auto|off)"
}
if (($ListMirrors -or $Probe) -and $PrintEnv) {
  throw "-ListMirrors and -Probe cannot be combined with -PrintEnv"
}

# TLS 1.2 is not enabled by default in Windows PowerShell 5.1 on older images.
try {
  [System.Net.ServicePointManager]::SecurityProtocol =
    [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
} catch {
}

$script:UiWriter = $null
$script:UiIsTty = $false
$script:UiClearable = $false
$script:UiLastWidth = 0
$script:probeBestName = ""
$script:probeBestSpeed = 0.0
$script:probePrimarySpeed = 0.0
$script:probeCandidateCount = 0
$script:probeReportMode = "stdout"
$script:probeDone = $false
$script:preferredSource = ""

function Format-Bytes {
  param([double] $Bytes)
  if ($Bytes -lt 1024) { return ("{0:0} B" -f $Bytes) }
  $units = @("B", "KiB", "MiB", "GiB", "TiB")
  $index = 0
  while ($Bytes -ge 1024 -and $index -lt ($units.Count - 1)) {
    $Bytes = $Bytes / 1024
    $index++
  }
  return ("{0:0.0} {1}" -f $Bytes, $units[$index])
}

function Format-Seconds {
  param([double] $Seconds)
  $whole = [int][Math]::Round($Seconds)
  if ($whole -lt 60) { return ("{0:0.0}s" -f $Seconds) }
  if ($whole -lt 3600) { return ("{0}m{1:00}s" -f [int]($whole / 60), ($whole % 60)) }
  return ("{0}h{1:00}m" -f [int]($whole / 3600), [int](($whole % 3600) / 60))
}

function Write-Ui {
  param([string] $Message)
  if ($null -eq $script:UiWriter) { return }
  $script:UiWriter.Write($Message + "`n")
}

function Write-UiProgress {
  param([string] $Text)
  if ($null -eq $script:UiWriter -or -not $script:UiClearable) { return }
  $script:UiWriter.Write("`r" + $Text)
  $script:UiLastWidth = $Text.Length
}

function Clear-UiLine {
  if ($null -ne $script:UiWriter -and $script:UiClearable) {
    $width = [Math]::Max(1, $script:UiLastWidth)
    $script:UiWriter.Write("`r" + (" " * $width) + "`r")
    $script:UiLastWidth = 0
  }
}

function Initialize-UiChannel {
  $script:UiWriter = $null
  $script:UiIsTty = $false
  $script:UiClearable = $false
  if ($progressMode -eq "off") { return }
  $stderrIsTty = -not [Console]::IsErrorRedirected
  if ($progressMode -eq "stderr" -or $stderrIsTty) {
    $script:UiWriter = [Console]::Error
    $script:UiIsTty = $stderrIsTty
    $script:UiClearable = $stderrIsTty
    return
  }
  # A prebuild hook may capture stderr, so live progress goes straight to the
  # console device when one is attached.
  $consolePath = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') { "CONOUT$" } else { "/dev/tty" }
  try {
    $stream = [System.IO.File]::Open(
      $consolePath,
      [System.IO.FileMode]::Open,
      [System.IO.FileAccess]::Write,
      [System.IO.FileShare]::ReadWrite)
    $writer = New-Object System.IO.StreamWriter($stream)
    $writer.AutoFlush = $true
    $script:UiWriter = $writer
    $script:UiIsTty = $true
    $script:UiClearable = $true
    return
  } catch {
    if ($progressMode -eq "tty") {
      [Console]::Error.WriteLine("note: -Progress tty requested but no console is available; writing progress to stderr")
    }
    $script:UiWriter = [Console]::Error
    $script:UiIsTty = $false
    $script:UiClearable = $false
  }
}

Initialize-UiChannel

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot "skia-provider-lock.json"

function Resolve-RepoPath {
  param([Parameter(Mandatory = $true)][string] $Path)
  if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
  return Join-Path $repoRoot $Path
}

function Get-HostPlatform {
  if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)) { return "macos" }
  if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)) { return "linux" }
  if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) { return "windows" }
  throw "cannot auto-detect Skia release platform"
}

function Get-HostArch {
  switch ([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString().ToLowerInvariant()) {
    "arm64" { return "arm64" }
    "x64" { return "x64" }
    "amd64" { return "x64" }
    default { throw "cannot auto-detect Skia release architecture: $([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture)" }
  }
}

function Get-JsonPropertyValue {
  param([Parameter(Mandatory = $true)][object] $Object, [Parameter(Mandatory = $true)][string] $Name)
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}

function Find-HeaderRoot {
  param([Parameter(Mandatory = $true)][string] $Root)
  if (!(Test-Path -LiteralPath $Root -PathType Container)) { return $null }
  $header = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter "SkSurface.h" -ErrorAction SilentlyContinue |
    Where-Object { ($_.FullName -replace "\\", "/") -like "*/include/core/SkSurface.h" } |
    Select-Object -First 1
  if (!$header) { return $null }
  $full = $header.FullName -replace "\\", "/"
  return $full.Substring(0, $full.Length - "/include/core/SkSurface.h".Length)
}

function Find-LibDir {
  param(
    [Parameter(Mandatory = $true)][string] $Root,
    [Parameter(Mandatory = $true)][object] $LibraryNames
  )
  if (!(Test-Path -LiteralPath $Root -PathType Container)) { return $null }
  $names = @($LibraryNames) + @("libskia.a", "libskia.so", "libskia.dylib", "skia.lib")
  foreach ($name in $names) {
    $lib = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($lib) { return ($lib.DirectoryName -replace "\\", "/") }
  }
  return $null
}

function Find-LibFile {
  param(
    [Parameter(Mandatory = $true)][string] $Root,
    [Parameter(Mandatory = $true)][object] $LibraryNames
  )
  if (!(Test-Path -LiteralPath $Root -PathType Container)) { return $null }
  foreach ($name in @($LibraryNames)) {
    if (!$name) { continue }
    $lib = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($lib) { return ($lib.FullName -replace "\\", "/") }
  }
  return $null
}

function Download-File {
  param(
    [Parameter(Mandatory = $true)][string] $Url,
    [Parameter(Mandatory = $true)][string] $Output,
    [string] $Label = "Skia release file",
    [string] $SourceName = "primary",
    [string] $ExpectedSha256 = "",
    [string] $ExpectedSize = ""
  )
  $parent = Split-Path -Parent $Output
  if ($parent.Length -gt 0) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  [Console]::Error.WriteLine("Downloading $($Label):")
  [Console]::Error.WriteLine("  url=$Url")
  [Console]::Error.WriteLine("  output=$Output")
  if ($ExpectedSize) { [Console]::Error.WriteLine("  expected_size=$ExpectedSize") }
  if ($ExpectedSha256) { [Console]::Error.WriteLine("  expected_sha256=$ExpectedSha256") }

  # Invoke-WebRequest buffers the whole body, so a slow mirror shows nothing for
  # minutes and a 44 MiB archive is held in memory twice. Stream it instead and
  # report bytes, percent, and throughput while the transfer runs.
  $attempts = 3
  $attempt = 0
  $failure = ""
  while ($attempt -lt $attempts) {
    $attempt++
    $existing = 0L
    if (Test-Path -LiteralPath $Output -PathType Leaf) {
      $existing = (Get-Item -LiteralPath $Output).Length
    }
    $mode = if ($existing -gt 0) { "resume" } else { "fresh" }
    [Console]::Error.WriteLine("  mode=$mode")
    Write-Ui "  [skia] fetching $($Label) from $($SourceName)"
    Write-Ui "         url=$Url"

    $request = $null
    $response = $null
    $inputStream = $null
    $outputStream = $null
    $started = [DateTime]::UtcNow
    $received = $existing
    $httpCode = 0
    $total = -1L
    $success = $false
    $retryable = $true
    try {
      $request = [System.Net.WebRequest]::Create($Url)
      $request.Method = "GET"
      $request.Timeout = 30000
      if ($request -is [System.Net.HttpWebRequest]) {
        $request.AllowAutoRedirect = $true
        $request.UserAgent = "moui-skia-fetch/1.0"
        $request.Headers.Add("Accept-Encoding", "identity")
        if ($null -ne $request.PSObject.Properties["ReadWriteTimeout"]) {
          $request.ReadWriteTimeout = 60000
        }
        if ($existing -gt 0) { $request.AddRange([long]$existing) }
      }
      $response = $request.GetResponse()
      if ($null -ne $response.PSObject.Properties["StatusCode"]) {
        $httpCode = [int]$response.StatusCode
      }
      $contentLength = $response.ContentLength
      $total = $contentLength
      if ($existing -gt 0 -and $httpCode -ne 206) {
        # The server ignored `Range`; rewrite the file from the start.
        $existing = 0L
        $received = 0L
        $mode = "fresh"
        $outputStream = [System.IO.File]::Create($Output)
      } elseif ($existing -gt 0) {
        if ($contentLength -ge 0) { $total = $existing + $contentLength }
        $outputStream = New-Object System.IO.FileStream(
          $Output,
          [System.IO.FileMode]::Append,
          [System.IO.FileAccess]::Write,
          [System.IO.FileShare]::None)
      } else {
        $outputStream = [System.IO.File]::Create($Output)
      }
      $inputStream = $response.GetResponseStream()
      $buffer = New-Object byte[] (128 * 1024)
      $lastReport = [DateTime]::UtcNow
      while (($read = $inputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $outputStream.Write($buffer, 0, $read)
        $received += $read
        if ($script:UiClearable) {
          $now = [DateTime]::UtcNow
          if (($now - $lastReport).TotalMilliseconds -ge 250) {
            $soFar = ($now - $started).TotalSeconds
            $rate = if ($soFar -gt 0) { $received / $soFar } else { 0 }
            if ($total -gt 0) {
              $percent = [Math]::Min(100.0, 100.0 * $received / $total)
              Write-UiProgress ("  [skia] {0,5:0.0}%  {1} / {2}  {3}/s" -f $percent, (Format-Bytes $received), (Format-Bytes $total), (Format-Bytes $rate))
            } else {
              Write-UiProgress ("  [skia] {0}  {1}/s" -f (Format-Bytes $received), (Format-Bytes $rate))
            }
            $lastReport = $now
          }
        }
      }
      $success = $true
    } catch {
      $failure = $_.Exception.Message
      $webResponse = $null
      if ($_.Exception -is [System.Net.WebException]) { $webResponse = $_.Exception.Response }
      if ($null -ne $webResponse) {
        if ($null -ne $webResponse.PSObject.Properties["StatusCode"]) {
          $statusCode = [int]$webResponse.StatusCode
          if ($statusCode -ge 400 -and $statusCode -lt 500 -and $statusCode -ne 408 -and $statusCode -ne 429) {
            $retryable = $false
          }
        }
      }
    } finally {
      if ($null -ne $outputStream) { $outputStream.Dispose() }
      if ($null -ne $inputStream) { $inputStream.Dispose() }
      if ($null -ne $response) { $response.Dispose() }
    }
    Clear-UiLine
    if ($success) {
      $elapsed = [Math]::Max(0.001, ([DateTime]::UtcNow - $started).TotalSeconds)
      $speed = $received / $elapsed
      Write-Ui ("  [skia] {0}: received {1} in {2} ({3}/s, http {4}) from {5}" -f $mode, (Format-Bytes $received), (Format-Seconds $elapsed), (Format-Bytes $speed), $httpCode, $SourceName)
      return
    }
    if (!$retryable) { break }
    if ($attempt -lt $attempts) {
      [Console]::Error.WriteLine("  attempt $attempt of $attempts failed: $failure; retrying in 2s")
      Start-Sleep -Seconds 2
    }
  }
  Write-Ui ("  [skia] download failed from {0} ({1})" -f $SourceName, $failure)
  throw "download failed from $Url : $failure"
}

function Get-MirrorCandidates {
  param(
    [Parameter(Mandatory = $true)][object] $Provider,
    [Parameter(Mandatory = $true)][string] $Scope,
    [Parameter(Mandatory = $true)][string] $ArtifactName,
    [string] $PrimaryUrl = ""
  )
  $candidates = @()
  if ([string]::IsNullOrWhiteSpace($ArtifactName)) { return $candidates }
  $mirrors = Get-JsonPropertyValue -Object $Provider -Name "mirrors"
  if (!$mirrors) { return $candidates }
  foreach ($mirror in @($mirrors)) {
    $mirrorScope = Get-JsonPropertyValue -Object $mirror -Name "scope"
    if ($mirrorScope -is [string]) { $mirrorScope = @($mirrorScope) }
    if (@($mirrorScope) -notcontains $Scope) { continue }
    $name = Get-JsonPropertyValue -Object $mirror -Name "name"
    if ([string]::IsNullOrWhiteSpace($name)) { continue }
    $platforms = Get-JsonPropertyValue -Object $mirror -Name "platforms"
    if ($platforms -and (@($platforms) -notcontains $resolvedPlatform)) { continue }
    $configs = Get-JsonPropertyValue -Object $mirror -Name "configs"
    if ($configs -and (@($configs) -notcontains $Config)) { continue }
    $arches = Get-JsonPropertyValue -Object $mirror -Name "arches"
    if ($arches -and (@($arches) -notcontains $resolvedArch)) { continue }
    $linkModes = Get-JsonPropertyValue -Object $mirror -Name "link_modes"
    if ($linkModes -and (@($linkModes) -notcontains $resolvedLinkMode)) { continue }
    $kind = Get-JsonPropertyValue -Object $mirror -Name "kind"
    if ([string]::IsNullOrWhiteSpace($kind)) { $kind = "release-download" }
    if ($kind -eq "release-download") {
      $baseUrl = Get-JsonPropertyValue -Object $mirror -Name "base_url"
      if ([string]::IsNullOrWhiteSpace($baseUrl)) { continue }
      $url = $baseUrl.Replace("{tag}", $Tag) + $ArtifactName
    } elseif ($kind -eq "url-prefix") {
      $prefix = Get-JsonPropertyValue -Object $mirror -Name "prefix"
      if ([string]::IsNullOrWhiteSpace($prefix) -or [string]::IsNullOrWhiteSpace($PrimaryUrl)) { continue }
      $url = $prefix + $PrimaryUrl
    } else {
      continue
    }
    $candidates += [pscustomobject]@{
      Name = $name
      Url  = $url
    }
  }
  return $candidates
}

function Get-CandidateOrder {
  param(
    [string] $PrimaryUrl = "",
    [object[]] $MirrorCandidates = @(),
    [Parameter(Mandatory = $true)][string] $Mode
  )
  $preferred = @()
  $others = @()
  $matched = $false
  if ($Mode -ne "off") {
    foreach ($candidate in $MirrorCandidates) {
      if ($Mode -eq "auto") {
        # The automatic probe reorders the candidates: the fastest measured source
        # is tried first, and a prefix match keeps a sibling entry (e.g. the stub
        # hosted next to the package) on the same source.
        if (![string]::IsNullOrEmpty($script:preferredSource) -and
          ($candidate.Name -eq $script:preferredSource -or $candidate.Name.StartsWith("$($script:preferredSource)-"))) {
          $preferred += $candidate
        } else {
          $others += $candidate
        }
      } elseif ($candidate.Name -eq $Mode -or $candidate.Name.StartsWith("$Mode-")) {
        $preferred += $candidate
        $matched = $true
      } else {
        $others += $candidate
      }
    }
  }
  if ($Mode -ne "auto" -and $Mode -ne "off" -and !$matched) {
    [Console]::Error.WriteLine("note: mirror $Mode does not serve this artifact; using the primary host and the remaining mirrors")
  }
  $ordered = @()
  if ($Mode -ne "off" -and $preferred.Count -gt 0) { $ordered += $preferred }
  if (![string]::IsNullOrWhiteSpace($PrimaryUrl)) { $ordered += [pscustomobject]@{ Name = "primary"; Url = $PrimaryUrl } }
  if ($others.Count -gt 0) { $ordered += $others }
  return $ordered
}

function Get-CandidateNames {
  param([object[]] $Candidates = @())
  return (($Candidates | ForEach-Object { $_.Name }) -join ",")
}

# Every recorded candidate in discovery order (primary first), regardless of the
# active mirror mode. -ListMirrors and -Probe use it so a user can see and
# measure sources that the current mode would not try.
function Get-AllCandidates {
  param(
    [string] $PrimaryUrl = "",
    [object[]] $MirrorCandidates = @()
  )
  $all = @()
  if (![string]::IsNullOrWhiteSpace($PrimaryUrl)) {
    $all += [pscustomobject]@{ Name = "primary"; Url = $PrimaryUrl }
  }
  if ($MirrorCandidates.Count -gt 0) { $all += $MirrorCandidates }
  return $all
}

function Write-ProbeLine {
  param([string] $Message = "")
  # -Probe and -ListMirrors report on stdout; the automatic probe goes through
  # the progress channel so -PrintEnv's stdout stays machine-readable.
  if ($script:probeReportMode -eq "ui") {
    Write-Ui $Message
  } else {
    Write-Output $Message
  }
}

function Show-MirrorSources {
  param(
    [Parameter(Mandatory = $true)][string] $Label,
    [string] $PrimaryUrl = "",
    [object[]] $MirrorCandidates = @()
  )
  $candidates = @(Get-AllCandidates -PrimaryUrl $PrimaryUrl -MirrorCandidates $MirrorCandidates)
  Write-ProbeLine $Label
  if ($candidates.Count -eq 0) {
    Write-ProbeLine "  (none recorded)"
    return
  }
  foreach ($candidate in $candidates) {
    $marker = ""
    if ($mirrorMode -ne "auto" -and $mirrorMode -ne "off" -and
      ($candidate.Name -eq $mirrorMode -or $candidate.Name.StartsWith("$mirrorMode-"))) {
      $marker = "  (preferred by -Mirror $mirrorMode)"
    }
    Write-ProbeLine ("  {0,-26} {1}{2}" -f $candidate.Name, $candidate.Url, $marker)
  }
}

# Measure connection setup, time to first byte, and throughput over a bounded
# 256 KiB range. It is deliberately approximate: no archive is written, and a
# slow mirror is only ever a suggestion, since the real download still has to
# pass SHA256 and size verification.
function Invoke-ProbeCandidate {
  param(
    [Parameter(Mandatory = $true)][string] $Name,
    [Parameter(Mandatory = $true)][string] $Url
  )
  $request = $null
  $response = $null
  $stream = $null
  $started = [DateTime]::UtcNow
  $httpCode = 0
  $bytes = 0L
  $ttfb = 0.0
  $failure = ""
  $cutOff = $false
  try {
    $request = [System.Net.WebRequest]::Create($Url)
    $request.Method = "GET"
    $request.Timeout = 8000
    if ($request -is [System.Net.HttpWebRequest]) {
      $request.AllowAutoRedirect = $true
      $request.UserAgent = "moui-skia-fetch/1.0"
      $request.Headers.Add("Accept-Encoding", "identity")
      if ($null -ne $request.PSObject.Properties["ReadWriteTimeout"]) {
        $request.ReadWriteTimeout = 8000
      }
      $request.AddRange([long]0, [long]262143)
    }
    $response = $request.GetResponse()
    if ($null -ne $response.PSObject.Properties["StatusCode"]) {
      $httpCode = [int]$response.StatusCode
    }
    $contentLength = $response.ContentLength
    if ($httpCode -ge 400) {
      Write-ProbeLine ("  {0,-26} failed (http={1})" -f $Name, $httpCode)
      return
    }
    if ($httpCode -eq 200 -and $contentLength -gt 16777216) {
      Write-ProbeLine ("  {0,-26} skipped (too large and does not honor Range; try it directly with -Mirror {1})" -f $Name, $Name)
      return
    }
    $stream = $response.GetResponseStream()
    $buffer = New-Object byte[] (64 * 1024)
    $firstRead = $true
    while ($bytes -lt 262144) {
      $want = [int][Math]::Min([long]$buffer.Length, [long](262144 - $bytes))
      $read = $stream.Read($buffer, 0, $want)
      if ($read -le 0) { break }
      if ($firstRead) {
        $ttfb = ([DateTime]::UtcNow - $started).TotalSeconds
        $firstRead = $false
      }
      $bytes += $read
    }
    if ($bytes -ge 262144) { $cutOff = $true }
  } catch {
    $failure = $_.Exception.Message
  } finally {
    if ($null -ne $stream) { $stream.Dispose() }
    if ($null -ne $response) { $response.Dispose() }
  }
  $elapsed = [Math]::Max(0.001, ([DateTime]::UtcNow - $started).TotalSeconds)
  if ($failure -and $bytes -eq 0) {
    Write-ProbeLine ("  {0,-26} failed ({1})" -f $Name, $failure)
    return
  }
  $speed = $bytes / $elapsed
  $suffix = if ($failure -or $cutOff) { "  (probe cut off)" } else { "" }
  Write-ProbeLine ("  {0,-26} http={1}  ttfb={2:0.00}s  {3} in {4}  {5}/s{6}" -f `
      $Name, $httpCode, $ttfb, (Format-Bytes $bytes), (Format-Seconds $elapsed), (Format-Bytes $speed), $suffix)
  if ($speed -gt $script:probeBestSpeed) {
    $script:probeBestName = $Name
    $script:probeBestSpeed = $speed
  }
  if ($Name -eq "primary") { $script:probePrimarySpeed = $speed }
}

# Probe every recorded candidate once and record the fastest one in the probe_*
# globals. $script:probeCandidateCount tells the callers whether the lock records
# any source at all.
function Invoke-ProbeAllCandidates {
  param(
    [string] $PrimaryUrl = "",
    [object[]] $MirrorCandidates = @()
  )
  $script:probeBestName = ""
  $script:probeBestSpeed = 0.0
  $script:probePrimarySpeed = 0.0
  $candidates = @(Get-AllCandidates -PrimaryUrl $PrimaryUrl -MirrorCandidates $MirrorCandidates)
  $script:probeCandidateCount = $candidates.Count
  foreach ($candidate in $candidates) {
    Invoke-ProbeCandidate -Name $candidate.Name -Url $candidate.Url
  }
}

# -Probe writes its report on stdout and downloads nothing.
function Invoke-Probe {
  param(
    [Parameter(Mandatory = $true)][string] $Label,
    [string] $PrimaryUrl = "",
    [object[]] $MirrorCandidates = @()
  )
  $script:probeReportMode = "stdout"
  Write-ProbeLine ("Probing {0}: first 256 KiB from each candidate (max 25s each)." -f $Label)
  Invoke-ProbeAllCandidates -PrimaryUrl $PrimaryUrl -MirrorCandidates $MirrorCandidates
  if ($script:probeCandidateCount -eq 0) {
    Write-ProbeLine "  (no download source is recorded)"
    return
  }
  Write-ProbeLine ""
  if ([string]::IsNullOrEmpty($script:probeBestName)) {
    Write-ProbeLine "No candidate answered the probe; the default order still verifies every source."
    return
  }
  if ($script:probeBestName -eq "primary") {
    Write-ProbeLine ("Fastest probe: primary host ({0}/s). The default auto order already tries it first." -f (Format-Bytes $script:probeBestSpeed))
  } elseif ($script:probeBestSpeed -gt ($script:probePrimarySpeed * 1.15)) {
    Write-ProbeLine ("Fastest probe: {0} ({1}/s). Prefer it with:" -f $script:probeBestName, (Format-Bytes $script:probeBestSpeed))
    Write-ProbeLine ('  $env:MOUI_SKIA_MIRROR={0}; ./fetch-release-skia.ps1' -f $script:probeBestName)
    Write-ProbeLine ('  # or: ./fetch-release-skia.ps1 -Mirror {0}' -f $script:probeBestName)
  } else {
    Write-ProbeLine ("Fastest probe: {0} ({1}/s), close to the primary host." -f $script:probeBestName, (Format-Bytes $script:probeBestSpeed))
  }
  Write-ProbeLine "Note: the probe only measures the first 256 KiB; the real download still verifies the full SHA256 and size."
}

# The automatic probe runs once per invocation before a large download. It
# reports through the progress channel (stdout is reserved for -PrintEnv) and
# only reorders the candidates: every download still verifies SHA256 and size.
function Invoke-AutoProbe {
  param(
    [Parameter(Mandatory = $true)][string] $Label,
    [string] $PrimaryUrl = "",
    [object[]] $MirrorCandidates = @()
  )
  $script:probeReportMode = "ui"
  Write-Ui "  [skia] probing $Label (first 256 KiB from each recorded source)"
  Invoke-ProbeAllCandidates -PrimaryUrl $PrimaryUrl -MirrorCandidates $MirrorCandidates
  if ($script:probeCandidateCount -eq 0) {
    Write-Ui "  [skia] no download source is recorded; keeping the default order"
  } elseif ([string]::IsNullOrEmpty($script:probeBestName)) {
    Write-Ui "  [skia] probe answered nothing; keeping the default order"
  } elseif ($script:probeBestName -eq "primary") {
    Write-Ui ("  [skia] fastest source: primary host ({0}/s)" -f (Format-Bytes $script:probeBestSpeed))
  } else {
    $script:preferredSource = $script:probeBestName
    Write-Ui ("  [skia] fastest source: {0} ({1}/s); trying it first" -f $script:probeBestName, (Format-Bytes $script:probeBestSpeed))
  }
  $script:probeReportMode = "stdout"
}

function Download-Artifact {
  param(
    [Parameter(Mandatory = $true)][string] $Label,
    [Parameter(Mandatory = $true)][string] $Output,
    [string] $ExpectedSha256 = "",
    [string] $ExpectedSize = "",
    [string] $PrimaryUrl = "",
    [object[]] $MirrorCandidates = @()
  )
  $script:downloadSource = ""
  # Automatic speed probe: default in auto mirror mode, at most once per run,
  # and only for an asset worth measuring (a tiny stub keeps the plain order).
  $expectedSizeBytes = 0L
  if (![string]::IsNullOrWhiteSpace($ExpectedSize)) {
    [long]::TryParse($ExpectedSize, [ref]$expectedSizeBytes) | Out-Null
  }
  if ($probeMode -eq "auto" -and $mirrorMode -eq "auto" -and !$script:probeDone -and
    $MirrorCandidates.Count -gt 0 -and
    ([string]::IsNullOrWhiteSpace($ExpectedSize) -or $expectedSizeBytes -ge 4194304)) {
    $script:probeDone = $true
    Invoke-AutoProbe -Label $Label -PrimaryUrl $PrimaryUrl -MirrorCandidates $MirrorCandidates
  }
  $candidates = @(Get-CandidateOrder -PrimaryUrl $PrimaryUrl -MirrorCandidates $MirrorCandidates -Mode $mirrorMode)
  if ($candidates.Count -eq 0) {
    [Console]::Error.WriteLine("no download candidate is recorded for $Label")
    return $false
  }
  $first = $true
  foreach ($candidate in $candidates) {
    if (!$first -and (Test-Path -LiteralPath $Output -PathType Leaf)) { Remove-Item -LiteralPath $Output -Force }
    $first = $false
    [Console]::Error.WriteLine("  candidate=$($candidate.Name)")
    try {
      Download-File -Url $candidate.Url -Output $Output -Label $Label -SourceName $candidate.Name `
        -ExpectedSha256 $ExpectedSha256 -ExpectedSize $ExpectedSize
    } catch {
      [Console]::Error.WriteLine("download failed from $($candidate.Url); trying the next candidate")
      Write-Ui "  [skia] $($candidate.Name) failed; trying the next source"
      if (Test-Path -LiteralPath $Output -PathType Leaf) { Remove-Item -LiteralPath $Output -Force }
      continue
    }
    $actualSha256 = Get-Sha256Hex -Path $Output
    if ($ExpectedSha256 -and $actualSha256 -ne $ExpectedSha256.ToLowerInvariant()) {
      [Console]::Error.WriteLine("SHA256 mismatch from $($candidate.Url)")
      [Console]::Error.WriteLine("  expected=$ExpectedSha256")
      [Console]::Error.WriteLine("  actual=$actualSha256")
      Write-Ui "  [skia] $($candidate.Name) returned a file with the wrong SHA256; trying the next source"
      Remove-Item -LiteralPath $Output -Force
      continue
    }
    $actualSize = 0L
    if (Test-Path -LiteralPath $Output -PathType Leaf) {
      $actualSize = (Get-Item -LiteralPath $Output).Length
    }
    if ($ExpectedSize -and "$actualSize" -ne "$ExpectedSize") {
      [Console]::Error.WriteLine("size mismatch from $($candidate.Url)")
      [Console]::Error.WriteLine("  expected=$ExpectedSize")
      [Console]::Error.WriteLine("  actual=$actualSize")
      Write-Ui "  [skia] $($candidate.Name) returned the wrong size; trying the next source"
      Remove-Item -LiteralPath $Output -Force
      continue
    }
    $script:downloadSource = $candidate.Name
    [Console]::Error.WriteLine("  verified_from=$($candidate.Name)")
    Write-Ui ("  [skia] verified {0} from {1}" -f (Format-Bytes $actualSize), $candidate.Name)
    return $true
  }
  [Console]::Error.WriteLine("could not download $Label from any recorded source")
  Write-Ui "  [skia] all recorded sources failed for $Label"
  return $false
}

function Expand-ZipArchive {
  param([Parameter(Mandatory = $true)][string] $Archive, [Parameter(Mandatory = $true)][string] $Destination)
  New-Item -ItemType Directory -Force -Path $Destination | Out-Null
  # Windows runners ship bsdtar; prefer it over Expand-Archive, whose
  # ExtractToDirectory overload breaks on some PowerShell/.NET image updates.
  $tar = Get-Command tar.exe -ErrorAction SilentlyContinue
  if ($null -ne $tar) {
    & $tar.Source -xf $Archive -C $Destination
    if ($LASTEXITCODE -ne 0) {
      throw "tar extraction failed for $Archive (exit $LASTEXITCODE)"
    }
    return
  }
  Expand-Archive -LiteralPath $Archive -DestinationPath $Destination -Force
}

function Get-Sha256Hex {
  param([Parameter(Mandatory = $true)][string] $Path)
  if (Get-Command Get-FileHash -ErrorAction SilentlyContinue) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
  }

  $stream = [System.IO.File]::OpenRead($Path)
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  try {
    $hashBytes = $sha256.ComputeHash($stream)
    return ([System.BitConverter]::ToString($hashBytes) -replace "-", "").ToLowerInvariant()
  } finally {
    $sha256.Dispose()
    $stream.Dispose()
  }
}

if (!(Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
  throw "Skia release provider manifest is missing: $manifestPath"
}

$resolvedPlatform = $Platform
if ($resolvedPlatform -eq "auto") { $resolvedPlatform = Get-HostPlatform }

$resolvedArch = $Arch
if ($resolvedPlatform -eq "wasm") {
  if ($resolvedArch -ne "auto") { throw "-Platform wasm only supports -Arch auto with the wasm manifest asset" }
  $resolvedArch = "wasm"
} elseif ($resolvedArch -eq "auto") {
  $resolvedArch = Get-HostArch
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$providers = $manifest.providers
$providerKey = "release"
if ($resolvedPlatform -eq "harmonyos" -and (Get-JsonPropertyValue -Object $providers -Name "harmonyos_release")) {
  $providerKey = "harmonyos_release"
}
$provider = Get-JsonPropertyValue -Object $providers -Name $providerKey
if (!$provider) { throw "skia-provider-lock.json is missing providers.$providerKey" }
if ([string]::IsNullOrWhiteSpace($Tag)) { $Tag = $provider.tag }
if ($provider.tag -ne $Tag) { throw "manifest provider $providerKey only locks release tag $($provider.tag), requested $Tag" }

$platformAssets = Get-JsonPropertyValue -Object $provider.assets -Name $resolvedPlatform
if (!$platformAssets) { throw "manifest has no release assets for platform=$resolvedPlatform" }
$configAssets = Get-JsonPropertyValue -Object $platformAssets -Name $Config
if (!$configAssets) { throw "manifest has no release assets for platform=$resolvedPlatform config=$Config" }
$archAssets = Get-JsonPropertyValue -Object $configAssets -Name $resolvedArch
if (!$archAssets) { throw "manifest has no release asset for platform=$resolvedPlatform config=$Config arch=$resolvedArch" }

$resolvedLinkMode = $LinkMode
if ($resolvedLinkMode -eq "auto") {
  $resolvedLinkMode = if (Get-JsonPropertyValue -Object $archAssets -Name "dynamic") { "dynamic" } else { "static" }
}
$asset = Get-JsonPropertyValue -Object $archAssets -Name $resolvedLinkMode
if (!$asset) { throw "manifest has no $resolvedLinkMode release asset for platform=$resolvedPlatform config=$Config arch=$resolvedArch" }

$assetName = $asset.name
$assetSha256 = $asset.sha256.ToLowerInvariant()
$assetSize = $asset.size
$assetUrl = $asset.url
$sourceName = if ($provider.source_archive.name) { $provider.source_archive.name } else { "$($provider.owner)-$($provider.repo)-$Tag-source.zip" }
$sourceUrl = if ($provider.source_archive.url) { $provider.source_archive.url } else { "https://github.com/$($provider.owner)/$($provider.repo)/archive/refs/tags/$Tag.zip" }
$libraryNames = @($asset.library_names)
$stubEntry = $null
$stubLibraries = Get-JsonPropertyValue -Object $provider -Name "stub_libraries"
if ($stubLibraries) {
  $stubPlatform = Get-JsonPropertyValue -Object $stubLibraries -Name $resolvedPlatform
  if ($stubPlatform) {
    $stubConfig = Get-JsonPropertyValue -Object $stubPlatform -Name $Config
    if ($stubConfig) { $stubEntry = Get-JsonPropertyValue -Object $stubConfig -Name $resolvedArch }
  }
}
$stubName = ""
$stubSha256 = ""
$stubSize = ""
$stubUrl = ""
$stubSourcesSha256 = ""
$stubLibraryNames = @()
if ($stubEntry) {
  $stubName = $stubEntry.name
  $stubSha256 = $stubEntry.sha256.ToLowerInvariant()
  $stubSize = $stubEntry.size
  $stubUrl = $stubEntry.url
  $stubSourcesSha256 = $stubEntry.sources_sha256
  $stubLibraryNames = @($stubEntry.library_names)
}
$extraCcFlags = Get-JsonPropertyValue -Object $provider.default_extra_cc_flags -Name $resolvedPlatform
if ($null -eq $extraCcFlags) { $extraCcFlags = "" }
$extraLinkFlags = Get-JsonPropertyValue -Object $provider.default_extra_link_flags -Name $resolvedPlatform
if ($null -eq $extraLinkFlags) { $extraLinkFlags = "" }
$packageMirrorCandidates = @(Get-MirrorCandidates -Provider $provider -Scope "skia" -ArtifactName $assetName -PrimaryUrl $assetUrl)
$sourceMirrorCandidates = @(Get-MirrorCandidates -Provider $provider -Scope "source" -ArtifactName $sourceName -PrimaryUrl $sourceUrl)
$stubMirrorCandidates = @()
if ($stubName) {
  $stubMirrorCandidates = @(Get-MirrorCandidates -Provider $provider -Scope "stub" -ArtifactName $stubName -PrimaryUrl $stubUrl)
}

$resolvedCacheDir = Resolve-RepoPath $CacheDir
$tagDir = Join-Path $resolvedCacheDir $Tag
$entryDir = Join-Path $tagDir "$resolvedPlatform-$Config-$resolvedArch-$resolvedLinkMode"
$packageZip = Join-Path $entryDir $assetName
$packageDir = Join-Path $entryDir "package"
$sourceDir = Join-Path $tagDir "source"
$sourceZip = Join-Path $tagDir $sourceName
$stubEntryDir = Join-Path $tagDir "$resolvedPlatform-$Config-$resolvedArch-stub"
$stubZip = Join-Path $stubEntryDir $stubName
$stubDir = Join-Path $stubEntryDir "package"

if ($ListMirrors) {
  Write-Output ("Skia download sources (mirror mode: {0})" -f $mirrorMode)
  Write-Output ""
  Show-MirrorSources -Label "release asset: $assetName" -PrimaryUrl $assetUrl -MirrorCandidates $packageMirrorCandidates
  Write-Output ""
  Show-MirrorSources -Label "source archive: $sourceName" -PrimaryUrl $sourceUrl -MirrorCandidates $sourceMirrorCandidates
  Write-Output ""
  if ($stubName) {
    Show-MirrorSources -Label "stub library: $stubName" -PrimaryUrl $stubUrl -MirrorCandidates $stubMirrorCandidates
  } else {
    Write-Output ("stub library: not published for {0}-{1}-{2} (native/*.cpp compiles locally)" -f $resolvedPlatform, $Config, $resolvedArch)
  }
  Write-Output ""
  Write-Output 'Pick a source with -Mirror <name> or $env:MOUI_SKIA_MIRROR=<name>; -NoMirror keeps the primary host only.'
  exit 0
}

if ($Probe) {
  Invoke-Probe -Label "Skia release asset $assetName" -PrimaryUrl $assetUrl -MirrorCandidates $packageMirrorCandidates
  exit 0
}

if (!$DryRunConfig) {
  if ($Force -or !(Test-Path -LiteralPath $packageDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $entryDir | Out-Null
    if (Test-Path -LiteralPath $packageZip -PathType Leaf) {
      $cachedSha256 = Get-Sha256Hex -Path $packageZip
      if ($cachedSha256 -ne $assetSha256) {
        [Console]::Error.WriteLine("cached Skia release asset SHA256 mismatch; re-downloading: $packageZip expected=$assetSha256 actual=$cachedSha256")
        Remove-Item -LiteralPath $packageZip -Force
      }
    }
    if (!(Test-Path -LiteralPath $packageZip -PathType Leaf)) {
      [Console]::Error.WriteLine("Downloading Skia release asset: $assetName")
      $downloaded = Download-Artifact -Label "Skia release asset $assetName" -Output $packageZip `
        -ExpectedSha256 $assetSha256 -ExpectedSize "$assetSize" `
        -PrimaryUrl $assetUrl -MirrorCandidates $packageMirrorCandidates
      if (!$downloaded) { throw "could not download the Skia release asset: $assetName" }
      if ($script:downloadSource -ne "primary") { $packageMirror = $script:downloadSource }
    }
    Expand-ZipArchive -Archive $packageZip -Destination $packageDir
  }
}

$stubLibPath = ""
if ($stubName) {
  if (!$DryRunConfig) {
    if ($Force -or !(Test-Path -LiteralPath $stubDir -PathType Container)) {
      New-Item -ItemType Directory -Force -Path $stubEntryDir | Out-Null
      if ($Force -or !(Test-Path -LiteralPath $stubZip -PathType Leaf)) {
        [Console]::Error.WriteLine("Downloading Skia stub library asset: $stubName")
        $stubDownloaded = Download-Artifact -Label "Skia stub library asset $stubName" -Output $stubZip `
          -ExpectedSha256 $stubSha256 -ExpectedSize "$stubSize" `
          -PrimaryUrl $stubUrl -MirrorCandidates $stubMirrorCandidates
        if (!$stubDownloaded) { throw "could not download the Skia stub library asset: $stubName" }
        if ($script:downloadSource -ne "primary") { $stubMirror = $script:downloadSource }
      }
      $actualStubSha256 = Get-Sha256Hex -Path $stubZip
      if ($actualStubSha256 -ne $stubSha256) {
        throw "Skia stub library SHA256 mismatch: $stubZip expected=$stubSha256 actual=$actualStubSha256"
      }
      Expand-ZipArchive -Archive $stubZip -Destination $stubDir
    }
  }
  if (Test-Path -LiteralPath $stubDir -PathType Container) {
    # The stub is a single archive handed straight to the link command, so it must be
    # the file path: the directory would reach the linker as an input (MSVC appends
    # `.obj` and fails with LNK1181 on `package.obj`).
    $stubLibPath = Find-LibFile -Root $stubDir -LibraryNames $stubLibraryNames
    if (!$stubLibPath) {
      $stubLibPath = Find-LibFile -Root $stubDir -LibraryNames @("libmoui_skia_stub.a", "moui_skia_stub.lib")
    }
  }
} elseif (!$DryRunConfig) {
  [Console]::Error.WriteLine("note: skia-provider-lock.json has no released stub library for platform=$resolvedPlatform config=$Config arch=$resolvedArch; the build compiles native/*.cpp locally instead")
}
$stubLibPath = "$stubLibPath" -replace "\\", "/"
$stubSource = if ($stubLibPath) { "release" } else { "" }

$skiaInclude = Find-HeaderRoot -Root $packageDir
$includeSource = "package"
if (!$skiaInclude) {
  $includeSource = "source"
  if (!$DryRunConfig) {
    if ($Force -or !(Test-Path -LiteralPath $sourceDir -PathType Container)) {
      New-Item -ItemType Directory -Force -Path $tagDir | Out-Null
      if ($Force -or !(Test-Path -LiteralPath $sourceZip -PathType Leaf)) {
        [Console]::Error.WriteLine("Downloading Skia release source archive for headers: $Tag")
        $sourceDownloaded = Download-Artifact -Label "Skia release source archive for headers $Tag" -Output $sourceZip `
          -PrimaryUrl $sourceUrl -MirrorCandidates $sourceMirrorCandidates
        if (!$sourceDownloaded) { throw "could not download the Skia release source archive for $Tag" }
      }
      Expand-ZipArchive -Archive $sourceZip -Destination $sourceDir
    }
    $skiaInclude = Find-HeaderRoot -Root $sourceDir
    if (!$skiaInclude) { throw "Skia headers were not found in package or source archive for tag $Tag" }
  } else {
    $skiaInclude = $sourceDir -replace "\\", "/"
  }
}

$skiaLibDir = Find-LibDir -Root $packageDir -LibraryNames $libraryNames
if (!$skiaLibDir) {
  if ($DryRunConfig) {
    $skiaLibDir = $packageDir -replace "\\", "/"
  } else {
    throw "Skia library for platform=$resolvedPlatform link_mode=$resolvedLinkMode was not found in $packageDir"
  }
}

$skiaInclude = $skiaInclude -replace "\\", "/"
$skiaLibDir = $skiaLibDir -replace "\\", "/"
$skiaRoot = $skiaInclude
$libDirNormalized = $skiaLibDir.TrimEnd("/").ToLowerInvariant()
foreach ($suffix in @(
    "/out/$Config-$resolvedPlatform-$resolvedArch-shared",
    "/out/$Config-$resolvedPlatform-$resolvedArch",
    "/out/$Config-$resolvedArch-shared",
    "/out/$Config-$resolvedArch"
  )) {
  if ($libDirNormalized.EndsWith($suffix.ToLowerInvariant())) {
    $skiaRoot = $skiaLibDir.Substring(0, $skiaLibDir.Length - $suffix.Length)
    break
  }
}

if ($PrintEnv) {
  @(
    "MOUI_SKIA_PROVIDER=$providerKey"
    "MOUI_SKIA_SKIA_PROVIDER=$providerKey"
    "MOUI_SKIA_RELEASE_OWNER=$($provider.owner)"
    "MOUI_SKIA_RELEASE_REPO=$($provider.repo)"
    "MOUI_SKIA_RELEASE_TAG=$Tag"
    "MOUI_SKIA_RELEASE_URL=$($provider.release_url)"
    "MOUI_SKIA_SKIA_ROOT=$skiaRoot"
    "MOUI_SKIA_SKIA_COMMIT=$($provider.commit)"
    "MOUI_SKIA_SKIA_PACKAGE=$assetName"
    "MOUI_SKIA_SKIA_PACKAGE_SHA256=$assetSha256"
    "MOUI_SKIA_LINK_MODE=$resolvedLinkMode"
    "MOUI_SKIA_SKIA_INCLUDE=$skiaInclude"
    "MOUI_SKIA_SKIA_LIB_DIR=$skiaLibDir"
    "MOUI_SKIA_SKIA_LIB=skia"
    "MOUI_SKIA_EXTRA_CC_FLAGS=$extraCcFlags"
    "MOUI_SKIA_EXTRA_LINK_FLAGS=$extraLinkFlags"
    "MOUI_SKIA_SKIA_PACKAGE_MIRROR=$packageMirror"
    "MOUI_SKIA_STUB_ASSET_MIRROR=$stubMirror"
    "MOUI_SKIA_STUB_LIB=$stubLibPath"
    "MOUI_SKIA_STUB_ASSET_SHA256=$stubSha256"
    "MOUI_SKIA_STUB_SOURCES_SHA256=$stubSourcesSha256"
    "MOUI_SKIA_STUB_SOURCE=$stubSource"
  ) | Write-Output
  exit 0
}

@(
  "Skia release provider:"
  "  skia_provider=$providerKey"
  "  release_owner=$($provider.owner)"
  "  release_repo=$($provider.repo)"
  "  release_tag=$Tag"
  "  release_url=$($provider.release_url)"
  "  skia_commit=$($provider.commit)"
  "  skia_package=$assetName"
  "  skia_package_sha256=$assetSha256"
  "  skia_package_size=$assetSize"
  "  skia_package_url=$assetUrl"
  "  skia_package_candidates=$(Get-CandidateNames -Candidates (Get-CandidateOrder -PrimaryUrl $assetUrl -MirrorCandidates $packageMirrorCandidates -Mode $mirrorMode))"
  "  skia_package_mirror=$packageMirror"
  "  skia_link_mode=$resolvedLinkMode"
  "  mirror_mode=$mirrorMode"
  "  platform=$resolvedPlatform"
  "  config=$Config"
  "  arch=$resolvedArch"
  "  cache_dir=$entryDir"
  "  include_source=$includeSource"
  "  skia_root=$skiaRoot"
  "  skia_include=$skiaInclude"
  "  skia_lib_dir=$skiaLibDir"
  "  skia_lib=skia"
  "  extra_cc_flags=$extraCcFlags"
  "  extra_link_flags=$extraLinkFlags"
  "  stub_asset=$stubName"
  "  stub_asset_candidates=$(Get-CandidateNames -Candidates (Get-CandidateOrder -PrimaryUrl $stubUrl -MirrorCandidates $stubMirrorCandidates -Mode $mirrorMode))"
  "  stub_asset_mirror=$stubMirror"
  "  stub_asset_sha256=$stubSha256"
  "  stub_asset_size=$stubSize"
  "  stub_sources_sha256=$stubSourcesSha256"
  "  stub_lib=$stubLibPath"
) | Write-Output

if ($DryRunConfig) {
  Write-Output "Dry run complete; Skia release asset was not downloaded or extracted."
}
