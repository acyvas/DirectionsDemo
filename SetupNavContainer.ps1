function Log([string]$line, [string]$color = "Gray") { ("<font color=""$color"">" + [DateTime]::Now.ToString([System.Globalization.DateTimeFormatInfo]::CurrentInfo.ShortTimePattern.replace(":mm",":mm:ss")) + " $line</font>") | Add-Content -Path "c:\demo\status.txt" }

# Override AdditionalSetup to copy iguration to not use SSL for Developer Services
'$wwwRootPath = Get-WWWRootPath
$httpPath = Join-Path $wwwRootPath "http"
Copy-Item -Path "C:\demo\http\*.*" -Destination $httpPath -Recurse
if ($hostname -ne "") {
"full address:s:${hostname}:3389
prompt for credentials:i:1
username:s:$vmAdminUsername" | Set-Content "$httpPath\Connect.rdp"
}' | Set-Content -Path "c:\myfolder\AdditionalSetup.ps1"

$registry = "navdocker.azurecr.io"
Log("Logging in to $registry")
docker login $registry -u "7cc3c660-fc3d-41c6-b7dd-dd260148fff7" -p "G/7gwmfohn5bacdf4ooPUjpDOwHIxXspLIFrUsGN+sU="

docker ps --filter name=$containerName -a -q | % {
    Log "Removing container $containerName"
    docker rm $_ -f | Out-Null
}

Log "pulling $imageName"
docker pull $imageName

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
                          --publish  80:8080 `
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
