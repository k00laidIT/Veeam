<#
.Synopsis
For Veeam Backup & Replication v12 this script will create a AWS credential set if needed and 
then create an object storage repository for a provided bucket

.Notes
Version: 1.0
Authors: Jim Jones, @1111systems
Modified Date: 05/30/2024
Parameters:
    -bucket: (mandatory) bucket name to be used
    -VBRSrv: (optional) defaults to localhost, supply if using remotely
    -RegionId: (mandatory) region code for AWS. example: us-east-1
    -accessKey: (mandatory) first part of key pair provided to you by 11:11 Service Delivery
    -IMM: (optional) Mandatory if you have enabled object lock on the bucket. Recommended.
    -IMMDays: (optional) Defaults to 30 days which should be the minimum. Maximum is 90.

.EXAMPLE
.\New-1111AwsRepo.ps1  #to load function into memory
New-1111AwsRepo -Bucket 'bucket1' -accessKey "myAWSaccessKey" -RegionId 'us-west-2' -IMM -IMMDays '30'
#>

#Requires -Modules AWS.Tools.Common, AWS.Tools.S3

[CmdletBinding(DefaultParametersetName = 'None')] 
param (
  [Parameter(Mandatory = $true)]
  [string] $bucket,

  [Parameter(Mandatory = $false)]
  [string] $VBRSrv = "localhost",

  [Parameter(Mandatory = $true)]
  [string] $RegionId,

  [Parameter(Mandatory = $true)]
  [string] $accessKey,

  [Parameter(ParameterSetName = 'IMM', Mandatory = $false)]
  [Switch] $IMM,

  [Parameter(ParameterSetName = 'IMM', Mandatory = $false)]
  [int] $IMMDays = "30"
)


begin {
  #Logic for supporting 5.x Powershell which can't convert from secure to insecure just for AWS use, ewwwww
  if ($PSVersionTable.PSVersion -ge "7.0.0" ) {
    Write-Host "Veeam does not currently support Powershell Core. Please launch via powershell.exe"
    # $secretKey = read-host -Prompt "Please Supply the Provided Secret Key" -AsSecureString
    # $inSecureKey = ConvertFrom-SecureString -SecureString $secretKey -AsPlainText
  } else {
    $inSecureKey = read-host -Prompt "Please Supply the Provided Secret Key"
    $secretKey = ConvertTo-SecureString -string $insecureString -AsPlainText -Force
  }

  import-module AWS.Tools.Common, AWS.Tools.S3, Veeam.Backup.Powershell 

  Connect-VBRServer -Server $VBRSrv  

  #Let's use those AWS Creds
  Set-AWSCredential -AccessKey $accessKey -SecretKey $inSecureKey

      # Add AWS credentials to Veeam and make connection
      try {
        $s3cred = get-vbramazonaccount -AccessKey $accessKey -ErrorAction Stop
      }
      
      catch {       
        $s3cred = Add-VBRAmazonAccount -AccessKey $accessKey -SecretKey $secretKey -Description "11:11 Provided AWS Credential"
      }

    #Check Immutability
    if ($IMM -and $IMMDays -lt 1) {
        Write-Host "Immutabilty is enabled, please supply a period greater than 0. The recommended is 30."
        break
    }

    #Check VBR Version. For 12.3 and later we'll use the new 11:11 Object Repository Type. For earlier version of v12 we'll use AWS.
    $vbrBuild = Get-VBRBackupServerInfo | Select-Object Build
    if ($vbrBuild.Build -ge "12.3.0.310") {
      $vbrRepoType = "1111"
    } else {
      $vbrRepoType = "AWS"
    }
  
    #Check if bucket exists, if it appropriately has object lock enabled and if not create it. 
    if ($IMM) {
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
  } #end begin block

  process {
    #create Veeam Connection to AWS
    $awsConn = Connect-VBRAmazonS3Service -Account $s3cred -RegionType "Global" -ServiceType "CapacityTier" -ConnectionType "Direct"
    $region = Get-VBRAmazonS3Region -Connection $awsConn -Region $RegionId

    # Add bucket  as Veeam Repository

    $vBucket = Get-VBRAmazonS3Bucket -Connection $awsConn -Name $bucket -Region $region
    $folder = New-VBRAmazonS3Folder -Connection $awsConn -Bucket $vBucket -Name "Veeam"

    if ($vbrRepoType -eq "AWS") {
      if ($IMM) {
        Add-VBRAmazonS3Repository -Connection $awsConn -AmazonS3Folder $folder -Name $bucket -EnableIAStorageClass -EnableBackupImmutability -ImmutabilityPeriod $immdays            
      } else {
        Add-VBRAmazonS3Repository -Connection $awsConn -AmazonS3Folder $folder  -EnableIAStorageClass -Name $bucket
      }
    } elseif ($vbrRepoType -eq "1111") {
      if ($IMM) {
        Add-VBR1111SystemsS3Repository -Connection $awsConn -AmazonS3Folder $folder -Name $bucket -EnableIAStorageClass -EnableBackupImmutability -ImmutabilityPeriod $immdays            
      } else {
        Add-VBR1111SystemsS3Repository -Connection $awsConn -AmazonS3Folder $folder  -EnableIAStorageClass -Name $bucket
      }
    }
  } #end process block