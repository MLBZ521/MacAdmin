<#

Script Name:  jamf_createSite.ps1
By:  Zack Thompson / Created:  5/11/2018
Version:  1.3.0 / Updated:  6/3/2019 / By:  ZT

Description:  This script will automate the creation of a new Site with the information provided.

#>

[CmdletBinding(DefaultParameterSetName="SingleRun")]
param (
    [Parameter(Mandatory=$true, ParameterSetName="SingleRun", HelpMessage = "Specify prod or dev server instance")][ValidateSet('prod', 'dev', IgnoreCase = $true)][string]$Environment,
    [Parameter(Mandatory=$true, ParameterSetName="SingleRun", HelpMessage = "Specify domain")][ValidateSet('main', 'east', IgnoreCase = $true)][string]$Domain,
    [Parameter(Mandatory=$true, ParameterSetName="SingleRun", HelpMessage = "Provide desired Site name")][string]$SiteName,
    [Parameter(Mandatory=$true, ParameterSetName="SingleRun", HelpMessage = "Provide a Security Group")][string]$NestSecurityGroup,
    [Parameter(Mandatory=$false, ParameterSetName="SingleRun", HelpMessage = "Provide to create a Department")][string]$Department,

    [Parameter(Mandatory=$true, ParameterSetName="csv")][string]$csv
)

Write-Host "jamf_createSite Process:  START"

# ============================================================
# Define Variables
# ============================================================

# Setup instance of the Class
$CreateSite = [PwshJamf]::new($(Get-Credential))
$CreateSite.Headers['Accept'] = "application/xml"
if ( $Environment -eq "prod" ) {
    $CreateSite.Server = "https://prod-jps.company.com:8443"
}
elseif ( $Environment -eq "dev" ) {
    $CreateSite.Server = "https://dev-jps.company.com:8443"
}

# Get the standard group configuration from another previously create group
[xml]$GroupTemplate = $CreateSite.GetAccountByGroupname("Group Template")

# Drop the Site and group IDs
$GroupTemplate.SelectNodes("//site/id | //group/id") | ForEach-Object { $_.ParentNode.RemoveChild($_) } | Out-Null

# ============================================================
# Functions
# ============================================================

Function Confirm {
	$Title = "Continue?";
	$Message = "Please review the configuration and confirm.  Enter ? for more information on the options."
	$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Create the requested Site!";
    $No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Do not create the requested Site!";
    $Quit = New-Object System.Management.Automation.Host.ChoiceDescription "No to &All","Quit";
    $Options = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No,$Quit);
	$script:Confirm = $Host.UI.PromptForChoice($Title,$Message,$Options,0)
}

