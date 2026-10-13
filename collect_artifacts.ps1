<#
collect_artifacts.ps1
Collect artifacts: files under C:\temp, netstat snapshots, process list, DNS cache, scheduled tasks, run keys.
Parameters: -OutDir -LogFile
#>
param(
  [Parameter(Mandatory=$true)][string]$OutDir,
  [Parameter(Mandatory=$true)][string]$LogFile
)

function Log($m){ $ts=(Get-Date).ToString('o'); "$ts`t$m" | Out-File -FilePath $LogFile -Append -Encoding utf8 }

# Ensure output dirs
New-Item -Path $OutDir -ItemType Directory -Force | Out-Null
$filesDir = Join-Path $OutDir 'files'
New-Item -Path $filesDir -ItemType Directory -Force | Out-Null

Log "Starting artifact collection to $OutDir"

# 1) Index C:\temp
$base = 'C:\temp'
Log "Indexing $base"
try{
    $items = Get-ChildItem -Path $base -Recurse -File -ErrorAction SilentlyContinue
    foreach ($f in $items){
        $dest = Join-Path $filesDir ($f.FullName -replace '[:\\]','_')
        # Create small manifest, not copying entire files to avoid exfil
        $meta = [PSCustomObject]@{ Path=$f.FullName; Length=$f.Length; LastWrite=$f.LastWriteTime.ToString('o') }
        $meta | ConvertTo-Json | Out-File ($dest + '.json')
    }
    Log "Indexed $($items.Count) files"
} catch { Log "Indexing failed: $($_)" }

# 2) Netstat now + snapshots
Log "Collecting netstat snapshots"
netstat -ano | Out-File (Join-Path $OutDir 'netstat_now.txt')
for ($i=0;$i -lt 6;$i++){ netstat -ano | Out-File (Join-Path $OutDir ("netstat_snap_{0}.txt" -f (Get-Date).ToString('yyyyMMdd_HHmmss_fff'))); Start-Sleep -Seconds 2 }

# 3) Process list + CIM lines
Log "Collecting process list"
Get-Process | Select-Object Id,ProcessName,Path,StartTime | ConvertTo-Json -Depth 3 | Out-File (Join-Path $OutDir 'process_list.json')
Get-CimInstance Win32_Process | Select ProcessId,ParentProcessId,CommandLine,CreationDate | ConvertTo-Json -Depth 3 | Out-File (Join-Path $OutDir 'process_cim.json')

# 4) DNS cache
Log "Collecting DNS cache"
try{ Get-DnsClientCache | ConvertTo-Json -Depth 4 | Out-File (Join-Path $OutDir 'dns_clientcache.json') } catch { ipconfig /displaydns 2>&1 | Out-File (Join-Path $OutDir 'displaydns.txt') }

# 5) Scheduled tasks and Run keys
Log "Collecting scheduled tasks and Run keys"
schtasks /query /fo LIST /v 2>&1 | Out-File (Join-Path $OutDir 'schtasks.txt')
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Run -ErrorAction SilentlyContinue | ConvertTo-Json -Depth 3 | Out-File (Join-Path $OutDir 'run_hklm.json')
Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Run -ErrorAction SilentlyContinue | ConvertTo-Json -Depth 3 | Out-File (Join-Path $OutDir 'run_hkcu.json')

# 6) Wireless adapters and network config
Log "Collecting network adapters and IP configuration"
Get-NetAdapter | Select Name,InterfaceDescription,Status | ConvertTo-Json -Depth 3 | Out-File (Join-Path $OutDir 'net_adapters.json')
Get-NetIPConfiguration | ConvertTo-Json -Depth 4 | Out-File (Join-Path $OutDir 'net_ipconfig.json')

# 7) Save summary
Log "Writing summary"
$summary = [PSCustomObject]@{ Host=$env:COMPUTERNAME; Timestamp=(Get-Date).ToString('o'); FilesIndexed=(Get-ChildItem -Path $base -Recurse -File -ErrorAction SilentlyContinue).Count }
$summary | ConvertTo-Json -Depth 3 | Out-File (Join-Path $OutDir 'summary.json')

Log "Collection finished"
