<#
.Synopsis
Script utilizes a specified CSV file to supply group names, RegEx expressions and usage locations to create dynamic groups 
in Azure AD for use by Veeam Backup for Microsoft365. Requires Azure AD Premium P1 or greater subscription.
Also requires the AzureADPreview module to be available requiring it to be run from Amd64 architecture

Install-Module AzureADPreview -Scope CurrentUser -Force

.Notes
Version: 1.0
Authors: Jim Jones, @k00laidIT
Modified Date: 06/21/2023

.EXAMPLE
.\New-VBODynamicGroups.ps1
#>
Import-Module AzureADPreview

$SourceCsv = ".\sourcecsv.csv"

$grpData = Import-Csv -Path $SourceCsv
Connect-AzureAD
foreach($grp in $grpData){
    $groupName = $grp.$groupName
    $regEx = $grp.regex
    $usageLocation = $grp.$usageLocation
    $query = "(user.userPrincipalName -match '$regEx') and (user.usageLocation -eq '$usageLocation')"

    New-AzureADMSGroup -DisplayName $groupName `
        -MailNickName $groupName `
        -Description "Group for VB365 backup with rule $regEx" `
        -MailEnabled $false `
        -SecurityEnabled $true `
        -GroupTypes "DynamicMembership" `
        -membershipRule "$($query)"
        -membershipRuleProcessingState 'on'
}