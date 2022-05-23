<#
.Synopsis
To be used after running the iland-kb3067.ps1 to verify that all data has been evacuated from the source repository. As logging is done by
 user it can be hard to ensure all data has moved from the Data Management job session logs.
.Notes
Version: 1.0
Author: Jim Jones, @k00laidIT
Modified Date: 5/23/2022

.EXAMPLE
.\kb3067-validation.ps1
#>

Import-Module Veeam.Archiver.PowerShell

#Organization selection
$orgs=Get-vboorganization | Sort-Object Name
for($i=0; $i -lt $orgs.count; $i++){write-host $i. $orgs[$i].name}
$organisationNum = Read-Host  "Enter organisation number"
$vboOrg = $orgs[$organisationNum]

$orgjobs = $vboOrg | get-vbojob
[System.Collections.ArrayList]$orgrepos = @()
foreach ($orgjob in $orgjobs) {
    $repo = $orgjob.repository
    $output = [PSCustomObject]@{
        repoName = $repo                         
    }
    $orgrepos += $output        
}

#Source Repository selection
$sourcerepo = $orgrepos
#$sourcerepo=Get-VBORepository | Sort-Object Name
for($i=0; $i -lt $sourcerepo.count; $i++){write-host $i.  $sourcerepo[$i].repoName}
$sourcerepoNum = Read-Host  "Enter Source repository number"
$fromRepo = Get-VBORepository -Name $sourcerepo.repoName[$sourcerepoNum]

$users = Get-VBOEntityData -Type User -Repository $fromRepo
$sites =  Get-VBOEntityData -Type Site -Repository $fromRepo 
$groups = Get-VBOEntityData -Type Group -Repository $fromRepo
$teams = Get-VBOEntityData -Type Team -Repository $fromRepo 

$usage = Get-VBOUsageData -Repository $fromRepo -Organization $vboOrg

Write-Host "Summary of sources:"
Write-Host "Source storage use after the move: $usage"
Write-Host "Users:   $users"
Write-Host "Groups:  $groups"
Write-Host "Sites:   $sites"
Write-Host "Teams:   $teams"