$AppName = "ADUpdate"
$RepoName = "it-powershell-adupdate"
$SourceDir = "C:\ProgramData\chocolatey\lib\{0}" -f $RepoName
$DestinationDir = "C:\Test\{0}" -f $AppName
#$DestinationDir = "C:\Windows\SYSVOL\domain\scripts\{0}" -f $AppName
[String[]] $ExecutablesToIgnore = @{}#"$SourceDir\$AppName.exe" #, $SourceDir\<NextExecutableInArray>.exe