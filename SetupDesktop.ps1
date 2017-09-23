function Log([string]$line, [string]$color = "Gray") { ("<font color=""$color"">" + [DateTime]::Now.ToString([System.Globalization.DateTimeFormatInfo]::CurrentInfo.ShortTimePattern.replace(":mm",":mm:ss")) + " $line</font>") | Add-Content -Path "c:\demo\status.txt"; Write-Host -ForegroundColor $color $line }

. (Join-Path $PSScriptRoot "settings.ps1")

function DownloadFile([string]$sourceUrl, [string]$destinationFile)
{
    Log("Downloading $destinationFile")
    Remove-Item -Path $destinationFile -Force -ErrorAction Ignore
    (New-Object System.Net.WebClient).DownloadFile($sourceUrl, $destinationFile)
}
#>>1CF helper functions
function NewContainerSession($containerName) {
    $session = New-PSSession -ContainerId (docker ps --no-trunc -qf "name=$containerName")
    Invoke-Command -Session $session -ScriptBlock {
        . c:\run\prompt.ps1 | Out-Null
        . c:\run\HelperFunctions.ps1 | Out-Null
    }
    $session
}

function RemoveContainerSession($session) {
    Remove-PSSession -Session $session
}

function GetNavContainerNavVersion($containerName) {
    docker inspect --format='{{.Config.Labels.version}}-{{.Config.Labels.country}}' $containerName
}

function GetContainerImage($containerName) {
    docker inspect --format='{{.Config.Image}}' $containerName
}

function GetNavContainerGenericTag($containerName) {
    docker inspect --format='{{.Config.Labels.tag}}' $containerName
}

function GetNavContainerOsVersion($containerName) {
    docker inspect --format='{{.Config.Labels.osversion}}' $containerName
}

function GetNavContainerLegal($containerName) {
    docker inspect --format='{{.Config.Labels.legal}}' $containerName
}

function GetNavContainerCountry($containerName) {
    docker inspect --format='{{.Config.Labels.country}}' $containerName
}

function WaitNavContainerReady($containerName) {
    Write-Host "Waiting for container $containerName to be ready, this shouldn't take more than a few minutes"
    Write-Host "Time:          ½              1              ½              2"
    $cnt = 150
    $log = ""
    do {
        Write-Host -NoNewline "."
        Start-Sleep -Seconds 2
        $logs = docker logs $containerName
        if ($logs) { $log = [string]::Join(" ",$logs) }
        if ($log.Contains("<ScriptBlock>")) { $cnt = 0 }
    } while ($cnt-- -gt 0 -and !($log.Contains("Ready for connections!")))
    Write-Host "Ready"
}

