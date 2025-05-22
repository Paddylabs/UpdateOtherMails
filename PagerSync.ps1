<#
.SYNOPSIS
Updates entra users othermails attribute.
.DESCRIPTION
Updates hybrid entra users othermails attribute with the value from the AD users pager attribute.
.PARAMETER
None
.EXAMPLE
None
.INPUTS
A config.ps1 file with the following variables: $ClientId, $TenantId, $ClientSecret, $GroupName
# Update $Clientsecret to $thumbprint when using a certificate for authentication (which you should be doing in production)
.OUTPUTS
A logfile
.NOTES
Author:        Patrick Horne
Creation Date: 30/01/25
Requires:       Active Directory Module
                Microsoft.Graph.Authentication Module
                Microsoft.Graph.Users Module
Version:        An App registration in Azure AD with the following application permissions:
                - User.ReadWrite.All
                - User.Read.All
                - Mail.Send

Change Log:
    V1.0:         Initial Development
#>

# Functions
function WriteLog {
    param (
        [string]$LogString
    )
        $Stamp      = (Get-Date).ToString("yyyy/MM/dd HH:mm:ss")
        $LogMessage = "$Stamp $LogString"
        Add-Content $LogFile -Value $LogMessage
}
function Import-ModuleIfNeeded {
    param (
        [string]$ModuleName
    )
    if (-not (Get-Module -Name $ModuleName)) {
        if (Get-Module -ListAvailable -Name $ModuleName) {
            Import-Module $ModuleName
            Write-Host "$ModuleName module imported successfully." -ForegroundColor Green
            WriteLog "$ModuleName module imported successfully."
        } else {
            Write-Host "$ModuleName module is not installed on this system." -ForegroundColor Red
            WriteLog "$ModuleName module is not installed on this system."
            exit 1
        }
    } else {
        Write-Host "$ModuleName module is already imported." -ForegroundColor Green
        WriteLog "$ModuleName module is already imported."
    }
}

# Start of script
# Try to create a log file and exit if it fails.
try {
    $logfilePath = "C:\temp\Othermailupdate_Log_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
    $null = $logfile = New-Item -Path $logfilePath -ItemType File -Force -ErrorAction Stop
    WriteLog "Script started at $(Get-Date) under user $($env:USERDOMAIN)\$($env:USERNAME) on system $($env:COMPUTERNAME)"
    Write-Host "Log file created at $logfilePath" -ForegroundColor Green
}
catch {
    Write-Host "Error creating or opening the log file: $_"
    exit 2
}
# Check for configuration file
$configPath = "$PSScriptRoot\config.ps1"
if (Test-Path $configPath) {
    . $configPath  # Load configuration file
} else {
    WriteLog "Configuration file not found at $configPath. Please ensure it exists."
    Write-Host "Configuration file not found at $configPath. Please ensure it exists." -ForegroundColor Red
    exit 1
}
# Import the required modules
Import-ModuleIfNeeded -ModuleName "ActiveDirectory"
Import-ModuleIfNeeded -ModuleName "Microsoft.Graph.Users"

# Connect to Microsoft Graph
Try {
$ClientSecretPass = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
$ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $ClientSecretPass
Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $ClientSecretCredential -ErrorAction Stop
}
Catch {
    Write-Host "Error connecting to mgGraph" -ForegroundColor Red
    WriteLog "Error connecting to mgGraph"
    Exit
}

# Email regex pattern
$EmailRegex = '^[a-zA-Z0-9][\w\.-]*@[a-zA-Z0-9-]+(\.[a-zA-Z]{2,}){1,2}$'

# Get the users from the AD group - You can use Get-ADGroupMember if the group contains less than 5k users
#$users = Get-ADGroupMember -Identity $GroupName | Get-ADUser -Properties pager
$users = Get-ADGroup -Identity $GroupName -properties Members | Select-Object -ExpandProperty Members  | Get-ADUser -Properties pager

Foreach ($User in $users) {
    $ADUsersPager = $user.pager

    # If the AD user does not have the pager attribute populated, skip the user, log it and continue
    If ($ADUsersPager -notmatch $EmailRegex) {
        Write-Host "$($User.UserPrincipalName) does not have a valid email in their AD pager attribute" -ForegroundColor Red
        WriteLog "$($User.UserPrincipalName) does not have a valid email in their AD pager attribute"
        Continue
    }
    # If the AD user does not have a UserPrincipalName attribute populated, skip the user, log it and continue
    If (-not $User.userPrincipalName ) {
        Write-Host "$($User.sAMAccountName) does not have a valid UserPrincipalName" -ForegroundColor Red
        WriteLog "$($User.sAMAccountName) does not have a valid UserPrincipalName"
        Continue
    }

    $MgUser = Get-MgUser -UserId $User.UserPrincipalName  -Property "displayName,userPrincipalName,otherMails,createdDateTime" | Select-Object displayName,userPrincipalName,OtherMails

    # If the entra user does not have the ad pager attribute value in the othermails attribute, add it
    if ($MgUser.otherMails -notcontains $ADUsersPager) {
            try {
                Update-MgUser -UserId $User.UserPrincipalName -OtherMails $ADUsersPager -ErrorAction Stop
                Write-Host "$($User.UserPrincipalName) otherMails updated with $ADUsersPager" -ForegroundColor Green
                WriteLog "$($User.UserPrincipalName) otherMails updated with $ADUsersPager"
            }
            catch {
                Write-Host "Cannot update $($User.UserPrincipalName). User may hold a Privileged Role" -ForegroundColor Red
                WriteLog "Cannot update $($User.UserPrincipalName). User may hold a Privileged Role"
            }
    }
    # If the entra user does have the ad pager attribute value in the othermails attribute, skip the user, log it and continue
    else {
    Write-Host "$($User.UserPrincipalName) already has the pager email in otherMails"
    WriteLog "$($User.UserPrincipalName) already has the pager email in otherMails"
}

}

Disconnect-Graph