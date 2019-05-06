<#

Script Name:  jamf_createSite.ps1
By:  Zack Thompson / Created:  5/11/2018
Version:  1.1.0 / Updated:  2/7/2019 / By:  ZT

Description:  This script will automate the creation of a new Site as much as possible with the information provided.

#>

param (
    [Parameter][string]$csv,
    [string]$SiteName,
    [string]$Department,
    [string]$NestSecurityGroup
 )

Write-Host "jamf_createSite Process:  START"

# ============================================================
# Define Variables
# ============================================================

# Setup instance of the Class
$CreateSite = [PwshJamf]::new($(Get-Credential))
$CreateSite.Server = "https://jss.company.com:8443"
$CreateSite.Headers['Accept'] = "application/xml"

# Active Directory OU Location for Endpoint Management Security Group
$OU = "DC=Security Groups,DC=ad,DC=contoso,DC=com"

# Get the standard group configuration from another previously create group
[xml]$GroupTemplate = $CreateSite.GetAccountByGroupname("Group Template")

# Drop the Site and group IDs
$GroupTemplate.SelectNodes("//site/id | //group/id") | ForEach-Object { $_.ParentNode.RemoveChild($_) } | Out-Null

# ============================================================
# Functions
# ============================================================

function SiteCreation {

    # ============================================================
    # Define Variables for current run...

    # AD Security Group Name
    $SecurityGroup = "EndPntMgmt.Apple ${SiteName}"

    # Edit group and Site names in the group template
    $GroupTemplate.group.name = "EndPntMgmt.Apple ${SiteName}"
    $GroupTemplate.group.site.name = "${SiteName}"

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
    Write-Host "Site:  ${SiteName}"
    Write-Host "Department:  ${Department}"
    Write-Host "Nested Security Group:  ${NestSecurityGroup}"
    Write-Host ""

    # Active Directory Setup
    Write-Host "Creating Endpoint Management Security Group:  ${SecurityGroup}"
    New-ADGroup -Name $SecurityGroup -DisplayName $SecurityGroup -SamAccountName $SecurityGroup -GroupCategory Security -GroupScope Universal -Path "${OU}" -Description "This group manages the ${SiteName} Jamf Site." #-Credential

    Write-Host "Nesting the Securty Group:  ${NestSecurityGroup} into:  ${SecurityGroup}"
    Add-ADGroupMember -Identity $SecurityGroup -Members $NestSecurityGroup

    # Jamf Setup
    Write-host "Creating Site:  ${SiteName}"
    $CreateSite.CreateSite($SiteName)

    Write-host "Creating Jamf Pro Management Group:  ${SecurityGroup}  and setting permissions..."
    $CreateSite.CreateAccountGroup($GroupTemplate)

    Write-host "Creating Department:  ${Department}"
    $CreateSite.CreateDepartment($Department)

    Write-host "Creating Category:  Testing - ${SiteName}"
    $CreateSite.CreateCategory("Testing - ${SiteName}")

    Write-host "Creating Computer Group:  [Deskside] ${SiteName}"
    $CreateSite.CreateComputerGroup($configComputerGroup)

    Write-host "Creating Mobile Device Group:  [Deskside] ${SiteName}"
    $CreateSite.CreateMobileDeviceGroup($configMobileGroup)
}

# ============================================================
# Bits Staged...
# ============================================================

If ( $csv.Length -eq 0) {
    # Use command line parameters...
    siteCreation
}
Else {
    # A CSV was provided...
    $csvContents = Import-Csv "${csv}"

    ForEach ($Site in $csvContents) {
        $SiteName = "$(${Site}.SiteName)"
        $Department = "$(${Site}.Department)"
        $NestSecurityGroup = "$(${Site}.SecurityGroup)"

        siteCreation
        Write-Host ""
    }
    Write-Host "All provided Sites have been created!"
}

Write-Host "jamf_createSite Process:  COMPLETE"