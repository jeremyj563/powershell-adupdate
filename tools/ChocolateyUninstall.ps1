# Purpose: Delete the destination folder that was created by ChocolateyInstall.ps1.
#          This is only necessary since the free version of chocolatey doesn't
#          support custom install paths.

# Dot source the variables file
. "$PSScriptRoot\vars.ps1"

# Delete destination folder if it exists
if (Test-Path -Path $DestinationDir) {
    Write-Host ("`nRemoving directory: {0}`n" -f $DestinationDir) -ForegroundColor Green
    [System.IO.Directory]::Delete($DestinationDir, $true)
}