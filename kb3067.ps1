<#
.Synopsis
For VB365 will migrate all data from one repository to another, based on the Veeam KB 3067. This version brings some 
sanity to the selection of proxies and repos while also providing information on what is to be moved (storage and user counts).
.Notes
Version: 1.0
Author: Jim Jones, @k00laidIT
Modified Date: 5/23/2022

.EXAMPLE
.\iland-kb3067.ps1
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
for($i=0; $i -lt $sourcerepo.count; $i++){write-host $i.  $sourcerepo[$i].repoName}
$sourcerepoNum = Read-Host  "Enter Source repository number"
$fromRepo = Get-VBORepository -Name $sourcerepo.repoName[$sourcerepoNum]

#Backup proxy selection
$proxies=Get-VBOProxy | Sort-Object Name
for($i=0; $i -lt $proxies.count; $i++){write-host $i.  $proxies[$i].hostname}
$proxyNum = Read-Host  "Enter proxy number"
#$vboProxyTarget = $proxies[$proxyNum]
$vboProxyTarget = Get-VBOProxy -Id $fromRepo.ProxyID

#Target Repository selection
$targetrepo=Get-VBORepository -Proxy $vboProxyTarget | Sort-Object Name
for($i=0; $i -lt $targetrepo.count; $i++){write-host $i.  $targetrepo[$i].name}
$targetrepoNum = Read-Host  "Enter Target repository number"
$destinationRepo = $targetrepo[$targetrepoNum]

#Gather Data on storage use prior to move
$usage = Get-VBOUsageData -Repository $fromRepo -Organization $vboOrg

#Limiting migrations sessions to a half of Backup Proxy threads
$jobs_for_move=($vboProxyTarget.ThreadsNumber)/2

#Disabling all jobs for selected organization
$vboJobs = Get-VBOJob -Organization $vboOrg | where-object {$_.Repository -eq $fromRepo.Name}
$vboJobs | ?{$_.IsEnabled} | Disable-VBOJob > $null

#finding all users and migrating them
    $users = Get-VBOEntityData -Type User -Repository $fromRepo | Where-Object {$_.Organization.DisplayName -eq $vboOrg.Name}

    foreach ($user in $users)
    {
        Write-Host $user.displayname
        Move-VBOEntityData -From $fromRepo -To $destinationRepo -User $user -Mailbox -ArchiveMailbox -OneDrive -Sites -Confirm:$false -RunAsync
        while((Get-VBODataManagementSession | ? {$_.Status -eq "Running"}).Count -ge $jobs_for_move){sleep 10}
    }

#finding all sites and migrating them
    $sites =  Get-VBOEntityData -Type Site -Repository $fromRepo | Where-Object {$_.Organization.DisplayName -eq $vboOrg.Name}

    foreach ($site in $sites) {
        Write-Host $site.title
        Move-VBOEntityData -From $fromRepo -To $destinationRepo -Site $site -Confirm:$false -RunAsync
        while((Get-VBODataManagementSession | ? {$_.Status -eq "Running"}).Count -ge $jobs_for_move){sleep 10}
    }

#finding all groups and migrating them
    $groups = Get-VBOEntityData -Type Group -Repository $fromRepo | Where-Object {$_.Organization.DisplayName -eq $vboOrg.Name}

    foreach ($group in $groups) {
        Write-Host $group.displayname
        Move-VBOEntityData -From $fromRepo -To $destinationRepo -Group $group -Mailbox -ArchiveMailbox -OneDrive -Sites -GroupMailbox -GroupSite -Confirm:$false -RunAsync
        while((Get-VBODataManagementSession | ? {$_.Status -eq "Running"}).Count -ge $jobs_for_move){sleep 10}
    }

#finding all Teams and migrating them
    $teams = Get-VBOEntityData -Type Team -Repository $fromRepo | Where-Object {$_.Organization.DisplayName -eq $vboOrg.Name}

    foreach ($team in $teams) {
        Write-Host $team.displayname
        Move-VBOEntityData -From $fromRepo -To $destinationRepo -Team $team -Confirm:$false -RunAsync
        while((Get-VBODataManagementSession | ? {$_.Status -eq "Running"}).Count -ge $jobs_for_move){sleep 10}
    }


#reconfiguring the job to use new repository and enabling it
foreach ($job  in  $vboJobs) 
{

    Set-VBOJob -Job $job -Repository $destinationRepo > $null
    Enable-VBOJob -Job $job > $null
    
} 

Write-Host "All migration jobs started. You can check each job state in UI (History->Jobs->Data Management)"
Write-Host ""
Write-Host "Processed Selections"
Write-Host "Organization:     $vboOrg.Name ($organisationNum)"
Write-Host "Proxy:            $vboProxyTarget ($proxyNum)"
Write-Host "Source Repo:      $fromRepo ($sourcerepoNum)"
Write-Host "Destination Repo: $destinationRepo ($targetrepoNum)"
Write-Host ""
Write-Host "Summary of sources:"
Write-Host "Storage use prior to move: $usage"
Write-Host "Users:   $users"
Write-Host "Groups:  $groups"
Write-Host "Sites:   $sites"
Write-Host "Teams:   $teams"

& cmd /c pause
exit
