#Requires -Version 7.0
param(
  [string]$CompilerFile,
  [string]$SourceRepository
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $IsWindows -or [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'X64') {
  throw 'This toolchain requires Windows/AMD64.'
}
if ($CompilerFile -and $SourceRepository) { throw 'Choose CompilerFile or SourceRepository, not both.' }
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$manifestPath = Join-Path $repo 'toolchain.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$lock = Get-Content -LiteralPath (Join-Path $repo 'fairy.lock') -Raw | ConvertFrom-Json
if ($manifest.schema -ne 'browniec.toolchain/v1' -or $manifest.platform -ne 'windows/amd64' -or
    $manifest.compiler.revision -cnotmatch '^[0-9a-f]{40}$' -or $manifest.compiler.sha256 -cnotmatch '^[0-9a-f]{64}$') {
  throw 'Unsupported toolchain manifest or invalid compiler identity.'
}
$stdlib = @($lock.packages | Where-Object role -eq 'standard-library')
if ($stdlib.Count -ne 1 -or $lock.language -cne $manifest.language -or
    $stdlib[0].sdkIdentity -cne $manifest.sdk.identity -or $stdlib[0].version -cne $manifest.sdk.version -or
    $stdlib[0].runtimeAbi -cne $manifest.runtimeAbi -or $stdlib[0].sourceDigest -cne $manifest.sdk.sourceDigest) {
  throw 'toolchain.json and fairy.lock disagree; adopt the SDK and language together.'
}
function Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Set-SetupEnvironment([string]$Name, $Value) {
  if ($null -eq $Value) { Remove-Item -LiteralPath ('Env:' + $Name) -ErrorAction SilentlyContinue }
  else { [Environment]::SetEnvironmentVariable($Name, $Value, 'Process') }
}
function Validate-Compiler([string]$Path) {
  if ((Hash $Path) -cne $manifest.compiler.sha256) { throw 'Compiler SHA-256 mismatch; no executable was run or installed.' }
  $lines = @(& $Path --version)
  if ($LASTEXITCODE -ne 0) { throw 'Cannot identify the verified compiler.' }
  foreach ($expected in @("compiler: $($manifest.compiler.version)",
      "sdk: $($manifest.sdk.identity) $($manifest.sdk.version)", "language: $($manifest.language)",
      "runtime: $($manifest.runtimeAbi)", "revision: $($manifest.compiler.revision)", 'modified: false')) {
    if ($lines -cnotcontains $expected) { throw "Compiler identity mismatch: $expected" }
  }
  return $lines
}
$output = Join-Path $repo 'build/toolchain'
$destination = Join-Path $output 'fairyc.exe'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$scratch = Join-Path $output ('.setup-' + [Guid]::NewGuid().ToString('N'))
$savedEnvironment = @{}
$environmentValues = @{
  GOENV = 'off'; GOWORK = 'off'; GOTOOLCHAIN = 'local'; GOFLAGS = ''; GOEXPERIMENT = '';
  CGO_ENABLED = '0'; GOOS = 'windows'; GOARCH = 'amd64'; GOAMD64 = 'v1';
  GIT_TERMINAL_PROMPT = '0'; GCM_INTERACTIVE = 'never';
  GIT_DIR = $null; GIT_WORK_TREE = $null; GIT_COMMON_DIR = $null; GIT_INDEX_FILE = $null;
  GIT_OBJECT_DIRECTORY = $null; GIT_ALTERNATE_OBJECT_DIRECTORIES = $null;
  GIT_CONFIG = $null; GIT_CONFIG_PARAMETERS = $null; GIT_CONFIG_COUNT = '0'
}
try {
  $mode = 'existing'
  if (-not $CompilerFile -and -not $SourceRepository -and (Test-Path -LiteralPath $destination)) {
    $version = @(Validate-Compiler $destination)
  } else {
    New-Item -ItemType Directory -Path $scratch | Out-Null
    $candidate = Join-Path $scratch 'fairyc.exe'
    if ($CompilerFile) {
      $mode = 'file'
      Copy-Item -LiteralPath (Resolve-Path -LiteralPath $CompilerFile).Path -Destination $candidate
    } else {
      $mode = 'source-build'
      foreach ($key in $environmentValues.Keys) {
        $savedEnvironment[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
        Set-SetupEnvironment $key $environmentValues[$key]
      }
      # Explicit repository overrides are local paths. The only remote fallback
      # is the HTTPS repository recorded in this reviewed manifest.
      $source = if ($SourceRepository) { (Resolve-Path -LiteralPath $SourceRepository).Path }
        elseif (Test-Path -LiteralPath (Join-Path $repo $manifest.source.localRepository)) {
          (Resolve-Path -LiteralPath (Join-Path $repo $manifest.source.localRepository)).Path
        } else { $manifest.source.repository }
      if ($source -match '^[a-zA-Z][a-zA-Z0-9+.-]*://' -and $source -notmatch '^https://[^/@]+/') {
        throw 'Remote source must use HTTPS without embedded credentials.'
      }
      if ($manifest.bootstrap.package -cne './cmd/fairyc' -or
          (@($manifest.bootstrap.buildFlags) -join ' ') -cne '-mod=readonly -trimpath -buildvcs=true') {
        throw 'Unsupported bootstrap build recipe.'
      }
      $goVersion = & go env GOVERSION
      if ($LASTEXITCODE -ne 0 -or $goVersion -cne $manifest.bootstrap.goVersion) {
        throw "Source bootstrap requires $($manifest.bootstrap.goVersion); install it separately or supply CompilerFile."
      }
      $checkout = Join-Path $scratch 'source'
      & git -c core.autocrlf=false init --quiet $checkout
      if ($LASTEXITCODE -ne 0) { throw 'Cannot initialize isolated compiler source.' }
      & git -C $checkout config core.autocrlf false
      if ($LASTEXITCODE -ne 0) { throw 'Cannot configure isolated compiler source.' }
      & git -C $checkout config core.longpaths true
      if ($LASTEXITCODE -ne 0) { throw 'Cannot enable Windows long paths for isolated compiler source.' }
      & git -C $checkout fetch --quiet --no-tags --depth=1 -- $source $manifest.compiler.revision
      if ($LASTEXITCODE -ne 0) { throw 'Cannot fetch the selected compiler commit; check repository access.' }
      & git -C $checkout checkout --quiet --detach FETCH_HEAD
      if ($LASTEXITCODE -ne 0) { throw 'Cannot check out the selected compiler commit.' }
      $revision = & git -C $checkout rev-parse HEAD
      $dirty = @(& git -C $checkout status --porcelain --untracked-files=all)
      if ($LASTEXITCODE -ne 0 -or $revision -cne $manifest.compiler.revision -or $dirty.Count -ne 0) {
        throw 'Compiler source identity mismatch or dirty isolated checkout.'
      }
      Push-Location $checkout
      try {
        & go build @($manifest.bootstrap.buildFlags) -o $candidate $manifest.bootstrap.package
        if ($LASTEXITCODE -ne 0) { throw 'Compiler source build failed.' }
      } finally { Pop-Location }
    }
    $version = @(Validate-Compiler $candidate)
    # Candidate and destination share a volume. Validation precedes replacement;
    # failures during acquisition/build leave an existing compiler untouched.
    [IO.File]::Move($candidate, $destination, $true)
  }
  [ordered]@{
    schema = 'browniec.toolchain-setup/v1'; status = 'passed'; mode = $mode;
    recordedAt = [DateTime]::UtcNow.ToString('o'); manifestSha256 = Hash $manifestPath;
    compilerSha256 = Hash $destination; compilerVersion = $version;
    artifact = 'build/toolchain/fairyc.exe'
  } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output 'setup-receipt.json') -Encoding utf8NoBOM
  Write-Host "PASS: $mode; build/toolchain/fairyc.exe"
} finally {
  foreach ($key in $savedEnvironment.Keys) {
    Set-SetupEnvironment $key $savedEnvironment[$key]
  }
  if (Test-Path -LiteralPath $scratch) {
    $relative = [IO.Path]::GetRelativePath($output, [IO.Path]::GetFullPath($scratch))
    if ([IO.Path]::IsPathRooted($relative) -or $relative.StartsWith('..') -or $relative -notmatch '^\.setup-[0-9a-f]{32}$') {
      throw 'Refusing cleanup outside the toolchain scratch directory.'
    }
    Remove-Item -LiteralPath $scratch -Recurse -Force
  }
}
