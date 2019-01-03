# Purpose: Copy install folder to production Applications folder since the
#          free version of chocolatey doesn't support custom install paths.

# Dot source the init file
. "$PSScriptRoot\init.ps1"

# Copy source folder to destination folder
Write-Host ("`nCopying folder: {0} -> {1}`n" -f $SourceDir, $DestinationDir) -ForegroundColor Green
Copy-Item -Path $SourceDir -Destination $DestinationDir -Recurse -Exclude ".chocolateyPending" | Out-Null

# Find log4net.dll within the lib folder and move it to destination folder
$LibDir = "$DestinationDir\lib"
$Log4netDll = Get-ChildItem -Path $LibDir -Filter "log4net.dll" -Recurse -ErrorAction SilentlyContinue -Force
Write-Host ("`nMoving file: {0} -> {1}`n" -f $Log4netDll.ToString(), $DestinationDir) -ForegroundColor Green
$Log4netDll.MoveTo("{0}\log4net.dll" -f $DestinationDir)

# Delete the "lib" folder
Write-Host ("`nRemoving directory: {0}`n" -f $LibDir) -ForegroundColor Green
[System.IO.Directory]::Delete($LibDir, $true)