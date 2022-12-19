<#
.Synopsis
For Veeam Backup & Replication v12 this script will create the desired number of buckets with a given prefix and then add them into a SOBR

.Notes
Version: 1.0
Authors: Jim Jones, @k00laidIT; Joe Houghes @jhoughes
Modified Date: 12/19/2022

.EXAMPLE
./New-cVBRSOBR.ps1  #to local function into memory
New-cVBRSOBR -NamePrefix '123-test1' -VBRSrv 'localhost' -SvcPoint 'https://us-central-1a.object.ilandcloud.com' -AWSProfile 'ilanduscentral' -NumRepos '5' -IMM $true -IMMDays '30'
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
    [string] $AWSProfile,

    [Parameter(Mandatory = $true)]
    [int] $NumRepos,

    [Parameter(Mandatory = $true)]
    [boolean] $IMM,

    [Parameter(Mandatory = $true)]
    [int] $IMMDays

  )

  begin {
    #import-module AWS.Tools.Common, AWS.Tools.S3
    Connect-VBRServer -Server $VBRSrv

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
      $objkey = Get-VBRAmazonAccount -Id 02be1fe1-de9e-4bbf-a76b-2ab90d88fe1e
      $connect = Connect-VBRAmazonS3CompatibleService -Account $objkey -CustomRegionId 'us-east-1' -ServicePoint $SvcPoint -Force
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