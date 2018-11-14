<#

Script Name:  jamf_Reporting.ps1
By:  Zack Thompson / Created:  11/6/2018
Version:  0.6.0 / Updated:  11/14/2018 / By:  ZT

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


$folderDate=$(Get-Date -Format FileDateTime)
$saveDirectory = ($(Read-Host "Provide directiory to save the report") -replace '"')
$Position = 1

# Set the session to use TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ============================================================
# Logic Functions
# ============================================================

function getEndpoint($Endpoint, $urlAll) {
    # Get all records
    Write-host "Querying:  ${Endpoint}"
    $xml_AllRecords = Invoke-RestMethod -Uri "${urlAll}" -Method Get -Headers @{"accept"="application/xml"} -Credential $APIcredentials

    return $xml_AllRecords
}

function getEndpointDetails () {
    [cmdletbinding()]
    Param (
        [Parameter(ValuefromPipeline)][String]$urlDetails,
        [Parameter(ValuefromPipeline)][Xml]$xml_AllRecords      
    )

    $objectOf_AllRecordDetails = New-Object System.Collections.Arraylist

    # Loop through each endpoint
    ForEach ( $Record in $xml_AllRecords.SelectNodes("//$($xml_AllRecords.FirstChild.NextSibling.LastChild.LocalName)") ) {
        Write-Progress -Activity "Processing $($Record.LocalName) records..." -Status "Policy:  $(${Record}.id) / $(${Record}.name)" -PercentComplete (($Position/$xml_AllRecords.SelectNodes("//$($xml_AllRecords.FirstChild.NextSibling.LastChild.LocalName)").Count)*100)

        # Get the configuration of each Policy
        $xml_Record = Invoke-RestMethod -Uri "${urlDetails}/$(${Record}.id)" -Method Get -Headers @{"accept"="application/xml"} -Credential $APIcredentials
        $objectOf_AllRecordDetails.add($xml_Record) | Out-Null
        $Position++
    }
    return $objectOf_AllRecordDetails
}

function processEndpoints($typeOf_AllRecords, $xmlOf_UnusedComputerGroups, $xmlOf_UnusedPrinters) {
    ForEach ( $Record in $typeOf_AllRecords ) {
        Write-Progress -Activity "Testing all Policies..." -Status "Policy:  $(${Record}.SelectNodes("//general").id) / $(${Record}.SelectNodes("//general").name)" -PercentComplete (($Position/$typeOf_AllRecords.Count)*100)
        #Write-host "Policy ID $(${Record}.policy.general.id):"
        policyFunctionsToRun $Record
        $xmlOf_UnusedPrinters = printerUsage $Record $xmlOf_UnusedPrinters
        $xmlOf_UnusedComputerGroups = computerGroupUsage $Record $xmlOf_UnusedComputerGroups
        $Position++
    }
    createReport $xmlOf_UnusedPrinters "printer"
    createReport $xmlOf_UnusedComputerGroups "computer_group"
}

function policyFunctionsToRun($objectOf_Policy) {
    # Build the object for this policy
    $policy = build_PolicyObject $objectOf_Policy

    $policy = policyDisabled $objectOf_Policy $policy
    $policy = policyNoScope $objectOf_Policy $policy
    ### Cannot be determined at this time. ### $policy = policyScopeAllUsers $objectOf_Policy $policy
    $policy = policyNoConfig $objectOf_Policy $policy
    $policy = policyNoCategory $objectOf_Policy $policy
    $policy = policySSNoDescription $objectOf_Policy $policy
    $policy = policySSNoIcon $objectOf_Policy $policy
    # $policy = policySiteLevelRecon $objectOf_Policy $policy
    #$policy = policyOngoingEvent $objectOf_Policy $policy
    #$policy = policyOngoingEventInventory $objectOf_Policy $policy

    createReport $policy "Policies"
}

function build_PolicyObject($objectOf_Policy) {
    $policy = New-Object PSObject -Property ([ordered]@{
        ID = $objectOf_Policy.policy.general.id
        Name = $objectOf_Policy.policy.general.name
        Site = $objectOf_Policy.policy.general.site.name
        "Self Service" = $objectOf_Policy.policy.self_service.use_for_self_service
    })

    return $policy
}

