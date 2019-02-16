<#

Script Name:  jamf_initialEntry.ps1
By:  Zack Thompson / Created:  9/13/2018
Version:  1.0.0 / Updated:  9/13/2018 / By:  ZT

Description:  This script will pull the initial enrollment for every device and export to a file.

#>

Write-Host "jamf_initialEntry Process:  START"

# ============================================================
# Define Variables
# ============================================================

# Setup Credentials
$jamfAPIUser = $(Read-Host "JPS Account")
$jamfAPIPassword = $(Read-Host -AsSecureString "JPS Password")
$APIcredentials = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $jamfAPIUser, $jamfAPIPassword

# Setup API URLs
$jamfPS = "https://jps.company.com:8443"
$getComputers = "${jamfPS}/JSSResource/computers"
$getComputer = "${jamfPS}/JSSResource/computers/id"
$getMobileDevices = "${jamfPS}/JSSResource/mobiledevices"
$getMobileDevice = "${jamfPS}/JSSResource/mobiledevices/id"

# ============================================================
# Functions
# ============================================================
    
function getComputerRecords($deviceType, $urlALL, $urlID, $idEA, $csvLocation) {

    # Get a list of all computer records.
    Write-Host "Pulling all ${deviceType} records..."
    $objectOf_Devices = Invoke-RestMethod -Uri $urlALL -Method Get -Credential $APIcredentials

    # Get the ID of each device.
    Write-Host "Pulling data for each individual ${deviceType} record..."
    $deviceList = $objectOf_Devices."${deviceType}s"."${deviceType}" | ForEach-Object {$_.ID}

    ForEach ( $ID in $deviceList ) {
        # Get Computer's General Section.
        $objectOf_deviceGeneral = Invoke-RestMethod -Uri "${urlID}/${ID}/subset/General" -Method Get -Headers @{"accept"="application/xml"} -Credential $APIcredentials

        # Optional, if you want only mananaged devices, uncomment the if statement.
        # If ( $objectOf_deviceGeneral.${deviceType}.general.remote_management.managed -eq "true") {  
            $objectOf_deviceGeneral.${deviceType}.general | Select-Object id, name, serial_number, initial_entry_date, @{Name="site"; Expression={$_.site.name}}, @{Name="platform"; Expression={$_.platform}} | Export-Csv -Path "$csvLocation\Enrolled${deviceType}s.csv" -Append -NoTypeInformation
        # }
    }
    Write-Host "All ${deviceType} records have been processed."
}


function getMobileDeviceRecords($deviceType, $urlALL, $urlID, $idEA, $csvLocation) {

    # Get a list of all Mobile Device records.
    Write-Host "Pulling all ${deviceType} records..."
    $objectOf_Devices = Invoke-RestMethod -Uri $urlALL -Method Get -Credential $APIcredentials

    # Get the ID of each device.
    Write-Host "Pulling data for each individual ${deviceType} record..."
    $deviceList = $objectOf_Devices."${deviceType}s"."${deviceType}" | ForEach-Object {$_.ID}

    ForEach ( $ID in $deviceList ) {
        # Get Mobile Device's General Section.
        $objectOf_deviceGeneral = Invoke-RestMethod -Uri "${urlID}/${ID}/subset/General" -Method Get -Headers @{"accept"="application/xml"} -Credential $APIcredentials

        # Optional, if you want only mananaged devices, uncomment the if statement.
        # If ( $objectOf_deviceGeneral.${deviceType}.general.managed -eq "true") {  
            $objectOf_deviceGeneral.${deviceType}.general | Select-Object id, name, serial_number, @{Name="initial_entry_date"; Expression={$($_.initial_entry_date_utc).Split("T")[0]}} , @{Name="site"; Expression={$_.site.name}}, @{Name="platform"; Expression={$_.os_type}} | Export-Csv -Path "$csvLocation\Enrolled${deviceType}s.csv" -Append -NoTypeInformation
        # }
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
		Write-Host "jamf_initialEntry Process:  FAILED"
		Exit
	}
}

Write-Host "API Credentials Valid -- continuing..."

$saveDirectory = ($(Read-Host "Provide directiory to save the report") -replace '"')

# Call Device Update function for each device type
getComputerRecords computer $getComputers $getComputer "${saveDirectory}"
getMobileDeviceRecords mobile_device $getMobileDevices $getMobileDevice "${saveDirectory}"

Write-Host "jamf_initialEntry Process:  COMPLETE"