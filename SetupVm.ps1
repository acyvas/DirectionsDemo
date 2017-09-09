function Log([string]$line, [string]$color = "Gray") { ("<font color=""$color"">" + [DateTime]::Now.ToString([System.Globalization.DateTimeFormatInfo]::CurrentInfo.ShortTimePattern.replace(":mm",":mm:ss")) + " $line</font>") | Add-Content -Path "c:\demo\status.txt" }

Log "Setup VM"

. (Join-Path $PSScriptRoot "settings.ps1")

# Remove Scheduled Tasks
if (Get-ScheduledTask -TaskName setupVm -ErrorAction Ignore) {
    schtasks /DELETE /TN setupVm /F | Out-Null
}
if (Get-ScheduledTask -TaskName setupDesktop -ErrorAction Ignore) {
    schtasks /DELETE /TN setupDesktop /F | Out-Null
}

# Re-register with username+password and start now

Log "Launch Desktop Setup"
$onceAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "c:\demo\setupdesktop.ps1"
Register-ScheduledTask -TaskName "SetupDesktop" `
                       -Action $onceAction `
                       -RunLevel Highest `
                       -User $vmAdminUsername `
                       -Password $adminPassword | Out-Null
Start-ScheduledTask -TaskName SetupDesktop
