<#
.Synopsis
For Veeam Backup 365 this will take a series of parameters and quickly create object storage buckets in either AWS S3 or S3 compatible storage 
and provision VB365 object storage buckets.

Parameters:
    -endpointurl (default us-central-1a.object.ilandcloud.com)
    -region (default us-central-1a)
    -awsprofile (MANDATORY ex. myawsprofile, can be created with aws configure --profile myawsprofile)
    -bucket (MANDATORY ex. tenant-bucket-01)
    -vb365server (MANDATORY, defaults to localhost)
    -vb365proxy (if not supplied then a list of available proxies will be presented to select from)
    -accesskey (if not supplied then a list of available keys present on the system will be presented for choice, 
        also the last option will allow you create a new set in VB365)
    -localrootpath (default is C:\VeeamBackups, where local folder with provided bucket name will be reflected)acked by the object repository
.Notes
Version: 1.0
Author: Jim Jones, @k00laidIT
Modified Date: 10/22/2022

.EXAMPLE
.\New-VboObjRepo.ps1 -profile myawsprofile -bucket tenant-bucket-01
#>

[CmdletBinding()]
Param (
    [string]$endpointurl = "us-central-1a.object.ilandcloud.com",
    [string]$region = 'us-central-1a',
    [string]$awsprofile,
    [string]$bucket,
    [string]$vb365server = 'localhost',
    [string]$accesskey,
    [string]$localrootpath = 'C:\VeeamBackups\'
)


$account = Get-VBOAmazonS3CompatibleAccount -AccessKey "SOSZW67TP4RO0VATDXBY"
$connect = New-VBOAmazonS3CompatibleConnectionSettings -Account $account -ServicePoint "https://us-central-1a.object.ilandcloud.com" -CustomRegionId "us-central-1a"
$key = Get-VBOEncryptionKey -Id 7cfd791b-923b-4f36-871c-8ce269c5215a
$proxy = get-vboproxy

$name = "was-vbov6-od4b-unencrypted"
$path = “c:\vboCache\$name”
$bucket = Get-VBOAmazonS3Bucket -AmazonS3CompatibleConnectionSettings $connect -Name $name
$folder = Add-VBOAmazonS3Folder -Bucket $bucket -Name "Veeam"
$objrepo = Add-VBOAmazonS3CompatibleObjectStorageRepository -Folder $folder -Name $name
Add-VBORepository -Proxy $proxy -Name $name -Path $path -RetentionPeriod KeepForever -RetentionFrequencyType Daily -DailyTime 00:00:00 -DailyType Everyday  -RetentionType ItemLevel -ObjectStorageRepository $objrepo -ObjectStorageEncryptionKey $key
