<#

Script Name:  jamf_ea_Site.ps1
By:  Zack Thompson / Created:  2/21/2018
Version:  0.2 / Updated:  2/23/2018 / By:  ZT

Description:  This script will basically update an EA to the value of the computers Site membership.

#>

# ============================================================
# Define Variables
# ============================================================

# Jamf EA IDs
$id_EAComputer="43"
$id_MobileComputer="43"

# Setup Credentials
$jamfAPIUser = ""
$jamfAPIPassword = ConvertTo-SecureString -String "" -AsPlainText -Force
$APIcredentials = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $jamfAPIUser, $jamfAPIPassword

# Setup API URLs
$jamfPS="https://newjss.company.com:8443"
$getSites="${jamfPS}/JSSResource/sites"
$getComputerEA="${jamfPS}/JSSResource/computerextensionattributes/id/${id_EAComputer}"
$getMobileEA="${jamfPS}/JSSResource/mobiledeviceextensionattributes/id/"
$getComputers="${jamfPS}/JSSResource/computers"
$computersGeneral="${jamPS}/JSSResource/computers/id/subset/General"
$computersEA="${jamPS}/JSSResource/computers/id/subset/extension_attribute"

# ============================================================
# Functions
# ============================================================

function updateSiteList {

    Write-Host "Pulling required data..."
    # Get a list of all Sites.
        $objectOf_Sites = Invoke-RestMethod -Uri $getSites -Method Get -Credential $APIcredentials
    # Get the ComputerEA for Site.
        $objectOf_EAComputer = Invoke-RestMethod -Uri $getComputerEA -Method Get -Credential $APIcredentials

    # Compare the Sites count to the list of Choices from the ComputerEA.
    if ( $objectOf_Sites.sites.site.Count -eq $($objectOf_EAComputer.computer_extension_attribute.input_type.popup_choices.choice.Count - 1) ) {
        Write-Host "Site count equal Computer EA Choice Count"
        Write-Host "Presuming these are up to date"
    }
    else {
        Write-Host "Site count does not equal Computer EA Choice Count"

        $SiteList = $objectOf_Sites.sites.site | ForEach-Object {$_.Name}
        $EASiteList = $objectOf_EAComputer.computer_extension_attribute.input_type.popup_choices.choice
        # Compare the two lists to find the objects that are missing from the EA List.
        Write-Host "Finding the missing objects..."
        $missingChoices = $(Compare-Object -ReferenceObject $SiteList -DifferenceObject $EASiteList) | ForEach-Object {$_.InputObject}

        Write-Host "Adding missing objects to into an XML list..."
        # For each missing value, add it to the original retrived XML list.
        ForEach ( $choice in $missingChoices ) {
            # Write-Host $choice
            $newChoice = $objectOf_EAComputer.CreateElement("choice")
            $newChoice.InnerXml = $choice
            $objectOf_EAComputer.SelectSingleNode("//popup_choices").AppendChild($newChoice)
        }

        # Upload the XML back.
        Write-Host "Updating the EA Computer List..."
        Invoke-RestMethod -Uri $getComputerEA -Method Put -Credential $APIcredentials -Body $objectOf_EAComputer
    }
}


}


$getComputers = Invoke-RestMethod -Method Get -Uri $getComputers -Credential $APIcredentials
$getComputers.computers.computer

