﻿#This script exports all ALR objects from a fob based database
param( [parameter(Mandatory=$true)][string]$ServerName, [parameter(Mandatory=$true)] [string]$DatabaseName, [parameter(Mandatory=$true)] [string]$WorkDirectory, [parameter(Mandatory=$true)][string][ValidateSet("txt","fob")]$FileExtension)

#Create directory for temporary files
$ModifiedPath = $(Join-Path $WorkDirectory "MODIFIED")
New-Item -ItemType Directory -Force -Path $ModifiedPath

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

    Export-NAVApplicationObject -DatabaseName $DatabaseName -DatabaseServer $ServerName -Path $(Join-Path $ModifiedPath "$objectPrefix$ObjectId.$FileExtension") -Filter "Type=$ObjectType;Id=$ObjectId" -Force -ExportToNewSyntax
}

exportObject -ObjectId 61000 -ObjectType Codeunit
exportObject -ObjectId 61001 -ObjectType Codeunit
exportObject -ObjectId 61002 -ObjectType Codeunit
exportObject -ObjectId 61003 -ObjectType Codeunit
exportObject -ObjectId 6085579 -ObjectType Table
exportObject -ObjectId 6085580 -ObjectType Table
exportObject -ObjectId 6085597 -ObjectType Page
exportObject -ObjectId 6085584 -ObjectType Page
exportObject -ObjectId 6085586 -ObjectType Page