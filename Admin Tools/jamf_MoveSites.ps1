<#

Script Name:  jamf_MoveSites.ps1
By:  Zack Thompson / Created:  4/18/2018
Version:  1.1 / Updated:  5/14/2018 / By:  ZT

Description:  This script will move a device record between Sites given information from a CSV.

#>

Write-Host "jamf_MoveSites Process:  START"

# ============================================================
# Define Variables
# ============================================================

# Setup Credentials
$jamfAPIUser = $(Read-Host "JPS Account")
$jamfAPIPassword = $(Read-Host -AsSecureString "JPS Password")
$APIcredentials = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $jamfAPIUser, $jamfAPIPassword

# Prompt for the Site to move objects into.
$NewSite = $(Read-Host "New Site")

# Setup API URLs
$jamfPS="https://jss.company.com:8443"
$getSites="${jamfPS}/JSSResource/sites"
$getComputers="${jamfPS}/JSSResource/computers"
$getComputer="${jamfPS}/JSSResource/computers/id"
$getMobileDevices="${jamfPS}/JSSResource/mobiledevices"
$getMobileDevice="${jamfPS}/JSSResource/mobiledevices/id"

# ============================================================
# Functions
# ============================================================

Function Prompt {
	$Title = "Choose Device Type";
	$Message = "Chose which device types you want to move:"
	$Option1 = New-Object System.Management.Automation.Host.ChoiceDescription "&Both";
	$Option2 = New-Object System.Management.Automation.Host.ChoiceDescription "&Computers";
	$Option3 = New-Object System.Management.Automation.Host.ChoiceDescription "Mobile Devices";
	$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Option1,$Option2,$Option3);
	$script:Answer = $Host.UI.PromptForChoice($Title,$Message,$Options,0)
}

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
        If ( ( "${currentSite}" -ne "${NewSite}" ) -and ( "${currentSite}" -ne "${NewSite}.dev" ) ) {
            Write-host "${deviceType} ID:  ${ID} is a member of ${currentSite}"
            
            [xml]$upload_deviceEA = "<?xml version='1.0' encoding='UTF-8'?><${deviceType}><general><site><name>${NewSite}</name></site></general></${deviceType}>"
            
            Try {
                $Response = Invoke-RestMethod -Uri "${urlID}/${ID}" -Method Put -Credential $APIcredentials -Body $upload_deviceEA -ErrorVariable RestError -ErrorAction SilentlyContinue
            }
            Catch {
                $statusCode = $_.Exception.Response.StatusCode.value__
                $statusDescription = $_.Exception.Response.StatusDescription

                If ($statusCode -notcontains "200") {
                    Write-host " -> Failed to assign site for ${deviceType} ID:  ${ID}..."
                    Write-Host "  -> Response:  ${statusCode}/${statusDescription}"
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

# Prompt for the CSV Files with the devices that need to be moved.
Prompt

# Request list of devices and call Update function for each device type
switch ($Answer) {
    0 { 
        $csvComputers = Import-Csv -Path ($(Read-Host "List of Computers") -replace '"')
        $csvMobileDevices = Import-Csv -Path ($(Read-Host "List of Mobile Devices") -replace '"')
        updateRecord computer $getComputers $getComputer $csvComputers 'JSS Computer ID'
        updateRecord mobile_device $getMobileDevices $getMobileDevice $csvMobileDevices "JSS Mobile Device ID"
    }
    1 { 
        $csvComputers = Import-Csv -Path ($(Read-Host "List of Computers") -replace '"')
        updateRecord computer $getComputers $getComputer $csvComputers 'JSS Computer ID'
    }
    2 { 
        $csvMobileDevices = Import-Csv -Path ($(Read-Host "List of Mobile Devices") -replace '"')
        updateRecord mobile_device $getMobileDevices $getMobileDevice $csvMobileDevices "JSS Mobile Device ID"
    }
}

Write-Host "jamf_MoveSites Process:  COMPLETE"