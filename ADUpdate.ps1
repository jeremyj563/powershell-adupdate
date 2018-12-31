[void][Reflection.Assembly]::LoadFile(([System.IO.Directory]::GetParent($MyInvocation.MyCommand.Path)).FullName+"\log4net.dll");
[log4net.LogManager]::ResetConfiguration();

# EventLog Appender
$EventLogAppender = New-Object log4net.Appender.EventLogAppender(([log4net.Layout.ILayout](New-Object log4net.Layout.PatternLayout('%date %-5level %logger - %message%newline'))))
$EventLogAppender.ApplicationName = "ADUpdate"
$EventLogAppender.ActivateOptions()
[log4net.Config.BasicConfigurator]::Configure($EventLogAppender)

$Log=[log4net.LogManager]::GetLogger("EventLogAppender");

$Log.Info('Info message.');