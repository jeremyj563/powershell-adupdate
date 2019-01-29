<#   
.SYNOPSIS
Gather user/system data from the local machine then update the corresponding "ds_computer" ldap class instance via the local WMI Active Directory provider
    
.DESCRIPTION 
Uses the Get-ItemProperty and Get-WmiObject Cmdlets to gather data from the Registry and WMI respectively. Calls the ManagementObject.Put(PutOptions) overload on the modified record to update the instance.

.PARAMETER SetLastLogonExtensionAttribute
[switch] When using this switch the 'extensionAttribute1' attribute will be set the current date/time. This should only be used when running the script at logon.

.NOTES   
Name: Set-CustomLdapComputerClassData.ps1
Author: Jeremy Johnson
Date Created: 1-3-2019
Date Updated: 1-28-2019
Site: https://www.jmjohnson85.com
Version: 1.0.2

.LINK
https://www.jmjohnson85.com

.EXAMPLE
    .\Set-CustomLdapComputerClassData.ps1

.EXAMPLE
    .\Set-CustomLdapComputerClassData.ps1 -SetLastLogonExtensionAttribute
#>

#region Script Parameters

param (
    [switch]$SetLastLogonExtensionAttribute
)

#endregion

#region Private Variables

$_scriptName = "ADUpdate"

#endregion

#region Logging

function Initialize-Log4Net {
    param (
        [string]$libraryPath
    )

    # Load the log4net assembly from log4net.dll
    try {
        # UnsafeLoadFrom() allows loading the assembly from a UNC path
        [System.Reflection.Assembly]::UnsafeLoadFrom($libraryPath) | Out-Null
        [log4net.LogManager]::ResetConfiguration()
    }
    catch {
        Exit-Script -exitCode 99 -message ("EXCEPTION in {0}: {1}" -f $MyInvocation.MyCommand, $PSItem.Exception.Message) -errorWritingToLog $true
    }
}

function Get-EventLogger {
    param (
        [string]$applicationName
    )

    # Configure log4net event logger
    $PatternLayoutFormat = '%date %-5level %logger - %message%newline'
    $PatternLayout = [log4net.Layout.PatternLayout]::New($PatternLayoutFormat)
    $EventLogAppender = [log4net.Appender.EventLogAppender]::New($PatternLayout)
    $EventLogAppender.ApplicationName = $applicationName
    $EventLogAppender.ActivateOptions()
    [log4net.Config.BasicConfigurator]::Configure($EventLogAppender)
    
    return [log4net.LogManager]::GetLogger("EventLogAppender");
}

enum LogEvent {
    Debug
    Error
    Fatal
    Info
    Warn
}

function Exit-Script {
    param (
        [int]$exitCode,
        [string]$message,
        [LogEvent]$logEvent = [LogEvent]::Error,
        [bool]$errorWritingToLog = $false
    )

    if ($exitCode = 0) {$message = "completed successfully"}

    $message = ("[{0}] {1} - exit code: {2}" -f $_scriptName, $message, $exitCode)
    if ($errorWritingToLog) {
        Write-Host($message)
    } else {
        Write-Log -message $message -logEvent $logEvent
    }

    exit $exitCode
}

function Write-Log {
    param (
        [string]$message,
        [LogEvent]$logEvent = [LogEvent]::Error,
        [bool]$logToLog4Net = $true,
        [bool]$logToConsole = $false
    )

    $message = ("{0} | {1}@{2}" -f $message, $env:USERNAME, $env:COMPUTERNAME)

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
            Exit-Script -exitCode 99 -message ("EXCEPTION in {0}: {1}" -f $MyInvocation.MyCommand, $PSItem.Exception.Message) -errorWritingToLog $true
        }
    }

    if ($logToConsole) {
        Write-Host -Object $message
    }
}

#endregion

#region Create Updated Object

