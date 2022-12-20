<#
.Synopsis
For Veeam Backup & Replication v12 this script will create the desired number of buckets with a given prefix and then add them into a SOBR
The aws CLI needs to be installed (choco install awscli -y) 
    and a named profile configured (aws configure --profile=myprofile) for this to function.

.Notes
Version: 1.0
Author: Jim Jones, @k00laidIT; Joe Houghes @jhoughes
Modified Date: 12/19/2022

.EXAMPLE
.\New-cVBOAWSObjRepos.ps1  #to local function into memory
New-cVBOAWSObjRepos -NamePrefix 'myorg' -VBOSrv 'localhost' -AWSProfile 'awsprofile'  -ObjCache 'C:\objCache\' -NumRepos '1' -IMM $true -IMMDays '30'
#>


function New-cVBOAWSObjRepos {

  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string] $NamePrefix,

    [Parameter(Mandatory = $true)]
    [string] $VBOSrv = 'localhost',

    [Parameter(Mandatory = $true)]
    [string] $AWSProfile,

    [Parameter(Mandatory = $true)]
    [string] $ObjCache = 'C:\objCache\',

    [Parameter(Mandatory = $true)]
    [int] $NumRepos = "1",

    [Parameter(Mandatory = $true)]
    [boolean] $IMM = $true,

    [Parameter(Mandatory = $true)]
    [int] $IMMDays = '30'
  )


  begin {

    Connect-VBOServer -Server $vbosrv
    $awscred = Get-VBOAmazonS3Account | Where-Object { $_.Description -eq $awsprofile }
    $connect = New-VBOAmazonS3ConnectionSettings -Account $awscred -RegionType Global
    $enckey = Get-VBOEncryptionKey | Where-Object { $_.Description -eq $nameprefix }

  } #end begin block

  process {
    $i = 1
    do {
      #Create bucket via aws cli
      $bucketname = $nameprefix + '-' + $i
      Invoke-Command -ScriptBlock { aws --profile $awsprofile s3api create-bucket --bucket $bucketname --create-bucket-configuration 'LocationConstraint=us-east-2' }

      #Create object storage repository in VB365

      $bucket = Get-VBOAmazonS3Bucket -AmazonS3ConnectionSettings $connect -Name $bucketname
      $folder = Add-VBOAmazonS3Folder -Bucket $bucket -Name 'Veeam'
      $objrepo = Add-VBOAmazonS3ObjectStorageRepository -Folder $folder -Name $bucketname

      #Create Repository in VB365
      $path = $objCache + $bucketname
      $proxy = Get-VBOProxy
      Add-VBORepository -Proxy $proxy -Name $bucketname -Path $path -RetentionPeriod Years3 -RetentionFrequencyType Daily -DailyTime 00:00:00 -DailyType Everyday -RetentionType ItemLevel -ObjectStorageRepository $objrepo -ObjectStorageEncryptionKey $enckey

      if ($IMM) {
        $immbucketname = "$bucketname-imm"
        Invoke-Command -ScriptBlock { aws --profile $awsprofile s3api create-bucket --bucket $immbucketname --create-bucket-configuration 'LocationConstraint=us-east-2' --object-lock-enabled-for-bucket }

        $immbucket = Get-VBOAmazonS3Bucket -AmazonS3ConnectionSettings $connect -Name $immbucketname
        $immfolder = Add-VBOAmazonS3Folder -Bucket $immbucket -Name 'Veeam'
        $immobjrepo = Add-VBOAmazonS3ObjectStorageRepository -Folder $immfolder -Name $immbucketname -EnableImmutability

        $immpath = $objCache + $immbucketname
        Add-VBORepository -Proxy $proxy -Name $immbucketname -Path $immpath -CustomRetentionPeriodType Days -CustomRetentionPeriod $immdays -RetentionFrequencyType Daily -DailyTime 00:00:00 -DailyType Everyday -RetentionType ItemLevel -ObjectStorageRepository $immobjrepo -ObjectStorageEncryptionKey $enckey
      }
      $i++

    } while ($i -le $numrepos)

  } #end process block

  end {
    if ($IMM) {
      Write-Host "Immutability has been enabled. Please setup backup jobs to standard repos and backup copies to the '-imm' repos."
    }
  } #end end block

} #end function



