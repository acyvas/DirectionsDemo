function Log([string]$line, [string]$color = "Gray") { ("<font color=""$color"">" + [DateTime]::Now.ToString([System.Globalization.DateTimeFormatInfo]::CurrentInfo.ShortTimePattern.replace(":mm",":mm:ss")) + " $line</font>") | Add-Content -Path "c:\demo\status.txt"; Write-Host -ForegroundColor $color $line }

function DownloadFile([string]$sourceUrl, [string]$destinationFile)
{
    Log("Downloading '$sourceUrl'")
    Remove-Item -Path $destinationFile -Force -ErrorAction Ignore
    (New-Object System.Net.WebClient).DownloadFile($sourceUrl, $destinationFile)
}

function New-DesktopShortcut([string]$Name, [string]$TargetPath, [string]$WorkingDirectory = "", [string]$IconLocation = "", [string]$Arguments = "")
{
    $filename = "C:\Users\Public\Desktop\$Name.lnk"
    if (!(Test-Path -Path $filename)) {
        $Shell =  New-object -comobject WScript.Shell
        $Shortcut = $Shell.CreateShortcut($filename)
        $Shortcut.TargetPath = $TargetPath
        if (!$WorkingDirectory) {
            $WorkingDirectory = Split-Path $TargetPath
        }
        $Shortcut.WorkingDirectory = $WorkingDirectory
        if ($Arguments) {
            $Shortcut.Arguments = $Arguments
        }
        if ($IconLocation) {
            $Shortcut.IconLocation = $IconLocation
        }
        $Shortcut.save()
    }
}

Log -color Green "Using Docker Image $imageName"

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

# Enable File Download in IE
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1803" -Value 0
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1803" -Value 0

# Enable Font Download in IE
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1604" -Value 0
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1604" -Value 0

Log("Docker Login")
$registry = "navdocker.azurecr.io"
docker login $registry -u "7cc3c660-fc3d-41c6-b7dd-dd260148fff7" -p "G/7gwmfohn5bacdf4ooPUjpDOwHIxXspLIFrUsGN+sU=" | Out-Null

Log "Docker pull $imageName"
docker pull $imageName

docker ps --filter name=$containerName -q | % {
    Log "Remove container $containerName"
    docker rm $_ -f | Out-Null
}

Set-Content -Path "C:\Demo\Country.txt" -Value $Country
switch ($country) {
"DK"    { $locale = "da-DK" }
"CA"    { $locale = "en-CA" }
"GB"    { $locale = "en-GB" }
default { $locale = "en-US" }
}

Log "Docker Run $imageName"
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
Write-Host -ForegroundColor Gray "Time:          ½              1              ½              2"
do {
    Write-Host -NoNewline -ForegroundColor Gray "."
    Start-Sleep -Seconds 2
    $status = (docker ps -a --filter Name=$containerName --format '{{.Status}}')
    $healthy = $status.Contains('healthy')
} while (!$healthy)
Write-Host -ForegroundColor Gray "Healthy"

if ($containerName -ne $hostName) {
    # Add Container IP Address to Hosts file as $containername
    Log "Add $containerName to hosts file"
    $s = docker inspect $containerId
    $IPAddress = ([string]::Join(" ", $s) | ConvertFrom-Json).NetworkSettings.Networks.nat.IPAddress
    " $IPAddress $containerName" | Set-Content -Path "c:\windows\system32\drivers\etc\hosts" -Force
}

# Copy .vsix and Certificate to C:\Demo
Log "Copy .vsix and Certificate to C:\Demo"
Remove-Item "C:\Demo\*.vsix" -Force
Remove-Item "C:\Demo\*.cer" -Force
docker exec -it navserver powershell "copy-item -Path 'C:\Run\*.vsix' -Destination 'C:\Demo' -force
copy-item -Path 'C:\Run\*.cer' -Destination 'C:\Demo' -force"
$vsixFileName = (Get-Item "C:\Demo\*.vsix").FullName
$certFileName = (Get-Item "C:\Demo\*.cer").FullName

# Install Certificate on host
if ($certFileName) {
    Log "Import $certFileName to trusted root"
    $pfx = new-object System.Security.Cryptography.X509Certificates.X509Certificate2 
    $pfx.import($certFileName)
    $store = new-object System.Security.Cryptography.X509Certificates.X509Store([System.Security.Cryptography.X509Certificates.StoreName]::Root,"localmachine")
    $store.open("MaxAllowed") 
    $store.add($pfx) 
    $store.close()
}

