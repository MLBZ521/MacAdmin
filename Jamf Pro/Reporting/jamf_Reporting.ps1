<#

Script Name:  jamf_Reporting.ps1
By:  Zack Thompson / Created:  11/6/2018
Version:  0.3.1 / Updated:  11/8/2018 / By:  ZT

Description:  This script is used to generate reports on specific configurations.

#>

Write-Host "jamf_Reporting Process:  START"

# ============================================================
# Define Variables
# ============================================================

# Setup Credentials
$jamfAPIUser = $(Read-Host "JPS Account")
$jamfAPIPassword = $(Read-Host -AsSecureString "JPS Password")
$APIcredentials = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $jamfAPIUser, $jamfAPIPassword

# Setup API URLs
$jamfPS = "https://jps.company.com:8443"
$getPolicies = "${jamfPS}/JSSResource/policies/createdBy/jss"
$getPolicy = "${jamfPS}/JSSResource/policies/id"
$getComputerGroups = "${jamfPS}/JSSResource/computergroups"
$getComputerGroup = "${jamfPS}/JSSResource/computergroups/id"
$getPrinters = "${jamfPS}/JSSResource/printers"

$fileDate=$(Get-Date -Format FileDateTime)
$Position = 1

# Set the session to use TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ============================================================
# Logic Functions
# ============================================================

function getEndpoint($Endpoint, $details, $urlAll, $urlDetails) {

    # Get all records
    Write-host "Querying Type:  ${Endpoint}"
    $objectOf_AllRecords = Invoke-RestMethod -Uri "${urlAll}" -Method Get -Headers @{"accept"="application/xml"} -Credential $APIcredentials

    if ( $details -eq "FullDetails" ) {
        getEndpointDetails $Endpoint $urlDetails
    }
    else {
        return $objectOf_AllRecords
    }
}

function getEndpointDetails ($Endpoint, $urlDetails) {

    $objectOf_AllRecordDetails = New-Object System.Collections.Arraylist

    # Loop through each endpoint
    ForEach ( $Record in $objectOf_AllRecords.SelectNodes("//${Endpoint}") ) {
        Write-Progress -Activity "Processing ${Endpoint} records..." -Status "Policy:  $(${Record}.id) / $(${Record}.name)" -PercentComplete (($Position/$objectOf_AllRecords.SelectNodes("//${Endpoint}").Count)*100)

        # Get the configuration of each Policy
        $objectOf_Record = Invoke-RestMethod -Uri "${urlDetails}/$(${Record}.id)" -Method Get -Headers @{"accept"="application/xml"} -Credential $APIcredentials
        $objectOf_AllRecordDetails.add($objectOf_Record) | Out-Null
        $Position++
    }
    return $objectOf_AllRecordDetails
}

function processEndpoints($Endpoint, $objectOf_AllRecords) {
    ForEach ( $Record in $objectOf_AllRecords ) {
        Write-Progress -Activity "Testing all Policies..." -Status "Policy:  $(${Record}.SelectNodes("//id")) / $(${Record}.SelectNodes("//name"))" -PercentComplete (($Position/$objectOf_AllRecords.Count)*100)
        Write-host "Policy ID $(${Record}.policy.general.id):"
        funcToRun $Record
        $Position++
    }
}

function funcToRun($objectOf_Policy) {
    Write-Host "FunctionToRun  $(${objectOf_Policy}.policy.general.id)"
    policyDisabled $objectOf_Policy
    policyNoScope $objectOf_Policy
    policyNoConfig $objectOf_Policy
    policyNoCategory $objectOf_Policy
    policySSNoDescription $objectOf_Policy
    policySSNoIcon $objectOf_Policy
    #policySiteLevelRecon $objectOf_Policy
    policyOngoingEvent $objectOf_Policy
    policyOngoingEventInventory $objectOf_Policy
}

function policyOutputObject($objectOf_Policy, $condition) {
    $outputObject = New-Object PSObject -Property @{
        id = $objectOf_Policy.policy.general.id  
        name = $objectOf_Policy.policy.general.name
        Site = $objectOf_Policy.policy.general.site.name
        selfService = $objectOf_Policy.policy.self_service.use_for_self_service
    }

    output $outputObject $condition
}

function output($outputObject, $condition) {
    # Export each Policy object to a file.
    Export-Csv -InputObject $outputObject -Path "\\Mac\Home\Desktop\testing\Reporting\${condition}_${fileDate}.csv" -Append -NoTypeInformation
    # Export-Csv -InputObject $policyNodes -Path "${workingDirectory}\AllPolicies_${fileDate}.csv" -Append -NoTypeInformation
}

# ============================================================
# Criteria Functions
# ============================================================

function policyDisabled($objectOf_Policy) {
    #Write-Host "policyDisabled  $(${objectOf_Policy}.policy.general.id)"
    if ( $objectOf_Policy.policy.general.enabled -eq $false) {
        Write-host "  -> Is Disabled"
        policyOutputObject $objectOf_Policy "policy_Disabled"
    }
}

