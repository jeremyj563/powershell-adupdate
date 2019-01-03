$_scriptName = ([IO.FileInfo]$MyInvocation.MyCommand.Definition).BaseName

#region Logging

Function Initialize-Log4Net {
    param (
        [string]$libraryPath
    )
    [void][Reflection.Assembly]::LoadFile($libraryPath)
    [log4net.LogManager]::ResetConfiguration()
}

Function Get-EventLogger {
    param (
        [string]$applicationName
    )
    # Configure log4net event logger
    $PatternLayout = '%date %-5level %logger - %message%newline'
    $EventLogAppender = New-Object log4net.Appender.EventLogAppender(([log4net.Layout.ILayout](New-Object log4net.Layout.PatternLayout($PatternLayout))))
    $EventLogAppender.ApplicationName = $applicationName
    $EventLogAppender.ActivateOptions()
    [log4net.Config.BasicConfigurator]::Configure($EventLogAppender)
    
    return [log4net.LogManager]::GetLogger("EventLogAppender");
}

Enum LogEvent {
    Debug
    Error
    Fatal
    Info
    Warn
}

Function Exit-Script {
    param (
        [int]$exitCode,
        [string]$message,
        [LogEvent]$logEvent,
        [bool]$errorWritingToLog = $false
    )

    if ($exitCode = 0) {$message = "completed successfully"}

    $message = ("[{0}] {1} - exit code: {2}" -f $_scriptName, $message, $exitCode)
    if ($errorWritingToLog) {
        Write-Host($message)
    } else {
        Write-EventLog -message $message -logEvent $logEvent
    }

    exit $exitCode
}

Function Write-EventLog {
    param (
        [string]$message,
        [LogEvent]$logEvent,
        [bool]$logToLog4Net = $true,
        [bool]$logToConsole = $false
    )

    $message = ("{0} | {1} @ {2}" -f $message, $env:USERNAME, $env:COMPUTERNAME)

    if ($logToLog4Net) {
        $Logger = Get-EventLogger -applicationName $_scriptName

        try {
            switch ($logEvent) {
                Debug {$Logger.DebugFormat($message)}
                Error {$Logger.ErrorFormat($message)}
                Fatal {$Logger.FatalFormat($message)}
                Info {$Logger.InfoFormat($message)}
                Warn {$Logger.WarnFormat($message)}
            }
        }
        catch {
            Exit-Script -exitCode 99, -message ("EXCEPTION in {0}: {1}" -f $MyInvocation.MyCommand, $PSItem.Exception.Message) -errorWritingToLog $true
        }
    }
}

#endregion

#region Create Updated Object

Function New-UpdatedComputerObject {
    # Query the registry for the last logged on user
    $userName = Get-LastLoggedOnUserName
    # Query AD (through WMI) for the user's display name
    $displayName = Get-UserDisplayName -userName $userName
    # Query WMI for a list of network addresses
    $networkAddresses = Get-NetworkAddresses

    if ($null -ne $userName -and $null -ne $displayName -and $null -ne $networkAddresses) {
        # Build the updated Active Directory computer attribute
        $props = @{
            DS_uid = @( $userName )
            DS_displayName = $displayName
            DS_networkAddress = $networkAddresses
        }
        $updatedRecord = New-Object -TypeName psobject -Property $props
        return $updatedRecord
    }

    return $null
}

Function Get-LastLoggedOnUserName {
    # This data comes from the registry
    $regEntry = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI -Name "LastLoggedOnSAMUser"
    $lastLoggedOnSAMUserData = $regEntry.LastLoggedOnSAMUser.Split('\')
    $userName = [Linq.Enumerable]::Last($lastLoggedOnSAMUserData)
    return $userName
}

Function Get-UserDisplayName {
    param (
        [string]$userName
    )
    # This data comes from AD through the local WMI provider
    $ds_user = Get-WmiObject -Namespace "ROOT\directory\LDAP" -Class "ds_user" -Filter "DS_sAMAccountName='$userName'"
    if ($null -ne $ds_user) {
        $displayName = if ($null -ne $ds_user.DS_displayName) {$ds_user.DS_displayName} else {[string]::Empty}
        return $displayName
    }
    return $null
}

Function Get-NetworkAddresses {
    # This data comes from WMI
    $networkAdapterConfigurations = Get-WmiObject -Class "Win32_NetworkAdapterConfiguration" | Where-Object { $null -ne $PSItem.IPAddress }
    $networkAddresses = $networkAdapterConfigurations | ForEach-Object { $PSItem.IPAddress }
    return $networkAddresses
}

#endregion

#region Set Updated Object

Function Set-UpdatedComputerObject {
    param (
        [psobject]$updatedRecord
    )
    # Get an array of all the properties to be updated
    [string[]]$props = $updatedRecord.PSObject.Properties | ForEach-Object {$PSItem.Name}

    # Create the connection/update context using these properties
    $context = [System.Management.ManagementNamedValueCollection]::New()
    $context.Add("__PUT_EXT_PROPERTIES", $props)
    $context.Add("__PUT_EXTENSIONS", $true)
    $context.Add("__PUT_EXT_CLIENT_REQUEST", $true)

    # Build the context into the options object
    $putOptions = [System.Management.PutOptions]::New()
    $putOptions.Context = $context
    $putOptions.UseAmendedQualifiers = $false
    $putOptions.Type = [System.Management.PutType]::UpdateOnly

    # Retrieve the "ds_computer" class instance from WMI
    $managementObject = Get-WmiObject -Namespace "root\directory\ldap" -Class "ds_computer" -Filter "DS_name='$env:COMPUTERNAME'"
    
    # Set the objects properties to the updated values
    $updatedRecord.PSObject.Properties | ForEach-Object {$managementObject.SetPropertyValue($PSItem.Name, $PSItem.Value)}
    
    return $managementObject.Put($putOptions)
}

#endregion

#region Main
Initialize-Log4Net -libraryPath "$PSScriptRoot\log4net.dll"

# Only run the update if running as "NT AUTHORITY\SYSTEM"
if ([System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem -eq $false) {
    $updatedRecord = New-UpdatedComputerObject
    if ($null -ne $updatedRecord) {
        if (Set-UpdatedComputerObject -updatedRecord $updatedRecord) {
            Write-EventLog -message "Update successful" -logEvent Info
        } else {
            Exit-Script -exitCode 3 -message "Failed to update computer attribute"
        }
    } else {
        Exit-Script -exitCode 2 -message "Failed to build updated computer attribute"
    }
} else {
    Exit-Script -exitCode 1 -message "Not running as ""NT AUTHORITY\SYSTEM""" -logEvent [LogEvent]::Fatal
}

#endregion