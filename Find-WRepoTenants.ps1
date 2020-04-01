<#
.Synopsis
  Finds all tenant directories on a standard Veeam Repository server
.Notes
   Version: 0.1
   Author: Jim Jones, @k00laidIT
   Modified Date: 3/31/2020
.EXAMPLE
  From the repo server run .\find-wrepotenants.ps1
#>

[System.Collections.ArrayList]$AllTenants = @()
$hostname = $env:COMPUTERNAME
$driveletters = get-wmiobject Win32_LogicalDisk | Where-Object {$_.drivetype -eq 3} | ForEach-Object {get-psdrive $_.deviceid[0]}
foreach ($a in $driveletters) {
    if ($a.Name -ne 'C') {
	$path = $a.Root+'Backups'
        $Tenants = Get-ChildItem $path -Directory | Select-Object Name
        $AllTenants.Add($Tenants) | Out-Null
    }
}

$AllTenants | Export-Csv $hostname+"tenants.csv" -NoTypeInformation