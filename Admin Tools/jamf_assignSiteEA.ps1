<#

Script Name:  jamf_assignSiteEA.ps1
By:  Zack Thompson / Created:  2/21/2018
Version:  1.5 / Updated:  7/2/2018 / By:  ZT

Description:  This script will basically update an EA to the value of the computers Site membership.

#>

# Log Location
$Global:LogPath = "C:\Temp\jamf_assignSiteEA.log"
Function Add-LogContent {
	Param (
		[parameter(Mandatory = $false)]
		[switch]$Load,
		[parameter(Mandatory = $true)]
		$Content
	)
	If ($Load) {
		If ((Get-Item $LogPath).length -gt 1000kb) {
			Write-Output "$(Get-Date -Format G) - $Content" > $LogPath
		}
		Else {
			Write-Output "$(Get-Date -Format G) - $Content" >> $LogPath
		}
	}
	Else {
		Write-Output "$(Get-Date -Format G) - $Content" >> $LogPath
	}
}

Add-LogContent -Load -Content " "
Add-LogContent -Content "jamf_assignSiteEA Process:  START"

# ============================================================
# Define Variables
# ============================================================

# Jamf EA IDs
$id_EAComputer="43"
$id_EAMobileDevice="1"

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
$getSites="${jamfPS}/JSSResource/sites"
$getComputers="${jamfPS}/JSSResource/computers"
$getComputer="${jamfPS}/JSSResource/computers/id"
$getMobileDevices="${jamfPS}/JSSResource/mobiledevices"
$getMobileDevice="${jamfPS}/JSSResource/mobiledevices/id"
$getComputerEA="${jamfPS}/JSSResource/computerextensionattributes/id/${id_EAComputer}"
$getMobileEA="${jamfPS}/JSSResource/mobiledeviceextensionattributes/id/${id_MobileComputer}"

# ============================================================
# Functions
# ============================================================

function updateSiteList {

    Add-LogContent -Content "Pulling required data..."
    # Get a list of all Sites.
        $objectOf_Sites = Invoke-RestMethod -Uri $getSites -Method Get -Credential $APIcredentials
    # Get the ComputerEA for Site.
        $objectOf_EAComputer = Invoke-RestMethod -Uri $getComputerEA -Method Get -Credential $APIcredentials

    # Compare the Sites count to the list of Choices from the ComputerEA.
    if ( $objectOf_Sites.sites.site.Count -eq $($objectOf_EAComputer.computer_extension_attribute.input_type.popup_choices.choice.Count - 1) ) {
        Add-LogContent -Content "Site count equal Computer EA Choice Count"
        Add-LogContent -Content "Presuming these are up to date"
    }
    else {
        Add-LogContent -Content "Site count does not equal Computer EA Choice Count"

        $SiteList = $objectOf_Sites.sites.site | ForEach-Object { $_.Name }
        $EASiteList = $objectOf_EAComputer.computer_extension_attribute.input_type.popup_choices.choice
        # Compare the two lists to find the objects that are missing from the EA List.
        Add-LogContent -Content "Finding the missing objects..."
        $missingChoices = $(Compare-Object -ReferenceObject $SiteList -DifferenceObject $EASiteList) | ForEach-Object { $_.InputObject }

        Add-LogContent -Content "Adding missing objects to into an XML list..."
        # For each missing value, add it to the original retrived XML list.
        ForEach ( $choice in $missingChoices ) {
            $newChoice = $objectOf_EAComputer.CreateElement("choice")
            $newChoice.InnerXml = $choice
            $objectOf_EAComputer.SelectSingleNode("//popup_choices").AppendChild($newChoice)
        }

        # Upload the XML back.
        Add-LogContent -Content "Updating the EA Computer List..."
        Invoke-RestMethod -Uri $getComputerEA -Method Put -Credential $APIcredentials -Body $objectOf_EAComputer
    }
}

function updateRecord($deviceType, $urlALL, $urlID, $idEA) {

    Add-LogContent -Content "Pulling all ${deviceType} records..."
    # Get a list of all records
    $objectOf_Devices = Invoke-RestMethod -Uri $urlALL -Method Get -Credential $APIcredentials

    Add-LogContent -Content "Pulling data for each individual ${deviceType} record..."
    # Get the ID of each device
    $deviceList = $objectOf_Devices."${deviceType}s"."${deviceType}" | ForEach-Object {$_.ID}

    ForEach ( $ID in $deviceList ) {
        # Get Computer's General Section
        $objectOf_deviceGeneral = Invoke-RestMethod -Uri "${urlID}/${ID}/subset/General" -Method Get -Credential $APIcredentials

        # Get Computer's Extention Attribute Section
        $objectOf_deviceEA = Invoke-RestMethod -Uri "${urlID}/${ID}/subset/extension_attributes" -Method Get -Credential $APIcredentials
        
        If ( $objectOf_deviceGeneral.$deviceType.general.site.name -ne $($objectOf_deviceEA.$deviceType.extension_attributes.extension_attribute | Select-Object ID, Value | Where-Object { $_.id -eq $idEA }).value) {
            Add-LogContent -Content "Site is incorrect for ${deviceType} ID:  ${ID} -- updating..."
            [xml]$upload_deviceEA = "<?xml version='1.0' encoding='UTF-8'?><${deviceType}><extension_attributes><extension_attribute><id>${idEA}</id><value>$(${objectOf_deviceGeneral}.$deviceType.general.site.name)</value></extension_attribute></extension_attributes></${deviceType}>"
            
            Try {
                $Response = Invoke-RestMethod -Uri "${urlID}/${ID}" -Method Put -Credential $APIcredentials -Body $upload_deviceEA -ErrorVariable RestError -ErrorAction SilentlyContinue
            }
            Catch {
                $statusCode = $_.Exception.Response.StatusCode.value__
                $statusDescription = $_.Exception.Response.StatusDescription

                If ($statusCode -notcontains "200") {
                    Add-LogContent -Content " -> Failed to assign site for ${deviceType} ID:  ${ID}"
                    Add-LogContent -Content "  --> Response:  ${statusCode}/${statusDescription}: $($RestError.Message | ForEach { $_.Split(":")[1];} | ForEach { $_.Split([Environment]::NewLine)[0];})"
                }
            }
        }
    }
    Add-LogContent -Content "All ${deviceType} records have been processed."
}

# ============================================================
# Bits Staged...
# ============================================================

# Verify credentials that were provided by doing an API call and checking the result to verify permissions.
Add-LogContent -Content "Verifying API credentials..."
Try {
    $Response = Invoke-RestMethod -Uri "${jamfPS}/JSSResource/jssuser" -Method Get -Credential $APIcredentials -ErrorVariable RestError -ErrorAction SilentlyContinue
}
Catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $statusDescription = $_.Exception.Response.StatusDescription

    If ($statusCode -notcontains "200") {
        Add-LogContent -Content "ERROR:  Invalid Credentials or permissions."
        Add-LogContent -Content "Response:  ${statusCode}/${statusDescription}"
        Add-LogContent -Content "jamf_assignSiteEA Process:  FAILED"
        Exit
    }
}

Add-LogContent -Content "API Credentials Valid -- continuing..."

$StopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
$StopWatch.Start()

# Call Update function for each device type
updateRecord computer $getComputers $getComputer $id_EAComputer
updateRecord mobile_device $getMobileDevices $getMobileDevice $id_EAMobileDevice

$StopWatch.Stop()
Add-LogContent -Content "Mins: " $StopWatch.Elapsed.Minutes "Seconds: " $StopWatch.Elapsed.Seconds
Add-LogContent -Content "jamf_assignSiteEA Process:  COMPLETE"