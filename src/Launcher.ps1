# Started by WintoolBox.bat: turns its raw command line into parameters for the application.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\Common.ps1')
Set-EnglishCulture
$parameters = ConvertTo-LauncherParameters -CommandLine $env:WTB_ARGS
& (Join-Path $PSScriptRoot 'WinToolBox.ps1') @parameters
exit $LASTEXITCODE
