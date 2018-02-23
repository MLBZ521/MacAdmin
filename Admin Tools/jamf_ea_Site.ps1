<#

Script Name:  jamf_ea_Site.ps1
By:  Zack Thompson / Created:  2/21/2018
Version:  0.1 / Updated:  2/21/2018 / By:  ZT

Description:  This script will basically update an EA to the value of the computers Site membership.

#>

# ============================================================
# Define Variables
# ============================================================

# Setup Credentials
$jamfAPIUser = ""
$jamfAPIPassword = ConvertTo-SecureString -String "" -AsPlainText -Force
$APIcredentials = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $jamfAPIUser, $jamfAPIPassword

# Setup API URLs
$jamfPS="https://newjss.company.com:8443"
$getSites="${jamfPS}/JSSResource/sites"
$getComputerEA="${jamfPS}/JSSResource/computerextensionattributes/id/43"
$getMobileEA="${jamfPS}/JSSResource/mobiledeviceextensionattributes/id/"
$getComputers="${jamfPS}/JSSResource/computers"
$computersGeneral="${jamPS}/JSSResource/computers/id/subset/General"
$computersEA="${jamPS}/JSSResource/computers/id/subset/extension_attribute"

# ============================================================
# Functions
# ============================================================

function updateSiteList {

$objectOf_Sites = Invoke-RestMethod -Uri $getSites -Method Get -Credential $APIcredentials
$objectOf_ComputerEA = Invoke-RestMethod -Uri $getComputerEA -Method Get -Credential $APIcredentials
[xml]$xml_ComputerEA = $objectOfComputerEA.InnerXml


if ( $objectOf_Sites.sites.site.Count -eq $($objectOf_ComputerEA.computer_extension_attribute.input_type.popup_choices.choice.Count - 1) ) {
    Write-Host "Site count equal Computer EA Choice Count"
    Write-Host "Presuming these are up to date"
}
else {
    Write-Host "Site count does not equal Computer EA Choice Count"

    $SiteList = $objectOf_Sites.sites.site | ForEach-Object {$_.Name}
    $missingChoices = $(Compare-Object -ReferenceObject $($objectOf_Sites.sites.site | ForEach-Object {$_.Name}) -DifferenceObject $objectOf_ComputerEA.computer_extension_attribute.input_type.popup_choices.choice) | ForEach-Object {$_.InputObject}
    $missingChoices

    ForEach ( $choice in $missingChoices ) {
        Write-Host $choice
        $newElement = $xml_ComputerEA.CreateElement("choice")
        $newElement.InnerXml = $choice
        $xml_ComputerEA.SelectSingleNode("//popup_choices").AppendChild($newElement)
   
    }

    #Invoke-RestMethod -Uri $getComputerEA -Method Put -Credential $APIcredentials -Body $template_ComputerEA
}

}

$getComputers = Invoke-RestMethod -Method Get -Uri $getComputers -Credential $APIcredentials
$getComputers.computers.computer

