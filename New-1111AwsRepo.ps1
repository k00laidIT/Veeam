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
.\New-1111AwsRepo.ps1  #to local function into memory
New-1111AwsRepo -Bucket 'bucket1' -accessKey "myAWSaccessKey" -RegionId 'us-west-2' -IMM -IMMDays '30'
#>

function New-1111AwsRepo {

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
        if (-Not $IMM -and $IMMDays -lt 1) {
            Write-Host "Please disable Immutability or supply a period greater than 0. The recommended is 30."
            break
        }
        Connect-VBRServer -Server $VBRSrv
        try {
            $s3cred = get-vbramazonaccount -AccessKey $accessKey -ErrorAction Stop
          }
          
          catch {
            $secretKey = read-host -Prompt "Please Supply the Provided Secret Key" -AsSecureString
            $s3cred = Add-VBRAmazonAccount -AccessKey $accessKey -SecretKey $secretKey -Description "11:11 Provided AWS Credential"
          }

          finally {
            $awsConn = Connect-VBRAmazonS3Service -Account $s3cred -RegionType "Global" -ServiceType CapacityTier -ConnectionType Direct
            $region = Get-VBRAmazonS3Region -Connection $awsConn -Region $RegionId
          }
   
      } #end begin block

      process {
        $vBucket = Get-VBRAmazonS3Bucket -Connection $awsConn -Name $bucket -Region $region
        $folder = New-VBRAmazonS3Folder -Connection $awsConn -Bucket $vBucket -Name "Veeam"
        if ($IMM) {
                Add-VBRAmazonS3Repository -Connection $awsConn -AmazonS3Folder $folder -Name $bucket -EnableIAStorageClass -EnableBackupImmutability -ImmutabilityPeriod $immdays            
          } else {
            Add-VBRAmazonS3Repository -Connection $awsConn -AmazonS3Folder $folder  -EnableIAStorageClass -Name $bucket
          }
      } #end process block

    } #end function