function New-DesktopShortcut([string]$Name, [string]$TargetPath, [string]$WorkingDirectory = "", [string]$IconLocation = "", [string]$Arguments = "")
{
    $filename = "C:\Users\Public\Desktop\$Name.lnk"
    if (Test-Path -Path $filename) {
        Remove-Item $filename -force
    }

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

function Remove-DesktopShortcut([string]$Name)
{
    $filename = "C:\Users\Public\Desktop\$Name.lnk"
    if (Test-Path -Path $filename) {
        Remove-Item $filename -force
    }
}

function RemoveDevServerContainer($devContainerName = "devserver") {
    docker ps --filter name=$devContainerName -a -q | % {
        Write-Host "Removing container $devContainerName"
        docker rm $devContainerName -f | Out-Null
        $containerFolder = Join-Path $PSScriptRoot $devContainerName
        Remove-Item -Path $containerFolder -Force -Recurse -ErrorAction Ignore
        Write-Host "Removing Desktop Shortcuts for container $devContainerName"
        Remove-DesktopShortcut -Name "$devContainerName Web Client"
        Remove-DesktopShortcut -Name "$devContainerName Windows Client"
        Remove-DesktopShortcut -Name "$devContainerName CSIDE"
        Remove-DesktopShortcut -Name "$devContainerName Command Prompt"
        Remove-DesktopShortcut -Name "$devContainerName PowerShell Prompt"
        Write-Host -ForegroundColor Green "Successfully removed container $devContainerName"
    }
}

function CreateDevServerContainer($devContainerName = "devserver", $devImageName = "", $dbBackup="") {

    Write-Host "Creating developer server container $devContainerName"
  
    . "c:\demo\settings.ps1"

    $licenseFile = "C:\DEMO\license.flf"
    if (!(Test-Path $licenseFile)) {
        throw "License file '$licenseFile' must exist in order to create a Developer Server Container."
    }

    if ($devImageName -eq "") { 
        $devImageName = $imageName
        $devCountry = $country
    } else {
        $imageId = docker images -q $devImageName
        if ($imageId -eq "") {
            Write-Host "Pulling docker Image $devImageName"
            docker pull $devImageName
        }
        $devCountry = GetNavContainerCountry $devImageName
    }

    $containerFolder = Join-Path $PSScriptRoot $devContainerName
    New-Item -Path $containerFolder -ItemType Directory -ErrorAction Ignore | Out-Null
    $myFolder = Join-Path $containerFolder "my"
    New-Item -Path $myFolder -ItemType Directory -ErrorAction Ignore | Out-Null
    $programFilesFolder = Join-Path $containerFolder "Program Files"
    New-Item -Path $programFilesFolder -ItemType Directory -ErrorAction Ignore | Out-Null

    RemoveDevServerContainer $devContainerName
    $locale = GetLocaleFromCountry $devCountry

    'sqlcmd -d $DatabaseName -Q "update [dbo].[Object] SET [Modified] = 0"
    ' | Set-Content -Path "$myfolder\AdditionalSetup.ps1"

    if (Test-Path $programFilesFolder) {
        Remove-Item $programFilesFolder -Force -Recurse -ErrorAction Ignore
    }
    New-Item $programFilesFolder -ItemType Directory -ErrorAction Ignore | Out-Null
    
    ('Copy-Item -Path "C:\Program Files (x86)\Microsoft Dynamics NAV\*" -Destination "c:\navpfiles" -Recurse -Force -ErrorAction Ignore
    $destFolder = (Get-Item "c:\navpfiles\*\RoleTailored Client").FullName
    $ClientUserSettingsFileName = "$runPath\ClientUserSettings.config"
    [xml]$ClientUserSettings = Get-Content $clientUserSettingsFileName
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""Server""]").value = "'+$devContainerName+'"
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ServerInstance""]").value="NAV"
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ServicesCertificateValidationEnabled""]").value="false"
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ClientServicesPort""]").value="$publicWinClientPort"
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ACSUri""]").value = ""
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""DnsIdentity""]").value = "$dnsIdentity"
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ClientServicesCredentialType""]").value = "$Auth"
    $clientUserSettings.Save("$destFolder\ClientUserSettings.config")
    ') | Add-Content -Path "$myfolder\AdditionalSetup.ps1"
    
    if ($dbBackup -ne  ""){
        write-host "Copying file $dbBackup to $myFolder"
        $dbBackupFileName = Split-Path $dbBackup -Leaf
        Copy-Item -Path $dbBackup -Destination "$myFolder\" -Recurse -Force 
    }
    Write-Host "Running Conainer Image $devImageName"
    $id = docker run `
                 --name $devContainerName `
                 --hostname $devContainerName `
                 --env accept_eula=Y `
                 --env useSSL=N `
                 --env auth=Windows `
                 --env username=$vmAdminUsername `
                 --env password=$adminPassword `
                 --env ExitOnError=N `
                 --env locale=$locale `
                 --env licenseFile="$licenseFile" `
                 --env bakfile="C:\Run\my\${dbBackupFileName}" `
                 --publish  80:8080 `
                 --publish  443:443 `
                 --publish  7046-7049:7046-7049 `
                 --env      publicFileSharePort=80 `
                 --volume C:\DEMO:C:\DEMO `
                 --volume "${myFolder}:C:\Run\my" `
                 --volume "${programFilesFolder}:C:\navpfiles" `
                 --restart always `
                 --detach `
                 $devImageName

    WaitNavContainerReady $devContainerName

    Write-Host "Create Desktop Shortcuts for $devContainerName"
    $winClientFolder = (Get-Item "$programFilesFolder\*\RoleTailored Client").FullName
    
    $ps = '$customConfigFile = Join-Path (Get-Item ''C:\Program Files\Microsoft Dynamics NAV\*\Service'').FullName "CustomSettings.config"
    [System.IO.File]::ReadAllText($customConfigFile)'
    [xml]$customConfig = docker exec $devContainerName powershell $ps
    $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value
    $databaseName = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value
    $databaseServer = "$devContainerName"
    if ($databaseInstance) { $databaseServer += "\$databaseInstance" }

    New-DesktopShortcut -Name "$devContainerName Web Client" -TargetPath "http://${devContainerName}/NAV/" -IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3"
    New-DesktopShortcut -Name "$devContainerName Windows Client" -TargetPath "$WinClientFolder\Microsoft.Dynamics.Nav.Client.exe"
    New-DesktopShortcut -Name "$devContainerName CSIDE" -TargetPath "$WinClientFolder\finsql.exe" -Arguments "servername=$databaseServer, Database=$databaseName, ntauthentication=yes"
    New-DesktopShortcut -Name "$devContainerName Command Prompt" -TargetPath "CMD.EXE" -IconLocation "C:\Program Files\Docker\docker.exe, 0" -Arguments "/C docker.exe exec -it $devContainerName cmd"
    New-DesktopShortcut -Name "$devContainerName PowerShell Prompt" -TargetPath "CMD.EXE" -IconLocation "C:\Program Files\Docker\docker.exe, 0" -Arguments "/C docker.exe exec -it $devContainerName powershell -noexit c:\run\prompt.ps1"

    Write-Host -ForegroundColor Green "Developer server container $devContainerName successfully created"

    Log "Copying .vsix and Certificate to C:\Demo"
    Remove-Item "C:\Demo\*.vsix" -Force
    Remove-Item "C:\Demo\*.cer" -Force
    docker exec -it $devImageName powershell "copy-item -Path 'C:\Run\*.vsix' -Destination 'C:\Run\My' -force
      copy-item -Path 'C:\Run\*.cer' -Destination 'C:\Run\My' -force"
    $certFileName = (Get-Item "C:\Demo\$devImageName*.cer").FullName

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


}



function GetLocaleFromCountry($country) {
    switch ($country) {
    "finus" { "en-US" }
    "finca" { "en-CA" }
    "fingb" { "en-GB" }
    "findk" { "da-DK" }
    "at"    { "de-AT" }
    "au"    { "en-AU" } 
    "be"    { "nl-BE" }
    "ch"    { "de-CH" }
    "cz"    { "cs-CZ" }
    "de"    { "de-DE" }
    "dk"    { "da-DK" }
    "es"    { "es-ES" }
    "fi"    { "fi-FI" }
    "fr"    { "fr-FR" }
    "gb"    { "en-GB" }
    "in"    { "en-IN" }
    "is"    { "is-IS" }
    "it"    { "it-IT" }
    "na"    { "en-US" }
    "nl"    { "nl-NL" }
    "no"    { "nb-NO" }
    "nz"    { "en-NZ" }
    "ru"    { "ru-RU" }
    "se"    { "sv-SE" }
    "w1"    { "en-US" }
    "us"    { "en-US" }
    "mx"    { "es-MX" }
    "ca"    { "en-CA" }
    "dech"  { "de-CH" }
    "frbe"  { "fr-BE" }
    "frca"  { "fr-CA" }
    "frch"  { "fr-CH" }
    "itch"  { "it-CH" }
    "nlbe"  { "nl-BE" }
    default { "en-US" }
    }
}

function ExportNavContainerObjects($session, $dbUsername, $adminPassword, $filter = "", $objectsFolder) {
    Invoke-Command -Session $session -ScriptBlock { Param($dbUsername, $adminPassword, $filter, $objectsFolder)

        $objectsFile = "$objectsFolder.txt"
        Remove-Item -Path $objectsFile -Force -ErrorAction Ignore
        Remove-Item -Path $objectsFolder -Force -Recurse -ErrorAction Ignore
        Write-Host "Export Objects as new format to $objectsFile $adminPassword"
        Export-NAVApplicationObject -DatabaseName FinancialsUS `
                                    -Path $objectsFile `
                                    -DatabaseServer localhost\SQLEXPRESS `
                                    -Force `
                                    -Filter "$filter" `
                                    -ExportToNewSyntax `
                                    -Username $dbUsername `
                                    -Password $adminPassword | Out-Null
        Write-Host "Split $objectsFile to $objectsFolder"
        New-Item -Path $objectsFolder -ItemType Directory -Force -ErrorAction Ignore | Out-Null
        Split-NAVApplicationObjectFile -Source $objectsFile `
                                       -Destination $objectsFolder
        Remove-Item -Path $objectsFile -Force -ErrorAction Ignore
    
    }  -ArgumentList $dbUsername, $adminPassword, $filter, $objectsFolder
}

function CreateMyOriginalFolder($originalFolder, $modifiedFolder, $myoriginalFolder) {
    Write-Host "Copy original objects to $myoriginalFolder for all objects that are modified"
    Remove-Item -Path $myoriginalFolder -Recurse -Force -ErrorAction Ignore
    New-Item -Path $myoriginalFolder -ItemType Directory | Out-Null
    Get-ChildItem $modifiedFolder | % {
        $Name = $_.Name
        $OrgName = Join-Path $myOriginalFolder $Name
        $TxtFile = Join-Path $originalFolder $Name
        if (Test-Path -Path $TxtFile) {
        Write-Host "Copy $txtfile"
            Copy-Item -Path $TxtFile -Destination $OrgName
        }
    }
}

function CreateMyDeltaFolder($session, $modifiedFolder, $myOriginalFolder, $myDeltaFolder) {
    Invoke-Command -Session $session -ScriptBlock { Param($modifiedFolder, $myOriginalFolder, $myDeltaFolder)

        Write-Host "Compare modified objects with original objects in $myOriginalFolder and create Deltas in $myDeltaFolder"
        Remove-Item -Path $myDeltaFolder -Recurse -Force -ErrorAction Ignore
        New-Item -Path $myDeltaFolder -ItemType Directory | Out-Null
        Compare-NAVApplicationObject -OriginalPath $myOriginalFolder -ModifiedPath $modifiedFolder -DeltaPath $myDeltaFolder | Out-Null
    
    } -ArgumentList $modifiedFolder, $myOriginalFolder, $myDeltaFolder
}

function ConvertFromTxt2Al($session, $myDeltaFolder, $myAlFolder, $startId=50100) {
    Invoke-Command -Session $session -ScriptBlock { Param($myDeltaFolder, $myAlFolder, $startId)

        Write-Host "Converting files in $myDeltaFolder to .al files in $myAlFolder with startId $startId"
        $txt2al = $navide.replace("finsql.exe","txt2al.exe")
        Remove-Item -Path $myAlFolder -Recurse -Force -ErrorAction Ignore
        New-Item -Path $myAlFolder -ItemType Directory -ErrorAction Ignore | Out-Null
        Start-Process -FilePath $txt2al -ArgumentList "--source=""$myDeltaFolder"" --target=""$myAlFolder"" --rename --extensionStartId=$startId" -Wait -NoNewWindow -RedirectStandardOutput c:\demo\stdout.txt
    
    } -ArgumentList $myDeltaFolder, $myAlFolder, $startId
}

#<<1CF Helper functions


Log -color Green "Setting up Desktop Experience"

# Enable File Download in IE
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1803" -Value 0
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1803" -Value 0

# Enable Font Download in IE
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1604" -Value 0
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1604" -Value 0

# Do not open Server Manager At Logon
New-ItemProperty -Path HKCU:\Software\Microsoft\ServerManager -Name DoNotOpenServerManagerAtLogon -PropertyType DWORD -Value "0x1" –Force | Out-Null

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

$vsixFileName = (Get-Item "C:\Demo\*.vsix").FullName
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

Log "Creating Desktop Shortcuts"
#AC New-DesktopShortcut -Name "Landing Page" -TargetPath "http://${publicDnsName}" -IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3"
New-DesktopShortcut -Name "Visual Studio Code" -TargetPath "C:\Program Files (x86)\Microsoft VS Code\Code.exe"
#AC New-DesktopShortcut -Name "Web Client" -TargetPath "https://${publicDnsName}/NAV/" -IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3"

Log "Installing Visual C++ Redist"
$vcRedistUrl = "https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x86.exe"
$vcRedistFile = "C:\DOWNLOAD\vcredist_x86.exe"
(New-Object System.Net.WebClient).DownloadFile($vcRedistUrl, $vcRedistFile)
Start-Process $vcRedistFile -argumentList "/q" -wait
    
Log "Installing SQL Native Client"
$sqlncliUrl = "https://download.microsoft.com/download/3/A/6/3A632674-A016-4E31-A675-94BE390EA739/ENU/x64/sqlncli.msi"
$sqlncliFile = "C:\DOWNLOAD\sqlncli.msi"
(New-Object System.Net.WebClient).DownloadFile($sqlncliUrl, $sqlncliFile)
Start-Process "C:\Windows\System32\msiexec.exe" -argumentList "/i $sqlncliFile ADDLOCAL=ALL IACCEPTSQLNCLILICENSETERMS=YES /qn" -wait

<#AC
$winClientFolder = (Get-Item "C:\Program Files (x86)\Microsoft Dynamics NAV\*\RoleTailored Client").FullName
if ($winClientFolder) {

    Log "Installing Visual C++ Redist"
    $vcRedistUrl = "https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x86.exe"
    $vcRedistFile = "C:\DOWNLOAD\vcredist_x86.exe"
    (New-Object System.Net.WebClient).DownloadFile($vcRedistUrl, $vcRedistFile)
    Start-Process $vcRedistFile -argumentList "/q" -wait
    
    Log "Installing SQL Native Client"
    $sqlncliUrl = "https://download.microsoft.com/download/3/A/6/3A632674-A016-4E31-A675-94BE390EA739/ENU/x64/sqlncli.msi"
    $sqlncliFile = "C:\DOWNLOAD\sqlncli.msi"
    (New-Object System.Net.WebClient).DownloadFile($sqlncliUrl, $sqlncliFile)
    Start-Process "C:\Windows\System32\msiexec.exe" -argumentList "/i $sqlncliFile ADDLOCAL=ALL IACCEPTSQLNCLILICENSETERMS=YES /qn" -wait

    Log "Creating Windows Client configuration file"
    $ps = '$customConfigFile = Join-Path (Get-Item ''C:\Program Files\Microsoft Dynamics NAV\*\Service'').FullName "CustomSettings.config"
    [System.IO.File]::ReadAllText($customConfigFile)'
    [xml]$customConfig = docker exec $containerName powershell $ps
    $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value
    $databaseName = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value
    $databaseServer = "$containerName"
    if ($databaseInstance) { $databaseServer += "\$databaseInstance" }

    New-DesktopShortcut -Name "Windows Client" -TargetPath "$WinClientFolder\Microsoft.Dynamics.Nav.Client.exe"
    New-DesktopShortcut -Name "FinSql" -TargetPath "$WinClientFolder\finsql.exe" -Arguments "servername=$databaseServer, Database=$databaseName, ntauthentication=yes"
}
AC#>
#AC New-DesktopShortcut -Name "Container Command Prompt" -TargetPath "CMD.EXE" -IconLocation "C:\Program Files\Docker\docker.exe, 0" -Arguments "/C docker.exe exec -it $containerName cmd"
#AC New-DesktopShortcut -Name "Container PowerShell Prompt" -TargetPath "CMD.EXE" -IconLocation "C:\Program Files\Docker\docker.exe, 0" -Arguments "/C docker.exe exec -it $containerName powershell -noexit c:\run\prompt.ps1"
#AC New-DesktopShortcut -Name "PowerShell ISE" -TargetPath "C:\Windows\system32\WindowsPowerShell\v1.0\powershell_ise.exe" -WorkingDirectory "c:\demo"
#AC New-DesktopShortcut -Name "Command Prompt" -TargetPath "C:\Windows\system32\cmd.exe" -WorkingDirectory "c:\demo"

if ($style -eq "workshop") {
    Log "Patching landing page"
    $s = [System.IO.File]::ReadAllText("C:\DEMO\http\Default.aspx")
    [System.IO.File]::WriteAllText("C:\DEMO\http\Default.aspx", $s.Replace('Microsoft Dynamics NAV \"Tenerife\" Developer Preview','Directions 2017 Workshop VM'))

#>>1CF
$BackupsUrl = "https://www.dropbox.com/s/b2mmn9db4fqry2z/DB_Backups.zip?dl=1"
. C:\demo\HelperFunctions.ps1
$Folder = "C:\DOWNLOAD\Backups"
$Filename = "$Folder\dbBackups.zip"
New-Item $Folder -itemtype directory -ErrorAction ignore | Out-Null
if (!(Test-Path $Filename)) {
    DownloadFile -SourceUrl $BackupsUrl  -destinationFile $Filename
}

[Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.Filesystem") | Out-Null
[System.IO.Compression.ZipFile]::ExtractToDirectory($Filename,$Folder )

Get-ChildItem $Folder -Filter *.bak |%{
    $devDocker= $_.BaseName
    $bakupPath = $_.FullName

    CreateDevServerContainer -devContainerName $devDocker -dbBackup $bakupPath
}

#<<1CF


#AC    docker exec $containerName powershell "Copy-Item -Path 'C:\DEMO\http\Default.aspx' -Destination 'C:\inetpub\wwwroot\http\Default.aspx' -Force"
<#AC
    try {
        $Folder = "C:\DOWNLOAD\VisualStudio2017Enterprise"
        $Filename = "$Folder\vs_enterprise.exe"
        New-Item $Folder -itemtype directory -ErrorAction ignore | Out-Null
        
        if (!(Test-Path $Filename)) {
            Log "Downloading Visual Studio 2017 Enterprise Setup Program"
            $WebClient = New-Object System.Net.WebClient
            $WebClient.DownloadFile("https://aka.ms/vs/15/release/vs_enterprise.exe", $Filename)
        }
        
        Log "Installing Visual Studio 2017 Enterprise"
        $setupParameters = “--quiet --norestart"
        Start-Process -FilePath $Filename -WorkingDirectory $Folder -ArgumentList $setupParameters -Wait -Passthru | Out-Null
        
        Start-Sleep -Seconds 10
    } catch {
        Log -color Red -line ($Error[0].ToString() + " (" + ($Error[0].ScriptStackTrace -split '\r\n')[0] + ")")
    }
   AC#>
}

Log "Cleanup"
Remove-Item "C:\DOWNLOAD\AL-master" -Recurse -Force -ErrorAction Ignore
Remove-Item "C:\DOWNLOAD\VSCode" -Recurse -Force -ErrorAction Ignore
Remove-Item "C:\DOWNLOAD\samples.zip" -Force -ErrorAction Ignore

# Remove Scheduled Task
if (Get-ScheduledTask -TaskName setupDesktop -ErrorAction Ignore) {
    schtasks /DELETE /TN setupDesktop /F | Out-Null
}

#ACStart-Process "http://${publicDnsName}"
#AC Start-Process "http://aka.ms/moderndevtools"

Log -color Green "Desktop setup complete!"
