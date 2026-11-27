# Creates the portable Windows package (dist\<exe>-<version>-windows-x64 and .zip with .sha256),
# using name, version and executable from branding\brand.json.
# Usage: powershell -File tools\package.ps1 [-Suffix preview]
param([string]$Suffix = '')
$ErrorActionPreference = 'Stop'
$root  = Split-Path $PSScriptRoot -Parent
$brand = Get-Content "$root\branding\brand.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$name  = if ($Suffix) { "$($brand.exeName)-$($brand.version)-$Suffix-windows-x64" } else { "$($brand.exeName)-$($brand.version)-windows-x64" }
$d     = "$root\dist\$name"
$rel   = "$root\app\build\windows\x64\runner\Release"
if (-not (Test-Path "$rel\$($brand.exeName).exe")) { throw "Missing $rel\$($brand.exeName).exe: run the release build first." }
if (Test-Path $d) { Remove-Item $d -Recurse -Force }
New-Item -ItemType Directory -Force "$d\documenti", "$d\marchio" | Out-Null
Copy-Item "$rel\*" $d -Recurse
# Visual C++ runtime next to the executable (redistributable), so no separate runtime installer is needed
foreach ($f in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') { Copy-Item "$env:WINDIR\System32\$f" $d }
Copy-Item "$root\docs\GUIDA_UTENTE.md" "$d\LEGGIMI.md"
Copy-Item "$root\README.md" "$d\README.md"
Copy-Item "$root\CHANGELOG.md", "$root\THIRD_PARTY_NOTICES.md", "$root\docs\COMPATIBILITY.md", "$root\docs\KNOWN_LIMITATIONS.md", "$root\docs\NETWORK_SETUP.md" "$d\documenti\"
if (Test-Path "$root\LICENSE") { Copy-Item "$root\LICENSE" "$d\LICENSE.txt" }
Copy-Item "$root\branding\out\logo_scuro.svg", "$root\branding\out\logo_chiaro.svg", "$root\branding\out\icona_512.png" "$d\marchio\"
$zip = "$root\dist\$name.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path $d -DestinationPath $zip
$h = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
Set-Content "$zip.sha256" "$h  $name.zip" -Encoding ascii
"$zip  $([math]::Round((Get-Item $zip).Length/1MB,1)) MB  sha256 $h"
