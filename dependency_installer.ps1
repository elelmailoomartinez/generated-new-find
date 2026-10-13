<#
dependency_installer.ps1
Download Sysinternals procdump and listdlls to tools dir and optionally install Wireshark via winget.
Parameters: -OutDir -LogFile
#>
param(
  [Parameter(Mandatory=$true)][string]$OutDir,
  [Parameter(Mandatory=$true)][string]$LogFile
)
function Log($m){ $ts=(Get-Date).ToString('o'); "$ts`t$m" | Out-File -FilePath $LogFile -Append -Encoding utf8 }

$toolsDir = Join-Path $OutDir 'tools'
New-Item -Path $toolsDir -ItemType Directory -Force | Out-Null

$sys = @{
  procdump='https://download.sysinternals.com/files/Procdump.zip'
  listdlls='https://download.sysinternals.com/files/ListDlls.zip'
}

foreach ($k in $sys.Keys){
  try{
    $zip = Join-Path $toolsDir ("$k.zip")
    Log "Downloading $k from $($sys[$k]) to $zip"
    Invoke-WebRequest -Uri $sys[$k] -OutFile $zip -UseBasicParsing -ErrorAction Stop
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $toolsDir)
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Log "Extracted $k"
  } catch { Log ("Failed downloading/extracting {0}: {1}" -f $k, $($_)) }
}

# optional: install tshark via winget
$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($winget){
  $resp = Read-Host "winget detected. Install Wireshark (tshark) via winget? (S/N)"
  if ($resp -match '^[sS]'){
    try{ Start-Process -FilePath $winget.Source -ArgumentList 'install --id=WiresharkFoundation.Wireshark -e --accept-package-agreements --accept-source-agreements' -NoNewWindow -Wait; Log 'winget install requested' } catch { Log "winget install failed: $($_)" }
  }
} else { Log 'winget not detected; skipping tshark install.' }

Log 'Dependency installer finished.'
