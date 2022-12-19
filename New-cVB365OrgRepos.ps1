<#
.Synopsis
For Veeam Backup for Microsoft 365 Version 7 (Beta) this is will create the desired number of buckets and if desired a second set of buckets for immutable backup copy use. 
Requires aws cli to be installed and configured with a profile via "aws configure --profile profilename" to create buckets

.Notes
Version: 1.0
Author: Jim Jones, @k00laidIT
Modified Date: 12/16/2022

.EXAMPLE
.\New-VboAwsObjRepos.ps1
#>

$nameprefix = "bucketprefix"
$vbosrv = "localhost"
$awsprofile = "aws cli profile name"
$objCache = "C:\objCache\"
$numrepos = "3"
$imm = $true
$immdays = "14"

Connect-VBOServer -Server $vbosrv
$awscred = Get-VBOAmazonS3Account | where {$_.Description -eq $awsprofile}    
$connect = New-VBOAmazonS3ConnectionSettings -Account $awscred -RegionType Global
$enckey = Get-VBOEncryptionKey | where {$_.Description -eq $nameprefix}

$i = 1
do {
    #Create bucket via aws cli    
    $bucketname = $nameprefix+"-"+$i
    Invoke-Command -ScriptBlock {aws --profile $awsprofile s3api create-bucket --bucket $bucketname --create-bucket-configuration "LocationConstraint=us-east-2"}    
    
    #Create object storage repository in VB365
   
    $bucket = Get-VBOAmazonS3Bucket -AmazonS3ConnectionSettings $connect -Name $bucketname
    $folder = Add-VBOAmazonS3Folder -Bucket $bucket -Name "Veeam"
    $objrepo = Add-VBOAmazonS3ObjectStorageRepository -Folder $folder -Name $bucketname

    #Create Repository in VB365
    $path = $objCache+$bucketname
    $proxy = Get-VBOProxy 
    Add-VBORepository -Proxy $proxy -Name $bucketname -Path $path -RetentionPeriod Years3 -RetentionFrequencyType Daily -DailyTime 00:00:00 -DailyType Everyday -RetentionType ItemLevel -ObjectStorageRepository $objrepo -ObjectStorageEncryptionKey $enckey

    if ($imm -eq $true) {
        $immbucketname = "$bucketname-imm"
        Invoke-Command -ScriptBlock {aws --profile $awsprofile s3api create-bucket --bucket $immbucketname --create-bucket-configuration "LocationConstraint=us-east-2" --object-lock-enabled-for-bucket}

        $immbucket = Get-VBOAmazonS3Bucket -AmazonS3ConnectionSettings $connect -Name $immbucketname
        $immfolder = Add-VBOAmazonS3Folder -Bucket $immbucket -Name "Veeam"
        $immobjrepo = Add-VBOAmazonS3ObjectStorageRepository -Folder $immfolder -Name $immbucketname -EnableImmutability

        $immpath = $objCache+$immbucketname        
        Add-VBORepository -Proxy $proxy -Name $immbucketname -Path $immpath -CustomRetentionPeriodType Days -CustomRetentionPeriod $immdays -RetentionFrequencyType Daily -DailyTime 00:00:00 -DailyType Everyday -RetentionType ItemLevel -ObjectStorageRepository $immobjrepo -ObjectStorageEncryptionKey $enckey
    }
    $i++
} while ($i -le $numrepos)

if ($imm -eq $true) {
    WriteHost "Immutability has been enabled. Please setup backup jobs to standard repos and backup copies to the '-imm' repos."
}