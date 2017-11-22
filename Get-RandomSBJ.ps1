# Variables for script ------------------------
$AppGroupName = "Dynamic App Group"
$SbJobName = "Dynamic Surebackup Job"
$SbJobDesc = "Dynamic App Testing"
$Date = (get-date).AddDays(-30)
$VirtualLab = "MyVirtualLab"
$email = "me@host.com"
$VBRserver = "veeamserver.domain.local"
#Variables for function selectUntestedVMs
[string]$VeeamBackupCounterFile = ".\hashtable.xml"
[int]$NumberofVMs = 6
###############################################
 
# Functions ------------------------------
Function selectUntestedVMs
{
    param([string]$fVeeamBackupCounterFile,[int]$fNumberofVMs,$fVbrObjs)
 
    $fHashtable = @{}
    $fTestVMs = [System.Collections.ArrayList]@()
    $fDeletedVMs = [System.Collections.ArrayList]@()
 
    # Import VeeamBackupCounterfile if exists from a previous iteration
    if(Test-Path $fVeeamBackupCounterFile)
    {
        $fHashtable = import-clixml $fVeeamBackupCounterFile
    }
 
    # Check if all VM's were tested
    # if so the hashtable is cleared
 
    if(!($fHashtable.Values -contains 0))
    {
        $fHashtable = @{}
    }
 
    # Add newly created VM's from backup
    Foreach($fVbrObj in $fVbrObjs)
    {
        if(!($fHashtable.Contains($fVbrObj.name)))
        {
            $fHashtable.Add($fVbrObj.name, "0")
        }
    }
   
    # Remove old VM's from hashtable
    $fHashtable.getEnumerator() | %{ if($fVbrObjs.name -notcontains $_.name) {$fDeletedVMs += $_.name}}
    $fDeletedVMs | foreach{ $fHashtable.Remove($_)}
 
    # Sort hashtable by Value
    # Used new object because sorting the hashtable converts it to dictionary entry
    $fHashtableOrdered = $fHashtable.GetEnumerator() | sort -Property "Value", "Name"
 
    # Select least tested VMs and increment their value to 1 (tested)
    for ($i = 0; $i -lt $fNumberofVMs; $i++)
    {
        $fTestVMs += $fHashtableOrdered[$i].Name
        $fHashtable.Set_Item($fHashtableOrdered[$i].Name, 1)
    }
 
    #Save hashtable to file for the next iteration
    $fHashtable | export-clixml $fVeeamBackupCounterFile
 
    Return $fTestVMs
   
}
##########################################
 
asnp "VeeamPSSnapIn" -ErrorAction SilentlyContinue
Connect-VBRServer -Server $VBRserver

#Check if Application Group exists
if(!(Get-VSBApplicationGroup -Name $AppGroupName)) {
    # Find all VM objest successfully backed up in last 1 days
    $VbrObjs = (Get-VBRBackupSession | ?{$_.JobType -eq "Backup" -and $_.EndTime -ge $Date}).GetTaskSessions() | ?{$_.Status -eq "Success" -or $_.Status -eq "Warning" }
    # Call function selectUntestedVMs
    $TestVMs = selectUntestedVMs -fVeeamBackupCounterFile $VeeamBackupCounterFile -fNumberofVMs $NumberofVMs -fVbrObjs $VbrObjs
    $AppGroup = Add-VSBViApplicationGroup -Name $AppGroupName -VmFromBackup (Find-VBRViEntity -Name $TestVMs)
    elseif {
        Write-Host "App Group" $AppGroupName "already exists, please clean up your mess"
    }
}
 
# Check if SureBackup job exists
if(!(get-vsbjob -Name $SbJobName)) {
    # Set the Job Options
    $sureoptions = New-VSBJobOptions
    $sureoptions.EmailNotification = $true
    $sureoptions.EmailNotificationAddresses = $email
    # Create the new App Group, SureBackup Job, Start the Job
    $VirtualLab = Get-VSBVirtualLab -Name $VirtualLab    
    $VsbJob = Add-VSBJob -Name $SbJobName -VirtualLab $VirtualLab -AppGroup $AppGroup -Description $SbJobDesc    
    Set-VSBJobOptions -Job $VsbJob -Options $sureoptions
 
    Start-VSBJob -Job $VsbJob
 
    # Remove the old App Group, SureBackup Job, Disconnect from Server after running
    Remove-VSBJob -Job (Get-VSBJob -Name $SbJobName) -Confirm:$false
    Remove-VSBApplicationGroup -AppGroup (Get-VSBApplicationGroup -Name $AppGroupName) -Confirm:$false
    Disconnect-VBRServer
    elseif {
        Write-Host "SureBackup Job" $SbJobName "already exists, please clean up your mess"
    }
}