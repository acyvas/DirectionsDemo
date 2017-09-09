#usage initialize.ps1
param
(
       [string]$templateLink           = "https://raw.githubusercontent.com/NAVDEMO/DOCKER/master/navdeveloperpreview.json",
       [string]$hostName               = "",
       [string]$vmAdminUsername        = "vmadmin",
       [string]$navAdminUsername       = "admin",
       [string]$adminPassword          = "P@ssword1",
       [string]$country                = "us",
       [string]$navVersion             = "devpreview",
       [string]$licenseFileUri         = "",
       [string]$certificatePfxUrl      = "",
       [string]$certificatePfxPassword = "",
       [string]$publicDnsName          = "",
       [string]$style                  = "devpreview"
)

#
# styles:
#   devpreview
#   workshop
#

$includeWindowsClient = $true

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

Log -color Green "Starting initialization"
Log("TemplateLink: $templateLink")

Log("Upgrading Docker Engine")
Unregister-PackageSource -ProviderName DockerMsftProvider -Name DockerDefault -Erroraction Ignore
Register-PackageSource -ProviderName DockerMsftProvider -Name Docker -Erroraction Ignore -Location https://download.docker.com/components/engine/windows-server/index.json
Install-Package -Name docker -ProviderName DockerMsftProvider -Update -Force
Start-Service docker

$registry = "navdocker.azurecr.io"
Log("Logging in to $registry")
docker login $registry -u "7cc3c660-fc3d-41c6-b7dd-dd260148fff7" -p "G/7gwmfohn5bacdf4ooPUjpDOwHIxXspLIFrUsGN+sU="

$pullImage = "dynamics-nav:$navVersion"
$country = $country.ToLowerInvariant()
if ($country -ne "w1") {
    $pullImage += "-fin$country"
}
$imageName = "$registry/$pullImage"

# Turn off IE Enhanced Security Configuration
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0 | Out-Null
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0 | Out-Null

Log "pulling microsoft/windowsservercore"
docker pull microsoft/windowsservercore

Log "pulling $imageName"
docker pull $imageName

$settingsScript = "c:\demo\settings.ps1"
$setupDesktopScript = "c:\demo\SetupDesktop.ps1"
$setupVmScript = "c:\demo\SetupVm.ps1"
$setupNavContainerScript = "c:\demo\SetupNavContainer.ps1"

$scriptPath = $templateLink.SubString(0,$templateLink.LastIndexOf('/')+1)
DownloadFile -sourceUrl "${scriptPath}SetupNavUsers.ps1" -destinationFile "c:\myfolder\SetupNavUsers.ps1"

New-Item -Path "C:\DEMO\http" -ItemType Directory
DownloadFile -sourceUrl "${scriptPath}Default.aspx"          -destinationFile "c:\demo\http\Default.aspx"
DownloadFile -sourceUrl "${scriptPath}status.aspx"           -destinationFile "c:\demo\http\status.aspx"
DownloadFile -sourceUrl "${scriptPath}Line.png"              -destinationFile "c:\demo\http\Line.png"
DownloadFile -sourceUrl "${scriptPath}Microsoft.png"         -destinationFile "c:\demo\http\Microsoft.png"
DownloadFile -sourceUrl "${scriptPath}SetupDesktop.ps1"      -destinationFile $setupDesktopScript
DownloadFile -sourceUrl "${scriptPath}SetupNavContainer.ps1" -destinationFile $setupNavContainerScript

if ($style -eq "workshop") {
    DownloadFile -sourceUrl "${scriptPath}SetupVm.ps1"           -destinationFile $setupVmScript
}

if ($licenseFileUri -ne "") {
    DownloadFile -sourceUrl $licenseFileUri -destinationFile "c:\demo\license.flf"
}

if ($certificatePfxUrl -ne "" -and $certificatePfxPassword -ne "" -and $publicDnsName -ne "") {
    DownloadFile -sourceUrl $certificatePfxUrl -destinationFile "c:\demo\certificate.pfx"

('$certificatePfxPassword = "'+$certificatePfxPassword+'"
$certificatePfxFile = "c:\demo\certificate.pfx"
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certificatePfxFile, $certificatePfxPassword)
$certificateThumbprint = $cert.Thumbprint
Write-Host "Certificate File Thumbprint $certificateThumbprint"
if (!(Get-Item Cert:\LocalMachine\my\$certificateThumbprint -ErrorAction SilentlyContinue)) {
    Write-Host "Import Certificate to LocalMachine\my"
    Import-PfxCertificate -FilePath $certificatePfxFile -CertStoreLocation cert:\localMachine\my -Password (ConvertTo-SecureString -String $certificatePfxPassword -AsPlainText -Force) | Out-Null
}
Remove-Item $certificatePfxFile -force
Remove-Item "c:\run\my\SetupCertificate.ps1" -force
') | Add-Content "c:\myfolder\SetupCertificate.ps1"
$hostname = $publicDnsName
}

$containerName = "navserver"
$useSSL = "Y"
if ($hostName -eq "") { 
    $hostName = $containerName
    $useSSL = "N"
}

('$imageName = "' + $imageName + '"')                 | Set-Content $settingsScript
('$Country = "' + $Country + '"')                     | Add-Content $settingsScript
('$style = "' + $style + '"')                         | Add-Content $settingsScript
('$hostName = "' + $hostName + '"')                   | Add-Content $settingsScript
('$containerName = "' + $containerName + '"')         | Add-Content $settingsScript
('$navAdminUsername = "' + $navAdminUsername + '"')   | Add-Content $settingsScript
('$vmAdminUsername = "' + $vmAdminUsername + '"')     | Add-Content $settingsScript
('$adminPassword = "' + $adminPassword + '"')         | Add-Content $settingsScript

. $setupNavContainerScript

$logonAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $setupDesktopScript
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "SetupDesktop" `
                       -Action $logonAction `
                       -Trigger $logonTrigger `
                       -RunLevel Highest `
                       -User $vmAdminUsername | Out-Null

if ($style -eq "workshop") {
    $startupAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $setupVmScript
    $startupTrigger = New-ScheduledTaskTrigger -AtStartup
    Register-ScheduledTask -TaskName "SetupVm" `
                           -Action $startupAction `
                           -Trigger $startupTrigger `
                           -RunLevel Highest `
                           -User System | Out-Null
}
