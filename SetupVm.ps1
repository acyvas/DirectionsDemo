function Log([string]$line, [string]$color = "Gray") { ("<font color=""$color"">" + [DateTime]::Now.ToString([System.Globalization.DateTimeFormatInfo]::CurrentInfo.ShortTimePattern.replace(":mm",":mm:ss")) + " $line</font>") | Add-Content -Path "c:\demo\status.txt" }

Log "Setup VM"

# Remove Scheduled Task
if (Get-ScheduledTask -TaskName setupVm -ErrorAction Ignore) {
    schtasks /DELETE /TN setupVm /F | Out-Null
}
if (Get-ScheduledTask -TaskName setupDesktop -ErrorAction Ignore) {
    schtasks /DELETE /TN setupDesktop /F | Out-Null
}

Log "Register task"
$onceAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "c:\demo\setupdesktop.ps1"
$onceTrigger = New-ScheduledTaskTrigger -Once
Register-ScheduledTask -TaskName "SetupDesktop" `
                       -Action $onceAction `
                       -Trigger $onceTrigger `
                       -RunLevel Highest `
                       -User vmadmin `
                       -Password Pepsimax4ever | Out-Null

Log "Start task"
Start-ScheduledTask -TaskName SetupDesktop
log "done"