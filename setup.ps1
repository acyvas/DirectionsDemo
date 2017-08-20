. "c:\demo\settings.ps1"

function Log([string]$line, [string]$color = "Gray") { ("<font color=""$color"">" + [DateTime]::Now.ToString([System.Globalization.DateTimeFormatInfo]::CurrentInfo.ShortTimePattern.replace(":mm",":mm:ss")) + " $line</font>") | Add-Content -Path "c:\demo\status.txt"; Write-Host -ForegroundColor $color $line }

function DownloadFile([string]$sourceUrl, [string]$destinationFile)
{
    Log("Downloading '$sourceUrl' to '$destinationFile'")
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

Log -color Green "Finalizing Setup"

Log "Installing Docker PowerShell"
if (!(Get-PSRepository -Name DockerPS-Dev -ErrorAction Ignore)) {
    Register-PSRepository -Name DockerPS-Dev -SourceLocation https://ci.appveyor.com/nuget/docker-powershell-dev
}
if (!(Get-Module -Name Docker -ErrorAction Ignore)) {
    Install-Module -Name Docker -Repository DockerPS-Dev -Scope AllUsers -Force
}

Log "Create myfolder"
New-Item -Path "c:\myfolder" -ItemType Directory -ErrorAction Ignore | Out-Null

# Override SetupConfiguration to not use SSL for Developer Services
'. (Join-Path $runPath $MyInvocation.MyCommand.Name)
if ($servicesUseSSL) {
    # change urlacl reservation for DeveloperService
    netsh http delete sslcert ipport=0.0.0.0:7049 | Out-Null
    netsh http delete urlacl url=https://+:7049/NAV | Out-Null
    netsh http add urlacl url=http://+:7049/NAV user="NT AUTHORITY\SYSTEM" | Out-Null
    # No SSL for developer services port - only internal
    $CustomConfigFile =  Join-Path $ServiceTierFolder "CustomSettings.config"
    $CustomConfig = [xml](Get-Content $CustomConfigFile)
    $CustomConfig.SelectSingleNode("//appSettings/add[@key=""DeveloperServicesSSLEnabled""]").Value = "false"
    $CustomConfig.Save($CustomConfigFile)
}' | Set-Content -Path "c:\myfolder\SetupConfiguration.ps1"

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

Log "Remove container (if running)"
get-container | Where-Object { $_.Names.Contains("/$containerName") } | Remove-Container -Force

Log "Run $imageName"
$containerId = docker run --env      accept_eula=Y `
                          --hostname $hostName `
                          --name     $containerName `
                          --publish  8080:8080 `
                          --publish  80:80 `
                          --publish  443:443 `
                          --publish  7046-7048:7046-7048 `
                          --env      username="$navAdminUsername" `
                          --env      password="$adminPassword" `
                          --env      useSSL=$useSSL `
                          --volume   c:\demo:c:\demo `
                          --volume   c:\myfolder:c:\run\my `
                          --detach `
                          $imageName

if ($containerName -ne $hostName) {
    # Add Container IP Address to Hosts file as NAVSERVER
    Log "Add navserver to hosts file"
    $ipaddress = Get-Container -ContainerIdOrName $containerID | % { $_.NetworkSettings.Networks.Values[0].IPAddress }
    " $ipaddress navserver" | Set-Content -Path "c:\windows\system32\drivers\etc\hosts" -Force
}

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

# Get vsix Filename
$session = New-PSSession -ContainerId $containerID -RunAsAdministrator
$vsixName = Invoke-Command -Session $session -ScriptBlock {
    while (!(Test-Path "c:\inetpub\wwwroot\http\*.vsix")) {
        Start-Sleep -Seconds 5
    }
    (Get-Item "c:\inetpub\wwwroot\http\*.vsix").Name
}
$VsixFilename = "c:\demo\al.vsix"
DownloadFile -SourceUrl "http://navserver:8080/$vsixName" -destinationFile $VsixFilename

Log "install vsix"
$code = "C:\Program Files (x86)\Microsoft VS Code\bin\Code.cmd"
& $code @('--install-extension', $VsixFileName) | Out-Null

$username = [Environment]::UserName
if (Test-Path -path "c:\Users\Default\.vscode" -PathType Container -ErrorAction Ignore) {
    if (!(Test-Path -path "c:\Users\$username\.vscode" -PathType Container -ErrorAction Ignore)) {
        Copy-Item -Path "c:\Users\Default\.vscode" -Destination "c:\Users\$username\" -Recurse -Force -ErrorAction Ignore
    }
}

Log "Creating Desktop Shortcuts"
New-DesktopShortcut -Name "Landing Page"                 -TargetPath "http://${hostname}:8080"                             -IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3"
New-DesktopShortcut -Name "Visual Studio Code"           -TargetPath "C:\Program Files (x86)\Microsoft VS Code\Code.exe"
New-DesktopShortcut -Name "Web Client"                   -TargetPath "https://${hostname}/NAV/"                            -IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3"
New-DesktopShortcut -Name "Container Command Prompt"     -TargetPath "CMD.EXE"                                             -IconLocation "C:\Program Files\Docker\docker.exe, 0" -Arguments "/C docker.exe exec -it $containerID cmd"
New-DesktopShortcut -Name "Container PowerShell Prompt"  -TargetPath "CMD.EXE"                                             -IconLocation "C:\Program Files\Docker\docker.exe, 0" -Arguments "/C docker.exe exec -it $containerID powershell"

Log "Cleanup"
Remove-Item "C:\DOWNLOAD\AL-master" -Recurse -Force -ErrorAction Ignore
Remove-Item "C:\DOWNLOAD\VSCode" -Recurse -Force -ErrorAction Ignore
Remove-Item "C:\DOWNLOAD\samples.zip" -Force -ErrorAction Ignore

# Turn off IE Enhanced Security Configuration
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0 | Out-Null
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0 | Out-Null

# Enable File Download in IE
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1803" -Value 0
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1803" -Value 0

# Enable Font Download in IE
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1604" -Value 0
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1604" -Value 0

# Remove Scheduled Task
if (Get-ScheduledTask -TaskName setupScript -ErrorAction Ignore) {
    Log "Remove Scheduled Task"
    schtasks /DELETE /TN setupScript /F | Out-Null
}

Start-Process "http://aka.ms/moderndevtools"

Log -color Green "Setup Successfully completed"
