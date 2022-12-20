<#
.Synopsis
For Veeam Backup & Replication v12 this script will create the desired number of buckets with a given prefix and then add them into a SOBR.
The aws CLI needs to be installed (choco install awscli -y) 
    and a named profile configured (aws configure --profile=myprofile) for this to function.

.Notes
Version: 1.0
Authors: Jim Jones, @k00laidIT; Joe Houghes @jhoughes
Modified Date: 12/19/2022

.EXAMPLE
.\New-cVBRSOBR.ps1  #to local function into memory
New-cVBRSOBR -NamePrefix 'testset1' -VBRSrv 'localhost' -SvcPoint 'https://us-central-1a.object.ilandcloud.com' -RegionId 'us-central-1a' -AWSProfile 'myprofile' -NumRepos '5' -IMM $true -IMMDays '30'
#>

function New-cVBRSOBR {

    [CmdletBinding()]
    param (
      [Parameter(Mandatory = $true)]
      [string] $NamePrefix,
  
      [Parameter(Mandatory = $true)]
      [string] $VBRSrv = "localhost",
  
      [Parameter(Mandatory = $true)]
      [string] $SvcPoint = "https://us-central-1a.ilandcloud.com",
  
      [Parameter(Mandatory = $true)]
      [string] $RegionId = "us-central-1a",
  
      [Parameter(Mandatory = $true)]
      [string] $AWSProfile,
  
      [Parameter(Mandatory = $true)]
      [int] $NumRepos,
  
      [Parameter(Mandatory = $true)]
      [boolean] $IMM = $true,
  
      [Parameter(Mandatory = $true)]
      [int] $IMMDays = "30"
    )
  
    begin {
      Connect-VBRServer -Server $VBRSrv
      $s3cred = Get-VBRAmazonAccount | Where-Object { $_.Description -eq $awsprofile }
      $connect = Connect-VBRAmazonS3CompatibleService -Account $s3cred -CustomRegionId $RegionId -ServicePoint $SvcPoint -Force
    } #end begin block
  
    process {
      $i = 1
      do {
        #Create bucket via aws cli
        $bucketname = $nameprefix.ToLower() + '-' + $i
        if ($IMM) {
          Invoke-Command -ScriptBlock { aws --endpoint $svcpoint --profile $awsprofile s3api create-bucket --object-lock-enabled-for-bucket --bucket $bucketname }
        } else {
          Invoke-Command -ScriptBlock { aws --endpoint $svcpoint --profile $awsprofile s3api create-bucket --bucket $bucketname }
        }
  
        #Create object storage repository in VBR v12
  
        $bucket = Get-VBRAmazonS3Bucket -Connection $connect -Name $bucketname
        $folder = New-VBRAmazonS3Folder -Bucket $bucket -Connection $connect -Name 'Veeam'
        if ($IMM) {
          Add-VBRAmazonS3CompatibleRepository -Connection $connect -AmazonS3Folder $folder -Name $bucketname -EnableBackupImmutability -ImmutabilityPeriod $immdays
        } else {
          Add-VBRAmazonS3CompatibleRepository -Connection $connect -AmazonS3Folder $folder -Name $bucketname
        }
  
        $i++
      } while ($i -le $NumRepos)
  
    } #end process block
  
    end {
  
      #Put all the created repos in a SOBR
      $objrepo = Get-VBRBackupRepository | Where-Object { $_.Name -like "$NamePrefix*" }
      $sobrname = $NamePrefix + '-sobr'
      Add-VBRScaleOutBackupRepository -Name $sobrname -Extent $objrepo -PolicyType 'DataLocality'
  
      Disconnect-VBRServer  -Server $VBRSrv
    } #end end block
  
  } #end function