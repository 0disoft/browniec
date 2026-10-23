param([string]$Compiler = (Join-Path $PSScriptRoot '../build/toolchain/fairyc.exe'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$Compiler = (Resolve-Path -LiteralPath $Compiler).Path
$output = Join-Path $repo 'build/m1'
New-Item -ItemType Directory -Force $output | Out-Null
$receiptPath = Join-Path $output 'receipt.json'
[ordered]@{ status = 'incomplete'; startedAt = [DateTime]::UtcNow.ToString('o') } |
  ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding utf8NoBOM
if ($env:CL -or $env:_CL_) { throw 'Unexpected CL/_CL_ override' }
Push-Location $repo
try {
  $version = & $Compiler --version
  if ($LASTEXITCODE -ne 0) { throw 'Cannot read compiler identity' }
  $results = @()
  foreach ($profile in @('development', 'release')) {
    $testArguments = @('test', '--native', '--capture-output', '--json')
    $buildArguments = @('build', '--locked')
    if ($profile -eq 'release') { $testArguments += @('--release', '--locked'); $buildArguments += '--release' }
    $nativeOutput = & $Compiler @testArguments
    if ($LASTEXITCODE -ne 0) { throw "Native tests failed: $profile" }
    $native = $nativeOutput | ConvertFrom-Json
    if ($native.status -ne 'ok' -or $native.failed -ne 0 -or $native.passed -ne 51) { throw 'Unexpected native test outcomes' }
    $buildOutput = & $Compiler @buildArguments
    if ($LASTEXITCODE -ne 0) { throw "Build failed: $profile" }
    $exe = Join-Path $output "browniec-$profile.exe"
    Copy-Item -LiteralPath (Join-Path $repo 'build/browniec.exe') -Destination $exe -Force
    & python -B (Join-Path $PSScriptRoot 'check-m1-cli.py') --exe $exe --profile $profile
    if ($LASTEXITCODE -ne 0) { throw "CLI verification failed: $profile" }
    $cli = Get-Content -LiteralPath (Join-Path $output "$profile/cli-receipt.json") -Raw | ConvertFrom-Json
    $results += [ordered]@{ profile = $profile; nativeTests = $native; build = $buildOutput;
      artifact = "build/m1/browniec-$profile.exe"; sha256 = (Get-FileHash -LiteralPath $exe).Hash.ToLowerInvariant();
      bytes = (Get-Item -LiteralPath $exe).Length; cliCases = $cli.count }
  }
  $inputs = @(Get-Item fairy.toml, fairy.lock, tools/verify-m1.ps1, tools/check-m1-cli.py, tools/m1_tagged_cases.py, tools/m1_propagation_cases.py, tools/m1_switch_expression_cases.py, tools/m1_i64_cases.py, examples/loops.brc, examples/tagged.brc, examples/propagation.brc, examples/switch-expression.brc, examples/i64.brc;
    Get-ChildItem src, tests -File -Recurse)
  [ordered]@{ schema = 'browniec.m1-scalar/v1'; status = 'passed'; recordedAt = [DateTime]::UtcNow.ToString('o');
    compilerVersion = $version; compilerSha256 = (Get-FileHash -LiteralPath $Compiler).Hash.ToLowerInvariant();
    os = [Environment]::OSVersion.VersionString; results = $results;
    sourceSha256 = @($inputs | Sort-Object FullName | ForEach-Object {
      [ordered]@{ path = [IO.Path]::GetRelativePath($repo, $_.FullName).Replace('\', '/'); sha256 = (Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant() }
    }); limitations = @('M1 i32/i64/bool scalar expressions, locals, functions, branches, loops, shallow Option/Result and exhaustive tagged switch statements and expressions, and typed question-mark propagation.',
      'Wrapper payloads are i32/bool only; no nested wrappers, aggregate payloads or implicit error conversion; value arms allow local declarations, assignments, and a final expression or direct function return only.',
      'For headers admit pure scalar clauses and reject direct calls, question-mark propagation, and switch expressions; loop termination is bounded by Fuel, not proven.',
      'Tool-free PATH is not clean-machine or OS isolation evidence.', 'No performance target measured.')
  } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $receiptPath -Encoding utf8NoBOM
  Write-Host 'PASS: build/m1/receipt.json'
} finally { Pop-Location }
