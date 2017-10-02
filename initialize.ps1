#usage initialize.ps1
param
(
       [string]$templateLink           = "https://raw.githubusercontent.com/NAVDEMO/DOCKER/master/navdeveloperpreview.json",
       [string]$hostName               = "",
       [string]$vmAdminUsername        = "vmadmin",
       [string]$navAdminUsername       = "admin",
       [string]$adminPassword          = "P@ssword1",
       [string]$country                = "finus",
       [string]$navVersion             = "devpreview",
       [string]$licenseFileUri         = "",
       [string]$certificatePfxUrl      = "",
       [string]$certificatePfxPassword = "",
       [string]$publicDnsName          = "",
	   [string]$workshopFilesUrl       = "",
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
    Log("Downloading $destinationFile")
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

#Log("Upgrading Docker Engine")
#Unregister-PackageSource -ProviderName DockerMsftProvider -Name DockerDefault -Erroraction Ignore
#Register-PackageSource -ProviderName DockerMsftProvider -Name Docker -Erroraction Ignore -Location https://download.docker.com/components/engine/windows-server/index.json
#Install-Package -Name docker -ProviderName DockerMsftProvider -Update -Force
#Start-Service docker

# Turn off IE Enhanced Security Configuration
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0 | Out-Null
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0 | Out-Null

$registry = "navdocker.azurecr.io"
Log("Logging in to $registry")
docker login $registry -u "7cc3c660-fc3d-41c6-b7dd-dd260148fff7" -p "G/7gwmfohn5bacdf4ooPUjpDOwHIxXspLIFrUsGN+sU="

$country = $country.ToLowerInvariant()
$imageName = ""
$navVersion.Split(',') | % {
    $pullImage = "$registry/dynamics-nav:$_"
    if ($imageName -eq "") {
        if ($country -ne "w1") {
            $pullImage += "-$country"
        }
        $imageName = $pullImage
    }
    
    $pulled = $false
    1..3 | % {
        if (!$pulled) {
            try {
                Log "pulling $pullImage"
                docker pull $pullImage
                if ($LastExitCode -eq 0) {
                    $pulled = $true
                }
            } catch {
            }
            if (!$pulled) {
                Start-Sleep -Seconds 120
            }
        }
    }
    if (!$pulled) {
        Log "pulling $pullImage"
        docker pull $pullImage
    }
}

$settingsScript = "c:\demo\settings.ps1"
$setupDesktopScript = "c:\demo\SetupDesktop.ps1"
$setupVmScript = "c:\demo\SetupVm.ps1"
$setupNavContainerScript = "c:\demo\SetupNavContainer.ps1"

$scriptPath = $templateLink.SubString(0,$templateLink.LastIndexOf('/')+1)
DownloadFile -sourceUrl "${scriptPath}SetupNavUsers.ps1" -destinationFile "c:\myfolder\SetupNavUsers.ps1"

if ($vmAdminUsername -ne $navAdminUsername) {
    '. "c:\run\SetupWindowsUsers.ps1"
    Write-Host "Creating Host Windows user"
    $hostUsername = "'+$vmAdminUsername+'"
    New-LocalUser -AccountNeverExpires -FullName $hostUsername -Name $hostUsername -Password (ConvertTo-SecureString -AsPlainText -String $password -Force) -ErrorAction Ignore | Out-Null
    Add-LocalGroupMember -Group administrators -Member $hostUsername -ErrorAction Ignore' | Set-Content "c:\myfolder\SetupWindowsUsers.ps1"
}

New-Item -Path "C:\DEMO\http" -ItemType Directory
DownloadFile -sourceUrl "${scriptPath}Default.aspx"          -destinationFile "c:\demo\http\Default.aspx"
DownloadFile -sourceUrl "${scriptPath}status.aspx"           -destinationFile "c:\demo\http\status.aspx"
DownloadFile -sourceUrl "${scriptPath}line.png"              -destinationFile "c:\demo\http\line.png"
DownloadFile -sourceUrl "${scriptPath}Microsoft.png"         -destinationFile "c:\demo\http\Microsoft.png"
DownloadFile -sourceUrl "${scriptPath}SetupDesktop.ps1"      -destinationFile $setupDesktopScript
DownloadFile -sourceUrl "${scriptPath}SetupNavContainer.ps1" -destinationFile $setupNavContainerScript

#>>1CF download Helper functions
DownloadFile -sourceUrl "${scriptPath}HelperFunctions.ps1" -destinationFile C:\DEMO\HelperFunctions.ps1
DownloadFile -sourceUrl "${scriptPath}Servers.csv" -destinationFile C:\DEMO\Servers.csv
DownloadFile -sourceUrl "${scriptPath}RestartNST.ps1" -destinationFile C:\DEMO\RestartNST.ps1

$workshopFilesUrl = 'https://www.dropbox.com/s/4iy5jft3ucgngqa/WorkshopFiles.zip?dl=1'

$downloadWorkshopFilesScript = 'c:\Demo\DownloadWorkshopFiles\DownloadWorkshopFiles.ps1'
New-Item 'c:\Demo\DownloadWorkshopFiles' -ItemType Directory -ErrorAction Ignore |Out-Null
('function DownloadFile([string]$sourceUrl, [string]$destinationFile)
{
    Remove-Item -Path $destinationFile -Force -ErrorAction Ignore
    (New-Object System.Net.WebClient).DownloadFile($sourceUrl, $destinationFile)
}
$workshopFilesUrl = "'+$workshopFilesUrl +'"
$workshopFilesFolder = "c:\WorkshopFiles"
$workshopFilesFile = "c:\demo\workshopFiles.zip"
Remove-Item $workshopFilesFolder -Force -Recurse |Out-Null
New-Item -Path $workshopFilesFolder -ItemType Directory -ErrorAction Ignore |Out-Null
DownloadFile -sourceUrl $workshopFilesUrl -destinationFile $workshopFilesFile
[Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.Filesystem") | Out-Null
[System.IO.Compression.ZipFile]::ExtractToDirectory($workshopFilesFile, $workshopFilesFolder)
')| Add-Content $downloadWorkshopFilesScript |Out-Null

#<<1CF

if ($style -eq "workshop") {
    DownloadFile -sourceUrl "${scriptPath}SetupVm.ps1"           -destinationFile $setupVmScript
}

if ($licenseFileUri -ne "") {
    DownloadFile -sourceUrl $licenseFileUri -destinationFile "c:\demo\license.flf"
}

if ($workshopFilesUrl -ne "") {
    $workshopFilesFolder = "c:\WorkshopFiles"
    $workshopFilesFile = "c:\demo\workshopFiles.zip"
    New-Item -Path $workshopFilesFolder -ItemType Directory -ErrorAction Ignore
	DownloadFile -sourceUrl $workshopFilesUrl -destinationFile $workshopFilesFile
	[Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.Filesystem") | Out-Null
	[System.IO.Compression.ZipFile]::ExtractToDirectory($workshopFilesFile, $workshopFilesFolder)
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
$dnsidentity = $cert.GetNameInfo("SimpleName",$false)
if ($dnsidentity.StartsWith("*")) {
    $dnsidentity = $dnsidentity.Substring($dnsidentity.IndexOf(".")+1)
}
Remove-Item $certificatePfxFile -force
Remove-Item "c:\run\my\SetupCertificate.ps1" -force
') | Add-Content "c:\myfolder\SetupCertificate.ps1"
} else {
    $publicDnsName = $hostname
}

$containerName = "navserver"

('$imageName = "' + $imageName + '"')                 | Set-Content $settingsScript
('$Country = "' + $Country + '"')                     | Add-Content $settingsScript
('$style = "' + $style + '"')                         | Add-Content $settingsScript
('$hostName = "' + $hostName + '"')                   | Add-Content $settingsScript
('$publicDnsName = "' + $publicDnsName + '"')         | Add-Content $settingsScript
('$containerName = "' + $containerName + '"')         | Add-Content $settingsScript
('$navAdminUsername = "' + $navAdminUsername + '"')   | Add-Content $settingsScript
('$vmAdminUsername = "' + $vmAdminUsername + '"')     | Add-Content $settingsScript
('$adminPassword = "' + $adminPassword + '"')         | Add-Content $settingsScript

#. $setupNavContainerScript


#>>1CF
Import-Module C:\DEMO\HelperFunctions.ps1

$BackupsUrl = "https://www.dropbox.com/s/b2mmn9db4fqry2z/DB_Backups.zip?dl=1"
$Folder = "C:\DOWNLOAD\Backups"
$Filename = "$Folder\dbBackups.zip"
New-Item $Folder -itemtype directory -ErrorAction ignore | Out-Null
if (!(Test-Path $Filename)) {
    DownloadFile -SourceUrl $BackupsUrl  -destinationFile $Filename
}

[Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.Filesystem") | Out-Null
[System.IO.Compression.ZipFile]::ExtractToDirectory($Filename,$Folder )

$ServersToCreate = Import-Csv "c:\demo\servers.csv"
$ServersToCreate |%{
    $d = $_.Server
    $bakupPath = "$Folder\$($_.Backup)"
    Copy-Item  -Path  "c:\myfolder\SetupCertificate.ps1" -Destination "c:\DEMO\$d\my\SetupCertificate.ps1" -Recurse -Force -ErrorAction Ignore
    #CreateDevServerContainer -devContainerName $d -dbBackup $bakupPath
    CreateDevServerContainer -devContainerName $d -devImageName 'navdocker.azurecr.io/dynamics-nav:devpreview-september'
    Copy-Item -Path "c:\myfolder\SetupNavUsers.ps1" -Destination "c:\DEMO\$d\my\SetupNavUsers.ps1"
    Copy-Item -Path "c:\DEMO\$d\my\*.vsix" -Destination "c:\DEMO\" -Recurse -Force -ErrorAction Ignore
    Copy-Item -Path "C:\DEMO\RestartNST.ps1" -Destination "c:\DEMO\$d\my\RestartNST.ps1" -Force -ErrorAction Ignore
}


#<<1CF

<# 1CF
$logonAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $setupDesktopScript
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "SetupDesktop" `
                       -Action $logonAction `
                       -Trigger $logonTrigger `
                       -RunLevel Highest `
                       -User $vmAdminUsername | Out-Null

#>
if ($style -eq "workshop") {
    $startupAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $setupVmScript
    $startupTrigger = New-ScheduledTaskTrigger -AtStartup
    Register-ScheduledTask -TaskName "SetupVm" `
                           -Action $startupAction `
                           -Trigger $startupTrigger `
                           -RunLevel Highest `
                           -User System | Out-Null
}


Restart-Computer -Force
