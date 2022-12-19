<#
.Synopsis
For Veeam Backup & Replication v12 this script will create the desired number of buckets with a given prefix and then add them into a SOBR
Requires aws cli to be installed and configured with a profile via "aws configure --profile profilename" to create buckets

.Notes
Version: 1.0
Author: Jim Jones, @k00laidIT
Modified Date: 12/16/2022

.EXAMPLE
.\New-VbrSobr.ps1
#>
#import-module AWS.Tools.Common, AWS.Tools.S3

$nameprefix = "123-test1"
$vbrsrv = "localhost"
$svcpoint = "https://us-central-1a.object.ilandcloud.com" 
$awsprofile = "ilanduscentral"
$numrepos = "5"
$imm = $true
$immdays = "30"

Connect-VBRServer -Server $vbrsrv

$i = 1
do {
    #Create bucket via aws cli    
    $bucketname = $nameprefix+"-"+$i
    if ($imm -eq $true) {
        Invoke-Command -ScriptBlock {aws --endpoint $svcpoint --profile $awsprofile --no-verify-ssl s3api create-bucket --object-lock-enabled-for-bucket --bucket $bucketname}
    }
    else {
        Invoke-Command -ScriptBlock {aws --endpoint $svcpoint --profile $awsprofile --no-verify-ssl s3api create-bucket --bucket $bucketname}
    }
    
    #New-S3Bucket -EndpointUrl $svcpoint -ProfileName $awsprofile $bucketname $bucketname -ObjectLockEnabledForBucket $true

    #Create object storage repository in VBR v12
    $objkey = Get-VBRAmazonAccount -Id 02be1fe1-de9e-4bbf-a76b-2ab90d88fe1e
    $connect = Connect-VBRAmazonS3CompatibleService -Account $objkey -CustomRegionId "us-east-1" -ServicePoint $svcpoint -Force
    $bucket = Get-VBRAmazonS3Bucket -Connection $connect -Name $bucketname
    $folder = New-VBRAmazonS3Folder -Bucket $bucket -Connection $connect -Name "Veeam" 
    if ($imm -eq $true) {
        Add-VBRAmazonS3CompatibleRepository -Connection $connect -AmazonS3Folder $folder -Name $bucketname -EnableBackupImmutability -ImmutabilityPeriod $immdays
    }
    else {
        Add-VBRAmazonS3CompatibleRepository -Connection $connect -AmazonS3Folder $folder -Name $bucketname
    }
    

    $i++
} while ($i -le $numrepos)

#Put all the created repos in a SOBR
$objrepo = Get-VBRBackupRepository | where {$_.Name -like "$nameprefix*"}
$sobrname = $nameprefix+"-sobr"
Add-VBRScaleOutBackupRepository -Name $sobrname -Extent $objrepo -PolicyType "DataLocality"