<#

Script Name:  jamf_updatePackageInfo.ps1
By:  Zack Thompson / Created:  10/3/2018
Version:  1.0.0 / Updated:  10/3/2018 / By:  ZT

Description:  This script gets all package meta data and exports it to a file.  After making changes to the desired meta data, it can upload the changes back into Jamf.

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
$getPackages = "${jamfPS}/JSSResource/packages"
$getPackage = "${jamfPS}/JSSResource/packages/id"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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

function getPackageInfo($csvLocation) {
    # Get all the Packages
    $objectOf_AllPackages = Invoke-RestMethod -Uri "${getPackages}" -Method Get -Headers @{"accept"="application/xml"} -Credential $APIcredentials

    # Loop through each Package
    ForEach ($package in $objectOf_AllPackages.packages.package) {
    
        # Get the configuration of each Package
        $objectOf_Package = Invoke-RestMethod -Uri "${getPackage}/$(${package}.id)" -Method Get -Headers @{"accept"="application/xml"} -Credential $APIcredentials

        # Export each Policy object
        Export-Csv -InputObject $objectOf_Package.package -Path "${csvLocation}\PackagesInfo.csv" -Append -NoTypeInformation

    }
    Write-Host "All Packages have been processed."
}

function updatePackageInfo($updateFile) {

    # Import the file provided
    $packageUpdates = Import-Csv -Path $updateFile

    # Loop through each record
    ForEach ($package in $packageUpdates) {
    
        # Added each records' contents to an XML object
        [xml]$upload_PackageConfig = "<?xml version='1.0' encoding='UTF-8'?><package><id>$($package.id)</id><name>$($package.name)</name><category>$($package.category)</category><filename>$($package.filename)</filename><info>$($package.info)</info><notes>$($package.notes)</notes><priority>$($package.priority)</priority><reboot_required>$($package.reboot_required)</reboot_required><fill_user_template>$($package.fill_user_template)</fill_user_template><fill_existing_users>$($package.fill_existing_users)</fill_existing_users><boot_volume_required>$($package.boot_volume_required)</boot_volume_required><allow_uninstalled>$($package.allow_uninstalled)</allow_uninstalled><os_requirements>$($package.os_requirements)</os_requirements><required_processor>$($package.required_processor)</required_processor><switch_with_package>$($package.switch_with_package)</switch_with_package><install_if_reported_available>$($package.install_if_reported_available)</install_if_reported_available><reinstall_option>$($package.reinstall_option)</reinstall_option><triggering_files>$($package.triggering_files)</triggering_files><send_notification>$($package.send_notification)</send_notification></package>"

        # Update each Package with the config in the XML object
        Try {
            $Response = Invoke-RestMethod -Uri "${getPackage}/$($package.id)" -Method Put -Credential $APIcredentials -Body $upload_PackageConfig -ErrorVariable RestError -ErrorAction SilentlyContinue
        }
        Catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $statusDescription = $_.Exception.Response.StatusDescription

            If ($statusCode -notcontains "200") {
                Write-host " -> Failed to update Package ID:  $($package.id)..."
                Write-Host "  -> Response:  ${statusCode}/${statusDescription}"
            }
        }
    }
    Write-Host "All Packages have been updated!"
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
        $saveDirectory = ($(Read-Host "Provide directiory to save the report") -replace '"')
        getPackageInfo "${saveDirectory}"
    }
    1 { 
        $readFile = ($(Read-Host "Please provide update file") -replace '"')
        updatePackageInfo "${readFile}"
    }
}

Write-Host "jamf_updateSelfServicePolicies Process:  COMPLETE"