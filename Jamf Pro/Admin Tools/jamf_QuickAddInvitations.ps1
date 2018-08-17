<#

Script Name:  jamf_QuickAddInvitations.ps1
By:  Zack Thompson / Created:  8/17/2018
Version:  1.0 / Updated:  8/17/2018 / By:  ZT

Description:  This script gets all QuickAdd created Computer Invitations and exports them to a file.  The file can be review and the desired IDs provided back to the script, via the file, to be deleted.

#>

Write-Host "jamf_QuickAddInvitations Process:  START"

# ============================================================
# Define Variables
# ============================================================

# Setup Credentials
$jamfAPIUser = $(Read-Host "JPS Account")
$jamfAPIPassword = $(Read-Host -AsSecureString "JPS Password")
$APIcredentials = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $jamfAPIUser, $jamfAPIPassword

# Setup API URLs
$jamfPS = "https://jps.company.com:8443"
$getInvitations = "${jamfPS}/JSSResource/computerinvitations"
$getInvitation = "${jamfPS}/JSSResource/computerinvitations/id"

# ============================================================
# Functions
# ============================================================

Function Prompt {
	$Title = "Choose Action";
	$Message = "Choose which action:"
	$Option1 = New-Object System.Management.Automation.Host.ChoiceDescription "&Get";
	$Option2 = New-Object System.Management.Automation.Host.ChoiceDescription "&Delete";
	$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Option1,$Option2);
	$script:Answer = $Host.UI.PromptForChoice($Title,$Message,$Options,0)
}

function getAllInvitations($workingDirectory) {
    # Get all the Policies
    $objectOf_AllInvitations = Invoke-RestMethod -Uri "${getInvitations}" -Method Get -Credential $APIcredentials

    $matchedInvites = @()

    # Loop through each Policy
    ForEach ($Invite in $objectOf_AllInvitations.computer_invitations.computer_invitation) {
        
        # Get the configuration of each Policy
        $objectOf_Invite = Invoke-RestMethod -Uri "${getInvitation}/$(${Invite}.id)" -Method Get -Credential $APIcredentials

        # If the Site is 'NONE' and is a Self Service Policy...
        If ( $objectOf_Invite.computer_invitation.invitation_type -ne "USER_INITIATED_EMAIL" -and $objectOf_Invite.computer_invitation.invitation_type -ne "USER_INITIATED_URL" ) {
            
            # Build an object of details we want to export for each Policy
            $matchedInvites = New-Object PSObject -Property @{
                id = $objectOf_Invite.computer_invitation.id
                invitation_type = $objectOf_Invite.computer_invitation.invitation_type
                multiple_uses_allowed = $objectOf_Invite.computer_invitation.multiple_uses_allowed
                times_used = $objectOf_Invite.computer_invitation.times_used
                enroll_into_site = $objectOf_Invite.computer_invitation.enroll_into_site.name
            }
            # Export each Policy object
            Export-Csv -InputObject $matchedInvites -Path "${workingDirectory}\InvitesNew.csv" -Append -NoTypeInformation
        }
    }
    Write-Host "All Invites have been processed."
}

function deleteInvitations($inviteFile) {

    # Import the file provided
    $invitesToDelete = Import-Csv -Path $inviteFile

    # Loop through each record
    ForEach ($Invite in $invitesToDelete) {
        
        # Expire Invitation IDs
        Try {
            $Response = Invoke-RestMethod -Uri "${getInvitation}/$(${Invite}.id)" -Method Delete -Credential $APIcredentials -Body $upload_PolicyConfig -ErrorVariable RestError -ErrorAction SilentlyContinue
        }
        Catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $statusDescription = $_.Exception.Response.StatusDescription

            If ($statusCode -notcontains "200") {
                Write-host " -> Failed to Expire Invite ID:  $($Invite.id)..."
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
        getAllInvitations "${saveDirectory}"
    }
    1 { 
        $readFile = ($(Read-Host "Please provide Policy File") -replace '"')
        deleteInvitations "${readFile}"
    }
}

Write-Host "jamf_QuickAddInvitations Process:  COMPLETE"