param([string]$Compiler = (Join-Path $PSScriptRoot '../build/toolchain/fairyc.exe'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$Compiler = (Resolve-Path -LiteralPath $Compiler).Path
$output = Join-Path $repo 'build/m2-owners'
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
  $inputs = @(Get-Item fairy.toml, fairy.lock, tools/verify-m2-owners.ps1, tests/m2/array_owners.fy;
    Get-ChildItem src -File -Recurse)
  $identities = @($inputs | Sort-Object FullName | ForEach-Object {
    [ordered]@{ path = [IO.Path]::GetRelativePath($repo, $_.FullName).Replace('\', '/');
      sha256 = (Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant() }
  })
  $compilerHash = (Get-FileHash -LiteralPath $Compiler).Hash.ToLowerInvariant()
  $results = @()
  foreach ($profile in @('development', 'release')) {
    $testArguments = @('test', '--native', '--file', 'tests/m2/array_owners.fy', '--capture-output', '--json', '--locked')
    if ($profile -eq 'release') { $testArguments += '--release' }
    $nativeOutput = & $Compiler @testArguments
    if ($LASTEXITCODE -ne 0) { throw "Native owner tests failed: $profile" }
    $native = $nativeOutput | ConvertFrom-Json
    if ($native.status -ne 'ok' -or $native.failed -ne 0 -or $native.passed -ne 5) { throw 'Unexpected owner test outcomes' }
    $results += [ordered]@{ profile = $profile; nativeTests = $native }
  }
  foreach ($item in $identities) {
    if ((Get-FileHash -LiteralPath (Join-Path $repo $item.path)).Hash.ToLowerInvariant() -ne $item.sha256) {
      throw "Verification input changed: $($item.path)"
    }
  }
  if ((Get-FileHash -LiteralPath $Compiler).Hash.ToLowerInvariant() -ne $compilerHash) { throw 'Compiler changed during verification' }
  [ordered]@{ schema = 'browniec.m2-array-owners/v1'; status = 'passed';
    recordedAt = [DateTime]::UtcNow.ToString('o'); compilerVersion = $version; compilerSha256 = $compilerHash;
    os = [Environment]::OSVersion.VersionString; lockedCheck = $check;
    results = $results; sourceSha256 = $identities;
    artifacts = 'Tool-managed temporary native test images; no shipped CLI array artifact.';
    limitations = @('Instance-local 16-slot metadata, generation-safe release, suffix reclamation and whole-table clear over caller-owned bytes.',
      'Retained dead middle extents count toward owner and arena limits until the suffix is released.',
      'No source arrays, copy operation, dynamic backing allocator, borrow checker integration, aggregate IR, frame cleanup or Fuel yet.',
      'Tokens are scoped to one table lifetime; caller binds table to backing bytes. No cross-instance or public-handle claim.',
      'No isolation, DLL, packaging or performance claim.')
  } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $receiptPath -Encoding utf8NoBOM
  Write-Host 'PASS: build/m2-owners/receipt.json'
} finally { Pop-Location }
