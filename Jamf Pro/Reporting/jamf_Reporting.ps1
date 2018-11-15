<#

Script Name:  jamf_Reporting.ps1
By:  Zack Thompson / Created:  11/6/2018
Version:  0.8.0 / Updated:  11/15/2018 / By:  ZT

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
        Write-Progress -Activity "Getting details for $($Record.LocalName) records..." -Status "Policy:  $(${Record}.id) / $(${Record}.name)" -PercentComplete (($Position/$xml_AllRecords.SelectNodes("//$($xml_AllRecords.FirstChild.NextSibling.LastChild.LocalName)").Count)*100)

        # Get the configuration of each Policy
        $xml_Record = Invoke-RestMethod -Uri "${urlDetails}/$(${Record}.id)" -Method Get -Headers @{"accept"="application/xml"} -Credential $APIcredentials
        $objectOf_AllRecordDetails.add($xml_Record) | Out-Null
        $Position++
    }
    return $objectOf_AllRecordDetails
}

function processEndpoints() {
    [cmdletbinding()]
    Param (
        [Parameter(Mandatory=$true,ValuefromPipeline)][System.Array]$typeOf_AllRecords,
        [Parameter(ValuefromPipeline)][System.Xml.XmlNode]$xmlOf_ComputerGroups,
        [Parameter(ValuefromPipeline)][System.Xml.XmlNode]$xmlOf_UnusedPrinters
    )

    # Using this object for two different tests, so need an "original" copy and one that will be modified
    $xmlOf_UnusedComputerGroups = $xmlOf_ComputerGroups
    
    ForEach ( $Record in $typeOf_AllRecords ) {
        Write-Progress -Activity "Checking all $($Record.FirstChild.NextSibling.LocalName)..." -Status "Policy:  $($Record.SelectSingleNode("//id").innerText) / $($Record.SelectSingleNode("//name").innerText)" -PercentComplete (($Position/$typeOf_AllRecords.Count)*100)
        # Write-host "$($Record.FirstChild.NextSibling.LocalName) ID $($Record.SelectSingleNode("$($Record.FirstChild.NextSibling.LocalName)//id").innerText) / $($Record.SelectSingleNode("$($Record.FirstChild.NextSibling.LocalName)//name").innerText):"
        
        if ( $($Record.FirstChild.NextSibling.LocalName) -eq "policy" ) {
            policyCriteria $Record $xmlOf_ComputerGroups
            $xmlOf_UnusedPrinters = printerUsage $Record $xmlOf_UnusedPrinters
            $xmlOf_UnusedComputerGroups = computerGroupUsage $Record $xmlOf_UnusedComputerGroups
        }
        elseif ( $($Record.FirstChild.NextSibling.LocalName) -eq "computer_group" ) {
            computerGroupCriteria $Record
            createReport $xmlOf_UnusedComputerGroups "computer_group"
        }
        
        if ($Position -eq $typeOf_AllRecords.Count) {
            createReport $xmlOf_UnusedPrinters "printer"
        }

        $Position++
    }
}

function createReport($outputObject, $Endpoint) {
    if ( !( Test-Path "${saveDirectory}\${folderDate}") ) {    
         Write-Host "Creating folder..."
         New-Item -Path "${saveDirectory}\${folderDate}" -ItemType Directory | Out-Null
    }

    # Export each Policy object to a file.
    if ( $Endpoint -eq "Policies" -or $Endpoint -eq "Computer Groups" ) {
        Export-Csv -InputObject $outputObject -Path "${saveDirectory}\${folderDate}\Report_${Endpoint}.csv" -Append -NoTypeInformation
    }
    else {
        ForEach-Object -InputObject $outputObject -Process { $_.SelectNodes("//$Endpoint") } | Export-Csv -Path "${saveDirectory}\${folderDate}\Report_Unused_${Endpoint}s.csv" -Append -NoTypeInformation
    }
}

# ============================================================
# Criteria Functions
# ============================================================

