<#

Script Name:  jamf_updateSiteAdminPrivileges.ps1
By:  Zack Thompson / Created:  5/6/2019
Version:  1.0.0 / Updated:  5/6/2019 / By:  ZT

Description:  This script will automate the updating of Site Admin Privileges.

#>

param (
    [Parameter(Mandatory=$true)][ValidateSet('prod', 'dev', IgnoreCase=$true)][string]$Environment
)

Write-Host "jamf_updateSiteAdminPrivileges Process:  START"

# ============================================================
# Setup Environment
# ============================================================

# Setup instance of the Class
$JamfProSession = [PwshJamf]::new($(Get-Credential))
$JamfProSession.Headers['Accept'] = "application/xml"

if ( $Environment -eq "prod" ) {
    $JamfProSession.Server = "https://prod-jps.company.com:8443"
}
elseif ( $Environment -eq "dev" ) {
    $JamfProSession.Server = "https://dev-jps.company.com:8443"
}

# ============================================================
# Bits Staged...
# ============================================================

# Get the standard group configuration and then get the configured privileges.
Write-Host "Getting default permissions..."
[xml]$Group_Template = $JamfProSession.GetAccountByGroupname("Group Template")
$PrivilegesNode_Template = $Group_Template.SelectSingleNode("//privileges")

# Get all accounts.
Write-Host "Getting all accounts..."
$All_Accounts = $JamfProSession.GetAccounts()

Write-Host "Filtering for Site Admin Groups..."
# Get the groups and remove ones we know we're not wanting to edit.
$CheckGroups = $All_Accounts.accounts.groups.group | Where-Object { $_.Name -ne "Testing Group" -and $_.Name -notmatch "Limited" } 

# Get group details and remove Auditor groups.
$SiteAdminGroups = $CheckGroups | ForEach-Object { $JamfProSession.GetAccountByGroupid( $_.id ) } | Where-Object { $_.group.privilege_set -ne "Auditor" -and $_.group.privilege_set -eq "Custom" -and $_.group.access_level -eq "Site Access" }

Write-Host "Updating permissions..."
# Remove the old privileges node and append the new privileges node.
$SiteAdminGroups | ForEach-Object { 
    $_.group.RemoveChild($_.group.privileges)
    $_.DocumentElement.AppendChild($_.ImportNode($PrivilegesNode_Template, $true)) | Out-Null
}

Write-Host "Saving changing back to the JPS..."
# Save back to the JPS.
$SiteAdminGroups | ForEach-Object { $JamfProSession.UpdateAccountByGroupID( $_.group.id, $_ ) }

Write-Host "jamf_updateSiteAdminPrivileges Process:  COMPLETE"
