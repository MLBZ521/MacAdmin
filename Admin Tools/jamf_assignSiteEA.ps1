<#

Script Name:  jamf_assignSiteEA.ps1
By:  Zack Thompson / Created:  2/21/2018
Version:  1.6 / Updated:  7/3/2018 / By:  ZT

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
$jamfAPIUser = "APIUsername"
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
$getMobileEA="${jamfPS}/JSSResource/mobiledeviceextensionattributes/id/${id_EAMobileDevice}"

# ============================================================
# Functions
# ============================================================

function updateEAList($deviceType, $urlEA) {

    # Get the List of Site choices from the EA.
    Add-LogContent -Content "Pulling the Site choices in the ${deviceType} EA..."
    $objectOf_EAdeviceType = Invoke-RestMethod -Uri $urlEA -Method Get -Credential $APIcredentials

    # Build lists for comparisions.
	$SiteList = $objectOf_Sites.sites.site.Name
	$EASiteList = $($objectOf_EAdeviceType."${deviceType}_extension_attribute".input_type.popup_choices.choice)

    # Check to see if the EA has been set before.
    If ($($objectOf_EAdeviceType."${deviceType}_extension_attribute".input_type.popup_choices.choice.Count) -eq "0") {

        # For each missing value, add it to the original retrived XML list.
        Add-LogContent -Content "EA list is empty...adding choices to the EA..."
        ForEach ($choice in $objectOf_Sites.sites.site.Name) {
            Add-LogContent -Content " + ${choice}"
            $newChoice = $objectOf_EAdeviceType.CreateElement("choice")
            $newChoice.InnerXml = $choice
            $objectOf_EAdeviceType.SelectSingleNode("//popup_choices").AppendChild($newChoice) | Out-Null
        }

        # Upload the XML back.
        Add-LogContent -Content "Updating the ${deviceType} EA List..."
        Try {
            $Response = Invoke-RestMethod -Uri $urlEA -Method Put -Credential $APIcredentials -Body $objectOf_EAdeviceType -ErrorVariable RestError -ErrorAction SilentlyContinue
        }
        Catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $statusDescription = $_.Exception.Response.StatusDescription

            If ($statusCode -notcontains "200") {
                Add-LogContent -Content " -> Failed to update the EA List for ${deviceType}s"
                Add-LogContent -Content "  --> Response:  ${statusCode}/${statusDescription}: $($RestError.Message | ForEach { $_.Split(":")[1];} | ForEach { $_.Split([Environment]::NewLine)[0];})"
            }
        }
    }
    Else {

        # Compare the two lists to find the objects that need to be added or removed from the EA List.
        Add-LogContent -Content "Comparing choices in the ${deviceType} EA to the Site list..."
        $addChoices = $(Compare-Object -ReferenceObject $SiteList -DifferenceObject $EASiteList) | Where-Object { $_.SideIndicator -eq '<=' } | ForEach-Object { $_.InputObject }
        $removeChoices = $(Compare-Object -ReferenceObject $SiteList -DifferenceObject $EASiteList) | Where-Object { $_.SideIndicator -eq '=>' } | ForEach-Object { $_.InputObject }

        # Check if there are any differences that needs to be made.
        If ($addChoices.Count -ne 0 -or $removeChoices.Count -ne 0) {

            If ($addChoices.Count -ne 0) {
                # For each missing value, add it to the original retrived XML list.
                Add-LogContent -Content "Adding choices to the EA list..."
                ForEach ( $choice in $addChoices ) {
                    Add-LogContent -Content " + ${choice}"
                    $newChoice = $objectOf_EAdeviceType.CreateElement("choice")
                    $newChoice.InnerXml = $choice
                    $objectOf_EAdeviceType.SelectSingleNode("//popup_choices").AppendChild($newChoice) | Out-Null
                }
            }

            If ($removeChoices.Count -ne 0) {
                # For each invalid value, remove it from the original retrived XML list.
                Add-LogContent -Content "Removing choices from EA list..."
                ForEach ( $choice in $removeChoices ) {
                    Add-LogContent -Content " - ${choice}"
                    $XMLNode = $objectOf_EAdeviceType.SelectSingleNode("//choice[.='${choice}']")
                    $XMLNode.ParentNode.RemoveChild($XMLNode) | Out-Null
                }
            }

            # Upload the XML back to the JPS.
            Add-LogContent -Content "Updating the ${deviceType} EA List in the JPS..."
            Try {
                $Response = Invoke-RestMethod -Uri $urlEA -Method Put -Credential $APIcredentials -Body $objectOf_EAdeviceType -ErrorVariable RestError -ErrorAction SilentlyContinue
            }
            Catch {
                $statusCode = $_.Exception.Response.StatusCode.value__
                $statusDescription = $_.Exception.Response.StatusDescription

                If ($statusCode -notcontains "200") {
                    Add-LogContent -Content " -> Failed to update the EA List for ${deviceType}s"
                    Add-LogContent -Content "  --> Response:  ${statusCode}/${statusDescription}: $($RestError.Message | ForEach { $_.Split(":")[1];} | ForEach { $_.Split([Environment]::NewLine)[0];})"
                }
            }
        }
        Else {
            Add-LogContent -Content "The ${deviceType} EA choices are up to date."
        }
    }
}

function updateDeviceRecord($deviceType, $urlALL, $urlID, $idEA) {

    # Get a list of all records.
    Add-LogContent -Content "Pulling all ${deviceType} records..."
    $objectOf_Devices = Invoke-RestMethod -Uri $urlALL -Method Get -Credential $APIcredentials

    # Get the ID of each device.
    Add-LogContent -Content "Pulling data for each individual ${deviceType} record..."
    $deviceList = $objectOf_Devices."${deviceType}s"."${deviceType}" | ForEach-Object {$_.ID}

    ForEach ( $ID in $deviceList ) {
        # Get Computer's General Section.
        $objectOf_deviceGeneral = Invoke-RestMethod -Uri "${urlID}/${ID}/subset/General" -Method Get -Credential $APIcredentials

        # Get Computer's Extention Attribute Section.
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

# Get a list of all Sites.
$objectOf_Sites = Invoke-RestMethod -Uri $getSites -Method Get -Credential $APIcredentials

# Call EA Update function for each device type
updateEAList computer $getComputerEA
updateEAList mobile_device $getMobileEA

# Call Device Update function for each device type
updateDeviceRecord computer $getComputers $getComputer $id_EAComputer
updateDeviceRecord mobile_device $getMobileDevices $getMobileDevice $id_EAMobileDevice

$StopWatch.Stop()
Add-LogContent -Content "Mins: " $StopWatch.Elapsed.Minutes "Seconds: " $StopWatch.Elapsed.Seconds
Add-LogContent -Content "jamf_assignSiteEA Process:  COMPLETE"