function SiteCreation {

    # ============================================================
    # Define Variables for current run...

    # Active Directory Domain Dependant Configurations.
    switch ( $Domain ) {
        "main" {
            $SecurityGroup = "EndPntMgmt.Apple ${SiteName}"
            $OU = "DC=Security Groups,DC=contoso,DC=com"
            $LDAPServer = "Constoso Main"
        }
        "east" {
            $SecurityGroup = "${NestSecurityGroup}"
            $OU = "DC=Security Groups,DC=east,DC=contoso,DC=com"
            $LDAPServer = "Constoso East"
        }
    }

    # Edit group and Site names in the group template
    $GroupTemplate.group.name = "${SecurityGroup}"
    $GroupTemplate.group.site.name = "${SiteName}"
    $GroupTemplate.group.ldap_server.name = "${LDAPServer}"

    # Build the computer group payload
    [xml]$configComputerGroup = "<?xml version='1.0' encoding='UTF-8'?>
        <computer_group>
            <name>[Deskside] ${SiteName}</name>
            <is_smart>true</is_smart>
            <site>
                <name>${SiteName}</name>
            </site>
        </computer_group>"

    # Build the mobile device group payload
    [xml]$configMobileGroup = "<?xml version='1.0' encoding='UTF-8'?>
        <mobile_device_group>
            <name>[Deskside] ${SiteName}</name>
            <is_smart>true</is_smart>
            <site>
                <name>${SiteName}</name>
            </site>
        </mobile_device_group>"

    # ============================================================

    # Some Verbosity
    Write-Host "Environment:  ${Environment}"
    Write-Host "LDAPServer:  ${LDAPServer}"
    Write-Host "Site:  ${SiteName}"
    Write-Host "Department:  ${Department}"
    Write-Host "Site/Security Group:  ${SecurityGroup}"
    Write-Host "Nested Security Group:  ${NestSecurityGroup}"
    Write-Host ""

    # Function Confirm
    Confirm

    if ( $Confirm -eq 0 ) {

        # Check if the Security Group already exists.
        try { 
            Get-ADGroup -Identity $SecurityGroup | Out-Null
            Write-Host "Notice:  The Endpoint Management Security Group `'${SecurityGroup}`' already exists!"
        }
        catch {
            # Active Directory Setup
            Write-Host "Creating Endpoint Management Security Group:  ${SecurityGroup}"
            New-ADGroup -Name $SecurityGroup -DisplayName $SecurityGroup -SamAccountName $SecurityGroup -GroupCategory Security -GroupScope Universal -Path "${OU}" -Description "This group manages the ${SiteName} Jamf Site."
        }

        # Check if the $NestSecurityGroup is already a member.
        if ( $NestSecurityGroup -notin $( Get-ADGroupMember -Identity $SecurityGroup | Select-Object Name ) ) {
            Write-Host "Nesting the Securty Group:  ${NestSecurityGroup} into:  ${SecurityGroup}"
            Add-ADGroupMember -Identity $SecurityGroup -Members $NestSecurityGroup
        }
        else {
            Write-Host "Notice:  ${NestSecurityGroup} is already a member of:  ${SecurityGroup}"
        }

        # Create the Site.
        Write-host "Creating Site:  ${SiteName}"
        $CreateSite.CreateSite($SiteName)

        # Create the Jamf Group.
        Write-host "Creating Jamf Pro Management Group:  ${SecurityGroup}  and setting permissions..."
        $CreateSite.CreateAccountGroup($GroupTemplate)

        # Create the Department.
        if ( $null -ne $Department ) {
            Write-host "Creating Department:  ${Department}"
            $CreateSite.CreateDepartment($Department)
        }

        # Create Smart Groups for Computers and Mobile Devices
        Write-host "Creating Computer Group:  [Deskside] ${SiteName}"
        $CreateSite.CreateComputerGroup($configComputerGroup)

        Write-host "Creating Mobile Device Group:  [Deskside] ${SiteName}"
        $CreateSite.CreateMobileDeviceGroup($configMobileGroup)
    }
    elseif ( $Confirm -eq 3 ) {
        Write-Host "Existing process..."
    }
    else {
        Write-Host "Did not create the requested Site:  ${SiteName}"
    }
}

# ============================================================
# Bits Staged...
# ============================================================

If ( $csv.Length -eq 0) {
    # Use command line parameters...
    SiteCreation
}
Else {
    # A CSV was provided...
    $csvContents = Import-Csv "${csv}"

    ForEach ($Site in $csvContents) {
        $Environment = "$(${Site}.Environment)"
        $Domain = "$(${Site}.Domain)"
        $SiteName = "$(${Site}.SiteName)"
        $Department = "$(${Site}.Department)"
        $NestSecurityGroup = "$(${Site}.SecurityGroup)"

        # Active Directory Domain Dependant Configurations.
        switch ( $Domain ) {
            "main" {
                $SecurityGroup = "EndPntMgmt.Apple ${SiteName}"
                $OU = "DC=Security Groups,DC=contoso,DC=com"
                $LDAPServer = "Constoso Main"
            }
            "east" {
                $SecurityGroup = "${NestSecurityGroup}"
                $OU = "DC=Security Groups,DC=east,DC=contoso,DC=com"
                $LDAPServer = "Constoso East"
            }
        }

        SiteCreation
        Write-Host ""
    }
    Write-Host "All provided Sites have been created!"
}

Write-Host "jamf_createSite Process:  COMPLETE"