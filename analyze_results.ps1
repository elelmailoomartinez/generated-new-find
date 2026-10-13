# analyze_results.ps1
<#
Analyze collected artifacts minimally: parse netstat, find candidate PIDs, list remote IPs to a file remote_ips.txt
#>
param(
  [Parameter(Mandatory=$true)][string]$OutDir,
  [Parameter(Mandatory=$true)][string]$LogFile
)
function Log($m){ $ts=(Get-Date).ToString('o'); "$ts`t$m" | Out-File -FilePath $LogFile -Append -Encoding utf8 }

Log "Starting analysis in $OutDir"

$netfiles = Get-ChildItem -Path $OutDir -Recurse -Include 'netstat*.txt' -ErrorAction SilentlyContinue
$remoteIps = @()
$candidatePids = @()
foreach ($n in $netfiles){
  $lines = Get-Content $n.FullName -ErrorAction SilentlyContinue
  foreach ($l in $lines){
    if ($l -match '\s*(TCP|UDP)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)\s*$'){
      $remote = $matches[3]
      $pid = [int]$matches[5]
      # strip port
      $ip = $remote -replace ':\d+$','' -replace '^\[|\]$',''
      if ($ip -and $ip -notmatch '127\.0\.0\.1|::1') { $remoteIps += $ip }
      if ($pid -and $pid -ne 0) { $candidatePids += $pid }
    }
  }
}
$remoteIps = $remoteIps | Sort-Object -Unique
$candidatePids = $candidatePids | Sort-Object -Unique

$remoteIps | Out-File (Join-Path $OutDir 'remote_ips.txt')
$candidatePids | Out-File (Join-Path $OutDir 'candidate_pids.txt')

# Produce quick proc details
$procDetails = @()
foreach ($pid in $candidatePids){
  try{
    $p = Get-Process -Id $pid -ErrorAction Stop
    $cim = Get-CimInstance Win32_Process -Filter "ProcessId=$pid" -ErrorAction SilentlyContinue
    $procDetails += [PSCustomObject]@{ PID=$pid; Name=$p.ProcessName; Path=$p.Path; CommandLine=$cim.CommandLine }
  } catch { Log ("Process $pid not accessible: {0}" -f $_) }
}
$procDetails | ConvertTo-Json -Depth 6 | Out-File (Join-Path $OutDir 'proc_candidates.json')

Log "Analysis finished. Remote IPs: $($remoteIps.Count). Candidate PIDs: $($candidatePids.Count)"
