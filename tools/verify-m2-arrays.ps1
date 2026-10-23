param(
  [ValidateSet('ir', 'vm')][string]$Slice = 'ir',
  [string]$Compiler = (Join-Path $PSScriptRoot '../build/toolchain/fairyc.exe')
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$Compiler = (Resolve-Path -LiteralPath $Compiler).Path
$output = Join-Path $repo "build/m2-array-$Slice"
New-Item -ItemType Directory -Force $output | Out-Null
$receiptPath = Join-Path $output 'receipt.json'
[ordered]@{ status = 'incomplete'; startedAt = [DateTime]::UtcNow.ToString('o') } |
  ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding utf8NoBOM
if ($env:CL -or $env:_CL_) { throw 'Unexpected CL/_CL_ override' }
$files = if ($Slice -eq 'ir') { @('tests/m2/array_ir.fy', 'tests/branches.fy', 'tests/loops.fy') } else { @('tests/m2/array_vm.fy') }
$expected = if ($Slice -eq 'ir') { 16 } else { 6 }
Push-Location $repo
try {
  $version = & $Compiler --version
  if ($LASTEXITCODE -ne 0) { throw 'Cannot identify compiler' }
  $check = & $Compiler check --locked
  if ($LASTEXITCODE -ne 0) { throw 'Locked check failed' }
  $inputs = @(Get-Item fairy.toml, fairy.lock, tools/verify-m2-arrays.ps1;
    $files | ForEach-Object { Get-Item -LiteralPath $_ }; Get-ChildItem src -File -Recurse)
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
    if ($LASTEXITCODE -ne 0) { throw "Native array $Slice tests failed: $profile" }
    $native = $nativeOutput | ConvertFrom-Json
    if ($native.status -ne 'ok' -or $native.failed -ne 0 -or $native.passed -ne $expected) { throw 'Unexpected native outcomes' }
    $results += [ordered]@{ profile = $profile; nativeTests = $native }
  }
  foreach ($item in $identities) {
    if ((Get-FileHash -LiteralPath (Join-Path $repo $item.path)).Hash.ToLowerInvariant() -ne $item.sha256) {
      throw "Verification input changed: $($item.path)"
    }
  }
  if ((Get-FileHash -LiteralPath $Compiler).Hash.ToLowerInvariant() -ne $compilerHash) { throw 'Compiler changed' }
  [ordered]@{ schema = "browniec.m2-array-$Slice/v1"; status = 'passed'; recordedAt = [DateTime]::UtcNow.ToString('o');
    compilerVersion = $version; compilerSha256 = $compilerHash; os = [Environment]::OSVersion.VersionString;
    lockedCheck = $check; results = $results; sourceSha256 = $identities;
    artifacts = 'Tool-managed temporary native test images; no public array bytecode loader or source syntax.';
    limitations = @('Private entry-function array IR; scalar functions cannot receive or return arrays.',
      'Source-array parsing, borrow analysis and full profile remain incomplete.',
      'Each receipt establishes only the selected slice, not later VM or delivery gates.',
      'No isolation, DLL, clean-machine or performance claim.')
  } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $receiptPath -Encoding utf8NoBOM
  Write-Host "PASS: build/m2-array-$Slice/receipt.json"
} finally { Pop-Location }
