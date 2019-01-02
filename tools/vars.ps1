$AppName = "ADUpdate"
$RepoName = "it-powershell-adupdate"
$SourceDir = "C:\ProgramData\chocolatey\lib\$RepoName"
$DestinationDir = "C:\Test\$AppName"
#$DestinationDir = "C:\Windows\SYSVOL\domain\scripts\$AppName"

$LibDir = "$DestinationDir\lib"
$Log4netDll = Get-ChildItem -Path $LibDir -Filter "log4net.dll" -Recurse -ErrorAction SilentlyContinue -Force