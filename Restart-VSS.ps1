#   Name:   Restart-VSS.ps1
#   Description: Restarts list of services in an array on VMs with a given vSphere tag. Helpful for Veeam B&R processing
#   For more info on Veeam VSS services that may cause failure see https://www.veeam.com/kb2041
asnp "VeeamPSSnapIn" -ErrorAction SilentlyContinue
Import-Module VMware.PowerCLI

$vcenter = "hqvcsa1.wvhdf.com"
$services = @("SQLWriter","VSS")
$tag = "HQ32Day"
Connect-VIServer $vcenter
$vms = Get-VM |where {$_.Tag -ne $tag}

ForEach ($vm in $vms){
  ForEach ($service in $services){
    If (Get-Service -ComputerName $vm -Name $service -ErrorAction SilentlyContinue) {
      Write-Host $service "on computer" $vm "restarting now."
      Restart-Service -InputObject $(Get-Service -Computer $vm -Name $service);
    }
  }
}