param(
  [ValidateSet('ir', 'vm', 'source', 'write', 'copy', 'length', 'scopes', 'assignment', 'frames', 'helpers')][string]$Slice = 'ir',
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
$expected = if ($Slice -in @('ir','assignment')) { 16 } elseif ($Slice -eq 'source') { 18 } elseif ($Slice -eq 'write') { 9 } elseif ($Slice -eq 'length') { 15 } elseif ($Slice -eq 'scopes') { 19 } else { 12 }
if ($Slice -eq 'write') { $files = @('tests/m2/array_source.fy', 'tests/m2/array_write.fy') }
if ($Slice -in @('copy', 'length', 'scopes')) { $files = @('tests/m2/array_source.fy', 'tests/m2/array_write.fy', 'tests/m2/array_copy_source.fy') }
if ($Slice -in @('length', 'scopes')) { $files += 'tests/m2/array_length.fy' }
if ($Slice -eq 'scopes') { $files += 'tests/m2/array_scopes.fy' }
if ($Slice -eq 'assignment') { $files = @('tests/m2/array_ir.fy', 'tests/m2/array_vm.fy', 'tests/m2/array_assign_storage.fy', 'tests/m2/array_assignment.fy') }
$sourceMode = $Slice -in @('source', 'write', 'copy', 'length', 'scopes', 'assignment')
if ($Slice -eq 'frames') {
  $files = @('tests/m2/array_ir.fy', 'tests/m2/array_vm.fy', 'tests/m2/array_assign_storage.fy',
    'tests/m2/array_assignment.fy', 'tests/m2/array_functions.fy', 'tests/m2/array_frames.fy')
  $expected = 24
  $sourceMode = $true
}
if ($Slice -eq 'helpers') {
  $files = @('tests/m2/array_source.fy', 'tests/propagation.fy', 'tests/m2/array_helpers.fy')
  $expected = 16
  $sourceMode = $true
}
# Later slices retain the full assignment CLI matrix.
$assignmentMode = $Slice -in @('assignment', 'frames', 'helpers')
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
    if ($assignmentMode -or $Slice -in @('write','copy','length','scopes')) { Get-Item tools/check-m2-array-write.py }
    if ($assignmentMode -or $Slice -in @('copy','length','scopes')) { Get-Item tools/check-m2-array-copy-source.py }
    if ($assignmentMode -or $Slice -in @('length','scopes')) { Get-Item tools/check-m2-array-length.py, examples/array-length.brc }
    if ($assignmentMode -or $Slice -eq 'scopes') { Get-Item tools/check-m2-array-scopes.py, examples/array-scopes.brc }
    if ($assignmentMode) { Get-Item tools/check-m2-array-assignment.py, examples/array-assignment.brc }
    if ($Slice -eq 'helpers') { Get-Item tools/check-m2-array-helpers.py, examples/array-helpers.brc })
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
      if ($assignmentMode -or $Slice -in @('write','copy','length','scopes')) {
        & python -B (Join-Path $PSScriptRoot 'check-m2-array-write.py') --exe $exe --profile $profile
        if ($LASTEXITCODE -ne 0) { throw "Array write CLI checks failed: $profile" }
        $writeCli = Get-Content -LiteralPath (Join-Path $repo "build/m2-array-write/$profile/cli-receipt.json") -Raw | ConvertFrom-Json
        $result.writeCliCases = $writeCli.count
      }
      if ($assignmentMode -or $Slice -in @('copy','length','scopes')) {
        & python -B (Join-Path $PSScriptRoot 'check-m2-array-copy-source.py') --exe $exe --profile $profile
        if ($LASTEXITCODE -ne 0) { throw "Array copy CLI checks failed: $profile" }
        $copyCli = Get-Content -LiteralPath (Join-Path $repo "build/m2-array-copy-source/$profile/cli-receipt.json") -Raw | ConvertFrom-Json
        $result.copyCliCases = $copyCli.count
      }
      if ($assignmentMode -or $Slice -in @('length','scopes')) {
        & python -B (Join-Path $PSScriptRoot 'check-m2-array-length.py') --exe $exe --profile $profile
        if ($LASTEXITCODE -ne 0) { throw "Array length CLI checks failed: $profile" }
        $lengthCli = Get-Content -LiteralPath (Join-Path $repo "build/m2-array-length/$profile/cli-receipt.json") -Raw | ConvertFrom-Json
        $result.lengthCliCases = $lengthCli.count
      }
      if ($assignmentMode -or $Slice -eq 'scopes') {
        & python -B (Join-Path $PSScriptRoot 'check-m2-array-scopes.py') --exe $exe --profile $profile
        if ($LASTEXITCODE -ne 0) { throw "Array scope CLI checks failed: $profile" }
        $scopeCli = Get-Content -LiteralPath (Join-Path $repo "build/m2-array-scopes/$profile/cli-receipt.json") -Raw | ConvertFrom-Json
        $result.scopeCliCases = $scopeCli.count
      }
      if ($assignmentMode) {
        & python -B (Join-Path $PSScriptRoot 'check-m2-array-assignment.py') --exe $exe --profile $profile
        if ($LASTEXITCODE -ne 0) { throw "Array assignment CLI checks failed: $profile" }
        $assignmentCli = Get-Content -LiteralPath (Join-Path $repo "build/m2-array-assignment/$profile/cli-receipt.json") -Raw | ConvertFrom-Json
        $result.assignmentCliCases = $assignmentCli.count
      }
      if ($Slice -eq 'helpers') {
        & python -B (Join-Path $PSScriptRoot 'check-m2-array-helpers.py') --exe $exe --profile $profile
        if ($LASTEXITCODE -ne 0) { throw "Helper array CLI checks failed: $profile" }
        $helperCli = Get-Content -LiteralPath (Join-Path $output "$profile/cli-receipt.json") -Raw | ConvertFrom-Json
        $result.helperCliCases = $helperCli.count
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
  $receipt = [ordered]@{ schema = "browniec.m2-array-$outputSlice/v1"; status = 'passed'; recordedAt = [DateTime]::UtcNow.ToString('o');
    compilerVersion = $version; compilerSha256 = $compilerHash; os = [Environment]::OSVersion.VersionString;
    lockedCheck = $check; results = $results; allocatorTests = $allocatorResults; sourceSha256 = $identities;
    artifacts = 'Tool-managed temporary native test images; source mode also retains hashed native CLI binaries.';
    limitations = @($(if ($Slice -eq 'frames') { 'Private IR supports function-owned frame-local arrays; source arrays remain entry-only. Array parameters and results remain unavailable.' } else { 'Entry-function arrays only; scalar functions cannot receive or return arrays.' }),
      $(if ($Slice -eq 'assignment') { 'Assignment mode admits exact-shape whole-array assignment into existing mutable storage; helper arrays, aggregate parameters/results, borrows, slices and for-header array operations remain unavailable.' } elseif ($Slice -eq 'scopes') { 'Scopes mode admits entry-function arrays in lexical blocks and loops; helper arrays, array parameters/results, for-header arrays, reassignment and borrows remain unavailable.' } elseif ($Slice -eq 'length') { 'Length mode adds NAME.len as a usize constant in scalar expressions; reassignment, array parameters, borrows and slices remain unavailable.' } elseif ($Slice -eq 'copy') { 'Copy mode admits new outer-main array bindings from exact-type/length bare sources; reassignment and borrows remain unavailable.' } elseif ($Slice -eq 'write') { 'Write mode admits outer-main let/var scalar arrays and indexed assignment; for-header writes, copies and borrows remain unavailable.' } else { 'Source mode admits outer-main immutable repeated arrays and scalar indexing; copies, borrows and full profile remain incomplete.' }),
      'Each receipt establishes only the selected slice, not later VM or delivery gates.',
      'No isolation, DLL, clean-machine or performance claim.')
  }
  if ($Slice -eq 'frames') {
    $receipt.limitations = @('Private IR supports function-owned frame-local arrays; source arrays remain entry-only.',
      'Array parameters/results, helper source declarations, borrows, slices and for-header array operations remain unavailable.',
      'The 16 live owners and 65536-byte arena ceiling are shared across all 32 VM frames.',
      'No isolation, DLL, clean-machine or performance claim.')
  }
  if ($Slice -eq 'helpers') {
    $receipt.limitations = @('Source fixed scalar arrays are supported in scalar and shallow wrapper-returning helper functions, with cleanup on question-mark failure paths.',
      'Array parameters/results, wrapper element arrays, borrows, slices and for-header array operations remain unavailable.',
      'All functions share 16 static array sites, 16 live owners, 32 VM frames and one payload arena capped at 65536 bytes.',
      'No isolation, DLL, clean-machine or performance claim.')
  }
  $receipt | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $receiptPath -Encoding utf8NoBOM
  Write-Host "PASS: build/m2-array-$outputSlice/receipt.json"
} finally { Pop-Location }
