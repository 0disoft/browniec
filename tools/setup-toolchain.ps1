#Requires -Version 7.0
param([string]$CompilerFile, [string]$SourceRepository, [switch]$FromSource)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$arguments = @('-B', (Join-Path $PSScriptRoot 'setup-toolchain.py'))
if ($CompilerFile) { $arguments += @('--compiler-file', $CompilerFile) }
if ($SourceRepository) { $arguments += @('--source-repository', $SourceRepository) }
if ($FromSource) { $arguments += '--from-source' }
& python @arguments
exit $LASTEXITCODE
