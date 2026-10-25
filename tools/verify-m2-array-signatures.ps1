param([string]$Compiler = (Join-Path $PSScriptRoot '../build/toolchain/fairyc.exe'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$Compiler = (Resolve-Path -LiteralPath $Compiler).Path
$output = Join-Path $repo 'build/m2-array-signatures'
New-Item -ItemType Directory -Force $output | Out-Null
$receiptPath = Join-Path $output 'receipt.json'
[ordered]@{ status = 'incomplete'; startedAt = [DateTime]::UtcNow.ToString('o') } |
  ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding utf8NoBOM
if ($env:CL -or $env:_CL_) { throw 'Unexpected CL/_CL_ override' }
Push-Location $repo
try {
  $version = & $Compiler --version
  if ($LASTEXITCODE -ne 0) { throw 'Cannot identify compiler' }
  & $Compiler check --locked
  if ($LASTEXITCODE -ne 0) { throw 'Locked check failed' }
  $files = @('tests/functions.fy', 'tests/m2/array_helpers.fy', 'tests/m2/array_signatures.fy')
  $inputs = @(Get-Item fairy.toml, fairy.lock, toolchain.json, tools/verify-m2-array-signatures.ps1;
    Get-ChildItem src -File -Recurse; $files | ForEach-Object { Get-Item -LiteralPath $_ };
    Get-ChildItem tools -File -Filter '*.py'; Get-ChildItem examples -File -Filter '*.brc')
  $identities = @($inputs | Sort-Object FullName | ForEach-Object {
    [ordered]@{ path = [IO.Path]::GetRelativePath($repo, $_.FullName).Replace('\', '/');
      sha256 = (Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant() }
  })
  $results = @()
  foreach ($profile in @('development', 'release')) {
    $arguments = @('test', '--native', '--capture-output', '--json', '--locked')
    foreach ($file in $files) { $arguments += @('--file', $file) }
    if ($profile -eq 'release') { $arguments += '--release' }
    $nativeOutput = & $Compiler @arguments
    $nativeExit = $LASTEXITCODE
    $nativeOutput | Set-Content -LiteralPath (Join-Path $output "$profile-native-output.json") -Encoding utf8NoBOM
    if ($nativeExit -ne 0) { throw "Native signature tests failed: $profile" }
    $native = $nativeOutput | ConvertFrom-Json
    if ($native.status -ne 'ok' -or $native.failed -ne 0 -or $native.passed -ne 16) { throw 'Unexpected native outcomes' }
    $buildArguments = @('build', '--locked')
    if ($profile -eq 'release') { $buildArguments += '--release' }
    $buildOutput = & $Compiler @buildArguments
    if ($LASTEXITCODE -ne 0) { throw "Build failed: $profile" }
    $exe = Join-Path $output "browniec-$profile.exe"
    Copy-Item -LiteralPath (Join-Path $repo 'build/browniec.exe') -Destination $exe -Force
    $cliResults = @()
    foreach ($suite in @('m1-cli', 'm2-array-source', 'm2-array-helpers')) {
      & python -B (Join-Path $PSScriptRoot "check-$suite.py") --exe $exe --profile $profile
      if ($LASTEXITCODE -ne 0) { throw "CLI checks failed: $profile $suite" }
      $directory = if ($suite -eq 'm1-cli') { 'm1' } else { $suite }
      $cliPath = Join-Path $repo "build/$directory/$profile/cli-receipt.json"
      $cli = Get-Content -LiteralPath $cliPath -Raw | ConvertFrom-Json
      $expected = if ($suite -eq 'm1-cli') { 1969 } elseif ($suite -eq 'm2-array-source') { 67 } else { 97 }
      $hash = (Get-FileHash -LiteralPath $exe).Hash.ToLowerInvariant()
      if ($cli.status -ne 'passed' -or $cli.count -ne $expected -or $cli.exeSha256 -ne $hash) { throw 'Unexpected CLI receipt' }
      $cliResults += [ordered]@{ suite = $suite; count = $cli.count;
        receiptSha256 = (Get-FileHash -LiteralPath $cliPath).Hash.ToLowerInvariant() }
    }
    $results += [ordered]@{ profile = $profile; nativeTests = $native; build = $buildOutput;
      artifact = "build/m2-array-signatures/browniec-$profile.exe";
      sha256 = (Get-FileHash -LiteralPath $exe).Hash.ToLowerInvariant(); cli = $cliResults }
  }
  [ordered]@{ schema = 'browniec.m2-array-signatures/v1'; status = 'passed';
    recordedAt = [DateTime]::UtcNow.ToString('o'); compilerVersion = $version;
    compilerSha256 = (Get-FileHash -LiteralPath $Compiler).Hash.ToLowerInvariant();
    os = [Environment]::OSVersion.VersionString; sourceSha256 = $identities; results = $results;
    limitations = @('Signature metadata only: all array parameter declarations still fail compilation with type error.',
      'No array call lowering, snapshot, transaction, verifier or VM implementation is claimed.',
      'Full scalar/private array/M0 native suites, allocator instrumentation, Linux, isolation, DLL and performance checks skipped.')
  } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $receiptPath -Encoding utf8NoBOM
  Write-Host 'PASS: build/m2-array-signatures/receipt.json'
} finally { Pop-Location }
