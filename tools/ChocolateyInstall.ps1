# Purpose: Copy install folder to production Applications folder since the
#          free version of chocolatey doesn't support custom install paths.

# Include variables file
. "$PSScriptRoot\vars.ps1"

# Delete destination folder if it already exists (eg. 'choco upgrade')
if (Test-Path -Path $DestinationDir) {
    Write-Host ("`nRemoving directory: {0}`n" -f $DestinationDir) -ForegroundColor Green
    [System.IO.Directory]::Delete($DestinationDir, $true)
}

# Copy source folder to destination folder
Write-Host ("`nCopying folder: {0} -> {1}`n" -f $SourceDir, $DestinationDir) -ForegroundColor Green
Copy-Item -Path $SourceDir -Destination $DestinationDir -Recurse -Exclude ".chocolateyPending" | Out-Null

# Create ignore files so that chocolatey doesn't shim the binaries
ForEach ($ExeToIgnore in $ExecutablesToIgnore) {
    $null > "$ExeToIgnore.ignore"
}