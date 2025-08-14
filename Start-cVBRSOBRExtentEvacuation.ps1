<#
.Synopsis
For a given 

.Notes
Version: 1
Authors: Jim Jones, @1111systems
Modified Date: 08/09/2025
Parameters:
    -organization (optional) allows the script to only apply to jobs and repositories of a single organization
    -VBOSrv: (optional) defaults to localhost, supply if using remotely
    -Process: (optional) If set it will provide the list but also modify the job descriptions

.EXAMPLE
.\Start-cVBRSOBRExtentEvacuation.ps1 -sobrName "MySOBR" -extentName "MyExtent" -Capacity
#>

# SOBR Evacuation
[CmdletBinding(DefaultParametersetName = 'None')] 
param (
  [Parameter(ParameterSetName = 'sobrName', Mandatory = $true)]
  [string] $sobrName,

  [Parameter(ParameterSetName = 'extentName',Mandatory = $false)]
  [string] $extentName,

  [Parameter(ParameterSetName = 'capacity',Mandatory = $false)]
  [switch] $capacity,

  [Parameter(ParameterSetName = 'performance',Mandatory = $false)]
  [switch] $performance
)

If($tier -eq "Capacity") {
    $Extent = Get-VBRCapacityExtent -Name "$extentName"
    If($Extent) {
        Enable-VBRCapacityExtentMaintenanceMode -Extent $Extent
        Enable-VBRCapacityExtentSealedMode -Extent $Extent
        Write-Host "Evacuating Capacity Extent: $($Extent.Name)"
        Start-VBRRepositoryExtentBackupEvacuation -Extent $Extent
    }
    elseif ($tier -eq "Performance") {
        If($Extent) {
        Enable-VBRPerformanceExtentMaintenanceMode -Extent $Extent
        Enable-VBRPerformanceExtentSealedMode -Extent $Extent
        Write-Host "Evacuating Capacity Extent: $($Extent.Name)"
        Start-VBRRepositoryExtentBackupEvacuation -Extent $Extent
        }
    }
}
