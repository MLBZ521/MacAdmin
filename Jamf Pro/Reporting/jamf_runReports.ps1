<#

Script Name:  jamf_runReports.ps1
By:  Zack Thompson / Created:  9/13/2018
Version:  1.1.1 / Updated:  12/27/2018 / By:  ZT

Description:  This script will run advanced searches and export each set of results to a file.

#>

Write-Host "jamf_runReports Process:  START"
Write-Host ""

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

# Define the Advanced Search IDs
$computerAdvancedSearches=83,84,85,86,109,110
$mobileDeviceAdvancedSearches=87

# Setup Save Directory
$folderDate=$( Get-Date -UFormat %m-%d-%y )
$saveDirectory = ( $( Read-Host "Provide directiory to save the report" ) -replace '"' )

# Set the session to use TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ============================================================
# Functions
# ============================================================

function runReports($deviceType, $IDs, $urlID, $csvLocation) {
    Write-Host "Pulling all ${deviceType} advanced searches..."

    ForEach ($ID in $IDs) {
        # Get the results of the Advanced Search.
        $objectOf_Report = Invoke-RestMethod -Uri "${urlID}/$ID" -Method Get -Headers @{"accept"="application/json"} -Credential $APIcredentials

        # Get the name of the Advanced Search.
        $reportName = $(${objectOf_Report}."advanced_${deviceType}_search".name) -Replace "\[","" -Replace "\]"," -"

        # Extract the values of the search criteria and output to a csv.
        $objectOf_Report."advanced_${deviceType}_search"."${deviceType}s" | ForEach-Object { $_ } | Select-Object -Property $( $objectOf_Report."advanced_${deviceType}_search".display_fields.name | ForEach-Object { $_ -Replace " ","_" -Replace "-","_" } ) | Export-Csv -Path "$csvLocation\${reportName}.csv" -Append -NoTypeInformation
    }

    Write-Host "All ${deviceType} advanced searches have been processed."
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
Write-Host ""
Write-Host "Saving reports to:  ${saveDirectory}\${folderDate}"
Write-Host ""

if ( !( Test-Path "${saveDirectory}\${folderDate}") ) {    
        New-Item -Path "${saveDirectory}\${folderDate}" -ItemType Directory | Out-Null
}

# Call runReports function for each device type
runReports computer $computerAdvancedSearches $runComputerReport "${saveDirectory}"
runReports mobile_device $mobileDeviceAdvancedSearches $runMobileDeivceReport "${saveDirectory}\${folderDate}"

Write-Host ""
Write-Host "jamf_runReports Process:  COMPLETE"