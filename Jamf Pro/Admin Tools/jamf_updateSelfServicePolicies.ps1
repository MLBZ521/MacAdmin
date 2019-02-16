<#

Script Name:  jamf_updateSelfServicePolicies.ps1
By:  Zack Thompson / Created:  7/19/2018
Version:  1.0.0 / Updated:  7/19/2018 / By:  ZT

Description:  This script gets all Global Self Service Policies details and exports them to a file.  After making changes to the desired Policy details, it can upload the changes to update the Policies.

#>

Write-Host "jamf_updateSelfServicePolicies Process:  START"

# ============================================================
# Define Variables
# ============================================================

# Setup Credentials
$jamfAPIUser = $(Read-Host "JPS Account")
$jamfAPIPassword = $(Read-Host -AsSecureString "JPS Password")
$APIcredentials = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $jamfAPIUser, $jamfAPIPassword

# Setup API URLs
$jamfPS = "https://jss.company.com:8443"
$getPolicies = "${jamfPS}/JSSResource/policies"
$getPolicy = "${jamfPS}/JSSResource/policies/id"

# ============================================================
# Functions
# ============================================================

Function Prompt {
	$Title = "Choose Action";
	$Message = "Choose which action:"
	$Option1 = New-Object System.Management.Automation.Host.ChoiceDescription "&Get";
	$Option2 = New-Object System.Management.Automation.Host.ChoiceDescription "&Update";
	$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Option1,$Option2);
	$script:Answer = $Host.UI.PromptForChoice($Title,$Message,$Options,0)
}

function getPolicyInfo($workingDirectory) {
    # Get all the Policies
    $objectOf_AllPolicies = Invoke-RestMethod -Uri "${getPolicies}" -Method Get -Credential $APIcredentials

    $matchedPolicies = @()

    # Loop through each Policy
    ForEach ($policy in $objectOf_AllPolicies.policies.policy) {
        
        # Get the configuration of each Policy
        $objectOf_Policy = Invoke-RestMethod -Uri "${getPolicy}/$(${policy}.id)" -Method Get -Credential $APIcredentials

        # If the Site is 'NONE' and is a Self Service Policy...
        If ( $objectOf_Policy.policy.General.Site.Name -eq "none" -and $objectOf_Policy.policy.Self_Service.use_for_self_service -eq "true" ) {
            
            # Build an object of details we want to export for each Policy
            $matchedPolicies = New-Object PSObject -Property @{
                id = $objectOf_Policy.policy.general.id
                name = $objectOf_Policy.policy.general.name
                self_service_display_name = $objectOf_Policy.policy.Self_Service.self_service_display_name
                install_button_text = $objectOf_Policy.policy.Self_Service.install_button_text
                reinstall_button_text = $objectOf_Policy.policy.Self_Service.reinstall_button_text
                self_service_description = $objectOf_Policy.policy.Self_Service.self_service_description
                notification_subject = $objectOf_Policy.policy.Self_Service.notification_subject
                message_start = $objectOf_Policy.policy.user_interaction.message_start
                message_finish = $objectOf_Policy.policy.user_interactionmessage_finish
            }
            # Export each Policy object
            Export-Csv -InputObject $matchedPolicies -Path "${workingDirectory}\matchedPolicies.csv" -Append -NoTypeInformation
        }
    }
    Write-Host "All Policies have been processed."
}

function updatePolicyInfo($updateFile) {

    # Import the file provided
    $policyUpdates = Import-Csv -Path $updateFile

    # Loop through each record
    ForEach ($policy in $policyUpdates) {
        
        # Added each records' contents to an XML object
        [xml]$upload_PolicyConfig = "<?xml version='1.0' encoding='UTF-8'?><policy><general><name>$($policy.name)</name></general><self_service><self_service_display_name>$($policy.self_service_display_name)</self_service_display_name><install_button_text>$($policy.install_button_text)</install_button_text><reinstall_button_text>$($policy.reinstall_button_text)</reinstall_button_text><self_service_description>$($policy.self_service_description)</self_service_description><notification_subject>$($policy.notification_subject)</notification_subject></self_service><user_interaction><message_start>$($policy.message_start)</message_start><message_finish>$($policy.message_finish)</message_finish></user_interaction></policy>"
        # Write-Host $upload_PolicyConfig.InnerXml
        # Update each Policy with the config in the XML object
        Try {
            $Response = Invoke-RestMethod -Uri "${getPolicy}/$($policy.id)" -Method Put -Credential $APIcredentials -Body $upload_PolicyConfig -ErrorVariable RestError -ErrorAction SilentlyContinue
        }
        Catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $statusDescription = $_.Exception.Response.StatusDescription

            If ($statusCode -notcontains "200") {
                Write-host " -> Failed to update Policy ID:  $($policy.id)..."
                Write-Host "  -> Response:  ${statusCode}/${statusDescription}"
            }
        }
    }
    Write-Host "All Policies have been updated!"
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

# Prompt what action to perform
Prompt

# Request list of devices and call Update function for each device type
switch ($Answer) {
    0 { 
        $saveDirectory = ($(Read-Host "Save Directiory") -replace '"')
        getPolicyInfo "${saveDirectory}"
    }
    1 { 
        $readFile = ($(Read-Host "Please provide Policy File") -replace '"')
        updatePolicyInfo "${readFile}"
    }
}

Write-Host "jamf_updateSelfServicePolicies Process:  COMPLETE"