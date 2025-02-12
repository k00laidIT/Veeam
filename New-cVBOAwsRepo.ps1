<#
.Synopsis
For Veeam Backup for Microsoft365 v8 this will create an AWS S3 bucket and then add it as an object storage repository

.Notes
Version: 1.0
Authors: Jim Jones, @1111systems
Modified Date: 02/06/2025
Parameters:
    -bucket: (mandatory) bucket name to be used
    -VBOSrv: (optional) defaults to localhost, supply if using remotely
    -RegionId: (mandatory) region code for AWS. example: us-east-1
    -accessKey: (mandatory) first part of key pair provided to you by 11:11 Service Delivery
    -pxyPool: (mandatory) defines which proxy pool the bucket will be attached to
    ### -proxy: (FUTURE ADD) proxy to attach the repository to. Either pxyPool or proxy needs to be present.
    -DaysMonthsYears: (optional) defines in which type you want to measure retention. Options are Years | Months | Days.
      Defaults to Years
    -rPeriod: How many of the retention type you want to keep. Default is 3 years.
    -IMM: (optional) Mandatory if you have enabled object lock on the bucket. Default is enabled.
    -IMMDays: (optional) How long data should be written as immutable. Defaults to 30 days. 

.EXAMPLE
.\New-cVBOAwsRepo.ps1 -Bucket 'bucket1' -accessKey "myAWSaccessKey" -RegionId 'us-west-2' -pxyPool 'pool1'
#>

#Requires -Modules AWS.Tools.Common, AWS.Tools.S3

[CmdletBinding(DefaultParametersetName = 'None')] 
param (
  [Parameter(Mandatory = $true)]
  [string] $bucket,

  [Parameter(Mandatory = $false)]
  [string] $VBOSrv = "localhost",

  [Parameter(Mandatory = $true)]
  [string] $regionId,

  [Parameter(Mandatory = $true)]
  [string] $accessKey,

  [Parameter(Mandatory = $true)]
  [string] $pxyPool,

  [Parameter(Mandatory = $false)]
  [string] $DaysMonthsYears = "Years",

  [Parameter(Mandatory = $false)]
  [Int] $rPeriod = "3",

  [Parameter(ParameterSetName = 'IMM', Mandatory = $false)]
  [Switch] $IMM,

  [Parameter(ParameterSetName = 'IMM', Mandatory = $false)]
  [int] $IMMDays = "30"
)

