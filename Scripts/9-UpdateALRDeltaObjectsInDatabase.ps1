#This scripts updates an existing fob based CDC database with the ALR  objects from step 2
param([string]$ServerName, [string]$DatabaseName, [string]$WorkDirectory, [string]$DeltaPath)

#Create directory for temporary files
$OriginalPath = $(Join-Path $WorkDirectory "ORIGINAL")
$ResultPath = $(Join-Path $WorkDirectory "RESULT")
New-Item -ItemType Directory -Force -Path $OriginalPath
New-Item -ItemType Directory -Force -Path $ResultPath

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

function getCurrentVersionList
{
    param([string]$ObjectFilePath)

    $currentObject = Get-NAVApplicationObjectProperty -source $ObjectFilePath 
    
    return $currentObject.VersionList
}

function updateObject
{
    param([int]$ObjectId,
          [Parameter()][ValidateSet('Page','Codeunit','Table')][string[]]$ObjectType)
    
    $objectPrefix = getObjectPrefix -ObjectType $ObjectType

    if($ObjectId -gt 99999) 
    {
        Export-NAVApplicationObject -DatabaseName $DatabaseName -DatabaseServer $ServerName -Path $(Join-Path $OriginalPath "$objectPrefix$ObjectId.txt") -Filter "Type=$ObjectType;Id=$ObjectId" -Force
        Update-NAVApplicationObject -TargetPath $(Join-Path $OriginalPath "$objectPrefix$ObjectId.txt") -DeltaPath $(Join-Path $DeltaPath "$objectPrefix$ObjectId.DELTA") -ResultPath $(Join-Path $ResultPath "$objectPrefix$ObjectId.txt") -ModifiedProperty Yes -Force
        $UpdatedVersionList = getCurrentVersionList -ObjectFilePath $(Join-Path $OriginalPath "$objectPrefix$ObjectId.txt")
        $UpdatedVersionList = "$UpdatedVersionList,ALR"
        Set-NAVApplicationObjectProperty -TargetPath $(Join-Path $ResultPath "$objectPrefix$ObjectId.txt") -VersionListProperty $UpdatedVersionList
    } else {
        Export-NAVApplicationObject -DatabaseName $DatabaseName -DatabaseServer $ServerName -Path $(Join-Path $OriginalPath "$objectPrefix$ObjectId.txt") -Filter "Type=$ObjectType;Id=$ObjectId" -Force
        Copy-Item -Path $(Join-Path $DeltaPath "$objectPrefix$ObjectId.DELTA") -Destination $(Join-Path $ResultPath "$objectPrefix$ObjectId.txt")
    }
    Import-NAVApplicationObject -Path $(Join-Path $ResultPath "$objectPrefix$ObjectId.txt") -DatabaseName $DatabaseName -DatabaseServer $ServerName -SynchronizeSchemaChanges Force -Confirm:$false
    
}

updateObject -ObjectId 61000 -ObjectType Codeunit
updateObject -ObjectId 61001 -ObjectType Codeunit
updateObject -ObjectId 61002 -ObjectType Codeunit
updateObject -ObjectId 61003 -ObjectType Codeunit
updateObject -ObjectId 6085580 -ObjectType Table
updateObject -ObjectId 6085597 -ObjectType Page
updateObject -ObjectId 6085586 -ObjectType Page
#updateObject -ObjectId 6085575 -ObjectType Codeunit
Compile-NAVApplicationObject -DatabaseName $DatabaseName -DatabaseServer $ServerName -Filter "Version List=*ALR*"