param([string]$Compiler = (Join-Path $PSScriptRoot '../build/toolchain/fairyc.exe'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$Compiler = (Resolve-Path -LiteralPath $Compiler).Path
$output = Join-Path $repo 'build/m2-layout'
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
  $inputs = @(Get-Item fairy.toml, fairy.lock, tools/verify-m1.ps1, tools/verify-m2-layout.ps1, tests/m2/array_layout.fy;
    Get-ChildItem src -File -Recurse)
  $identities = @($inputs | Sort-Object FullName | ForEach-Object {
    [ordered]@{ path = [IO.Path]::GetRelativePath($repo, $_.FullName).Replace('\', '/');
      sha256 = (Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant() }
  })
  $results = @()
  foreach ($profile in @('development', 'release')) {
    $testArguments = @('test', '--native', '--file', 'tests/m2/array_layout.fy', '--capture-output', '--json', '--locked')
    if ($profile -eq 'release') { $testArguments += '--release' }
    $nativeOutput = & $Compiler @testArguments
    if ($LASTEXITCODE -ne 0) { throw "Native layout tests failed: $profile" }
    $native = $nativeOutput | ConvertFrom-Json
    if ($native.status -ne 'ok' -or $native.failed -ne 0 -or $native.passed -ne 6) { throw 'Unexpected layout test outcomes' }
    $results += [ordered]@{ profile = $profile; nativeTests = $native }
  }
  foreach ($item in $identities) {
    if ((Get-FileHash -LiteralPath (Join-Path $repo $item.path)).Hash.ToLowerInvariant() -ne $item.sha256) {
      throw "Verification input changed: $($item.path)"
    }
  }
  [ordered]@{ schema = 'browniec.m2-array-layout/v1'; status = 'passed';
    recordedAt = [DateTime]::UtcNow.ToString('o');
    compilerVersion = $version; compilerSha256 = (Get-FileHash -LiteralPath $Compiler).Hash.ToLowerInvariant();
    os = [Environment]::OSVersion.VersionString; lockedCheck = $check;
    results = $results; sourceSha256 = $identities;
    artifacts = 'Tool-managed temporary native test images; no shipped CLI or array runtime artifact.';
    limitations = @('Private scalar-array layout, alignment, arena quota preflight and checked byte offsets only.',
      'Array source syntax, initialization, copies, frames, allocation, ledgers and aggregate Fuel are not implemented.',
      'M1 source grammar and IR/VM execution are unchanged; M2 is partial.',
      'No isolation, DLL, clean-machine packaging or performance claim.')
  } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $receiptPath -Encoding utf8NoBOM
  Write-Host 'PASS: build/m2-layout/receipt.json'
} finally { Pop-Location }
