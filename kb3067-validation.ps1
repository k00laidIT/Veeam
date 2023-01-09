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

#Determine the jobs from the organization and then create a list of repositories from that
$orgjobs = $vboOrg | get-vbojob
[System.Collections.ArrayList]$orgrepos = @()
foreach ($orgjob in $orgjobs) {
    $repo = $orgjob.repository
    $output = [PSCustomObject]@{
        repoName = $repo                         
    }
    $orgrepos += $output        
}

# Selector for chosing the repository to measure
for($i=0; $i -lt $orgrepos.count; $i++){write-host $i.  $orgrepos[$i].repoName}
$orgRepoNum = Read-Host  "Enter Source repository number"
$fromRepo = Get-VBORepository -Name $orgrepos.repoName[$orgRepoNum]

#Create listing of objects by type
$users = Get-VBOEntityData -Type User -Repository $fromRepo
$sites =  Get-VBOEntityData -Type Site -Repository $fromRepo 
$groups = Get-VBOEntityData -Type Group -Repository $fromRepo
$teams = Get-VBOEntityData -Type Team -Repository $fromRepo 

#Get actual storage size still present in the repository
$usage = Get-VBOUsageData -Repository $fromRepo -Organization $vboOrg

#Write output of all gathered data
Write-Host "Summary of sources:"
Write-Host "Source storage use after the move: $usage"
Write-Host "Users remaining:   $users.count"
Write-Host "Groups remaining:  $groups.count"
Write-Host "Sites remaining:   $sites.count"
Write-Host "Teams remaining:   $teams.count"