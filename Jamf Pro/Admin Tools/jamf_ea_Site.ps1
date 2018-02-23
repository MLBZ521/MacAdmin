<#

Script Name:  jamf_ea_Site.ps1
By:  Zack Thompson / Created:  2/21/2018
Version:  0.1 / Updated:  2/21/2018 / By:  ZT

Description:  This script will basically update an EA to the value of the computers Site membership.

#>

$jamfAPIUser = ""
$jamfAPIPassword = ConvertTo-SecureString -String "" -AsPlainText -Force
$APIcredentials = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $jamfAPIUser, $jamfAPIPassword

$jamfPS="https://newjss.company.com:8443"
$getSites="${jamfPS}/JSSResource/sites"
$getComputerEA="${jamfPS}/JSSResource/computerextensionattributes/id/43"
#$mobileEA="${jamfPS}/JSSResource/mobiledeviceextensionattributes/name/Jamf%20Site"
$getComputers="${jamfPS}/JSSResource/computers"
$computersGeneral="${jamPS}/JSSResource/computers/id/subset/General"
$computersEA="${jamPS}/JSSResource/computers/id/subset/extension_attribute"

#[xml]$template_ComputerEA = "<?xml version='1.0' encoding='UTF-8'?><computer_extension_attribute><input_type><type>Pop-up Menu</type><popup_choices><choice>default</choice></popup_choices></input_type></computer_extension_attribute>"

[xml]$template_ComputerEA = $objectComputerEA.InnerXml

function updateSiteList {

$objectOfSites = Invoke-RestMethod -Uri $getSites -Method Get -Credential $APIcredentials
$objectComputerEA = Invoke-RestMethod -Uri $getComputerEA -Method Get -Credential $APIcredentials

if ( $objectOfSites.sites.site.Count -eq $($objectComputerEA.computer_extension_attribute.input_type.popup_choices.choice.Count - 1) ) {
    Write-Host "Site count equal Computer EA Choice Count"
    Write-Host "Presuming these are up to date"
}
else {
    Write-Host "Site count does not equal Computer EA Choice Count"

    $SiteList = $objectOfSites.sites.site | ForEach-Object {$_.Name}
    $missingChoices = $(Compare-Object -ReferenceObject $($objectOfSites.sites.site | ForEach-Object {$_.Name}) -DifferenceObject $objectComputerEA.computer_extension_attribute.input_type.popup_choices.choice) | ForEach-Object {$_.InputObject}
    $missingChoices

    ForEach ( $choice in $missingChoices ) {
        Write-Host $choice
        $newElement = $template_ComputerEA.CreateElement("choice")
        $newElement.InnerXml = $choice
        $template_ComputerEA.SelectSingleNode("//popup_choices").AppendChild($newElement)
        Invoke-RestMethod -Uri $getComputerEA -Method Put -Credential $APIcredentials -Body $template_ComputerEA
    }
}

}

$getComputers = Invoke-RestMethod -Method Get -Uri $getComputers -Credential $APIcredentials
$getComputers.computers.computer

