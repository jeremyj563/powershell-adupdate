$AppName = "ADUpdate"
$RepoName = "it-adupdate"
$SourceDir = "C:\ProgramData\chocolatey\lib\{0}" -f $RepoName
$DestinationDir = "C:\Windows\SYSVOL\domain\scripts\{0}" -f $AppName
[String[]] $ExecutablesToIgnore = "$SourceDir\$AppName.exe" #, $SourceDir\<NextExecutableInArray>.exe