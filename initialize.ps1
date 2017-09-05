#usage initialize.ps1
param
(
       [string]$templateLink     = "https://raw.githubusercontent.com/NAVDEMO/DOCKER/master/navdeveloperpreview.json",
       [string]$hostName         = "",
       [string]$vmAdminUsername  = "vmadmin",
       [string]$navAdminUsername = "admin",
       [string]$adminPassword    = "P@ssword1",
       [string]$country          = "us",
       [string]$navVersion       = "devpreview",
       [string]$licenseFileUri   = ""
)

function Log([string]$line, [string]$color = "Gray") { ("<font color=""$color"">" + [DateTime]::Now.ToString([System.Globalization.DateTimeFormatInfo]::CurrentInfo.ShortTimePattern.replace(":mm",":mm:ss")) + " $line</font>") | Add-Content -Path "c:\demo\status.txt" }

function DownloadFile([string]$sourceUrl, [string]$destinationFile)
{
    Log("Downloading '$sourceUrl' to '$destinationFile'")
    Remove-Item -Path $destinationFile -Force -ErrorAction Ignore
    (New-Object System.Net.WebClient).DownloadFile($sourceUrl, $destinationFile)
}

if (Test-Path -Path "c:\DEMO\Status.txt" -PathType Leaf) {
    Log "VM already initialized."
    exit
}

New-Item -Path "c:\myfolder" -ItemType Directory -ErrorAction Ignore | Out-Null
New-Item -Path "C:\DEMO" -ItemType Directory -ErrorAction Ignore | Out-Null

Set-ExecutionPolicy -ExecutionPolicy unrestricted -Force

Log("Starting initialization")
Log("TemplateLink: $templateLink")

Log("Upgrade Docker Engine")
Unregister-PackageSource -ProviderName DockerMsftProvider -Name DockerDefault -Erroraction Ignore
Register-PackageSource -ProviderName DockerMsftProvider -Name Docker -Erroraction Ignore -Location https://download.docker.com/components/engine/windows-server/index.json
Install-Package -Name docker -ProviderName DockerMsftProvider -Update -Force
Start-Service docker

Log("Docker Login")
$registry = "navdocker.azurecr.io"
docker login $registry -u "7cc3c660-fc3d-41c6-b7dd-dd260148fff7" -p "G/7gwmfohn5bacdf4ooPUjpDOwHIxXspLIFrUsGN+sU="

$pullImage = "dynamics-nav:$navVersion"
$country = $country.ToLowerInvariant()
if ($country -ne "w1") {
    $pullImage += "-fin$country"
}

Log "pull microsoft/windowsservercore"
docker pull microsoft/windowsservercore

$setupScript = "c:\demo\setup.ps1"
$scriptPath = $templateLink.SubString(0,$templateLink.LastIndexOf('/')+1)
DownloadFile -sourceUrl "${scriptPath}SetupNavUsers.ps1" -destinationFile "c:\myfolder\SetupNavUsers.ps1"

New-Item -Path "C:\DEMO\http" -ItemType Directory
DownloadFile -sourceUrl "${scriptPath}Default.aspx"  -destinationFile "c:\demo\http\Default.aspx"
DownloadFile -sourceUrl "${scriptPath}status.aspx"   -destinationFile "c:\demo\http\status.aspx"
DownloadFile -sourceUrl "${scriptPath}Line.png"      -destinationFile "c:\demo\http\Line.png"
DownloadFile -sourceUrl "${scriptPath}Microsoft.png" -destinationFile "c:\demo\http\Microsoft.png"
if ($licenseFileUri -ne "") {
    DownloadFile -sourceUrl $licenseFileUri -destinationFile "c:\demo\license.flf"
}

('$imageName = "'+$registry + '/' + $pullImage + '"') | Set-Content $setupScript
('$vmAdminUsername = "' + $vmAdminUsername + '"')     | Add-Content $setupScript
('$navAdminUsername = "' + $navAdminUsername + '"')   | Add-Content $setupScript
('$adminPassword = "' + $adminPassword + '"')         | Add-Content $setupScript
('$hostName = "' + $hostName + '"')                   | Add-Content $setupScript
('$country = "' + $country + '"')                     | Add-Content $setupScript
(New-Object System.Net.WebClient).DownloadString("${scriptPath}setup.ps1") | Add-Content $setupScript

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoExit $setupScript"
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "setupScript" -Action $action -Trigger $trigger -RunLevel Highest -User $vmAdminUsername | Out-Null

Log "Reboot and run Setup Task"
Restart-Computer -Force
