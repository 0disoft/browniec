#Requires -Version 7.0
param([string]$SourceRepository = (Join-Path $PSScriptRoot '../../fairyc'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
& python -B (Join-Path $PSScriptRoot 'verify-toolchain.py') --source-repository $SourceRepository
exit $LASTEXITCODE
