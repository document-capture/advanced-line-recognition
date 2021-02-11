#This script exports the original CDC objects from a fob based database 
param([string]$ServerName, [string]$DatabaseName, [string]$WorkDirectory)

#Create directory for temporary files
$OriginalPath = $(Join-Path $WorkDirectory "ORIGINAL")
New-Item -ItemType Directory -Force -Path $OriginalPath

function getObjectPrefix
{
    param([string]$ObjectType)

    switch($ObjectType) 
    {
        "Page" {"PAG"; break}
        "Codeunit" {"COD"; break}
        "Table" {"TAB"; break}
    }
}

function exportObject 
{
    param([int]$ObjectId,
          [Parameter()][ValidateSet('Page','Codeunit','Table')][string[]]$ObjectType)
    
    $objectPrefix = getObjectPrefix -ObjectType $ObjectType

    Export-NAVApplicationObject -DatabaseName $DatabaseName -DatabaseServer $ServerName -Path $(Join-Path $OriginalPath "$objectPrefix$ObjectId.txt") -Filter "Type=$ObjectType;Id=$ObjectId" -Force -ExportToNewSyntax
}

exportObject -ObjectId 6085580 -ObjectType Table
exportObject -ObjectId 6085597 -ObjectType Page
exportObject -ObjectId 6085586 -ObjectType Page