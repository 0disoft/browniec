param([string]$Compiler = (Join-Path $PSScriptRoot '../build/toolchain/fairyc.exe'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$Compiler = (Resolve-Path -LiteralPath $Compiler).Path
$output = Join-Path $repo 'build/m2-storage'
New-Item -ItemType Directory -Force $output | Out-Null
$receiptPath = Join-Path $output 'receipt.json'
[ordered]@{ status = 'incomplete'; startedAt = [DateTime]::UtcNow.ToString('o') } |
  ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding utf8NoBOM
if ($env:CL -or $env:_CL_) { throw 'Unexpected CL/_CL_ override' }
Push-Location $repo
try {
  $version = & $Compiler --version
  if ($LASTEXITCODE -ne 0) { throw 'Cannot read compiler identity' }
  $check = & $Compiler check --locked
  if ($LASTEXITCODE -ne 0) { throw 'Locked source check failed' }
  $inputs = @(Get-Item fairy.toml, fairy.lock, tools/verify-m2-storage.ps1,
    tests/m2/scalar_codec.fy, tests/m2/array_storage.fy; Get-ChildItem src -File -Recurse)
  $identities = @($inputs | Sort-Object FullName | ForEach-Object {
    [ordered]@{ path = [IO.Path]::GetRelativePath($repo, $_.FullName).Replace('\', '/');
      sha256 = (Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant() }
  })
  $compilerHash = (Get-FileHash -LiteralPath $Compiler).Hash.ToLowerInvariant()
  $results = @()
  foreach ($profile in @('development', 'release')) {
    $testArguments = @('test', '--native', '--file', 'tests/m2/scalar_codec.fy',
      '--file', 'tests/m2/array_storage.fy', '--capture-output', '--json', '--locked')
    if ($profile -eq 'release') { $testArguments += '--release' }
    $nativeOutput = & $Compiler @testArguments
    if ($LASTEXITCODE -ne 0) { throw "Native storage tests failed: $profile" }
    $native = $nativeOutput | ConvertFrom-Json
    if ($native.status -ne 'ok' -or $native.failed -ne 0 -or $native.passed -ne 9) { throw 'Unexpected storage test outcomes' }
    $results += [ordered]@{ profile = $profile; nativeTests = $native }
  }
  foreach ($item in $identities) {
    if ((Get-FileHash -LiteralPath (Join-Path $repo $item.path)).Hash.ToLowerInvariant() -ne $item.sha256) {
      throw "Verification input changed: $($item.path)"
    }
  }
  if ((Get-FileHash -LiteralPath $Compiler).Hash.ToLowerInvariant() -ne $compilerHash) { throw 'Compiler changed during verification' }
  [ordered]@{ schema = 'browniec.m2-array-storage/v1'; status = 'passed';
    recordedAt = [DateTime]::UtcNow.ToString('o'); compilerVersion = $version; compilerSha256 = $compilerHash;
    os = [Environment]::OSVersion.VersionString; lockedCheck = $check;
    results = $results; sourceSha256 = $identities;
    artifacts = 'Tool-managed temporary native test images; no shipped CLI array artifact.';
    limitations = @('Caller-owned backing bytes with a private bounded cursor; repeated scalar initialization and checked element reads/writes.',
      'Little-endian scalar codecs preserve full signed and packed unsigned cells and reject noncanonical bool.',
      'No source arrays, aggregate IR, runtime allocation, ownership tokens, frame cleanup or aggregate Fuel yet.',
      'No isolation, DLL, packaging or performance claim.')
  } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $receiptPath -Encoding utf8NoBOM
  Write-Host 'PASS: build/m2-storage/receipt.json'
} finally { Pop-Location }