function policyCriteria($objectOf_Policy, $xmlOf_ComputerGroups) {

    $policy = New-Object PSObject -Property ([ordered]@{
        ID = $objectOf_Policy.policy.general.id
        Name = $objectOf_Policy.policy.general.name
        Site = $objectOf_Policy.policy.general.site.name
        "Self Service" = $objectOf_Policy.policy.self_service.use_for_self_service
    })

    # Checks if Policy is Disabled
    if ( $objectOf_Policy.policy.general.enabled -eq $false) {
        Add-Member -InputObject $policy -PassThru NoteProperty "Disabled" $true | Out-Null
    }
    else {
        Add-Member -InputObject $policy -PassThru NoteProperty "Disabled" $false | Out-Null
    }

    # Checks if Policy has no Scope
        # Cannot check for Scope of "All Users"
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

        Add-Member -InputObject $policy -PassThru NoteProperty "No Scope" $true | Out-Null
    }
    else {
        Add-Member -InputObject $policy -PassThru NoteProperty "No Scope" $false | Out-Null
    }

    # Checks if Policy has no Configured Items
        # Cannot check for Softare Updates or Restart Payloads
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

        Add-Member -InputObject $policy -PassThru NoteProperty "No Configuration" $true | Out-Null
    }
    else {
        Add-Member -InputObject $policy -PassThru NoteProperty "No Configuration" $false | Out-Null
    }

    # Checks if Policy does not have a Category Set
    if ( $objectOf_Policy.policy.general.category.name -eq "No category assigned" ) {
        Add-Member -InputObject $policy -PassThru NoteProperty "No Category" $true | Out-Null
    }
    else {
        Add-Member -InputObject $policy -PassThru NoteProperty "No Category" $false | Out-Null
    }

    # Checks if a Self Service Policy has a Description

    if ( $objectOf_Policy.policy.self_service.use_for_self_service -eq $true -and $objectOf_Policy.policy.self_service.self_service_description -eq "" ) {
        Add-Member -InputObject $policy -PassThru NoteProperty "SS No Description" $true | Out-Null
    }
    else {
        Add-Member -InputObject $policy -PassThru NoteProperty "SS No Description" $false | Out-Null
    }

    # Checks if a Self Service Policy has an Icon selected

    if ( $objectOf_Policy.policy.self_service.use_for_self_service -eq $true -and $objectOf_Policy.policy.self_service.self_service_icon.IsEmpty -ne $false) {
        Add-Member -InputObject $policy -PassThru NoteProperty "SS No Icon" $true | Out-Null
    }
    else {
        Add-Member -InputObject $policy -PassThru NoteProperty "SS No Icon" $false | Out-Null
    }

    # Checks if a Polcy is scoped to only "All Users"
        # Can't be done yet
#    if ( $objectOf_Policy.policy.scope.all_users -eq $true -and # This line is just an example, there isn't an actual element by this name
#     $objectOf_Policy.policy.scope.all_computers -eq $false -and 
#    $objectOf_Policy.policy.scope.computers.Length -eq 0 -and 
#    $objectOf_Policy.policy.scope.computer_groups.Length -eq 0 -and 
#    $objectOf_Policy.policy.scope.buildings.Length -eq 0 -and
#    $objectOf_Policy.policy.scope.departments.Length -eq 0 -and 
#    $objectOf_Policy.policy.scope.limit_to_users.user_groups.Length -eq 0 -and 
#    $objectOf_Policy.policy.scope.limitations.users.Length -eq 0 -and 
#    $objectOf_Policy.policy.scope.limitations.user_groups.Length -eq 0 -and 
#    $objectOf_Policy.policy.scope.limitations.network_segments.Length -eq 0 -and 
#    $objectOf_Policy.policy.scope.limitations.ibeacons.Length -eq 0 -and 
#    $objectOf_Policy.policy.scope.exclusions.computers.Length -eq 0 -and 
#    $objectOf_Policy.policy.scope.exclusions.computer_groups.computer_group.Length -eq 0 -and 
#    $objectOf_Policy.policy.scope.exclusions.buildings.Length -eq 0 -and 
#    $objectOf_Policy.policy.scope.exclusions.departments.Length -eq 0 -and 
#    $objectOf_Policy.policy.scope.exclusions.users.Length -eq 0 -and 
#    $objectOf_Policy.policy.scope.exclusions.user_groups.Length -eq 0 -and 
#    $objectOf_Policy.policy.scope.exclusions.network_segments.Length -eq 0 -and 
#    $objectOf_Policy.policy.scope.exclusions.ibeacons.Length -eq 0 ) {   
#
#        Add-Member -InputObject $policy -PassThru NoteProperty "Scope AllUsers" $true | Out-Null
#    }
#    else {
#        Add-Member -InputObject $policy -PassThru NoteProperty "Scope AllUsers" $false | Out-Null
#    }

    # Checks if a Policy is configured for an Ongoing Event (that's not Enrollment) and has a scope that is not a Smart Group
    if ( $objectOf_Policy.policy.general.frequency -eq "Ongoing" -and 
    $objectOf_Policy.policy.general.trigger -ne "USER_INITIATED" -and 
    $objectOf_Policy.policy.general.trigger_other.Length -eq 0 ) {

        if ( $objectOf_Policy.policy.scope.all_computers -eq $true ) {
            Add-Member -InputObject $policy -PassThru NoteProperty "Ongoing Event" $true | Out-Null
        }
        elseif ( $objectOf_Policy.policy.scope.computer_groups.IsEmpty -eq $false ) {

            ForEach ( $computerGroup in $objectOf_Policy.policy.scope.computer_groups.computer_group ) {
                if ( $($xmlOf_ComputerGroups.SelectNodes("//computer_group") | Where-Object { $_.name -eq $($computerGroup.name) }).is_smart -eq $false ) {
                    $ongoingCheck = 1
                }
            }

            if ( $ongoingCheck -eq 1 ) {
                Add-Member -InputObject $policy -PassThru NoteProperty "Ongoing Event" $true | Out-Null
            }
            else {
                Add-Member -InputObject $policy -PassThru NoteProperty "Ongoing Event" $false | Out-Null
            }
        }
        else {
            Add-Member -InputObject $policy -PassThru NoteProperty "Ongoing Event" $false | Out-Null
        }
    }
    else {
        Add-Member -InputObject $policy -PassThru NoteProperty "Ongoing Event" $false | Out-Null
    }

    # Checks if a Policy is configured for an Ongoing Event (that's not Enrollment) and has a scope that is not a Smart Group and Performs Inventory
    if ( $objectOf_Policy.policy.general.frequency -eq "Ongoing" -and 
    $objectOf_Policy.policy.general.trigger -ne "USER_INITIATED" -and 
    $objectOf_Policy.policy.general.trigger_other.Length -eq 0 -and 
    $objectOf_Policy.policy.maintenance.recon -eq $true ) {

        if ( $objectOf_Policy.policy.scope.all_computers -eq $true ) {
            Add-Member -InputObject $policy -PassThru NoteProperty "Ongoing Event Inventory" $true | Out-Null
        }
        elseif ( $objectOf_Policy.policy.scope.computer_groups.IsEmpty -eq $false ) {

            ForEach ( $computerGroup in $objectOf_Policy.policy.scope.computer_groups.computer_group ) {
                if ( $($xmlOf_ComputerGroups.SelectNodes("//computer_group") | Where-Object { $_.name -eq $($computerGroup.name) }).is_smart -eq $false ) {
                    $ongoingCheck = 1
                }
            }

            if ( $ongoingCheck -eq 1 ) {
                Add-Member -InputObject $policy -PassThru NoteProperty "Ongoing Event Inventory" $true | Out-Null
            }
            else {
                Add-Member -InputObject $policy -PassThru NoteProperty "Ongoing Event Inventory" $false | Out-Null
            }
        }
        else {
            Add-Member -InputObject $policy -PassThru NoteProperty "Ongoing Event Inventory" $false | Out-Null
        }
    }
    else {
        Add-Member -InputObject $policy -PassThru NoteProperty "Ongoing Event Inventory" $false | Out-Null
    }

    # Checks if a Site-Level Policy performs a Inventory
        # Keeping for now
