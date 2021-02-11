#This script creates the DELTA files from the ORIGINAL BC Objects (step 1) and the ALR objects (step 2)
param([string]$WorkDirectory)

#Create directory for DELTA files
New-Item -ItemType Directory -Force -Path $(Join-Path $WorkDirectory "DELTA")

Compare-NAVApplicationObject -OriginalPath $(Join-Path $WorkDirectory "ORIGINAL\*.txt") -ModifiedPath $(Join-Path $WorkDirectory "MODIFIED\*.txt") -DeltaPath $(Join-Path $WorkDirectory "DELTA") -ExportToNewSyntax