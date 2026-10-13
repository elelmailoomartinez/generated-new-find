<#
forensic_runner.ps1
Main orchestrator. Interactive. Requires Admin. Runs collection, pcap processing, analysis and optional GeoIP lookups.
Usage (Admin): powershell -ExecutionPolicy Bypass -File .\forensic_runner.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Log($m){ $ts=(Get-Date).ToString('o'); "$ts`t$m" | Out-File -FilePath $Global:FORNS_LOG -Append -Encoding utf8; Write-Output "[$ts] $m" }

# Pre-flight
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
    Write-Error "Run this script as Administrator."; exit 1
}

$ts = (Get-Date).ToString('yyyyMMdd_HHmmss')
$OUT = "C:\temp\forense_run_$ts"
New-Item -Path $OUT -ItemType Directory -Force | Out-Null
$Global:FORNS_LOG = Join-Path $OUT "run.log"
Log "Output directory: $OUT"

# Paths to helper scripts (assume in repo root next to runner)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$collect = Join-Path $ScriptDir 'collect_artifacts.ps1'
$deps = Join-Path $ScriptDir 'dependency_installer.ps1'
$pcap = Join-Path $ScriptDir 'pcap_process.ps1'
$analyze = Join-Path $ScriptDir 'analyze_results.ps1'
$geo_py = Join-Path $ScriptDir 'geoip_lookup.py'

# Confirm existence
foreach ($f in @($collect,$deps,$pcap,$analyze)){
    if (-not (Test-Path $f)){ Log "Missing helper script: $f"; Write-Error "Missing helper script: $f"; exit 1 }
}

# 1) Install/verify dependencies (with consent)
$cons = Read-Host "¿Deseas que intente instalar/descargar herramientas necesarias (procdump/listdlls, opcional tshark via winget)? (S/N)"
if ($cons -match '^[sS]'){
    & $deps -OutDir $OUT -LogFile $Global:FORNS_LOG
} else { Log "Operator declined auto-dependency install." }

# 2) Run artifact collection
Log "Starting artifact collection..."
try{
    & $collect -OutDir $OUT -LogFile $Global:FORNS_LOG
    Log "Collection complete."
} catch { Log ("Collection failed: {0}" -f $($_)); exit 1 }

# 3) If any ETL/PCAP present, offer to process
$pcap_files = Get-ChildItem -Path $OUT -Recurse -Include *.pcap,*.pcapng,*.etl -ErrorAction SilentlyContinue
if ($pcap_files.Count -gt 0){
    $cons2 = Read-Host "Se detectaron pcap/etl en $OUT. ¿Procesar con tshark/netsh? (S/N)"
    if ($cons2 -match '^[sS]'){
        & $pcap -OutDir $OUT -LogFile $Global:FORNS_LOG
        Log "PCAP processing complete."
    } else { Log "Operator skipped pcap processing." }
} else { Log "No pcap/etl files detected." }

# 4) Analysis
Log "Running analysis..."
try{ & $analyze -OutDir $OUT -LogFile $Global:FORNS_LOG; Log "Analysis complete." } catch { Log ("Analysis failed: {0}" -f $($_)); exit 1 }

# 5) Optional GeoIP lookups (analyze results may have remote_ips.txt)
$remoteFile = Join-Path $OUT 'remote_ips.txt'
if (Test-Path $remoteFile){
    $doGeo = Read-Host "Archivo remote_ips.txt encontrado. ¿Hacer lookups GeoIP públicos para estas IPs con consentimiento? (S/N)"
    if ($doGeo -match '^[sS]'){
        # call python script
        if (Get-Command python -ErrorAction SilentlyContinue){
            Log "Launching geoip_lookup.py"
            & python $geo_py $remoteFile $OUT
            Log "GeoIP lookups finished."
        } else { Log "Python not found on PATH. Skipping GeoIP. You can run geoip_lookup.py later." }
    } else { Log "Operator declined GeoIP lookups." }
}

Log "Run completed. Outputs in: $OUT"
Write-Output "Run completed. Check $OUT and run.log for details."
