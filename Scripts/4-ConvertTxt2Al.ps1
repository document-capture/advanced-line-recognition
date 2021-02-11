#This script converts the DELTA files to AL files
param([string]$WorkDirectory)

$DeltaPath = $(Join-Path $WorkDirectory "DELTA")
$ALPath = $(Join-Path $WorkDirectory "AL")
New-Item -ItemType Directory -Force -Path $ALPath

$txt2Al = "C:\Program Files (x86)\Microsoft Dynamics 365 Business Central\140\RoleTailored Client\Txt2Al.exe"
$txt2alParameters = @("--source=""$DeltaPath""", "--target=""$ALPath""", "--rename")

Write-Host "txt2al.exe $([string]::Join(' ', $txt2alParameters))"
& $txt2al $txt2alParameters 2> $null