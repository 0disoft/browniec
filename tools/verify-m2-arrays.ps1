param(
  [ValidateSet('ir', 'vm', 'source', 'write', 'copy')][string]$Slice = 'ir',
  [string]$Compiler = (Join-Path $PSScriptRoot '../build/toolchain/fairyc.exe')
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$Compiler = (Resolve-Path -LiteralPath $Compiler).Path
$outputSlice = if ($Slice -eq 'copy') { 'copy-source' } else { $Slice }
$output = Join-Path $repo "build/m2-array-$outputSlice"
New-Item -ItemType Directory -Force $output | Out-Null
$receiptPath = Join-Path $output 'receipt.json'
[ordered]@{ status = 'incomplete'; startedAt = [DateTime]::UtcNow.ToString('o') } |
  ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding utf8NoBOM
if ($env:CL -or $env:_CL_) { throw 'Unexpected CL/_CL_ override' }
$files = if ($Slice -eq 'ir') { @('tests/m2/array_ir.fy', 'tests/branches.fy', 'tests/loops.fy') } else { @('tests/m2/array_ir.fy', 'tests/m2/array_vm.fy', 'tests/m2/array_allocation.fy') }
if ($Slice -eq 'source') { $files += 'tests/m2/array_source.fy' }
$expected = if ($Slice -eq 'ir') { 16 } elseif ($Slice -eq 'source') { 18 } elseif ($Slice -eq 'write') { 9 } else { 12 }
if ($Slice -eq 'write') { $files = @('tests/m2/array_source.fy', 'tests/m2/array_write.fy') }
if ($Slice -eq 'copy') { $files = @('tests/m2/array_source.fy', 'tests/m2/array_write.fy', 'tests/m2/array_copy_source.fy') }
$sourceMode = $Slice -in @('source', 'write', 'copy')
Push-Location $repo
try {
  $version = & $Compiler --version
  if ($LASTEXITCODE -ne 0) { throw 'Cannot identify compiler' }
  $check = & $Compiler check --locked
  if ($LASTEXITCODE -ne 0) { throw 'Locked check failed' }
  $inputs = @(Get-Item fairy.toml, fairy.lock, tools/verify-m2-arrays.ps1;
    $files | ForEach-Object { Get-Item -LiteralPath $_ }; Get-ChildItem src -File -Recurse;
    if ($Slice -eq 'vm') { Get-Item probes/m0/native/allocator_probe.h }
    if ($sourceMode) { Get-Item tools/check-m2-array-source.py }
    if ($Slice -in @('write','copy')) { Get-Item tools/check-m2-array-write.py }
    if ($Slice -eq 'copy') { Get-Item tools/check-m2-array-copy-source.py })
  $identities = @($inputs | Sort-Object FullName | ForEach-Object {
    [ordered]@{ path = [IO.Path]::GetRelativePath($repo, $_.FullName).Replace('\', '/');
      sha256 = (Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant() }
  })
  $compilerHash = (Get-FileHash -LiteralPath $Compiler).Hash.ToLowerInvariant()
  $results = @()
  foreach ($profile in @('development', 'release')) {
    $arguments = @('test', '--native', '--capture-output', '--json', '--locked')
    foreach ($file in $files) { $arguments += @('--file', $file) }
    if ($profile -eq 'release') { $arguments += '--release' }
    $nativeOutput = & $Compiler @arguments
    $nativeExit = $LASTEXITCODE
    $nativeOutput | Set-Content -LiteralPath (Join-Path $output "$profile-native-output.json") -Encoding utf8NoBOM
    if ($nativeExit -ne 0) { throw "Native array $Slice tests failed: $profile; see $profile-native-output.json" }
    $native = $nativeOutput | ConvertFrom-Json
    if ($native.status -ne 'ok' -or $native.failed -ne 0 -or $native.passed -ne $expected) { throw 'Unexpected native outcomes' }
    $result = [ordered]@{ profile = $profile; nativeTests = $native }
    if ($sourceMode) {
      $buildArguments = @('build', '--locked')
      if ($profile -eq 'release') { $buildArguments += '--release' }
      $buildOutput = & $Compiler @buildArguments
      if ($LASTEXITCODE -ne 0) { throw "Array CLI build failed: $profile" }
      $exe = Join-Path $output "browniec-$profile.exe"
      Copy-Item -LiteralPath (Join-Path $repo 'build/browniec.exe') -Destination $exe -Force
      & python -B (Join-Path $PSScriptRoot 'check-m2-array-source.py') --exe $exe --profile $profile
      if ($LASTEXITCODE -ne 0) { throw "Array CLI checks failed: $profile" }
      $cli = Get-Content -LiteralPath (Join-Path $repo "build/m2-array-source/$profile/cli-receipt.json") -Raw | ConvertFrom-Json
      $result.build = $buildOutput
      $result.artifact = "build/m2-array-$outputSlice/browniec-$profile.exe"
      $result.sha256 = (Get-FileHash -LiteralPath $exe).Hash.ToLowerInvariant()
      $result.cliCases = $cli.count
      if ($Slice -in @('write','copy')) {
        & python -B (Join-Path $PSScriptRoot 'check-m2-array-write.py') --exe $exe --profile $profile
        if ($LASTEXITCODE -ne 0) { throw "Array write CLI checks failed: $profile" }
        $writeCli = Get-Content -LiteralPath (Join-Path $repo "build/m2-array-write/$profile/cli-receipt.json") -Raw | ConvertFrom-Json
        $result.writeCliCases = $writeCli.count
      }
      if ($Slice -eq 'copy') {
        & python -B (Join-Path $PSScriptRoot 'check-m2-array-copy-source.py') --exe $exe --profile $profile
        if ($LASTEXITCODE -ne 0) { throw "Array copy CLI checks failed: $profile" }
        $copyCli = Get-Content -LiteralPath (Join-Path $output "$profile/cli-receipt.json") -Raw | ConvertFrom-Json
        $result.copyCliCases = $copyCli.count
      }
    }
    $results += $result
  }
  $allocatorResults = @()
  if ($Slice -eq 'vm') {
    $originalCL = $env:CL
    $originalOom = $env:BROWNIE_M0_OOM
    if ($originalOom) { throw 'Unexpected allocator probe environment override' }
    try {
      $header = Join-Path $repo 'probes/m0/native/allocator_probe.h'
      $env:CL = '/FI"' + $header + '"'
      foreach ($profile in @('development', 'release')) {
        foreach ($mode in @('normal', 'oom')) {
          $arguments = @('test', '--native', '--file', 'tests/m2/array_allocation.fy', '--capture-output', '--json', '--locked')
          if ($profile -eq 'release') { $arguments += '--release' }
          if ($mode -eq 'oom') { $env:BROWNIE_M0_OOM = '1'; $arguments += @('--', 'oom') }
          else { $env:BROWNIE_M0_OOM = $null }
          $nativeOutput = & $Compiler @arguments
          if ($LASTEXITCODE -ne 0) { throw "Allocator $mode test failed: $profile" }
          $native = $nativeOutput | ConvertFrom-Json
          if ($native.status -ne 'ok' -or $native.failed -ne 0 -or $native.passed -ne 1) { throw 'Unexpected allocator outcome' }
          $allocatorResults += [ordered]@{ profile = $profile; mode = $mode;
            allocator = 'Instrumented target malloc/free; forced NULL and exit leak check'; nativeTests = $native }
        }
      }
    } finally { $env:CL = $originalCL; $env:BROWNIE_M0_OOM = $originalOom }
  }
  foreach ($item in $identities) {
    if ((Get-FileHash -LiteralPath (Join-Path $repo $item.path)).Hash.ToLowerInvariant() -ne $item.sha256) {
      throw "Verification input changed: $($item.path)"
    }
  }
  if ((Get-FileHash -LiteralPath $Compiler).Hash.ToLowerInvariant() -ne $compilerHash) { throw 'Compiler changed' }
  [ordered]@{ schema = "browniec.m2-array-$outputSlice/v1"; status = 'passed'; recordedAt = [DateTime]::UtcNow.ToString('o');
    compilerVersion = $version; compilerSha256 = $compilerHash; os = [Environment]::OSVersion.VersionString;
    lockedCheck = $check; results = $results; allocatorTests = $allocatorResults; sourceSha256 = $identities;
    artifacts = 'Tool-managed temporary native test images; source mode also retains hashed native CLI binaries.';
    limitations = @('Entry-function arrays only; scalar functions cannot receive or return arrays.',
      $(if ($Slice -eq 'copy') { 'Copy mode admits new outer-main array bindings from exact-type/length bare sources; reassignment and borrows remain unavailable.' } elseif ($Slice -eq 'write') { 'Write mode admits outer-main let/var scalar arrays and indexed assignment; for-header writes, copies and borrows remain unavailable.' } else { 'Source mode admits outer-main immutable repeated arrays and scalar indexing; copies, borrows and full profile remain incomplete.' }),
      'Each receipt establishes only the selected slice, not later VM or delivery gates.',
      'No isolation, DLL, clean-machine or performance claim.')
  } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $receiptPath -Encoding utf8NoBOM
  Write-Host "PASS: build/m2-array-$outputSlice/receipt.json"
} finally { Pop-Location }