function policyNoScope($objectOf_Policy) {
    if ( $objectOf_Policy.policy.scope.all_computers -eq $false -and 
    $objectOf_Policy.policy.scope.computers.Length -eq 0 -and 
    $objectOf_Policy.policy.scope.computer_groups.Length -eq 0 -and 
    $objectOf_Policy.policy.scope.buildings.Length -eq 0 -and
    $objectOf_Policy.policy.scope.departments.Length -eq 0 -and 
    $objectOf_Policy.policy.scope.limit_to_users.user_groups.Length -eq 0 -and 
    $objectOf_Policy.policy.scope.limitations.users.Length -eq 0 -and 
    $objectOf_Policy.policy.scope.limitations.user_groups.Length -eq 0 -and 
    $objectOf_Policy.policy.scope.limitations.network_segments.Length -eq 0 -and 
    $objectOf_Policy.policy.scope.limitations.ibeacons.Length -eq 0 -and 
    $objectOf_Policy.policy.scope.exclusions.computers.Length -eq 0 -and 
    $objectOf_Policy.policy.scope.exclusions.computer_groups.computer_group.Length -eq 0 -and 
    $objectOf_Policy.policy.scope.exclusions.buildings.Length -eq 0 -and 
    $objectOf_Policy.policy.scope.exclusions.departments.Length -eq 0 -and 
    $objectOf_Policy.policy.scope.exclusions.users.Length -eq 0 -and 
    $objectOf_Policy.policy.scope.exclusions.user_groups.Length -eq 0 -and 
    $objectOf_Policy.policy.scope.exclusions.network_segments.Length -eq 0 -and 
    $objectOf_Policy.policy.scope.exclusions.ibeacons.Length -eq 0 ) {

        Write-host "  -> Has No Scope"
        policyOutputObject $objectOf_Policy "policy_NoScope"
    }
}

function policyNoConfig($objectOf_Policy) {
    if ( $objectOf_Policy.policy.package_configuration.packages.size -eq 0 -and 
    $objectOf_Policy.policy.scripts.size -eq 0 -and 
    $objectOf_Policy.policy.printers.size -eq 0 -and 
    $objectOf_Policy.policy.dock_items.size -eq 0 -and
    $objectOf_Policy.policy.account_maintenance.accounts.size -eq 0 -and 
    $objectOf_Policy.policy.account_maintenance.directory_bindings.size -eq 0 -and 
    $objectOf_Policy.policy.account_maintenance.management_account.action -eq "doNotChange" -and 
    $objectOf_Policy.policy.account_maintenance.open_firmware_efi_password.of_mode -eq "none" -and 
    $objectOf_Policy.policy.maintenance.recon -eq $false -and 
    $objectOf_Policy.policy.maintenance.reset_name -eq $false -and 
    $objectOf_Policy.policy.maintenance.install_all_cached_packages -eq $false -and 
    $objectOf_Policy.policy.maintenance.heal -eq $false -and 
    $objectOf_Policy.policy.maintenance.prebindings -eq $false -and 
    $objectOf_Policy.policy.maintenance.permissions -eq $false -and 
    $objectOf_Policy.policy.maintenance.byhost -eq $false -and 
    $objectOf_Policy.policy.maintenance.system_cache -eq $false -and 
    $objectOf_Policy.policy.maintenance.user_cache -eq $false -and 
    $objectOf_Policy.policy.maintenance.verify -eq $false -and 
    $objectOf_Policy.policy.files_processes.search_by_path.Length -eq 0 -and 
    $objectOf_Policy.policy.files_processes.delete_file -eq $false -and 
    $objectOf_Policy.policy.files_processes.locate_file.Length -eq 0 -and 
    $objectOf_Policy.policy.files_processes.update_locate_database -eq $false -and 
    $objectOf_Policy.policy.files_processes.spotlight_search.Length -eq $false -and 
    $objectOf_Policy.policy.files_processes.search_for_process.Length -eq 0 -and 
    $objectOf_Policy.policy.files_processes.kill_process -eq $false -and 
    $objectOf_Policy.policy.files_processes.run_command.Length -eq 0 -and 
    $objectOf_Policy.policy.disk_encryption.action -eq "none" ) {

        Write-host "  -> Does Nothing"
        policyOutputObject $objectOf_Policy "policy_NoConfiguration"
    }
}

function policyNoCategory($objectOf_Policy) {
    if ( $objectOf_Policy.policy.general.category.name -eq "No category assigned" ) {
        Write-host "  -> Has No Category"
        policyOutputObject $objectOf_Policy "policy_NoCategory"
    }
}

function policySSNoDescription($objectOf_Policy) {
    if ( $objectOf_Policy.policy.self_service.use_for_self_service -eq $true -and $objectOf_Policy.policy.self_service.self_service_description -eq "" ) {
        Write-host "  -> Has No Description"
        policyOutputObject $objectOf_Policy "policy_SSNoDescription"
    }
}

