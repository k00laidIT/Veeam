#----------------------------------------
#
# Name: Add-SitesToJob.ps1
#
# Created By: Jim Jones, @k00laidIT
#   Based on work by Fabian Kessler in 
#   https://forums.veeam.com/veeam-backup-for-microsoft-365-f47/adding-existing-team-sites-to-teams-backup-job-vis-ps-t87550.html
#
# Description: For a given CSV file will add any Sharepoint sites in the list (under column Name)
#               will import those sites into a provided or chosen job. While the CSV file is mandatory
#               If not provided a wizard workflow will kick in asking to select an organization first 
#               and then from a list of jobs based on the organization.
#
# Usage:
#   .\Add-SitesToJob.ps1 -CSV .\mysites.csv -Job "1111product-teams"

[CmdletBinding(DefaultParametersetName = 'None')] 
param (
  [Parameter(Mandatory = $true)]
  [string] $CSV,

  [Parameter(Mandatory = $false)]
  [string] $Job
)

# Function to allow for selecting items from lists
function Select-FromArray {
    param(
        [Parameter(Mandatory = $true)]
        [array]$List,
        [string]$Title = "Please make a selection"
    )

    Write-Host $Title":" -ForegroundColor Cyan
    # Loop through the array and display indexed options (starting at 1 for user-friendliness)
    for ($i = 0; $i -lt $List.Length; $i++) {
        Write-Host "$($i + 1): $($List[$i])"
    }

    # Prompt for user input with validation
    $choice = $null
    while ($true) {
        $input = Read-Host -Prompt "Enter the number of your choice"
        # Validate that the input is a valid number within the range
        if ($input -match '^\d+$') {
            $choice = [int]$input
            if ($choice -ge 1 -and $choice -le $List.Length) {
                break # Exit the loop if valid
            }
        }
        Write-Host "Invalid choice. Please enter a number between 1 and $($List.Length)." -ForegroundColor Red
    }

    # Return the selected item from the array (adjusting for 0-based index)
    return $List[$choice - 1]
}

If($Job) {
    $sJob = Get-VBOJob -Name $Job
    $sOrg = Get-VBOOrganization -name $vJob.Organization
} else {
    #If no job provided work through getting the org
    $orgs = Get-VBOOrganization
    $sOrg = Select-FromArray -List $orgs -Title "Which Organization?"
    
    # Now we need to get the job from a list of jobs for the organization
    $orgJobs = Get-VBOJob -Organization $sOrg
    $sJob = Select-FromArray -List $orgJobs -Title "Which Job?"
}
$allsites = Get-VBOOrganizationSite -Organization $sOrg

# Import the CSV file
$cSites = Import-Csv -Path $CSV

# Iterate through each row in the CSV file
foreach ($site in $cSites) {
    $sSite = $allsites | where-object {$_.Name -eq $site.Name}
    $bSiteItem = New-VBOBackupItem -Site $sSite
    Add-VBOBackupItem -Job $sJob -BackupItem $bSiteItem
}