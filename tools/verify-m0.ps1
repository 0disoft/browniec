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
$receiptPath = Join-Path $output 'receipt.json'
[ordered]@{ schema = 'browniec.native-m0/v1'; status = 'incomplete'; startedAt = [DateTime]::UtcNow.ToString('o') } |
  ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding utf8NoBOM
if ($env:CL -or $env:_CL_) { throw 'Run the baseline without ambient CL or _CL_ overrides' }

function Invoke-Captured([string]$File, [string[]]$Arguments, [string]$Directory, [bool]$RuntimeOnly = $false, [bool]$ForceOom = $false, [int]$ExpectedExit = 0) {
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
    if ($ForceOom) { $start.Environment['BROWNIE_M0_OOM'] = '1' }
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
    if ($result.exit -ne $ExpectedExit -or ($ExpectedExit -eq 0 -and $result.stderr.Length)) {
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
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$vs = Invoke-Captured $vswhere @('-latest', '-products', '*', '-requires', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', '-property', 'installationPath') $project
$msvcVersion = (Get-Content -LiteralPath (Join-Path $vs.stdout.Trim() 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt') -Raw).Trim()
$cl = Join-Path $vs.stdout.Trim() "VC/Tools/MSVC/$msvcVersion/bin/Hostx64/x64/cl.exe"
$sdkRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$sdkCandidates = @(Get-ChildItem -LiteralPath (Join-Path $sdkRoot 'Include') -Directory | Where-Object {
  $candidate = $_.Name
  $required = @("Include/$candidate/ucrt", "Include/$candidate/shared", "Include/$candidate/um", "Lib/$candidate/ucrt/x64", "Lib/$candidate/um/x64")
  $missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $sdkRoot $_) -PathType Container) })
  $candidate.StartsWith('10.') -and $missing.Count -eq 0
} | Sort-Object Name)
if (-not $sdkCandidates.Count) { throw 'No complete Windows SDK found' }
$nativeToolchain = [ordered]@{
  name = 'msvc'; toolsVersion = $msvcVersion
  compilerFileVersion = (Get-Item -LiteralPath $cl).VersionInfo.FileVersion
  compilerSha256 = (Get-FileHash -LiteralPath $cl -Algorithm SHA256).Hash.ToLowerInvariant()
  windowsSdk = $sdkCandidates[-1].Name
  bootstrapGo = (Invoke-Captured (Get-Command go).Source @('version') $project).stdout.Trim()
}
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
$originalCL = $env:CL
try {
  $header = Join-Path $project 'native/allocator_probe.h'
  $env:CL = '/FI"' + $header + '"'
  foreach ($profile in @('development', 'release')) {
    $arguments = @('build', '--locked')
    if ($profile -eq 'release') { $arguments += '--release' }
    $built = Invoke-Captured $Compiler $arguments $project
    $exe = Join-Path $output "brownie-m0-allocator-$profile.exe"
    Copy-Item -LiteralPath (Join-Path $project 'build/brownie-native-m0.exe') -Destination $exe -Force
    foreach ($mode in @('normal', 'oom')) {
      $runtimeArguments = if ($mode -eq 'oom') { @('oom') } else { @() }
      $ran = Invoke-Captured $exe $runtimeArguments $emptyPath $true ($mode -eq 'oom')
      if ($ran.stdout -cne "brownie-m0: baseline passed`n") { throw "Unexpected $mode native output: $($ran.stdout)" }
      $results += [ordered]@{
        profile = $profile; mode = $mode; allocator = 'instrumented target malloc/free'; build = $built; runtime = $ran
        artifact = [IO.Path]::GetRelativePath($repo, $exe)
        sha256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant()
        bytes = (Get-Item -LiteralPath $exe).Length
        runtimePathHasToolchain = $false
      }
      Write-Host "PASS: $profile allocator $mode probe (including exit leak check)"
    }
  }
} finally { $env:CL = $originalCL }
$negativeResults = @()
foreach ($case in @(
  @{ name = 'use_after_move'; diagnostic = 'E1101' },
  @{ name = 'grow_with_live_view'; diagnostic = 'E2101' },
  @{ name = 'escape_local_view'; diagnostic = 'E2102' },
  @{ name = 'alias_exclusive_view'; diagnostic = 'E2101' }
)) {
  $directory = Join-Path $output "negative/$($case.name)"
  New-Item -ItemType Directory -Force (Join-Path $directory 'src') | Out-Null
  $manifest = (Get-Content -LiteralPath (Join-Path $project 'fairy.toml') -Raw).Replace('browniec.native-m0', "browniec.negative.$($case.name.Replace('_', '-'))")
  [IO.File]::WriteAllText((Join-Path $directory 'fairy.toml'), $manifest, [Text.UTF8Encoding]::new($false))
  Copy-Item -LiteralPath (Join-Path $project "negative/$($case.name).fy") -Destination (Join-Path $directory 'src/main.fy') -Force
  $checked = Invoke-Captured $Compiler @('check') $directory $false $false 3
  if ($checked.stderr -notmatch "(?m)^main\.fy:\d+:\d+: $($case.diagnostic):") { throw "Missing $($case.diagnostic) for $($case.name): $($checked.stderr)" }
  $negativeResults += [ordered]@{ name = $case.name; expectedDiagnostic = $case.diagnostic; result = $checked }
  Write-Host "PASS: rejects $($case.name) with $($case.diagnostic)"
}
$inputFiles = @(
  Get-Item -LiteralPath (Join-Path $project 'fairy.toml')
  Get-Item -LiteralPath (Join-Path $project 'fairy.lock')
  Get-Item -LiteralPath $PSCommandPath
  foreach ($directory in @('src', 'native', 'negative')) {
    Get-ChildItem -LiteralPath (Join-Path $project $directory) -File -Recurse
  }
)
$receipt = [ordered]@{
  schema = 'browniec.native-m0/v1'; status = 'passed'; recordedAt = [DateTime]::UtcNow.ToString('o')
  fairyRevision = $revision
  compilerSha256 = (Get-FileHash -LiteralPath $Compiler -Algorithm SHA256).Hash.ToLowerInvariant()
  compilerVersion = $version.stdout
  os = [Environment]::OSVersion.VersionString
  architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
  nativeToolchain = $nativeToolchain
  sourceSha256 = @($inputFiles | Sort-Object FullName | ForEach-Object {
    [ordered]@{ path = [IO.Path]::GetRelativePath($repo, $_.FullName).Replace('\', '/'); sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
  })
  lockSha256 = (Get-FileHash -LiteralPath (Join-Path $project 'fairy.lock') -Algorithm SHA256).Hash.ToLowerInvariant()
  executions = $results
  rejectedSources = $negativeResults
  limitations = @('Native primitives only; no Brownie source compiler or VM.', 'A tool-free PATH is not clean-machine packaging or Windows isolation evidence.')
}
$receipt | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $receiptPath -Encoding utf8NoBOM
Write-Host 'Receipt: build/m0/receipt.json'
