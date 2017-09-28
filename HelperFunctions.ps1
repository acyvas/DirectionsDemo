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
                 --volume C:\DEMO:C:\DEMO `
                 --volume "${myFolder}:C:\Run\my" `
                 --volume "${programFilesFolder}:C:\navpfiles" `
                 --restart always `
                 --detach `
                 $devImageName
    }else{
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
                 --volume C:\DEMO:C:\DEMO `
                 --volume "${myFolder}:C:\Run\my" `
                 --volume "${programFilesFolder}:C:\navpfiles" `
                 --restart always `
                 --detach `
                 $devImageName
    }

    WaitNavContainerReady $devContainerName

    docker exec -it $devContainerName powershell "copy-item -Path 'C:\Run\*.vsix' -Destination 'C:\Run\My' -force 
    copy-item -Path 'C:\Run\*.cer' -Destination 'C:\Run\My' -force"

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
#    New-DesktopShortcut -Name "$devContainerName Command Prompt" -TargetPath "CMD.EXE" -IconLocation "C:\Program Files\Docker\docker.exe, 0" -Arguments "/C docker.exe exec -it $devContainerName cmd"
    New-DesktopShortcut -Name "$devContainerName PowerShell Prompt" -TargetPath "CMD.EXE" -IconLocation "C:\Program Files\Docker\docker.exe, 0" -Arguments "/C docker.exe exec -it $devContainerName powershell -noexit c:\run\prompt.ps1"

    Write-Host -ForegroundColor Green "Developer server container $devContainerName successfully created"
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