function policySSNoIcon($objectOf_Policy) {
    if ( $objectOf_Policy.policy.self_service.use_for_self_service -eq $true -and $objectOf_Policy.policy.self_service.self_service_icon.IsEmpty -ne $false) {
        Write-host "  -> Has No Icon"
        policyOutputObject $objectOf_Policy "policy_SSNoIcon"
    }
}

# Can't be done yet
function policyScopeAllUsers($objectOf_Policy) {
    if ( $objectOf_Policy.policy.scope.all_users -eq $true ) {
        Write-host "  -> Scoped to All Users"
        policyOutputObject $objectOf_Policy "policy_ScopeAllUsers"
    }
}

function policyOngoingEvent($objectOf_Policy) {
    if ( $objectOf_Policy.policy.general.frequency -eq "Ongoing" -and 
    $objectOf_Policy.policy.general.trigger -ne "USER_INITIATED" -and 
    $objectOf_Policy.policy.general.trigger_other.Length -eq 0 ) {

        if ( $objectOf_Policy.policy.scope.all_computers -eq $true ) {
            Write-host "  -> Ongoing Policy"
            policyOutputObject $objectOf_Policy "policy_OngoingEvent"
        }
        elseif ( $objectOf_Policy.policy.scope.computer_groups.IsEmpty -eq $false ) {

            ForEach ( $computerGroup in $objectOf_Policy.policy.scope.computer_groups.computer_group ) {
                if ( $($objectOf_AllComputerGroupDetails.SelectNodes("//computer_group") | Where-Object { $_.name -eq $($computerGroup.name) }).is_smart -eq $false ) {
                    $ongoingCheck = 1
                }
            }

            if ( $ongoingCheck -eq 1 ) {
                Write-host "  -> Ongoing Policy"
                policyOutputObject $objectOf_Policy "policy_OngoingEvent"
            }
        }
    }
}

function policyOngoingEventInventory($objectOf_Policy) {
    if ( $objectOf_Policy.policy.general.frequency -eq "Ongoing" -and 
    $objectOf_Policy.policy.general.trigger -ne "USER_INITIATED" -and 
    $objectOf_Policy.policy.general.trigger_other.Length -eq 0 -and 
    $objectOf_Policy.policy.maintenance.recon -eq $true ) {

        if ( $objectOf_Policy.policy.scope.all_computers -eq $true ) {
            Write-host "  -> Ongoing Inventory"
            policyOutputObject $objectOf_Policy "policy_OngoingEventInventory"
        }
        elseif ( $objectOf_Policy.policy.scope.computer_groups.IsEmpty -eq $false ) {

            ForEach ( $computerGroup in $objectOf_Policy.policy.scope.computer_groups.computer_group ) {
                if ( $($objectOf_AllComputerGroupDetails.SelectNodes("//computer_group") | Where-Object { $_.name -eq $($computerGroup.name) }).is_smart -eq $false ) {
                    $ongoingCheck = 1
                }
            }

            if ( $ongoingCheck -eq 1 ) {
                Write-host "  -> Ongoing Inventory"
                policyOutputObject $objectOf_Policy "policy_OngoingEventInventory"
            }
        }
    }
}

# Keeping for now
function policySiteLevelRecon($objectOf_Policy) {
    if ( $objectOf_Policy.policy.general.site.name -ne "None" -and $objectOf_Policy.policy.maintenance.recon -eq $true) {
        Write-host "  -> Site-Level Performs Inventory"
        policyOutputObject $objectOf_Policy "policy_SiteLevelRecon"
    }
}

# ============================================================
# Bits Staged...
# ============================================================

# Verify credentials that were provided by doing an API call and checking the result to verify permissions.
#Write-Host "Verifying API credentials..."
#Try {
#    $Response = Invoke-RestMethod -Uri "${jamfPS}/JSSResource/jssuser" -Method Get -Credential $APIcredentials -ErrorVariable RestError -ErrorAction SilentlyContinue
#}
#Catch {
#    $statusCode = $_.Exception.Response.StatusCode.value__
#    $statusDescription = $_.Exception.Response.StatusDescription
#
#    If ($statusCode -notcontains "200") {
#        Write-Host "ERROR:  Invalid Credentials or permissions."
#        Write-Host "Response:  ${statusCode}/${statusDescription}"
#        Write-Host "jamf_MoveSites Process:  FAILED"
#        Exit
#    }
#}

Write-Host "API Credentials Valid -- continuing..."


# Call getEndpoint function for each type needed
$objectOf_AllComputerGroupDetails = getEndpoint computer_group NoDetails $getComputerGroups $getComputerGroup
$objectOf_AllPoliciesDetails = getEndpoint policy FullDetails $getPolicies $getPolicy
#$objectOf_AllPrinters = getEndpoint printer NoDetails $getPrinters


# Call processEndpoints function to process each type
processEndpoints policy $objectOf_AllPoliciesDetails
#processEndpoints computer_group $objectOf_AllComputerGroupDetails

Write-Host ""
Write-Host "All Criteria has been processed."
Write-Host "jamf_Reporting Process:  COMPLETE"

