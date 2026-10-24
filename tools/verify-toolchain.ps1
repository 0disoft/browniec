#Requires -Version 7.0
param([string]$SourceRepository = (Join-Path $PSScriptRoot '../../fairyc'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = (Resolve-Path -LiteralPath $SourceRepository).Path
$compiler = Join-Path $repo 'build/toolchain/fairyc.exe'
$manifest = Get-Content -LiteralPath (Join-Path $repo 'toolchain.json') -Raw | ConvertFrom-Json
$expectedHash = $manifest.compiler.sha256
$output = Join-Path $repo 'build/toolchain-verification'
New-Item -ItemType Directory -Force $output | Out-Null
$receiptPath = Join-Path $output 'receipt.json'
@{ status = 'incomplete' } | ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding utf8NoBOM
$scratch = Join-Path $output ([Guid]::NewGuid().ToString('N'))
$results = @()
function Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Fixture([string]$Name) {
  $path = Join-Path $scratch $Name
  New-Item -ItemType Directory -Path (Join-Path $path 'tools') -Force | Out-Null
  foreach ($file in @('toolchain.json', 'fairy.lock')) { Copy-Item -LiteralPath (Join-Path $repo $file) -Destination $path }
  Copy-Item -LiteralPath (Join-Path $repo 'tools/setup-toolchain.ps1') -Destination (Join-Path $path 'tools')
  return $path
}
function Run([string]$Path, [string[]]$Arguments, [bool]$Success, [string]$Message) {
  $captured = @(& pwsh -NoProfile -File (Join-Path $Path 'tools/setup-toolchain.ps1') @Arguments 2>&1)
  if (($LASTEXITCODE -eq 0) -ne $Success -or ($captured -join "`n") -notmatch [regex]::Escape($Message)) {
    throw "Unexpected setup result: $($captured -join [Environment]::NewLine)"
  }
  if (@(Get-ChildItem -LiteralPath (Join-Path $Path 'build/toolchain') -Directory -Filter '.setup-*' -ErrorAction SilentlyContinue).Count -ne 0) {
    throw 'Setup leaked a scratch directory.'
  }
}
function Preserved([string]$Path) {
  if ((Hash (Join-Path $Path 'build/toolchain/fairyc.exe')) -cne $expectedHash) { throw 'Existing compiler changed.' }
}
try {
  if ((Hash $compiler) -cne $expectedHash) { throw 'Verification requires the adopted compiler.' }
  $fixture = Fixture 'acquisition'
  Run $fixture @('-CompilerFile', $compiler) $true 'PASS: file'
  Preserved $fixture
  $results += 'verified executable import'
  Run $fixture @() $true 'PASS: existing'
  $results += 'existing compiler reuse'
  $bad = Join-Path $scratch 'invalid.exe'
  [IO.File]::WriteAllText($bad, 'This unverified input must never execute.')
  Run $fixture @('-CompilerFile', $bad) $false 'Compiler SHA-256 mismatch'
  Preserved $fixture
  $results += 'corrupt input rejected before execution; existing compiler preserved'
  $changed = Get-Content -LiteralPath (Join-Path $fixture 'toolchain.json') -Raw | ConvertFrom-Json
  $changed.compiler.version = 'incorrect-version'
  $changed | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $fixture 'toolchain.json') -Encoding utf8NoBOM
  Run $fixture @('-CompilerFile', $compiler) $false 'Compiler identity mismatch'
  Preserved $fixture
  $results += 'version metadata mismatch rejected; existing compiler preserved'
  $changed.sdk.version = 'incorrect-sdk'
  $changed | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $fixture 'toolchain.json') -Encoding utf8NoBOM
  Run $fixture @() $false 'toolchain.json and fairy.lock disagree'
  Preserved $fixture
  $results += 'SDK lock mismatch rejected'
  $tampered = Fixture 'tampered'
  New-Item -ItemType Directory -Path (Join-Path $tampered 'build/toolchain') -Force | Out-Null
  Copy-Item -LiteralPath $bad -Destination (Join-Path $tampered 'build/toolchain/fairyc.exe')
  Run $tampered @() $false 'Compiler SHA-256 mismatch'
  $results += 'tampered cached compiler rejected before execution'
  $rebuilt = Fixture 'source'
  $changed = Get-Content -LiteralPath (Join-Path $rebuilt 'toolchain.json') -Raw | ConvertFrom-Json
  $changed.source.localRepository = [IO.Path]::GetRelativePath($rebuilt, $source)
  $changed | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $rebuilt 'toolchain.json') -Encoding utf8NoBOM
  Run $rebuilt @() $true 'PASS: source-build'
  Preserved $rebuilt
  $results += 'missing compiler defaults to exact-commit isolated source bootstrap and reproduces SHA-256'
  $changed = Get-Content -LiteralPath (Join-Path $rebuilt 'toolchain.json') -Raw | ConvertFrom-Json
  $changed.compiler.revision = '0000000000000000000000000000000000000000'
  $changed | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $rebuilt 'toolchain.json') -Encoding utf8NoBOM
  Run $rebuilt @('-SourceRepository', $source) $false 'Cannot fetch the selected compiler commit'
  Preserved $rebuilt
  $results += 'unavailable source commit rejected; existing compiler preserved'
  [ordered]@{
    schema = 'browniec.toolchain-verification/v1'; status = 'passed';
    recordedAt = [DateTime]::UtcNow.ToString('o'); compilerSha256 = $expectedHash;
    compilerRevision = $manifest.compiler.revision; goVersion = $manifest.bootstrap.goVersion;
    cases = $results; count = $results.Count;
    sourceSha256 = @(foreach ($path in @('toolchain.json', 'fairy.lock', 'tools/setup-toolchain.ps1', 'tools/verify-toolchain.ps1')) {
      [ordered]@{ path = $path; sha256 = Hash (Join-Path $repo $path) }
    });
    limitations = @('Local Windows AMD64 provisioning checks; not a clean-machine or VM regression run.',
      'Authenticated HTTPS acquisition and module-cache-miss network downloads were not exercised.',
      'No automatic latest-version discovery or adoption; other verification tools keep explicit compiler overrides.')
  } | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $receiptPath -Encoding utf8NoBOM
  Write-Host "PASS: $($results.Count) provisioning cases; build/toolchain-verification/receipt.json"
} finally {
  if (Test-Path -LiteralPath $scratch) {
    $relative = [IO.Path]::GetRelativePath($output, [IO.Path]::GetFullPath($scratch))
    if ([IO.Path]::IsPathRooted($relative) -or $relative -notmatch '^[0-9a-f]{32}$') { throw 'Unsafe fixture cleanup path.' }
    Remove-Item -LiteralPath $scratch -Recurse -Force
  }
}
