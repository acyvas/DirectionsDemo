function Log([string]$line, [string]$color = "Gray") { ("<font color=""$color"">" + [DateTime]::Now.ToString([System.Globalization.DateTimeFormatInfo]::CurrentInfo.ShortTimePattern.replace(":mm",":mm:ss")) + " $line</font>") | Add-Content -Path "c:\demo\status.txt"; Write-Host -ForegroundColor $color $line }

. (Join-Path $PSScriptRoot "settings.ps1")

function DownloadFile([string]$sourceUrl, [string]$destinationFile)
{
    Log("Downloading $destinationFile")
    Remove-Item -Path $destinationFile -Force -ErrorAction Ignore
    (New-Object System.Net.WebClient).DownloadFile($sourceUrl, $destinationFile)
}
<#>>1CF helper functions
$helperurl = "https://www.dropbox.com/s/h9tksgc68qcacvw/HelperFunctions.ps1?dl=1"
DownloadFile -SourceUrl $helperurl  -destinationFile C:\DEMO\HelperFunctions.ps1
Import-Module C:\DEMO\HelperFunctions.ps1
#<<1CF Helper functions #>


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

<#
>>1CF
$BackupsUrl = "https://www.dropbox.com/s/b2mmn9db4fqry2z/DB_Backups.zip?dl=1"

$Folder = "C:\DOWNLOAD\Backups"
$Filename = "$Folder\dbBackups.zip"
New-Item $Folder -itemtype directory -ErrorAction ignore | Out-Null
if (!(Test-Path $Filename)) {
    DownloadFile -SourceUrl $BackupsUrl  -destinationFile $Filename
}

[Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.Filesystem") | Out-Null
[System.IO.Compression.ZipFile]::ExtractToDirectory($Filename,$Folder )

#$ServersToCreate = Import-Csv "$Folder\servers.csv"
$s1= "navdemo1"
$b1= "C:\DOWNLOAD\Backups\NAV_Demo1.bak"
CreateDevServerContainer -devContainerName $s1 -dbBackup C:\DOWNLOAD\Backups\NAV_Demo1.bak

$s2= "navdemo2"
$b2= "C:\DOWNLOAD\Backups\NAV_Demo2.bak"
CreateDevServerContainer -devContainerName $s2 -dbBackup C:\DOWNLOAD\Backups\NAV_Demo2.bak
#>

<#
$ServersToCreate |%{
    $d = $_.Server
    $bakupPath = "$Folder\$($_.Backup)"
    CreateDevServerContainer -devContainerName $d -dbBackup $bakupPath
}
#>
<# 1CF Evil Basename
Get-ChildItem $Folder -Filter *.bak |%{
    $devDocker= $_.BaseName
    $bakupPath = $_.FullName

    CreateDevServerContainer -devContainerName $devDocker -dbBackup $bakupPath
}
#>



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
