# Remove Scheduled Task
schtasks /DELETE /TN setupScript /F

function Log([string]$line, [string]$color = "Gray") { ("<font color=""$color"">" + [DateTime]::Now.ToString([System.Globalization.DateTimeFormatInfo]::CurrentInfo.ShortTimePattern.replace(":mm",":mm:ss")) + " $line</font>") | Add-Content -Path "c:\demo\status.txt" }

$imageName = "navdocker.azurecr.io/dynamics-nav:devpreview"

docker login navdocker.azurecr.io -u 7cc3c660-fc3d-41c6-b7dd-dd260148fff7 -p G/7gwmfohn5bacdf4ooPUjpDOwHIxXspLIFrUsGN+sU=
docker pull $imageName

