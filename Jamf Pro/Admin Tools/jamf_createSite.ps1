<#

Script Name:  jamf_createSite.ps1
By:  Zack Thompson / Created:  5/11/2018
Version:  0.1 / Updated:  5/11/2018 / By:  ZT

Description:  This script will basically update an EA to the value of the computers Site membership.

#>

param (
    [Parameter][string]$csv,
    [Parameter][string]$Site,
    [Parameter][string]$Department,
    [Parameter][string]$NestSecurityGroup
    #[Parameter(Mandatory=$true)][string]$,
 )

Write-Host "jamf_createSite Process:  START"

# ============================================================
# Define Variables
# ============================================================

# Setup Credentials
$jamfAPIUser = ""
# Define Password from within the script.
    # $jamfAPIPassword = ConvertTo-SecureString -String 'SecurePassPhrase' -AsPlainText -Force
# Create an encrypted password file.
    # $exportPassPhrase = 'SecurePassPhrase' | ConvertTo-Securestring -AsPlainText -Force
    # $exportPassPhrase | ConvertFrom-SecureString | Out-File $PSScriptRoot\Cred.txt
# Read in encrypted password.
    $jamfAPIPassword = Get-Content $PSScriptRoot\jamf_assignSiteEA_Creds.txt | ConvertTo-SecureString
$APIcredentials = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $jamfAPIUser, $jamfAPIPassword

# Setup API URLs
$jamfPS="https://jss.company.com:8443"
$apiSite="${jamfPS}/JSSResource/sites/name"
$apiGroup="${jamfPS}/JSSResource/accounts/groupname"
$apiDepartment="${jamfPS}/JSSResource/departments/name"
$apiCategory="${jamfPS}/JSSResource/categories/name"
$apiComputerGroup="${jamfPS}/JSSResource/computergroups/name"
$apiMobileGroup="${jamfPS}/JSSResource/mobiledevicegroups/name"
$apiPolicy="${jamfPS}/JSSResource/Policies/name"

# Active Directory Details
$OU = ""
$SecurityGroup = "EndPntMgmt.Apple ${Site}"

# Configuration XML
# %5BDeskside%5D%20uto

# ============================================================
# Functions
# ============================================================

function apiDo($uri, $method, $config) {
    Try {
        $Response = Invoke-RestMethod -Uri "${uri}" -Method $method -Credential $APIcredentials -Body $config -ErrorVariable RestError -ErrorAction SilentlyContinue
    }
    Catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $statusDescription = $_.Exception.Response.StatusDescription

        If ($statusCode -notcontains "200") {
            Write-host " -> Failed!"
            Write-Host "  --> Response:  ${statusCode}/${statusDescription}: $($RestError.Message | ForEach { $_.Split(":")[1];} | ForEach { $_.Split([Environment]::NewLine)[0];})"
        }
    }
}

# ============================================================
# Bits Staged...
# ============================================================

# Verify credentials that were provided by doing an API call and checking the result to verify permissions.
Write-Host "Verifying API credentials..."
Try {
    $Response = Invoke-RestMethod -Uri "${jamfPS}/JSSResource/jssuser" -Method Get -Credential $APIcredentials -ErrorVariable RestError -ErrorAction SilentlyContinue
}
Catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $statusDescription = $_.Exception.Response.StatusDescription

    If ($statusCode -notcontains "200") {
        Write-Host "ERROR:  Invalid Credentials or permissions."
        Write-Host "Response:  ${statusCode}/${statusDescription}"
        Write-Host "jamf_assignSiteEA Process:  FAILED"
        Exit
    }
}

Write-Host "API Credentials Valid -- continuing..."


# Jamf Setup

Write-host "Creating Site:  ${Site}"
apiDo "${apiSite}/${Site}" "Post"

Write-host "Creating Management Group:  ${SecurityGroup}"
apiDo "${$apiGroup}/${SecurityGroup}" "Post" $configSecurityGroup

Write-host "Configuring permissions..."
apiDo "${$apiGroup}/${SecurityGroup}" "Put"

Write-host "Creating Department:  ${Department}"
apiDo "${apiDepartment}/${Department}" "Post"

Write-host "Creating Category:  ${Site}"
apiDo "${apiCategory}/Testing - ${Department}" "Post"

Write-host "Creating Computer Group:  [Deskside] ${Site}"
apiDo "${apiComputerGroup}/[Deskside] ${Site}" "Post"

Write-host "Configuring Computer Smart Group..."
apiDo "${apiComputerGroup}/[Deskside] ${Site}" "Put" $configComputerGroup

Write-host "Creating Mobile Device Group:  [Deskside] ${Site}"
apiDo "${apiMobileGroup}/[Deskside] ${Site}" "Post"

Write-host "Configuring Mobile Device Smart Group..."
apiDo "${apiMobileGroup}/[Deskside] ${Site}" "Put" $configMobileGroup

Write-host "Creating Policy:  Department Loading Policy - ${Department}"
apiDo "${apiPolicy}/Department Loading Policy - ${Department}" "Post"

Write-host "Configuring Mobile Device Smart Group..."
apiDo "${apiPolicy}/Department Loading Policy - ${Department}" "Put" $configPolicy

Write-Host "jamf_createSite Process:  COMPLETE"