function createReport($outputObject, $Endpoint) {
    
    if ( !( Test-Path "${saveDirectory}\${folderDate}") ) {    
         Write-Host "Creating folder..."
         New-Item -Path "${saveDirectory}\${folderDate}" -ItemType Directory | Out-Null
    }

    # Export each Policy object to a file.
    if ( $Endpoint -eq "Policies" ) {
        Export-Csv -InputObject $outputObject -Path "${saveDirectory}\${folderDate}\Report_${Endpoint}.csv" -Append -NoTypeInformation
    }
    else {
        ForEach-Object -InputObject $outputObject -Process { $_.SelectNodes("//$Endpoint") } | Export-Csv -Path "${saveDirectory}\${folderDate}\Report_${Endpoint}s.csv" -Append -NoTypeInformation
    }
}

# ============================================================
# Criteria Functions
# ============================================================

function policyDisabled($objectOf_Policy, $policy) {
    if ( $objectOf_Policy.policy.general.enabled -eq $false) {
        return $policy | Add-Member -PassThru NoteProperty "Disabled" $true
    }
    else {
        return $policy | Add-Member -PassThru NoteProperty "Disabled" $false
    }
}

function policyNoScope($objectOf_Policy, $policy) {
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

        return $policy | Add-Member -PassThru NoteProperty "No Scope" $true
    }
    else {
        return $policy | Add-Member -PassThru NoteProperty "No Scope" $false
    }
}

function policyNoConfig($objectOf_Policy, $policy) {
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

        return $policy | Add-Member -PassThru NoteProperty "No Configuration" $true
    }
    else {
        return $policy | Add-Member -PassThru NoteProperty "No Configuration" $false
    }
}

function policyNoCategory($objectOf_Policy, $policy) {
    if ( $objectOf_Policy.policy.general.category.name -eq "No category assigned" ) {
        return $policy | Add-Member -PassThru NoteProperty "No Category" $true
    }
    else {
        return $policy | Add-Member -PassThru NoteProperty "No Category" $false
    }
}

function policySSNoDescription($objectOf_Policy, $policy) {
    if ( $objectOf_Policy.policy.self_service.use_for_self_service -eq $true -and $objectOf_Policy.policy.self_service.self_service_description -eq "" ) {
        return $policy | Add-Member -PassThru NoteProperty "SS No Description" $true
    }
    else {
        return $policy | Add-Member -PassThru NoteProperty "SS No Description" $false
    }
}

function policySSNoIcon($objectOf_Policy, $policy) {
    if ( $objectOf_Policy.policy.self_service.use_for_self_service -eq $true -and $objectOf_Policy.policy.self_service.self_service_icon.IsEmpty -ne $false) {
        return $policy | Add-Member -PassThru NoteProperty "SS No Icon" $true
    }
    else {
        return $policy | Add-Member -PassThru NoteProperty "SS No Icon" $false
    }
}

# Can't be done yet
function policyScopeAllUsers($objectOf_Policy, $policy) {
    if ( $objectOf_Policy.policy.scope.all_users -eq $true ) {
        return $policy | Add-Member -PassThru NoteProperty "Scope AllUsers" $true
    }
    else {
        return $policy | Add-Member -PassThru NoteProperty "Scope AllUsers" $false
    }
}

function policyOngoingEvent($objectOf_Policy, $policy) {
    if ( $objectOf_Policy.policy.general.frequency -eq "Ongoing" -and 
    $objectOf_Policy.policy.general.trigger -ne "USER_INITIATED" -and 
    $objectOf_Policy.policy.general.trigger_other.Length -eq 0 ) {

        if ( $objectOf_Policy.policy.scope.all_computers -eq $true ) {
            return $policy | Add-Member -PassThru NoteProperty "Ongoing Event" $true
        }
        elseif ( $objectOf_Policy.policy.scope.computer_groups.IsEmpty -eq $false ) {

            ForEach ( $computerGroup in $objectOf_Policy.policy.scope.computer_groups.computer_group ) {
                if ( $($xml_AllComputerGroups.SelectNodes("//computer_group") | Where-Object { $_.name -eq $($computerGroup.name) }).is_smart -eq $false ) {
                    $ongoingCheck = 1
                }
            }

            if ( $ongoingCheck -eq 1 ) {
                return $policy | Add-Member -PassThru NoteProperty "Ongoing Event" $true
            }
            else {
                return $policy | Add-Member -PassThru NoteProperty "Ongoing Event" $false
            }
        }
        else {
            return $policy | Add-Member -PassThru NoteProperty "Ongoing Event" $false
        }
    }
    else {
        return $policy | Add-Member -PassThru NoteProperty "Ongoing Event" $false
    }
}

