<#

Script Name:  jamf_createSiteSmartGroups.ps1
By:  Zack Thompson / Created:  7/6/2018
Version:  1.0 / Updated:  7/10/2018 / By:  ZT

Description:  This script will update a device record with information from a CSV.

#>

Write-Host "jamf_create_SiteSmartGroups Process:  START"

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
    $jamfAPIPassword = Get-Content $PSScriptRoot\jamf_UpdateRecord_Creds.txt | ConvertTo-SecureString

$APIcredentials = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $jamfAPIUser, $jamfAPIPassword

# Setup API URLs
$jamfPS="https://jss.company.com:8443"
$getSites="${jamfPS}/JSSResource/sites"
$apiMobileGroup="${jamfPS}/JSSResource/mobiledevicegroups/id/0"
$apiCheckMobileGroup="${jamfPS}/JSSResource/mobiledevicegroups/name"
$apiComputerGroup="${jamfPS}/JSSResource/computergroups/id/0"
$apiCheckComputerGroup="${jamfPS}/JSSResource/computergroups/name"

# ============================================================
# Functions
# ============================================================

function apiDo($uri, $config) {
    Try {
        $Response = Invoke-RestMethod -Uri "${uri}" -Method "POST" -ContentType "application/xml" -Credential $APIcredentials -Body $config -ErrorVariable RestError -ErrorAction SilentlyContinue
        Write-host " -> Success!"
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

function groupCreation($deviceType, $checkURI, $createURI, $SiteName) {

    # ============================================================
    # Define variables for current run...

    [xml]$configSmartGroup = "<?xml version='1.0' encoding='UTF-8'?><${deviceType}_group>
      <name>[Deskside] ${SiteName}</name>
      <is_smart>true</is_smart>
      <site>
        <name>${SiteName}</name>
      </site></${deviceType}_group>"

    # ============================================================

    # Check if the group exists first...
    Try {
        $Response = Invoke-RestMethod -Uri "${checkURI}/%5BDeskside%5D ${SiteName}" -Method "GET" -ContentType "application/xml" -Credential $APIcredentials -ErrorVariable RestError -ErrorAction SilentlyContinue
        Write-Host "A $deviceType Smart Group for [Deskside] ${SiteName} already exists!"
    }
    Catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $statusDescription = $_.Exception.Response.StatusDescription

        If ($statusCode -notcontains "200") {
            Write-host "Creating $deviceType group:  [Deskside] ${SiteName}"
            apiDo "${createURI}" $configSmartGroup
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
Write-Host ""

$objectOf_Sites = Invoke-RestMethod -Uri $getSites -Method Get -Credential $APIcredentials
$SiteList = $objectOf_Sites.sites.site.Name

ForEach ($Site in $SiteList) {
    groupCreation computer $apiCheckComputerGroup $apiComputerGroup $Site
    groupCreation mobile_device $apiCheckMobileGroup $apiMobileGroup $Site
}

Write-Host "Smart Groups for each Site have been created!"
Write-Host "jamf_create_SiteSmartGroups Process:  COMPLETE"