function New-UpdatedComputerObject {
    # Query the registry for the last logged on user
    [string]$userName = Get-LastLoggedOnUserName
    # Query AD (through WMI) for the user's display name
    [string]$displayName = Get-UserDisplayName -userName $userName
    # Query WMI for a list of network addresses
    [string[]]$networkAddresses = Get-NetworkAddresses

    # Only build the updated Active Directory record if all fields came back with data
    if ($userName -ne "" -and $displayName -ne "" -and $null -ne $networkAddresses) {
        $updatedRecord = [PSCustomObject]@{
            DS_uid = @( $userName )
            DS_displayName = $displayName
            DS_networkAddress = $networkAddresses
        }

        if ($SetLastLogonExtensionAttribute) {
            # The switch parameter is on so add the current date/time to the updated record
            $currentDateTime = Get-Date
            $updatedRecord | Add-Member -Name "DS_extensionAttribute1" -MemberType NoteProperty -Value $currentDateTime
        }

        return $updatedRecord
    }

    return $null
}

function Get-LastLoggedOnUserName {
    # This data comes from the registry
    try {
        $regEntry = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI -Name "LastLoggedOnSAMUser"
        if ($null -ne $regEntry) {
            $lastLoggedOnSAMUserData = $regEntry.LastLoggedOnSAMUser.Split('\')
            $lastLoggedOnUserName = [Linq.Enumerable]::Last($lastLoggedOnSAMUserData)

            return $lastLoggedOnUserName
        }
    }
    catch {
        Write-Log -message ("EXCEPTION in {0}: {1}" -f $MyInvocation.MyCommand, $PSItem.Exception.Message)
    }

    return $null
}

function Get-UserDisplayName {
    param (
        [string]$userName
    )

    # This data comes from AD through the local WMI provider
    try {
        $ds_user = Get-WmiObject -Namespace "ROOT\directory\LDAP" -Class "ds_user" -Filter "DS_sAMAccountName='$userName'"
        if ($null -ne $ds_user) {
            $userDisplayName = $ds_user.DS_displayName
            
            return $userDisplayName
        }   
    }
    catch {
        Write-Log -message ("EXCEPTION in {0}: {1}" -f $MyInvocation.MyCommand, $PSItem.Exception.Message)
    }

    return $null
}

function Get-NetworkAddresses {
    # This data comes from WMI
    try {
        $networkAdapterConfiguration = Get-WmiObject -Class "Win32_NetworkAdapterConfiguration" -Filter "DNSDomain LIKE '$env:USERDOMAIN%'"
        if ($null -ne $networkAdapterConfiguration) {
            $ipAddress = [Linq.Enumerable]::First($networkAdapterConfiguration.IPAddress)
            $macAddress = $networkAdapterConfiguration.MACAddress
            [string[]]$networkAddresses = $ipAddress, $macAddress
            
            return $networkAddresses
        }
    }
    catch {
        Write-Log -message ("EXCEPTION in {0}: {1}" -f $MyInvocation.MyCommand, $PSItem.Exception.Message)
    }

    return $null
}

#endregion

#region Set Updated Object

function Set-UpdatedComputerObject {
    param (
        [PSCustomObject]$updatedRecord
    )

    try {
         # Get an array of the names of the properties to be updated
        [string[]]$properties = $updatedRecord.PSObject.Properties | ForEach-Object {$PSItem.Name}

        # Create the connection/update context using these properties
        $context = [System.Management.ManagementNamedValueCollection]::New()
        $context.Add("__PUT_EXT_PROPERTIES", $properties)
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
    catch {
        Write-Log -message ("EXCEPTION in {0}: {1}" -f $MyInvocation.MyCommand, $PSItem.Exception.Message)
    }

    return $null
}

#endregion

#region Main

Initialize-Log4Net -libraryPath (Join-Path -Path $PSScriptRoot -ChildPath "log4net.dll")

# Only run the update if running as "NT AUTHORITY\SYSTEM"
if ([System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem) {
    $updatedRecord = New-UpdatedComputerObject
    if ($null -ne $updatedRecord) {
        if (Set-UpdatedComputerObject -updatedRecord $updatedRecord) {
            Write-Log -message "Update successful" -logEvent Info
        } else {
            Exit-Script -exitCode 3 -message "Failed to update 'ds_computer' instance" -logEvent Fatal
        }
    } else {
        Exit-Script -exitCode 2 -message "Failed to build updated 'ds_computer' data" -logEvent Fatal
    }
} else {
    Exit-Script -exitCode 1 -message "Not running as ""NT AUTHORITY\SYSTEM""" -logEvent Fatal
}

#endregion