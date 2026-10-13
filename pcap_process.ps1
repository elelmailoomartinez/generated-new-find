<#
pcap_process.ps1
Convert ETL->PCAP (netsh) and extract DNS queries with tshark if available.
Parameters: -OutDir -LogFile
#>
param(
  [Parameter(Mandatory=$true)][string]$OutDir,
  [Parameter(Mandatory=$true)][string]$LogFile
)
function Log($m){ $ts=(Get-Date).ToString('o'); "$ts`t$m" | Out-File -FilePath $LogFile -Append -Encoding utf8 }

$pcaps = Get-ChildItem -Path $OutDir -Recurse -Include *.etl,*.pcap,*.pcapng -ErrorAction SilentlyContinue
$tshark = Get-Command tshark -ErrorAction SilentlyContinue

foreach ($f in $pcaps){
    if ($f.Extension -ieq '.etl'){
        $outp = [System.IO.Path]::ChangeExtension($f.FullName,'.pcap')
        try{ Log ("Converting ETL $($f.FullName) -> $outp"); netsh trace convert input="$($f.FullName)" output="$outp" 2>$null; Log "Converted" } catch { Log ("ETL->PCAP failed: {0}" -f $_) }
    }
}

# Extract DNS with tshark if available
if ($tshark){
    $pcapfiles = Get-ChildItem -Path $OutDir -Recurse -Include *.pcap,*.pcapng -ErrorAction SilentlyContinue
    foreach ($p in $pcapfiles){
        $csv = Join-Path $OutDir ("dns_" + ($p.BaseName) + ".csv")
        $cmd = "`"$($tshark.Path)`" -r `"$($p.FullName)`" -Y dns.qry.name -T fields -e frame.time_epoch -e dns.qry.name -e dns.qry.type -e ip.src -E separator=, -E quote=d"
        try{ Log ("Extracting DNS from $($p.FullName) to $csv"); Invoke-Expression $cmd | Out-File $csv; Log "Extracted $csv" } catch { Log ("tshark extract failed for {0}: {1}" -f $p.FullName, $_) }
    }
} else { Log 'tshark not found; skipping DNS extraction' }

Log 'pcap processing finished.'
