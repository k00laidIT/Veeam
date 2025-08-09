<#
.Synopsis
Sets the Job Description to match the repository description. Good for aligning the Job:Repository relationship.
By default no descriptions will be modified, it will just output a list of orgs, jobs, before descriptions and 
after descriptions.

.Notes
Version: 1
Authors: Jim Jones, @1111systems
Modified Date: 08/09/2025
Parameters:
    -organization (optional) allows the script to only apply to jobs and repositories of a single organization
    -VBOSrv: (optional) defaults to localhost, supply if using remotely
    -Process: (optional) If set it will provide the list but also modify the job descriptions

.EXAMPLE
.\Set-VBODescriptions.ps1 -organization "dummyorg.onmicrosoft.com" -Process
#>

[CmdletBinding(DefaultParametersetName = 'None')] 
param (
  [Parameter(Mandatory = $false)]
  [string] $organization,

  [Parameter(Mandatory = $false)]
  [string] $VBOSrv = "localhost",

  [Parameter(ParameterSetName = 'Reverse', Mandatory = $false)]
  [Switch] $Reverse,

  [Parameter(ParameterSetName = 'Process', Mandatory = $false)]
  [Switch] $Process
)

[System.Collections.ArrayList]$Output = @()


If($organization) {
    $org = Get-VBOOrganization -Name $organization
    $jobs = get-vbojob -Organization $org
    ForEach ($job in $jobs) {
        $repoName = $job.Repository
        $repo = Get-VBORepository -Name $repoName
        $jDesc = $job.Description
        $rDesc = $repo.Description
        If($jDesc -ne $rDesc) {
            $oString = New-Object PSObject -Property @{
                Organization = $org.Name
                Job = $job.name
                Before = $jDesc
                After = $rDesc
            }
            $Output.Add($oString) | Out-Null
        }
        If($Process) {
            Set-VBOJob -Job $job -Description $rDesc
        }
    }
}
else {
    $orgs = Get-VBOOrganization
    ForEach($lorg in $orgs) {
        $org = Get-VBOOrganization -Name $lorg
        $jobs = get-vbojob -Organization $org
        ForEach ($job in $jobs) {
            $repoName = $job.Repository
            $repo = Get-VBORepository -Name $repoName
            $jDesc = $job.Description
            $rDesc = $repo.Description
            If($jDesc -ne $rDesc) {
                $oString = New-Object PSObject -Property @{
                    Organization = $org.Name
                    Job = $job.name
                    Repository = $repo.Name
                    Before = $jDesc
                    After = $rDesc
                }
                $Output.Add($oString) | Out-Null
            }
            If($Process) {
                Set-VBOJob -Job $job -Description $rDesc
            }
        }
    }
}
Write-Host $Output
$timestamp = Get-Date -Format yyyyMMdd_HHmmss
$Output | Export-CSV "$timestamp-DescriptionUpdates.csv" -NoTypeInformation

