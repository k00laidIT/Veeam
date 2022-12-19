<#
.Synopsis
For Veeam Backup & Replication v12 this script will create the desired number of buckets with a given prefix and then add them into a SOBR

.Notes
Version: 1.0
Authors: Jim Jones, @k00laidIT; Joe Houghes @jhoughes
Modified Date: 12/19/2022

.EXAMPLE
./New-cVBRSOBR.ps1  #to local function into memory
New-cVBRSOBR -NamePrefix '123-test1' -VBRSrv 'localhost' -SvcPoint 'https://us-central-1a.object.ilandcloud.com' -RegionId 'us-central-1a' -AWSProfile 'ilanduscentral' -NumRepos '5' -IMM $true -IMMDays '30'
#>


function New-cVBRSOBR {

    [CmdletBinding()]
    param (
      [Parameter(Mandatory = $true)]
      [string] $NamePrefix,
  
      [Parameter(Mandatory = $true)]
      [string] $VBRSrv,
  
      [Parameter(Mandatory = $true)]
      [string] $SvcPoint,
  
      [Parameter(Mandatory = $true)]
      [string] $RegionId,
  
      [Parameter(Mandatory = $true)]
      [string] $AWSProfile,
  
      [Parameter(Mandatory = $true)]
      [int] $NumRepos,
  
      [Parameter(Mandatory = $true)]
      [boolean] $IMM,
  
      [Parameter(Mandatory = $true)]
      [int] $IMMDays
  
    )
  
    begin {    
      Connect-VBRServer -Server $VBRSrv
      $awscred = Get-VBOAmazonS3Account | Where-Object { $_.Description -eq $awsprofile }
      $connect = Connect-VBRAmazonS3CompatibleService -Account $objkey -CustomRegionId $RegionId -ServicePoint $SvcPoint -Force
    } #end begin block
  
    process {
      $i = 1
      do {
        #Create bucket via aws cli
        $bucketname = $nameprefix + '-' + $i
        if ($IMM) {
          Invoke-Command -ScriptBlock { aws --endpoint $svcpoint --profile $awsprofile --no-verify-ssl s3api create-bucket --object-lock-enabled-for-bucket --bucket $bucketname }
        } else {
          Invoke-Command -ScriptBlock { aws --endpoint $svcpoint --profile $awsprofile --no-verify-ssl s3api create-bucket --bucket $bucketname }
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
  
    } #end end block
  
  } #end function