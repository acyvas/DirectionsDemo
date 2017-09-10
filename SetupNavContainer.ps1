function Log([string]$line, [string]$color = "Gray") { ("<font color=""$color"">" + [DateTime]::Now.ToString([System.Globalization.DateTimeFormatInfo]::CurrentInfo.ShortTimePattern.replace(":mm",":mm:ss")) + " $line</font>") | Add-Content -Path "c:\demo\status.txt" }

. (Join-Path $PSScriptRoot "settings.ps1")

docker ps --filter name=$containerName -a -q | % {
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

# Override AdditionalSetup to copy iguration to not use SSL for Developer Services
'$wwwRootPath = Get-WWWRootPath
$httpPath = Join-Path $wwwRootPath "http"
Copy-Item -Path "C:\demo\http\*.*" -Destination $httpPath -Recurse
if ($hostname -ne "") {
"full address:s:${hostname}:3389
prompt for credentials:i:1
username:s:$vmAdminUsername" | Set-Content "$httpPath\Connect.rdp"
}
' | Set-Content -Path "c:\myfolder\AdditionalSetup.ps1"


if (Test-Path "C:\Program Files (x86)\Microsoft Dynamics NAV") {
    Remove-Item "C:\Program Files (x86)\Microsoft Dynamics NAV" -Force -Recurse -ErrorAction Ignore
}
New-Item "C:\Program Files (x86)\Microsoft Dynamics NAV" -ItemType Directory -ErrorAction Ignore | Out-Null

('Copy-Item -Path "C:\Program Files (x86)\Microsoft Dynamics NAV\*" -Destination "c:\navpfiles" -Recurse -Force -ErrorAction Ignore
$destFolder = (Get-Item "c:\navpfiles\*\RoleTailored Client").FullName
$ClientUserSettingsFileName = "$runPath\ClientUserSettings.config"
[xml]$ClientUserSettings = Get-Content $clientUserSettingsFileName
$clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""Server""]").value = "'+$containerName+'"
$clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ServerInstance""]").value="NAV"
$clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ServicesCertificateValidationEnabled""]").value="false"
$clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ClientServicesPort""]").value="$publicWinClientPort"
$clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ACSUri""]").value = ""
$clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""DnsIdentity""]").value = "$dnsIdentity"
$clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ClientServicesCredentialType""]").value = "$Auth"
$clientUserSettings.Save("$destFolder\ClientUserSettings.config")
') | Add-Content -Path "c:\myfolder\AdditionalSetup.ps1"

$ip = "172.25.1.1"
Log "Running $imageName"
$containerId = docker run --env      accept_eula=Y `
                          --hostname $containerName `
                          --ip       $ip `
                          --add-host ${containerName}:$ip `
                          --name     $containerName `
                          --publish  80:8080 `
                          --publish  443:443 `
                          --publish  7046-7049:7046-7049 `
                          --env      publicFileSharePort=80 `
                          --env      username="$navAdminUsername" `
                          --env      password="$adminPassword" `
                          --env      useSSL=$useSSL `
                          --env      locale=$locale `
                          --volume   c:\demo:c:\demo `
                          --volume   c:\myfolder:c:\run\my `
                          --volume   "C:\Program Files (x86)\Microsoft Dynamics NAV:C:\navpfiles" `
                          --restart  always `
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

# Copy .vsix and Certificate to C:\Demo
Log "Copying .vsix and Certificate to C:\Demo"
Remove-Item "C:\Demo\*.vsix" -Force
Remove-Item "C:\Demo\*.cer" -Force
docker exec -it $containerName powershell "copy-item -Path 'C:\Run\*.vsix' -Destination 'C:\Demo' -force
copy-item -Path 'C:\Run\*.cer' -Destination 'C:\Demo' -force"
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
    docker exec -it $containerName powershell "Import-Module 'C:\Program Files\Microsoft Dynamics NAV\*\Service\Microsoft.Dynamics.Nav.Management.psm1'
Import-NAVServerLicense -LicenseFile 'c:\demo\license.flf' -ServerInstance 'NAV' -Database NavDatabase -WarningAction SilentlyContinue"
}

Log "Waiting for container to become ready, this will only take a few minutes"
$cnt = 150
do {
    Start-Sleep -Seconds 2
    $logs = docker logs $containerName 
    $log = [string]::Join(" ",$logs)
} while ($cnt-- -gt 0 -and !($log.Contains("Ready for connections!")))

Log -color Green "Container output"
docker logs $containerName | % { log $_ }

Log -color Green "Container setup complete!"