#    if ( $objectOf_Policy.policy.general.site.name -ne "None" -and $objectOf_Policy.policy.maintenance.recon -eq $true) {
#        Add-Member -InputObject $policy -PassThru NoteProperty "Site Level Recon" $true | Out-Null
#    }
#    else {
#        Add-Member -InputObject $policy -PassThru NoteProperty "Site Level Recon" $false | Out-Null
#    }


    createReport $policy "Policies"

}

# Checks if a Printer is used in a Policy and removes it from the complete list of printers, to find unused printers
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

# Checks if a Computer Group is used in a Policy and removes it from the complete list of computer groups, to find unused computer groups
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

# Computer Group Criteria
function computerGroupCriteria($objectOf_ComputerGroup){

    $computerGroup = New-Object PSObject -Property ([ordered]@{
        ID = $objectOf_ComputerGroup.computer_group.id
        Name = $objectOf_ComputerGroup.computer_group.name
        Site = $objectOf_ComputerGroup.computer_group.site.name
        "Smart Group" = $objectOf_ComputerGroup.computer_group.is_smart
    })

    if ( $objectOf_ComputerGroup.computer_group.computers.size -eq 0 ) {
        Add-Member -InputObject $computerGroup -PassThru NoteProperty "Empty" $true | Out-Null
    }
    else {
        Add-Member -InputObject $computerGroup -PassThru NoteProperty "Empty" $false | Out-Null
    }

    if ( $objectOf_ComputerGroup.computer_group.criteria.size -eq 0 ) {
        Add-Member -InputObject $computerGroup -PassThru NoteProperty "No Criteria" $true | Out-Null
    }
    else {
        Add-Member -InputObject $computerGroup -PassThru NoteProperty "No Criteria" $false | Out-Null
    }

    if ( [int]$objectOf_ComputerGroup.computer_group.criteria.size -ge 10 ) {
        Add-Member -InputObject $computerGroup -PassThru NoteProperty "10+ Criteria" $true | Out-Null
    }
    else {
        Add-Member -InputObject $computerGroup -PassThru NoteProperty "10+ Criteria" $false | Out-Null
    }
 
    createReport $computerGroup "Computer Groups"  
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
$xmlArray_AllComputerGroupsDetails = $xml_AllComputerGroups | getEndpointDetails $getComputerGroup

# Call processEndpoints function to process each type
processEndpoints $xmlArray_AllPoliciesDetails $xml_AllComputerGroups $xml_AllPrinters
processEndpoints $xmlArray_AllComputerGroupsDetails

Write-Host ""
Write-Host "All Criteria has been processed."
Write-Host "jamf_Reporting Process:  COMPLETE"

