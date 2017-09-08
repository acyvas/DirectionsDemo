function Log([string]$line, [string]$color = "Gray") { ("<font color=""$color"">" + [DateTime]::Now.ToString([System.Globalization.DateTimeFormatInfo]::CurrentInfo.ShortTimePattern.replace(":mm",":mm:ss")) + " $line</font>") | Add-Content -Path "c:\demo\status.txt" }

Log "Setup VM"

. c:\demo\setupDesktop.ps1

# Remove Scheduled Task
if (Get-ScheduledTask -TaskName setupVm -ErrorAction Ignore) {
    schtasks /DELETE /TN setupVm /F | Out-Null
}
