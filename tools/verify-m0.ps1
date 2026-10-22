param(
  [string]$Compiler,
  [string]$FairyRepository = (Join-Path $PSScriptRoot '../../fairyc')
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $Compiler) { $Compiler = Join-Path $repo 'build/toolchain/fairyc.exe' }
$Compiler = (Resolve-Path -LiteralPath $Compiler).Path
$FairyRepository = (Resolve-Path -LiteralPath $FairyRepository).Path
$project = Join-Path $repo 'probes/m0'
$output = Join-Path $repo 'build/m0'
New-Item -ItemType Directory -Force $output | Out-Null
$emptyPath = Join-Path $output 'no-runtime-tools'
New-Item -ItemType Directory -Force $emptyPath | Out-Null

function Invoke-Captured([string]$File, [string[]]$Arguments, [string]$Directory, [bool]$RuntimeOnly = $false) {
  $start = [Diagnostics.ProcessStartInfo]::new()
  $start.FileName = $File
  $start.WorkingDirectory = $Directory
  $start.UseShellExecute = $false
  $start.CreateNoWindow = $true
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
  if ($RuntimeOnly) {
    $start.Environment.Clear()
    $start.Environment['SystemRoot'] = $env:SystemRoot
    $start.Environment['WINDIR'] = $env:SystemRoot
    $start.Environment['PATH'] = $emptyPath
    $start.Environment['TEMP'] = $emptyPath
    $start.Environment['TMP'] = $emptyPath
  }
  $process = [Diagnostics.Process]::Start($start)
  try {
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(120000)) {
      $process.Kill($true)
      throw "Timed out: $File $Arguments"
    }
    $result = [ordered]@{ exit = $process.ExitCode; stdout = $stdout.GetAwaiter().GetResult(); stderr = $stderr.GetAwaiter().GetResult() }
    if ($result.exit -ne 0 -or $result.stderr.Length) {
      throw "Failed: $File $Arguments; exit=$($result.exit); stdout=$($result.stdout); stderr=$($result.stderr)"
    }
    return $result
  } finally { $process.Dispose() }
}

$version = Invoke-Captured $Compiler @('--version') $project
$revision = (& git -C $FairyRepository rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot identify Fairy source revision' }
if ($version.stdout -notmatch "revision: $revision") { throw 'Compiler does not match the selected Fairy checkout' }
if ($version.stdout -notmatch 'modified: false') { throw 'Compiler must be built from a clean Fairy checkout' }
$results = @()
foreach ($profile in @('development', 'release')) {
  $arguments = @('build')
  if ($profile -eq 'release') { $arguments += @('--release', '--locked') }
  $built = Invoke-Captured $Compiler $arguments $project
  $exe = Join-Path $output "brownie-m0-$profile.exe"
  Copy-Item -LiteralPath (Join-Path $project 'build/brownie-native-m0.exe') -Destination $exe -Force
  $ran = Invoke-Captured $exe @() $emptyPath $true
  if ($ran.stdout -cne "brownie-m0: baseline passed`n") { throw "Unexpected native output: $($ran.stdout)" }
  $results += [ordered]@{
    profile = $profile; build = $built; runtime = $ran
    artifact = [IO.Path]::GetRelativePath($repo, $exe)
    sha256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant()
    bytes = (Get-Item -LiteralPath $exe).Length
    runtimePathHasToolchain = $false
  }
  Write-Host "PASS: $profile native probe"
}
$receipt = [ordered]@{
  schema = 'browniec.native-m0/v1'; recordedAt = [DateTime]::UtcNow.ToString('o')
  fairyRevision = $revision
  compilerSha256 = (Get-FileHash -LiteralPath $Compiler -Algorithm SHA256).Hash.ToLowerInvariant()
  compilerVersion = $version.stdout
  os = [Environment]::OSVersion.VersionString
  architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
  sourceSha256 = @((Get-ChildItem -LiteralPath (Join-Path $project 'src') -File -Recurse | Sort-Object FullName) | ForEach-Object {
    [ordered]@{ path = [IO.Path]::GetRelativePath($repo, $_.FullName); sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
  })
  lockSha256 = (Get-FileHash -LiteralPath (Join-Path $project 'fairy.lock') -Algorithm SHA256).Hash.ToLowerInvariant()
  executions = $results
  limitations = @('Native primitives only; no Brownie source compiler or VM.', 'A tool-free PATH is not clean-machine packaging or Windows isolation evidence.')
}
$receipt | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $output 'receipt.json') -Encoding utf8NoBOM
Write-Host 'Receipt: build/m0/receipt.json'
