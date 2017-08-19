#usage initialize.ps1
param
(
       [string]$scriptPath = "",
       [string]$adminUser = ""
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

New-Item -Path "C:\DEMO" -ItemType Directory
Set-ExecutionPolicy -ExecutionPolicy unrestricted -Force

Log("Starting initialization")
Log("ScriptPath: $scriptPath")

$baseUrl = $scriptPath.SubString(0,$scriptPath.LastIndexOf('/')+1)
$setupScript = "c:\demo\setup.ps1"
DownloadFile -SourceUrl "${baseUrl}setup.ps1" -destinationFile $setupScript

$imageName = "navdocker.azurecr.io/dynamics-nav:devpreview"
Log "pull $imageName"
docker login navdocker.azurecr.io -u 7cc3c660-fc3d-41c6-b7dd-dd260148fff7 -p G/7gwmfohn5bacdf4ooPUjpDOwHIxXspLIFrUsGN+sU=
docker pull $imageName

Log "Register Setup Task"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoExit $setupScript"
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "setupScript" -Action $action -Trigger $trigger -RunLevel Highest -User $adminUser | Out-Null

Log "Reboot and run Setup Task"
Restart-Computer -Force
