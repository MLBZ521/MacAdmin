<#

Script Name:  jamf_runReports.ps1
By:  Zack Thompson / Created:  9/13/2018
Version:  1.1.0 / Updated:  12/27/2018 / By:  ZT

Description:  This script will run advanced searches and export each set of results to a file.

#>

Write-Host "jamf_runReports Process:  START"

# ============================================================
# Define Variables
# ============================================================

# Setup Credentials
$jamfAPIUser = $(Read-Host "JPS Account")
$jamfAPIPassword = $(Read-Host -AsSecureString "JPS Password")
$APIcredentials = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $jamfAPIUser, $jamfAPIPassword

# Setup API URLs
$jamfPS = "https://jps.company.com:8443"
$runComputerReport = "${jamfPS}/JSSResource/advancedcomputersearches/id"
$runMobileDeivceReport = "${jamfPS}/JSSResource/advancedmobiledevicesearches/id"

$computerReports=83,84,85,86,109,110
$mobileDeviceReports=87

# Set the session to use TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ============================================================
# Functions
# ============================================================

function runReports($deviceType, $IDs, $urlID, $csvLocation) {
    Write-Host "Pulling all ${deviceType} records..."
    ForEach ($ID in $IDs) {
        $objectOf_Devices = Invoke-RestMethod -Uri "${urlID}/${ID}" -Method Get -Headers @{"accept"="application/json"} -Credential $APIcredentials
        $reportName = $(${objectOf_Devices}."advanced_${deviceType}_search".name) -Replace "\[","" -Replace "\]"," -"
        $objectOf_Devices."advanced_${deviceType}_search"."${deviceType}s" | ForEach-Object {$_} | Select-Object -Property $($objectOf_Devices."advanced_${deviceType}_search".display_fields.name | ForEach-Object { $_ -Replace " ","_" -Replace "-","_"}) | Export-Csv -Path "$csvLocation\${reportName}.csv" -Append -NoTypeInformation
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
		Write-Host "jamf_runReports Process:  FAILED"
		Exit
	}
}

Write-Host "API Credentials Valid -- continuing..."

$saveDirectory = ($(Read-Host "Provide directiory to save the report") -replace '"')

# Call Device Update function for each device type
runReports computer $computerReports $runComputerReport "${saveDirectory}"
runReports mobile_device $MobileDeviceReports $runMobileDeivceReport "${saveDirectory}"

Write-Host "jamf_runReports Process:  COMPLETE"