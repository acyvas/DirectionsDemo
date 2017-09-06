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

('$hostName = "' + $hostName + '"')                   | Add-Content $setupScript
('$containerName = "' + $containerName + '"')         | Add-Content $setupScript
(New-Object System.Net.WebClient).DownloadString("${scriptPath}setup.ps1") | Add-Content $setupScript

# Override AdditionalSetup to copy iguration to not use SSL for Developer Services
'$wwwRootPath = Get-WWWRootPath
$httpPath = Join-Path $wwwRootPath "http"
Copy-Item -Path "C:\demo\http\*.*" -Destination $httpPath -Recurse
if ($hostname -ne "") {
"full address:s:$hostname:3389
prompt for credentials:i:1" | Set-Content "$httpPath\Connect.rdp"
}' | Set-Content -Path "c:\myfolder\AdditionalSetup.ps1"

$containerName = "navserver"
$useSSL = "Y"
if ($hostName -eq "") { 
    $hostName = $containerName
    $useSSL = "N"
}

docker ps --filter name=$containerName -q | % {
    Log "Removing container $containerName"
    docker rm $_ -f | Out-Null
}

Set-Content -Path "C:\Demo\Country.txt" -Value $Country
switch ($country) {
"DK"    { $locale = "da-DK" }
"CA"    { $locale = "en-CA" }
"GB"    { $locale = "en-GB" }
default { $locale = "en-US" }
}

Log "Running $imageName"
$containerId = docker run --env      accept_eula=Y `
                          --hostname $hostName `
                          --name     $containerName `
                          --publish  8080:8080 `
                          --publish  80:80 `
                          --publish  443:443 `
                          --publish  7046-7049:7046-7049 `
                          --env      username="$navAdminUsername" `
                          --env      password="$adminPassword" `
                          --env      useSSL=$useSSL `
                          --env      locale=$locale `
                          --volume   c:\demo:c:\demo `
                          --volume   c:\myfolder:c:\run\my `
                          --detach `
                          $imageName

if ($LastExitCode -ne 0) {
    throw "Docker run error"
}

Log "Waiting for container to become healthy, this shouldn't take more than 2 minutes"
do {
    Start-Sleep -Seconds 2
    $status = (docker ps -a --filter Name=$containerName --format '{{.Status}}')
    $healthy = $status.Contains('healthy')
} while (!$healthy)

if ($containerName -ne $hostName) {
    # Add Container IP Address to Hosts file as $containername
    Log "Adding $containerName to hosts file"
    $s = docker inspect $containerId
    $IPAddress = ([string]::Join(" ", $s) | ConvertFrom-Json).NetworkSettings.Networks.nat.IPAddress
    " $IPAddress $containerName" | Set-Content -Path "c:\windows\system32\drivers\etc\hosts" -Force
}

# Copy .vsix and Certificate to C:\Demo
Log "Copying .vsix and Certificate to C:\Demo"
Remove-Item "C:\Demo\*.vsix" -Force
Remove-Item "C:\Demo\*.cer" -Force
docker exec -it navserver powershell "copy-item -Path 'C:\Run\*.vsix' -Destination 'C:\Demo' -force
copy-item -Path 'C:\Run\*.cer' -Destination 'C:\Demo' -force"
$vsixFileName = (Get-Item "C:\Demo\*.vsix").FullName
$certFileName = (Get-Item "C:\Demo\*.cer").FullName

# Install Certificate on host
if ($certFileName) {
    Log "Importing $certFileName to trusted root"
    $pfx = new-object System.Security.Cryptography.X509Certificates.X509Certificate2 
    $pfx.import($certFileName)
    $store = new-object System.Security.Cryptography.X509Certificates.X509Store([System.Security.Cryptography.X509Certificates.StoreName]::Root,"localmachine")
    $store.open("MaxAllowed") 
    $store.add($pfx) 
    $store.close()
}

if (Test-Path -Path 'c:\demo\license.flf' -PathType Leaf) {
    Log "Importing license file"
    docker exec -it navserver powershell "Import-Module 'C:\Program Files\Microsoft Dynamics NAV\*\Service\Microsoft.Dynamics.Nav.Management.psm1'
Import-NAVServerLicense -LicenseFile 'c:\demo\license.flf' -ServerInstance 'NAV' -Database NavDatabase -WarningAction SilentlyContinue"
}

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoExit $setupScript"
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "setupScript" -Action $action -Trigger $trigger -RunLevel Highest -User $vmAdminUsername | Out-Null

Log "Restarting"

Restart-Computer -Force
