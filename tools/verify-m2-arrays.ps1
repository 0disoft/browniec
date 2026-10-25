param(
  [ValidateSet('ir', 'vm', 'source', 'write', 'copy', 'length', 'scopes', 'assignment', 'frames', 'helpers', 'arguments', 'calls', 'parameters', 'results', 'result-source')][string]$Slice = 'ir',
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
if ($Slice -eq 'arguments') {
  $files = @('tests/m2/array_owners.fy', 'tests/m2/array_copy.fy',
    'tests/m2/array_assign_storage.fy', 'tests/m2/array_argument_copies.fy')
  $expected = 18
  $sourceMode = $false
}
if ($Slice -eq 'calls') {
  $files = @('tests/functions.fy', 'tests/m2/array_ir.fy', 'tests/m2/array_vm.fy',
    'tests/m2/array_frames.fy', 'tests/m2/array_calls.fy')
  $expected = 29
  $sourceMode = $true
}
if ($Slice -eq 'parameters') {
  $files = @('tests/functions.fy', 'tests/propagation.fy', 'tests/m2/array_helpers.fy',
    'tests/m2/array_signatures.fy', 'tests/m2/array_parameters_source.fy')
  $expected = 28
  $sourceMode = $true
}
if ($Slice -eq 'results') {
  $files = @('tests/m2/array_results.fy', 'tests/m2/array_result_vm.fy', 'tests/m2/array_result_edges.fy',
    'tests/m2/array_calls.fy', 'tests/m2/array_frames.fy', 'tests/m2/array_vm.fy',
    'tests/functions.fy', 'tests/m2/array_ir.fy')
  $expected = 43
  $sourceMode = $true
}
if ($Slice -eq 'result-source') {
  $files = @('tests/m2/array_result_source.fy', 'tests/m2/array_result_signatures.fy',
    'tests/m2/array_parameters_source.fy', 'tests/functions.fy', 'tests/m2/array_return_calls.fy')
  $expected = 30
  $sourceMode = $true
}
# Later slices retain the full assignment CLI matrix.
$assignmentMode = $Slice -in @('assignment', 'frames', 'helpers', 'calls', 'parameters', 'results', 'result-source')
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
    if ($Slice -in @('helpers','calls','parameters','results','result-source')) { Get-Item tools/check-m2-array-helpers.py, examples/array-helpers.brc }
    if ($Slice -in @('parameters','results','result-source')) { Get-Item tools/check-m2-array-parameters.py }
    if ($Slice -in @('results','result-source')) { Get-Item tools/check-m2-array-result-signatures.py }
    if ($Slice -eq 'result-source') { Get-Item tools/check-m2-array-result-source.py, tools/check-m2-array-return-calls.py }
    if ($Slice -in @('calls','parameters','results','result-source')) { Get-Item tools/check-m1-cli.py; Get-ChildItem tools -File -Filter '*cases.py'; Get-ChildItem examples -File -Filter '*.brc' })
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
      if ($Slice -in @('helpers','calls','parameters','results','result-source')) {
        & python -B (Join-Path $PSScriptRoot 'check-m2-array-helpers.py') --exe $exe --profile $profile
        if ($LASTEXITCODE -ne 0) { throw "Helper array CLI checks failed: $profile" }
        $helperCli = Get-Content -LiteralPath (Join-Path $repo "build/m2-array-helpers/$profile/cli-receipt.json") -Raw | ConvertFrom-Json
        $result.helperCliCases = $helperCli.count
      }
      if ($Slice -in @('parameters','results','result-source')) {
        & python -B (Join-Path $PSScriptRoot 'check-m2-array-parameters.py') --exe $exe --profile $profile
        if ($LASTEXITCODE -ne 0) { throw "Source parameter CLI checks failed: $profile" }
        $parameterCli = Get-Content -LiteralPath (Join-Path $repo "build/m2-array-parameters/$profile/cli-receipt.json") -Raw | ConvertFrom-Json
        if ($parameterCli.count -ne 80 -or $parameterCli.exeSha256 -ne $result.sha256 -or $parameterCli.status -ne 'passed') {
          throw 'Unexpected source parameter receipt'
        }
        $result.parameterCliCases = $parameterCli.count
      }
      if ($Slice -in @('results','result-source')) {
        & python -B (Join-Path $PSScriptRoot 'check-m2-array-result-signatures.py') --exe $exe --profile $profile
        if ($LASTEXITCODE -ne 0) { throw "Result signature CLI checks failed: $profile" }
        $signatureCli = Get-Content -LiteralPath (Join-Path $repo "build/m2-array-result-signatures/$profile/cli-receipt.json") -Raw | ConvertFrom-Json
        if ($signatureCli.status -ne 'passed' -or $signatureCli.count -ne 96 -or $signatureCli.exeSha256 -ne $result.sha256) {
          throw 'Unexpected result signature receipt'
        }
        $result.resultSignatureCliCases = $signatureCli.count
      }
      if ($Slice -eq 'result-source') {
        & python -B (Join-Path $PSScriptRoot 'check-m2-array-result-source.py') --exe $exe --profile $profile
        if ($LASTEXITCODE -ne 0) { throw "Source result CLI checks failed: $profile" }
        $sourceResultCli = Get-Content -LiteralPath (Join-Path $repo "build/m2-array-result-source/$profile/cli-receipt.json") -Raw | ConvertFrom-Json
        if ($sourceResultCli.status -ne 'passed' -or $sourceResultCli.count -ne 119 -or $sourceResultCli.exeSha256 -ne $result.sha256) {
          throw 'Unexpected source result receipt'
        }
        $result.sourceResultCliCases = $sourceResultCli.count
        & python -B (Join-Path $PSScriptRoot 'check-m2-array-return-calls.py') --exe $exe --profile $profile
        if ($LASTEXITCODE -ne 0) { throw "Direct return CLI checks failed: $profile" }
        $returnCallCli = Get-Content -LiteralPath (Join-Path $repo "build/m2-array-return-calls/$profile/cli-receipt.json") -Raw | ConvertFrom-Json
        if ($returnCallCli.status -ne 'passed' -or $returnCallCli.count -ne 117 -or $returnCallCli.exeSha256 -ne $result.sha256) {
          throw 'Unexpected direct return receipt'
        }
        $result.returnCallCliCases = $returnCallCli.count
      }
      if ($Slice -in @('calls','parameters','results','result-source')) {
        & python -B (Join-Path $PSScriptRoot 'check-m1-cli.py') --exe $exe --profile $profile
        if ($LASTEXITCODE -ne 0) { throw "Scalar CLI checks failed: $profile" }
        $scalarCli = Get-Content -LiteralPath (Join-Path $repo "build/m1/$profile/cli-receipt.json") -Raw | ConvertFrom-Json
        if ($scalarCli.count -ne 1969 -or $scalarCli.exeSha256 -ne $result.sha256) { throw 'Unexpected scalar receipt' }
        $result.scalarCliCases = $scalarCli.count
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
  if ($Slice -eq 'arguments') {
    $receipt.limitations = @('Private atomic array-argument copy primitive only; no source, IR or VM CALL integration.',
      'All argument shapes, source tokens, bool payloads, owner slots and combined extents are checked before mutation.',
      'Argument evaluation/capture order, frame binding, immutable callee bindings and VM Fuel charges are not implemented.',
      'Native owner/copy/assignment regressions executed; CLI, full scalar/private-array suites and M0 reruns skipped.',
      'No allocator instrumentation, Linux, isolation, DLL, clean-machine or performance claim.')
  }
  if ($Slice -eq 'calls') {
    $receipt.limitations = @('This slice verifies private IR mixed scalar/immutable array parameters, independent frame copies and metered CALLs; source-call checks belong to the parameters slice.',
      'Array arguments must be live immutable snapshots in the caller; private array results receive separate results-slice evidence; source array returns, borrows and slices remain unavailable.',
      'All functions share 16 catalog sites, 16 live owners, 32 frame slots and one arena capped at 65536 bytes.',
      'Full scalar native suite, other private-array native suites, M0, allocator instrumentation, Linux, isolation, DLL and performance checks skipped.')
  }
  if ($Slice -eq 'parameters') {
    $receipt.limitations = @('Source immutable exact-shape scalar-array parameters with left-to-right argument capture and cleanup are supported.',
      'Array arguments are bare names; immutable sources are already stable and mutable sources create anonymous immutable captures.',
      'All parameters, locals and captures share 16 static catalog sites, 16 live owners and one 65536-byte arena; calls have at most eight arguments.',
      'Array results, wrapper element arrays, borrows, slices and for-header calls remain unavailable.',
      'This selection skips complete private IR/verifier/VM and batch-copy native suites, full scalar native suite, M0, allocator instrumentation, Linux, isolation, DLL and performance checks.')
  }
  if ($Slice -eq 'results') {
    $receipt.limitations = @('Private result shapes, CALL destinations and ARET lifetimes are independently verified; the sole callee owner transfers without payload copy or extra reservation.',
      'Source array-result declarations remain gated; wrapper-element arrays, borrows and slices are not implemented.',
      'All frames share 16 static array sites, 16 occupied descriptors and one arena capped at 65536 bytes; return Fuel prepays metadata and bool validation.',
      'Full scalar/other private-array native suites, M0, allocator instrumentation, Linux, isolation, DLL, clean-machine packaging and performance checks skipped.')
  }
  if ($Slice -eq 'result-source') {
    $receipt.limitations = @('Source return NAME, return FUNCTION(arguments) and exact-shape let/var array-result call initializers are supported; other visible arrays and pending captures are released before ARET.',
      'Returned literals/indexing/parentheses, result calls in scalar expressions, assignment RHS and for headers remain unsupported.',
      'Result shapes reuse an exact-shape parameter anchor or reserve one dead catalog site before body lowering; all sites share the 16-site ceiling.',
      'All frames share 16 occupied owners, 32 frame slots and one arena capped at 65536 bytes; owner transfer does not copy payload.',
      'Full scalar/private-array native suites, M0, allocator instrumentation, Linux, isolation, DLL, clean-machine packaging and performance checks skipped.')
  }
  $receipt | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $receiptPath -Encoding utf8NoBOM
  Write-Host "PASS: build/m2-array-$outputSlice/receipt.json"
} finally { Pop-Location }