begin {
  #Logic for supporting 5.x Powershell which can't convert from secure to insecure just for AWS use, ewwwww
  if ($PSVersionTable.PSVersion -ge "7.0.0" ) {
    #Write-Host "Veeam does not currently support Powershell Core. Please launch via powershell.exe"
    $secretKey = read-host -Prompt "Please Supply the Provided Secret Key" -AsSecureString
    $inSecureKey = ConvertFrom-SecureString -SecureString $secretKey -AsPlainText
  } else {
    $inSecureKey = read-host -Prompt "Please Supply the Provided Secret Key"
    $secretKey = ConvertTo-SecureString -string $inSecureKey -AsPlainText -Force
  }

  #ensure bucket is in all lowercase as S3 requires
  $bucket = $bucket.ToLower()

  #convert years or months to days for immutability check
  if ($DaysMonthsYears = "Years") {
    $rAsDays = $rPeriod*365
  } elseif ($DaysMonthsYears = "Months") {
    $rAsDays = $rPeriod*28
  } elseif ($DaysMonthsYears = "Days") {
    $rAsDays = $rPeriod
  } else {
    Write-Host "Please define DaysMonthsYears as either Days, Months, or Years or leave blank to default to Years."
    Break
  }
  
  #import AWS Modules
  import-module AWS.Tools.Common, AWS.Tools.S3

  #Let's use those AWS Creds
  Set-AWSCredential -AccessKey $accessKey -SecretKey $inSecureKey

  # Add AWS credentials to Veeam and make connection
  Connect-VBOServer -Server $VBOSrv   

#Check Immutability
    #Check for encryption key and if it doesn't exist prompt for password to be created
    try {      
      $encKey = Get-VBOEncryptionKey | Where-Object {$_.Description -eq $accessKey} 
      if([string]::IsNullOrEmpty($encKey)) {
        throw "Variable is empty or null"
      }
    }    
    catch {       
      $keyPrompt = Read-Host "No encryption key found for this account. Please enter a key to be used." -AsSecureString
      $encKey = Add-VBOEncryptionKey -Password $keyPrompt -Description $accessKey
    }
  
    
  } #end begin block

  process {
    #Check if bucket exists and if it appropriately has object lock enabled. If not found create it. 
    if ($IMM) {
      if ($IMMDays -lt 1) {
        Write-Host "Immutabilty is enabled, please supply a period greater than 0. The recommended is 30."
        break
      }
      if ($IMMDays -gt $rAsDays) {
        Write-Host "Please configure your immutability period to be less than your overal retention."
        break
      }
        $aBucket = Get-S3Bucket -Region $RegionId -BucketName $bucket
        if (!$aBucket.BucketName) {
          New-S3Bucket -Region $RegionId -ObjectLockEnabledForBucket $true -BucketName $bucket
        }else {
          $oblockcheck = Get-S3ObjectLockConfiguration -Region -BucketName $bucket
          if (-Not $oblockcheck.ObjectLockEnabled) {
            Write-Host "The supplied bucket does not have Object-Lock enabled. Please supply a different bucket or disable Immutability"
            break
          }
        }    
    }else {
        $aBucket = Get-S3Bucket -Region -BucketName $bucket
        if (!$aBucket.BucketName) {
          New-S3Bucket  -Region $RegionId -ObjectLockEnabledForBucket $false -BucketName $bucket
        }else {
          $oblockcheck = Get-S3ObjectLockConfiguration -Region $RegionId -BucketName $bucket
          if ($oblockcheck.ObjectLockEnabled) {
            Write-Host "The supplied bucket has Object-Lock enabled. Please supply a different bucket or enable Immutability"
            break
          }
        }    
    }      

    #create Veeam Connection to AWS
    try {
      $s3cred = get-VBOAmazonS3Account -AccessKey $accessKey -ErrorAction Stop
    }
    
    catch {       
      $s3cred = Add-VBOAmazonS3Account -AccessKey $accessKey -SecretKey $secretKey -Description "11:11 Provided AWS Credential"
    }

    $connect = New-VBOAmazonS3ConnectionSettings -Account $s3cred -RegionType Global
    $pool = get-vboproxypool -Name $pxyPool

    # Add bucket  as Veeam Repository
    $vBucket = Get-VBOAmazonS3Bucket -Name $bucket -AmazonS3ConnectionSettings $connect -RegionId $regionId
    $vFolder = Add-VBOAmazonS3Folder -Bucket $vBucket -Name 'Veeam' 
    $vSettings = New-VBOAmazonS3ObjectStorageSettings -Folder $vFolder

    if ($IMM) {
      if ($DaysMonthsYears = "Years") {
        #Variant that is immutable and has retention in years
        [string]$vrPeriod = "Years$rPeriod"
        $vDate = Get-Date -Format "MM/dd/yyyy"
        $vDesc = "AWS::$regionId::$bucket::$vDate"
        Add-VBOAmazonS3Repository -Name $bucket `
          -Description $vDesc `
          -EnableStandardIAStorageClass `
          -EnableImmutability `
          -ImmutabilityPeriodDays $IMMDays `
          -ObjectStorageSettings $vSettings `
          -ObjectStorageEncryptionKey $encKey `
          -ProxyPool $pool `
          -RetentionFrequencyType "Daily" `
          -DailyTime "00:00:00" `
          -DailyType "Everyday" `
          -RetentionPeriod $vrPeriod `
          -RetentionType "SnapshotBased"
      } elseif ($DaysMonthsYears = "Months") {
        #Variant that is immutable and retention in months
        $vDate = Get-Date -Format "MM/dd/yyyy"
        $vDesc = "AWS::$regionId::$bucket::$vDate"
        Add-VBOAmazonS3Repository -Name $bucket `
          -Description $vDesc `
          -EnableStandardIAStorageClass `
          -EnableImmutability `
          -ImmutabilityPeriodDays $IMMDays `
          -ObjectStorageSettings $vSettings `
          -ObjectStorageEncryptionKey $encKey `
          -ProxyPool $pool `
          -RetentionFrequencyType "Daily" `
          -DailyTime "00:00:00" `
          -DailyType "Everyday" `
          -CustomRetentionPeriodType "Months"
          -CustomRetentionPeriod $rPeriod `
          -RetentionType "SnapshotBased"
      } elseif ($DaysMonthsYears = "Days") {
        #Variant that is immutable and retention in days
        $vDate = Get-Date -Format "MM/dd/yyyy"
        $vDesc = "AWS::$regionId::$bucket::$vDate"
        Add-VBOAmazonS3Repository -Name $bucket `
          -Description $vDesc `
          -EnableStandardIAStorageClass `
          -EnableImmutability `
          -ImmutabilityPeriodDays $IMMDays `
          -ObjectStorageSettings $vSettings `
          -ObjectStorageEncryptionKey $encKey `
          -ProxyPool $pool `
          -RetentionFrequencyType "Daily" `
          -DailyTime "00:00:00" `
          -DailyType "Everyday" `
          -CustomRetentionPeriodType "Days"
          -CustomRetentionPeriod $rPeriod `
          -RetentionType "SnapshotBased"
      }      
    } else {
      if ($DaysMonthsYears = "Years") {
        #Variant that is not immutable and has retention in years
        [string]$vrPeriod = "Years$rPeriod"
        $vDate = Get-Date -Format "MM/dd/yyyy"
        $vDesc = "AWS::$regionId::$bucket::$vDate"
        Add-VBOAmazonS3Repository -Name $bucket `
          -Description $vDesc `
          -EnableStandardIAStorageClass `
          -ObjectStorageSettings $vSettings `
          -ObjectStorageEncryptionKey $encKey `
          -ProxyPool $pool `
          -RetentionFrequencyType "Daily" `
          -DailyTime "00:00:00" `
          -DailyType "Everyday" `
          -RetentionPeriod $vrPeriod `
          -RetentionType "SnapshotBased"
      } elseif ($DaysMonthsYears = "Months") {
        #Variant that is not immutable and retention in months
        $vDate = Get-Date -Format "MM/dd/yyyy"
        $vDesc = "AWS::$regionId::$bucket::$vDate"
        Add-VBOAmazonS3Repository -Name $bucket `
          -Description $vDesc `
          -EnableStandardIAStorageClass `
          -ObjectStorageSettings $vSettings `
          -ObjectStorageEncryptionKey $encKey `
          -ProxyPool $pool `
          -RetentionFrequencyType "Daily" `
          -DailyTime "00:00:00" `
          -DailyType "Everyday" `
          -CustomRetentionPeriodType "Months"
          -CustomRetentionPeriod $rPeriod `
          -RetentionType "SnapshotBased"
      } elseif ($DaysMonthsYears = "Days") {
        <# Action when this condition is true #>
      } elseif ($DaysMonthsYears = "Months") {
        #Variant that is immutable and retention in days
        $vDate = Get-Date -Format "MM/dd/yyyy"
        $vDesc = "AWS::$regionId::$bucket::$vDate"
        Add-VBOAmazonS3Repository -Name $bucket `
          -Description $vDesc `
          -EnableStandardIAStorageClass `
          -EnableImmutability `
          -ImmutabilityPeriodDays $IMMDays `
          -ObjectStorageSettings $vSettings `
          -ObjectStorageEncryptionKey $encKey `
          -ProxyPool $pool `
          -RetentionFrequencyType "Daily" `
          -DailyTime "00:00:00" `
          -DailyType "Everyday" `
          -CustomRetentionPeriodType "Days"
          -CustomRetentionPeriod $rPeriod `
          -RetentionType "SnapshotBased"
      }  
    }
  } #end process block