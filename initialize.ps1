#usage initialize.ps1
param
(
       [string]$ScriptPath = ""
)

function Log([string]$line) { ('<font color="Gray">' + [DateTime]::Now.ToString([System.Globalization.DateTimeFormatInfo]::CurrentInfo.ShortTimePattern.replace(":mm",":mm:ss")) + " $line</font>") | Add-Content -Path "c:\demo\status.txt" }

function DownloadFile([string]$sourceUrl, [string]$destinationFile)
{
    Log("Downloading '$sourceUrl' to '$destinationFile'")
    Remove-Item -Path $destinationFile -Force -ErrorAction Ignore
    Invoke-WebRequest $sourceUrl -OutFile $destinationFile
}

if (Test-Path -Path "c:\DEMO\Status.txt" -PathType Leaf) {
    Log "VM already initialized."
    exit
}

New-Item -Path "C:\DEMO" -ItemType Directory
Set-ExecutionPolicy -ExecutionPolicy unrestricted -Force

Log("Starting initialization")
Log("ScriptPath: $ScriptPath")

$baseUrl = $ScriptPath.SubString(0,$ScriptPath.LastIndexOf('/')+1)
DownloadFile("${scriptPath}initialize.ps1", "c:\demo\initialize.ps1")