if (!(Test-Path "C:\Program Files (x86)\Microsoft VS Code" -PathType Container)) {
    $Folder = "C:\DOWNLOAD\VSCode"
    $Filename = "$Folder\VSCodeSetup-stable.exe"
    New-Item $Folder -itemtype directory -ErrorAction ignore | Out-Null
    if (!(Test-Path $Filename)) {
        DownloadFile -SourceUrl "https://go.microsoft.com/fwlink/?LinkID=623230" -destinationFile $Filename
    }
    
    Log "Installing Visual Studio Code"
    $setupParameters = “/VerySilent /CloseApplications /NoCancel /LoadInf=""c:\demo\vscode.inf"" /MERGETASKS=!runcode"
    Start-Process -FilePath $Filename -WorkingDirectory $Folder -ArgumentList $setupParameters -Wait -Passthru | Out-Null
    
    Log "Download samples"
    $Folder = "C:\DOWNLOAD"
    $Filename = "$Folder\samples.zip"
    New-Item $folder -ItemType Directory -ErrorAction Ignore
    $WebClient = New-Object System.Net.WebClient
    $WebClient.DownloadFile("https://www.github.com/Microsoft/AL/archive/master.zip", $filename)
    Remove-Item -Path "$folder\AL-master" -Force -Recurse -ErrorAction Ignore | Out-null
    [Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.Filesystem") | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($filename, $folder)
    Copy-Item -Path "$folder\AL-master\*" -Destination $PSScriptRoot -Recurse -Force -ErrorAction Ignore
    
    $alFolder = "C:\Users\$([Environment]::UserName)\Documents\AL"
    Remove-Item -Path "$alFolder\Samples" -Recurse -Force -ErrorAction Ignore | Out-Null
    New-Item -Path "$alFolder\Samples" -ItemType Directory -Force -ErrorAction Ignore | Out-Null
    Copy-Item -Path (Join-Path $PSScriptRoot "Samples\*") -Destination "$alFolder\Samples" -Recurse -ErrorAction Ignore

    if ($vsixFileName -ne "") {

        Log "Installing .vsix"
        $code = "C:\Program Files (x86)\Microsoft VS Code\bin\Code.cmd"
        & $code @('--install-extension', $VsixFileName) | Out-Null
    
        $username = [Environment]::UserName
        if (Test-Path -path "c:\Users\Default\.vscode" -PathType Container -ErrorAction Ignore) {
            if (!(Test-Path -path "c:\Users\$username\.vscode" -PathType Container -ErrorAction Ignore)) {
                Copy-Item -Path "c:\Users\Default\.vscode" -Destination "c:\Users\$username\" -Recurse -Force -ErrorAction Ignore
            }
        }
    }
    
    if (Test-Path -Path 'c:\demo\license.flf' -PathType Leaf) {
        Invoke-Command -Session $session -ScriptBlock {
            Import-Module "C:\Program Files\Microsoft Dynamics NAV\*\Service\Microsoft.Dynamics.Nav.Management.psm1"
            Import-NAVServerLicense -LicenseFile 'c:\demo\license.flf' -ServerInstance 'NAV' -Database NavDatabase -WarningAction SilentlyContinue
        }
    }
    
    
    Log "Creating Desktop Shortcuts"
    New-DesktopShortcut -Name "Landing Page"                 -TargetPath "http://${hostname}:8080"                             -IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3"
    New-DesktopShortcut -Name "Visual Studio Code"           -TargetPath "C:\Program Files (x86)\Microsoft VS Code\Code.exe"
    New-DesktopShortcut -Name "Web Client"                   -TargetPath "https://${hostname}/NAV/"                             -IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3"
    New-DesktopShortcut -Name "Container Command Prompt"     -TargetPath "CMD.EXE"                                             -IconLocation "C:\Program Files\Docker\docker.exe, 0" -Arguments "/C docker.exe exec -it $containerName cmd"
    New-DesktopShortcut -Name "NAV Container PowerShell Prompt"  -TargetPath "CMD.EXE"                                             -IconLocation "C:\Program Files\Docker\docker.exe, 0" -Arguments "/C docker.exe exec -it $containerName powershell -noexit c:\run\prompt.ps1"
    
    Log "Cleanup"
    Remove-Item "C:\DOWNLOAD\AL-master" -Recurse -Force -ErrorAction Ignore
    Remove-Item "C:\DOWNLOAD\VSCode" -Recurse -Force -ErrorAction Ignore
    Remove-Item "C:\DOWNLOAD\samples.zip" -Force -ErrorAction Ignore
    
    # Remove Scheduled Task
    if (Get-ScheduledTask -TaskName setupScript -ErrorAction Ignore) {
        schtasks /DELETE /TN setupScript /F | Out-Null
    }
    
    Start-Process "http://${hostname}:8080"
    Start-Process "http://aka.ms/moderndevtools"

    Log "Container output:"
    docker logs navserver | % { log $_ }
}

