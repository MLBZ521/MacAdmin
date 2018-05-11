<#

Script Name:  jamf_MoveSites.ps1
By:  Zack Thompson / Created:  4/18/2018
Version:  1.0 / Updated:  4/18/2018 / By:  ZT

Description:  This script will move a device record between Sites given information from a CSV.

#>

Write-Host "jamf_MoveSites Process:  START"

# ============================================================
# Define Variables
# ============================================================

# Setup Credentials
$jamfAPIUser = ""
# Define Password from within the script.
     $jamfAPIPassword = ConvertTo-SecureString -String 'SecurePassPhrase' -AsPlainText -Force
# Create an encrypted password file.
    $exportPassPhrase = 'SecurePassPhrase' | ConvertTo-Securestring -AsPlainText -Force
    $exportPassPhrase | ConvertFrom-SecureString | Out-File $PSScriptRoot\Cred.txt
# Read in encrypted password.
    $jamfAPIPassword = Get-Content $PSScriptRoot\jamf_MoveSites_Creds.txt | ConvertTo-SecureString

$APIcredentials = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $jamfAPIUser, $jamfAPIPassword

# Setup API URLs
$jamfPS="https://jss.company.com:8443"
$getSites="${jamfPS}/JSSResource/sites"
$getComputers="${jamfPS}/JSSResource/computers"
$getComputer="${jamfPS}/JSSResource/computers/id"
$getMobileDevices="${jamfPS}/JSSResource/mobiledevices"
$getMobileDevice="${jamfPS}/JSSResource/mobiledevices/id"

# Import the CSV File with the information we want to update.
$csvComputers = Import-Csv "\path\to\file\MoveComputers.csv"
$csvMobileDevices = Import-Csv "\path\to\file\MoveMobileDevices.csv"

# ============================================================
# Functions
# ============================================================

function updateRecord($deviceType, $urlALL, $urlID, $csvValues, $columnName) {

    Write-Host "Pulling data for each individual ${deviceType} record..."
    # Get the old values from report.
    $IDs = $csvValues | Select-Object "${columnName}" -ExpandProperty "${columnName}"

    ForEach ( $ID in $IDs ) {
        # Get Computer's General Section
        $objectOf_deviceGeneral = Invoke-RestMethod -Uri "${urlID}/${ID}/subset/General" -Method Get -Credential $APIcredentials

        # Get the values for the properties we're looking to check
        $currentSite = $objectOf_deviceGeneral.${deviceType}.general.site.name

        # Compare the values to what we do want them to be
        If ( ( "${currentSite}" -ne "site1" ) -and ( "${currentSite}" -ne "site2" ) ) {
            Write-host "${deviceType} ID:  ${ID} is a member of ${currentSite}"
            
            [xml]$upload_deviceEA = "<?xml version='1.0' encoding='UTF-8'?><${deviceType}><general><site><name>newSite</name></site></general></${deviceType}>"
            
            Try {
                $Response = Invoke-RestMethod -Uri "${urlID}/${ID}" -Method Put -Credential $APIcredentials -Body $upload_deviceEA -ErrorVariable RestError -ErrorAction SilentlyContinue
            }
            Catch {
                $statusCode = $_.Exception.Response.StatusCode.value__
                $statusDescription = $_.Exception.Response.StatusDescription

                If ($statusCode -notcontains "200") {
                    Write-host "Failed to assign site for ${deviceType} ID:  ${ID}..."
                    Write-Host "Response:  ${statusCode}/${statusDescription}"
                }
            }
        }
    }
    Write-Host "All ${deviceType} records have been processed."
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
        Write-Host "jamf_MoveSites Process:  FAILED"
        Exit
    }
}

Write-Host "API Credentials Valid -- continuing..."

# Call Update function for each device type
updateRecord computer $getComputers $getComputer $csvComputers 'JSS Computer ID'
updateRecord mobile_device $getMobileDevices $getMobileDevice $csvMobileDevices "JSS Mobile Device ID"

Write-Host "jamf_MoveSites Process:  COMPLETE"