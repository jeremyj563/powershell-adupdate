# Global variables
$AppName = "PS-ADUpdate"
$RepoName = "it-powershell-adupdate"
$SourceDir = "C:\ProgramData\chocolatey\lib\$RepoName"
$DestinationDir = "C:\Windows\SYSVOL\domain\scripts\$AppName"

# Close any files that are open on the SMB share
Write-Host ("`nClosing any open SMB files for application: {0}`n" -f $AppName) -ForegroundColor Green
Get-SmbOpenFile | ? Path -m "$AppName" | Close-SmbOpenFile -Force
Write-Host "`n"

# Delete destination folder if it already exists (eg. upgrade or uninstall)
if (Test-Path -Path $DestinationDir) {
    Write-Host ("`nRemoving directory: {0}`n" -f $DestinationDir) -ForegroundColor Green
    [System.IO.Directory]::Delete($DestinationDir, $true)
}