function policyOngoingEventInventory($objectOf_Policy, $policy) {
    if ( $objectOf_Policy.policy.general.frequency -eq "Ongoing" -and 
    $objectOf_Policy.policy.general.trigger -ne "USER_INITIATED" -and 
    $objectOf_Policy.policy.general.trigger_other.Length -eq 0 -and 
    $objectOf_Policy.policy.maintenance.recon -eq $true ) {

        if ( $objectOf_Policy.policy.scope.all_computers -eq $true ) {
            return $policy | Add-Member -PassThru NoteProperty "Ongoing Event Inventory" $true
        }
        elseif ( $objectOf_Policy.policy.scope.computer_groups.IsEmpty -eq $false ) {

            ForEach ( $computerGroup in $objectOf_Policy.policy.scope.computer_groups.computer_group ) {
                if ( $($xml_AllComputerGroups.SelectNodes("//computer_group") | Where-Object { $_.name -eq $($computerGroup.name) }).is_smart -eq $false ) {
                    $ongoingCheck = 1
                }
            }

            if ( $ongoingCheck -eq 1 ) {
                return $policy | Add-Member -PassThru NoteProperty "Ongoing Event Inventory" $true
            }
            else {
                return $policy | Add-Member -PassThru NoteProperty "Ongoing Event Inventory" $false
            }
        }
        else {
            return $policy | Add-Member -PassThru NoteProperty "Ongoing Event Inventory" $false
        }
    }
    else {
        return $policy | Add-Member -PassThru NoteProperty "Ongoing Event Inventory" $false
    }
}

# Keeping for now
function policySiteLevelRecon($objectOf_Policy, $policy) {
    if ( $objectOf_Policy.policy.general.site.name -ne "None" -and $objectOf_Policy.policy.maintenance.recon -eq $true) {
        return $policy | Add-Member -PassThru NoteProperty "Site Level Recon" $true
    }
    else {
        return $policy | Add-Member -PassThru NoteProperty "Site Level Recon" $false
    }
}


function printerUsage($objectOf_Policy, $xmlOf_UnusedPrinters) {
   if ( $objectOf_Policy.policy.printers.size -ne 0 ) {
#        Write-Host "Printer Size not 0"
        ForEach ( $Printer in $objectOf_Policy.policy.printers.printer ) {
            if ( $xmlOf_UnusedPrinters.printers.printer | Where-Object { $_.id -eq $($Printer.id) } ) {
#                Write-Host "If printer object equals printer ID"
#                Write-Host "Policy ID $($objectOf_Policy.policy.general.id) uses: Printer $($Printer.id) / $($Printer.name)"
                $Remove = $xmlOf_UnusedPrinters.printers.printer | Where-Object { $_.id -eq $($Printer.id) }
                $Remove.ParentNode.RemoveChild($Remove) | Out-Null
            }
        }
    }
    return $xmlOf_UnusedPrinters
}

function computerGroupUsage($objectOf_Policy, $xmlOf_UnusedComputerGroups) {

   if ( $objectOf_Policy.policy.scope.computer_groups.IsEmpty -eq $false ) {
        ForEach ( $computerGroup in $objectOf_Policy.policy.scope.computer_groups.computer_group ) {
            # Write-Host "Policy ID $($objectOf_Policy.policy.general.id) uses:  Computer Group $($computerGroup.id) / $($computerGroup.name)"

            if ( $xmlOf_UnusedComputerGroups.computer_groups.computer_group | Where-Object { $_.id -eq $($computerGroup.id) } ) {
                $Remove = $xmlOf_UnusedComputerGroups.computer_groups.computer_group | Where-Object { $_.id -eq $($computerGroup.id) }
                $Remove.ParentNode.RemoveChild($Remove) | Out-Null
            }
        }
    }
    return $xmlOf_UnusedComputerGroups
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
$xml_AllComputerGroups = getEndpoint "Computer Groups" $getComputerGroups
$xml_AllPrinters = getEndpoint "Printers" $getPrinters
$xmlArray_AllPoliciesDetails = getEndpoint "Policies" $getPolicies | getEndpointDetails $getPolicy
$xml_AllComputerGroupsDetails = $xml_AllComputerGroups | getEndpointDetails $getComputerGroup

# Call processEndpoints function to process each type
processEndpoints $xmlArray_AllPoliciesDetails $xml_AllComputerGroups $xml_AllPrinters
#processEndpoints $xml_AllComputerGroupDetails

Write-Host ""
Write-Host "All Criteria has been processed."
Write-Host "jamf_Reporting Process:  COMPLETE"

