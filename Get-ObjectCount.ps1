[System.Collections.ArrayList]$RawResults = @()

$org = get-vboorganization 
$J = get-vbojob -organization $org
foreach($Job in $J)
{
    $JS = Get-VBOJobsession -Job $Job -Last
    $Objects = $Js.Progress
    $TrData = $Js.statistics.TransferredData
    $TrItems = $Js.statistics.ProcessedObjects
    $repo = $job.Repository
    $proxy = $repo.proxy
    $output = @{
      Job         = $Job
      Repository  = $repo
      Proxy       = $proxy
      jobObjects  = $objects
      xferData    = $TrData
      jobItems    = $TrItems
    }

    $RawResults.Add($output)
}
$RawResults