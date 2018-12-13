<#

Script Name:  jamf_Audit.ps1
By:  Zack Thompson / Created:  11/6/2018
Version:  1.8.0 / Updated:  12/13/2018 / By:  ZT

Description:  This script is used to generate reports on specific configurations.

#>

Write-Host "jamf_Audit Process:  START"
Write-Host ""

# ============================================================
# Define Variables
# ============================================================

# Setup Credentials
$jamfAPIUser = $( Read-Host "JPS Account" )
$jamfAPIPassword = $( Read-Host -AsSecureString "JPS Password" )
$APIcredentials = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $jamfAPIUser, $jamfAPIPassword

# Setup API URLs
$jamfPS = "https://jps.company.com:8443"
$getSites = "${jamfPS}/JSSResource/sites"
$getPolicies = "${jamfPS}/JSSResource/policies/createdBy/jss"
$getPolicy = "${jamfPS}/JSSResource/policies/id"
$getComputerGroups = "${jamfPS}/JSSResource/computergroups"
$getComputerGroup = "${jamfPS}/JSSResource/computergroups/id"
$getPrinters = "${jamfPS}/JSSResource/printers"
$getComputerConfigProfiles = "${jamfPS}/JSSResource/osxconfigurationprofiles"
$getComputerConfigProfile = "${jamfPS}/JSSResource/osxconfigurationprofiles/id"
$getRestrictedSoftwareItems = "${jamfPS}/JSSResource/restrictedsoftware"
$getRestrictedSoftwareItem = "${jamfPS}/JSSResource/restrictedsoftware/id"
$getComputerAppStoreApps = "${jamfPS}/JSSResource/macapplications"
$getComputerAppStoreApp = "${jamfPS}/JSSResource/macapplications/id"
$getPatchPolicies = "${jamfPS}/JSSResource/patchpolicies"
$getPatchPolicy = "${jamfPS}/JSSResource/patchpolicies/id"
$geteBooks = "${jamfPS}/JSSResource/ebooks"
$geteBook = "${jamfPS}/JSSResource/ebooks/id"
$getMobileDeviceGroups = "${jamfPS}/JSSResource/mobiledevicegroups"
$getMobileDeviceGroup = "${jamfPS}/JSSResource/mobiledevicegroups/id"
$getMobileDeviceConfigProfiles = "${jamfPS}/JSSResource/mobiledeviceconfigurationprofiles"
$getMobileDeviceConfigProfile = "${jamfPS}/JSSResource/mobiledeviceconfigurationprofiles/id"
$getMobileDeviceAppStoreApps = "${jamfPS}/JSSResource/mobiledeviceapplications"
$getMobileDeviceAppStoreApp = "${jamfPS}/JSSResource/mobiledeviceapplications/id"
$iTunesAPI = "https://uclient-api.itunes.apple.com/WebObjects/MZStorePlatform.woa/wa/lookup?version=1&p=mdm-lockup&caller=MDM&cc=us&l=en&id="

# Setup Save Directory
$folderDate=$( Get-Date -UFormat %m-%d-%y )
$saveDirectory = ( $( Read-Host "Provide directiory to save the report" ) -replace '"' )

# Set the session to use TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Setup a Json.NET/JavaScriptSerializer Object
# Credit to:  https://kevinmarquette.github.io/2016-11-06-powershell-hashtable-everything-you-wanted-to-know-about/
# And:  https://unhandled.wordpress.com/2016/12/18/powershell-performance-tip-use-javascriptserializer-instead-of-convertto-json/
Add-Type -AssemblyName System.Web.Extensions
$jsonSerializer = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer

# Miscellaneous Variables
$usedComputerGroups = @()
$usedPackages = @()
$usedMobileDeviceGroups = @()
$Position = 1

# ============================================================
# Logic Functions
# ============================================================

# This Function gets an inital list of all Endpoints.
function getEndpoint($Endpoint, $urlAll) {
    Write-host "Querying:  ${Endpoint}"

    # Get all records
    Try {
        $xml_AllRecords = Invoke-RestMethod -Uri "${urlAll}" -Method Get -Headers @{"accept"="application/xml"} -Credential $APIcredentials
    }
    Catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $statusDescription = $_.Exception.Response.StatusDescription

        If ($statusCode -notcontains "200") {
           " -> Failed to get information for $($Record.LocalName) ID:  $(${Record}.id)" | ForEach-Object { Write-Host $_ ; Out-File -FilePath "${saveDirectory}\${folderDate}\errors.txt" -InputObject $_ -Append }
            "  --> Response:  ${statusCode} / $($RestError.Message | ForEach { $_.Split([Environment]::NewLine)[5];})" | ForEach-Object { Write-Host $_ ; Out-File -FilePath "${saveDirectory}\${folderDate}\errors.txt" -InputObject $_ -Append }
        }
    }
    return $xml_AllRecords
}

# This Function takes the results of the inital function and gets each records details, adding them to an Array.
function getEndpointDetails() {
    [cmdletbinding()]
    Param (
        [Parameter(ValuefromPipeline)][String]$urlDetails,
        [Parameter(ValuefromPipeline)][Xml]$xml_AllRecords
    )
    
    if ( $xml_AllRecords.FirstChild.NextSibling.size -ne 0 ) {
        $objectOf_AllRecordDetails = New-Object System.Collections.Arraylist

        # Loop through each endpoint
        ForEach ( $Record in $xml_AllRecords.SelectNodes("//$($xml_AllRecords.FirstChild.NextSibling.LastChild.LocalName)") ) {
            Write-Progress -Activity "Getting details for $($Record.LocalName) records..." -Status "Record:  $(${Record}.id) / $(${Record}.name)" -PercentComplete (($Position/$xml_AllRecords.SelectNodes("//$($xml_AllRecords.FirstChild.NextSibling.LastChild.LocalName)").Count)*100)
            #Write-Host "Getting details for $($Record.LocalName) records..." -Status "Policy:  $(${Record}.id) / $(${Record}.name)"

            # Get the configuration of each record.
            Try {
                $xml_Record = Invoke-RestMethod -Uri "${urlDetails}/$(${Record}.id)" -Method Get -Headers @{"accept"="application/xml"} -Credential $APIcredentials -ErrorVariable RestError -ErrorAction SilentlyContinue
                $objectOf_AllRecordDetails.add($xml_Record) | Out-Null
            }
            Catch {
                $statusCode = $_.Exception.Response.StatusCode.value__
                $statusDescription = $_.Exception.Response.StatusDescription

                If ($statusCode -notcontains "200") {
                    " -> Failed to get information for $($Record.LocalName) ID:  $(${Record}.id)" | ForEach-Object { Write-Host $_ ; Out-File -FilePath "${saveDirectory}\${folderDate}\errors.txt" -InputObject $_ -Append }
                    "  --> Response:  ${statusCode} / $($RestError.Message | ForEach { $_.Split([Environment]::NewLine)[5];})" | ForEach-Object { Write-Host $_ ; Out-File -FilePath "${saveDirectory}\${folderDate}\errors.txt" -InputObject $_ -Append }
                }
            }
            $Position++
        }
        return $objectOf_AllRecordDetails
    }
}

# This Function processes individual records from a list of record objects, over defined criteria.
function processEndpoints() {
    [cmdletbinding()]
    Param (
        [Parameter(Mandatory=$true,ValuefromPipeline)][AllowNull()][System.Array]$typeOf_AllRecords,
        [Parameter(ValuefromPipeline)][System.Xml.XmlNode]$xmlOf_ComputerGroups,
        [Parameter(ValuefromPipeline)][System.Xml.XmlNode]$xmlOf_UnusedPrinters
    )
    
    if ( $typeOf_AllRecords -ne $null ) {    
        $usedObjects = @()

        ForEach ( $Record in $typeOf_AllRecords ) {
            Write-Progress -Activity "Checking all $($Record.FirstChild.NextSibling.LocalName)..." -Status "Record:  $($Record.SelectSingleNode("//id").innerText) / $($Record.SelectSingleNode("//name").innerText)" -PercentComplete (($Position/$typeOf_AllRecords.Count)*100)
            # Write-host "$($Record.FirstChild.NextSibling.LocalName) ID $($Record.SelectSingleNode("$($Record.FirstChild.NextSibling.LocalName)//id").innerText) / $($Record.SelectSingleNode("$($Record.FirstChild.NextSibling.LocalName)//name").innerText):"
        
            if ( $($Record.FirstChild.NextSibling.LocalName) -eq "computer_group" -or $($Record.FirstChild.NextSibling.LocalName) -eq "mobile_device_group" ) {
                $usedObjects += groupCriteria $Record $typeOf_AllRecords
            }
            else {
                if ( $($Record.FirstChild.NextSibling.LocalName) -eq "policy" ) {
                    $usedObjects += policyCriteria $Record $xmlOf_ComputerGroups
                }
                elseif ( $($Record.FirstChild.NextSibling.LocalName) -eq "mac_application"  -or $($Record.FirstChild.NextSibling.LocalName) -eq "mobile_device_application" ) {
                    appStoreAppCriteria $Record
                }
                $usedObjects += groupUsage $Record
            }
            $Position++
        }
    }
    return $usedObjects
}

# This Function is used to find unused objects and then write them to a report.
function findUnusedObjects() {
        [cmdletbinding()]
    Param (
        [Parameter(Mandatory=$true,ValuefromPipeline)][AllowNull()][System.Array]$typeOf_AllObjects,
        [Parameter(Mandatory=$true,ValuefromPipeline)][AllowNull()][System.Array]$usedObjects,
        [Parameter(ValuefromPipeline)][String]$Type
        #[Parameter(Mandatory=$true,ValuefromPipeline)][String]$id
    )
    Process {
        $( $typeOf_AllObjects.SelectNodes("//$($Type)") | Where-Object { $_.id -in $( Compare-Object -ReferenceObject $($($typeOf_AllObjects.SelectNodes("//$($Type)")).id) -DifferenceObject $( $($usedObjects).id | Sort-Object -Unique ) | Where-Object { $_.SideIndicator -eq '<=' } | ForEach-Object { $_.InputObject } ) } | Select-Object id, name, @{Name="site"; Expression={$_.site.name}}, is_smart ) | createReport -Endpoint "Unused_$($Type)"
    }
}

# This Function creates files from the results of the defined criteria.
function createReport() {
        [cmdletbinding()]
    Param (
        [Parameter(ValuefromPipeline)][String]$Endpoint,
        [Parameter(Mandatory=$true,ValuefromPipeline)]$outputObject
    )
    Process {
        Export-Csv -InputObject $outputObject -Path "${saveDirectory}\${folderDate}\Report_${Endpoint}.csv" -Append -NoTypeInformation
    }
}

# ============================================================
# Criteria Functions
# ============================================================

# This Function checks criteria that is configured within a Policy object.
function policyCriteria($objectOf_Policy, $xmlOf_ComputerGroups) {

    # Build an object for this policy record.
    $policy = New-Object PSObject -Property ([ordered]@{
        ID = $objectOf_Policy.policy.general.id
        Name = $objectOf_Policy.policy.general.name
        Site = $objectOf_Policy.policy.general.site.name
        "Self Service" = $objectOf_Policy.policy.self_service.use_for_self_service
    })

    # Checks if Policy is Disabled.
    if ( $objectOf_Policy.policy.general.enabled -eq $false ) {
        Add-Member -InputObject $policy -PassThru NoteProperty "Disabled" $true | Out-Null
    }
    else {
        Add-Member -InputObject $policy -PassThru NoteProperty "Disabled" $false | Out-Null
    }

    # Checks if Policy has no Scope.
        # Cannot check for Scope of "All Users".
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

    # Checks if Policy has no Configured Items.
        # Cannot check for Softare Updates or Restart Payloads.
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

    # Checks if Policy does not have a Category Set.
    if ( $objectOf_Policy.policy.general.category.name -eq "No category assigned" ) {
        Add-Member -InputObject $policy -PassThru NoteProperty "No Category" $true | Out-Null
    }
    else {
        Add-Member -InputObject $policy -PassThru NoteProperty "No Category" $false | Out-Null
    }

    # Checks if a Self Service Policy has a Description.
    if ( $objectOf_Policy.policy.self_service.use_for_self_service -eq $true -and $objectOf_Policy.policy.self_service.self_service_description -eq "" ) {
        Add-Member -InputObject $policy -PassThru NoteProperty "SS No Description" $true | Out-Null
    }
    else {
        Add-Member -InputObject $policy -PassThru NoteProperty "SS No Description" $false | Out-Null
    }

    # Checks if a Self Service Policy has an Icon selected.
    if ( $objectOf_Policy.policy.self_service.use_for_self_service -eq $true -and $objectOf_Policy.policy.self_service.self_service_icon.IsEmpty -ne $false ) {
        Add-Member -InputObject $policy -PassThru NoteProperty "SS No Icon" $true | Out-Null
    }
    else {
        Add-Member -InputObject $policy -PassThru NoteProperty "SS No Icon" $false | Out-Null
    }

    # Checks if a Polcy is scoped to only "All Users".
        # Can't be done yet.
#    if ( $objectOf_Policy.policy.scope.all_users -eq $true -and # This line is just an example, there isn't an actual element by this name.
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

    # Checks if a Policy is configured for an Ongoing Event (that's not Enrollment) and has a scope that is not a Smart Group.
    if ( $objectOf_Policy.policy.general.frequency -eq "Ongoing" -and 
    $objectOf_Policy.policy.general.trigger -ne "USER_INITIATED" -and 
    $objectOf_Policy.policy.general.trigger_other.Length -eq 0 ) {

        if ( $objectOf_Policy.policy.scope.all_computers -eq $true ) {
            Add-Member -InputObject $policy -PassThru NoteProperty "Ongoing Event" $true | Out-Null
        }
        elseif ( $objectOf_Policy.policy.scope.computer_groups.IsEmpty -eq $false ) {

            ForEach ( $computerGroup in $objectOf_Policy.policy.scope.computer_groups.computer_group ) {
                if ( $($xmlOf_ComputerGroups.SelectNodes("//computer_group") | Where-Object { $_.name -eq $($computerGroup.name) } ).is_smart -eq $false ) {
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

    # Checks if a Policy is configured for an Ongoing Event (that's not Enrollment) and has a scope that is not a Smart Group and Performs Inventory.
    if ( $objectOf_Policy.policy.general.frequency -eq "Ongoing" -and 
    $objectOf_Policy.policy.general.trigger -ne "USER_INITIATED" -and 
    $objectOf_Policy.policy.general.trigger_other.Length -eq 0 -and 
    $objectOf_Policy.policy.maintenance.recon -eq $true ) {

        if ( $objectOf_Policy.policy.scope.all_computers -eq $true ) {
            Add-Member -InputObject $policy -PassThru NoteProperty "Ongoing Event Inventory" $true | Out-Null
        }
        elseif ( $objectOf_Policy.policy.scope.computer_groups.IsEmpty -eq $false ) {

            ForEach ( $computerGroup in $objectOf_Policy.policy.scope.computer_groups.computer_group ) {
                if ( $($xmlOf_ComputerGroups.SelectNodes("//computer_group") | Where-Object { $_.name -eq $($computerGroup.name) } ).is_smart -eq $false ) {
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

    # Checks if a Site-Level Policy performs a Inventory.
        # Keeping for now.
#    if ( $objectOf_Policy.policy.general.site.name -ne "None" -and $objectOf_Policy.policy.maintenance.recon -eq $true ) {
#        Add-Member -InputObject $policy -PassThru NoteProperty "Site Level Recon" $true | Out-Null
#    }
#    else {
#        Add-Member -InputObject $policy -PassThru NoteProperty "Site Level Recon" $false | Out-Null
#    }

    # Check for configurable items.
    $usedObjects = @()
    ForEach ( $Printer in $objectOf_Policy.policy.printers.printer ) {
        # Write-Host "Policy ID $($objectOf_Policy.policy.general.id) uses: Printer $($Printer.id) / $($Printer.name)"
        $usedObjects += $Printer | Select-Object @{Name="type"; Expression={$($_)}}, id, name
    }

    createReport -outputObject $policy -Endpoint "Policies"
    return $usedObjects
}

# Checks if a Group is used in the scope of a configuration and adds to a list of used groups.
function groupUsage($objectOf_Record) {
    $usedGroups = @()

    # For each Targeted Group, add it to a list of used groups.
    ForEach ( $Group in $objectOf_Record.SelectNodes("//scope/*[contains(name(), 'groups') and not(contains(name(), 'user'))]/*[contains(name(), 'group')]") ) {
        # Write-Host "$($objectOf_Record.FirstChild.NextSibling.LocalName) ID $($objectOf_Record.SelectSingleNode("//id").innerText) Targets:  Group $($Group.id) / $($Group.name)"
        $usedGroups += $Group | Select-Object @{Name="type"; Expression={$($_)}}, id, name
    }

    # For each Excluded Group, add it to a list of used groups.
    ForEach ( $Group in $objectOf_Record.SelectNodes("//scope/exclusions/*[contains(name(), 'groups') and not(contains(name(), 'user'))]/*[contains(name(), 'group')]") ) {
        # Write-Host "$($objectOf_Record.FirstChild.NextSibling.LocalName) ID $($objectOf_Record.SelectSingleNode("//id").innerText) Excludes:  Group $($Group.id) / $($Group.name)"
        $usedGroups += $Group | Select-Object @{Name="type"; Expression={$($_)}}, id, name
    }
    
    return $usedGroups
}

# This Function checks criteria that is configured within a Group object.
function groupCriteria($objectOf_Group, $xmlOf_AllGroups) {

    # Build an object for this group record.
    $Group = New-Object PSObject -Property ([ordered]@{
        ID = $objectOf_Group.FirstChild.NextSibling.id
        Name = $objectOf_Group.FirstChild.NextSibling.name
        Site = $objectOf_Group.FirstChild.NextSibling.site.name
        "Smart Group" = $objectOf_Group.FirstChild.NextSibling.is_smart
    })

    # Check if the Group is Empty.
    if ( $objectOf_Group.FirstChild.NextSibling.LastChild.size -eq 0 ) {
        Add-Member -InputObject $Group -PassThru NoteProperty "Empty" $true | Out-Null
    }
    else {
        Add-Member -InputObject $Group -PassThru NoteProperty "Empty" $false | Out-Null
    }

    # Check if the Group has any defined criteria.
    if ( $objectOf_Group.FirstChild.NextSibling.criteria.size -eq 0 ) {
        Add-Member -InputObject $Group -PassThru NoteProperty "No Criteria" $true | Out-Null
    }
    else {
        Add-Member -InputObject $Group -PassThru NoteProperty "No Criteria" $false | Out-Null
    }

    # Check if the Group has 10 or more defined criteria.
    if ( [int]$objectOf_Group.FirstChild.NextSibling.criteria.size -ge 10 ) {
        Add-Member -InputObject $Group -PassThru NoteProperty "10+ Criteria" $true | Out-Null
    }
    else {
        Add-Member -InputObject $Group -PassThru NoteProperty "10+ Criteria" $false | Out-Null
    }
    
    $count = 0
    $usedGroups = @()
    # Check for Nested Groups  and adds to a list of used groups.
    ForEach ( $criteria in $objectOf_Group.FirstChild.NextSibling.criteria.criterion ) {
        if ( $criteria.name -match "Group" ) {
            # Get the Groups full details.
            # Write-Host "$($objectOf_Group.FirstChild.NextSibling.LocalName) ID $($objectOf_Group.SelectSingleNode("//id").innerText) Targets:  Computer Group $($nestedGroup.id) / $($nestedGroup.name)"
            $usedGroups += $xmlOf_AllGroups.FirstChild.NextSibling | Where-Object { $_.name -eq $($criteria.value) } | Select-Object @{Name="type"; Expression={$($_)}}, id, name

            # Tracking number of Nested Smart Groups
            if ( $nestedGroup.is_smart -eq $true ) {
                $count++
            }
        }
    }

    # Checking if the Group has 4 or more Nested Smart Groups.
    if ( $count -ge 4 ) {
        Add-Member -InputObject $Group -PassThru NoteProperty "4+ Criteria" $true | Out-Null
    }
    else {
        Add-Member -InputObject $Group -PassThru NoteProperty "4+ Criteria" $false | Out-Null
    }

    createReport -outputObject $Group -Endpoint $objectOf_Group.FirstChild.NextSibling.LocalName
    return $usedGroups
}

# This Function checks criteria against App Store App objects.
function appStoreAppCriteria($objectOf_App) {

    # Build an object for this App record.
    $App = New-Object PSObject -Property ([ordered]@{
        ID = $objectOf_App.FirstChild.NextSibling.general.id
        Name = $objectOf_App.FirstChild.NextSibling.general.name
        Site = $objectOf_App.FirstChild.NextSibling.general.site.name
        "Bundle ID" = $objectOf_App.FirstChild.NextSibling.general.bundle_id
        "Jamf Version" = $objectOf_App.FirstChild.NextSibling.general.version
        "iTunes Store URL" = $(
            if ( $objectOf_App.FirstChild.NextSibling.LocalName -eq "mobile_device_application" ) {
                 $objectOf_App.FirstChild.NextSibling.general.itunes_store_url
            }
            elseif ( $objectOf_App.FirstChild.NextSibling.LocalName -eq "mac_application" ) {
                $objectOf_App.FirstChild.NextSibling.general.url
            }
        )
    })

    # Get the Adam ID which is needed for the iTunes API.
    $appAdamID = (($($App."iTunes Store URL") -split "/id")[1] -split "\?")[0]

    # Get App details from Apple.
    Try {
        $iTunesReturn = Invoke-WebRequest -Uri "${iTunesAPI}${appAdamID}" -Method Get
    }
    Catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $statusDescription = $_.Exception.Response.StatusDescription

        If ($statusCode -notcontains "200") {
            Write-Output " -> Failed to get information for $($Record.LocalName) ID:  $(${Record}.id)" | Tee-Object -FilePath "${saveDirectory}\${folderDate}\errors.txt" -Append
            Write-Output "  --> Response:  ${statusCode} / $($RestError.Message | ForEach { $_.Split([Environment]::NewLine)[5];})" | Tee-Object -FilePath "${saveDirectory}\${folderDate}\errors.txt" -Append
        }
    }

    # Convert the JSON Object to a Hashtable -- this was the only way I could find to reliably test if the JSON results object property had a value.
    $appConfig = $jsonSerializer.Deserialize($iTunesReturn,'Hashtable')

    # Check if App is available from Apple.
    if ( $appConfig.results.Count -ne 0 ) {
        Add-Member -InputObject $App -PassThru NoteProperty "Available" $true | Out-Null
    }
    else {
        Add-Member -InputObject $App -PassThru NoteProperty "Available" $false | Out-Null
    }

    # Check if:  App is 32bit, the version available on iTunes, and if the version in Jamf is out of date.
    Add-Member -InputObject $App -PassThru NoteProperty "32bit" $($appConfig.results.Values.is32bitOnly) | Out-Null
    Add-Member -InputObject $App -PassThru NoteProperty "iTunes Version" $($appConfig.results.Values.offers.version.display) | Out-Null
    Add-Member -InputObject $App -PassThru NoteProperty "Out of Date" $( $($App."iTunes Version") -ne $($App."Jamf Version") ) | Out-Null

    createReport -outputObject $App -Endpoint $objectOf_App.FirstChild.NextSibling.LocalName
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
Write-Host ""
Write-Host "Saving reports to:  ${saveDirectory}\${folderDate}"

if ( !( Test-Path "${saveDirectory}\${folderDate}") ) {    
        New-Item -Path "${saveDirectory}\${folderDate}" -ItemType Directory | Out-Null
}

Write-Host ""

# Adding a stop watch object to monitor how long the audit takes.
$StopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
$StopWatch.Start()

# Call getEndpoint function for each type needed.
$xml_AllSites = getEndpoint "Sites" $getSites
$xmlArray_AllPoliciesDetails = getEndpoint "Policies" $getPolicies | getEndpointDetails $getPolicy
$xml_AllComputerGroups = getEndpoint "Computer Groups" $getComputerGroups
$xmlArray_AllComputerGroupsDetails = $xml_AllComputerGroups | getEndpointDetails $getComputerGroup
$xml_AllPrinters = getEndpoint "Printers" $getPrinters
$xmlArray_AllComputerConfigProfileDetails = getEndpoint "Computer Config Profiles" $getComputerConfigProfiles | getEndpointDetails $getComputerConfigProfile
$xmlArray_AllRestrictedSoftwareItemDetails = getEndpoint "Restricted Software Items" $getRestrictedSoftwareItems | getEndpointDetails $getRestrictedSoftwareItem
$xmlArray_AllComputerAppStoreAppDetails = getEndpoint "Computer App Store Apps" $getComputerAppStoreApps | getEndpointDetails $getComputerAppStoreApp
$xmlArray_AllPatchPoliciesDetails = getEndpoint "Patch Policies" $getPatchPolicies | getEndpointDetails $getPatchPolicy
$xmlArray_AlleBookDetails = getEndpoint "eBooks" $geteBooks | getEndpointDetails $geteBook
$xml_AllMobileDeviceGroups = getEndpoint "Mobile Device Groups" $getMobileDeviceGroups
$xmlArray_AllMobileDeviceGroupsDetails = $xml_AllMobileDeviceGroups | getEndpointDetails $getMobileDeviceGroup
$xmlArray_AllMobileDeviceConfigProfileDetails = getEndpoint "Mobile Device Config Profiles" $getMobileDeviceConfigProfiles | getEndpointDetails $getMobileDeviceConfigProfile
$xmlArray_AllMobileDeviceAppStoreAppDetails = getEndpoint "Mobile Device App Store Apps" $getMobileDeviceAppStoreApps | getEndpointDetails $getMobileDeviceAppStoreApp

# Create a file containing the total for each Endpoint.
$totalObjects=@()
$totalObjects += New-Object PSObject -Property ([ordered]@{ Name="Policies"; Value= $( $xmlArray_AllPoliciesDetails | Measure-Object | Select-Object Count -ExpandProperty Count ) } )
$totalObjects += New-Object PSObject -Property ([ordered]@{ Name="Computer Groups"; Value= $( $xmlArray_AllComputerGroupsDetails | Measure-Object | Select-Object Count -ExpandProperty Count ) } )
$totalObjects += New-Object PSObject -Property ([ordered]@{ Name="Printers"; Value= $( $xml_AllPrinters.printers.printer | Measure-Object | Select-Object Count -ExpandProperty Count ) } )
$totalObjects += New-Object PSObject -Property ([ordered]@{ Name="Computer Config Profiles"; Value= $( $xmlArray_AllComputerConfigProfileDetails | Measure-Object | Select-Object Count -ExpandProperty Count ) } )
$totalObjects += New-Object PSObject -Property ([ordered]@{ Name="Restricted Software"; Value= $( $xmlArray_AllRestrictedSoftwareItemDetails | Measure-Object | Select-Object Count -ExpandProperty Count ) } )
$totalObjects += New-Object PSObject -Property ([ordered]@{ Name="Computer App Store Apps"; Value= $( $xmlArray_AllComputerAppStoreAppDetails | Measure-Object | Select-Object Count -ExpandProperty Count ) } )
$totalObjects += New-Object PSObject -Property ([ordered]@{ Name="Patch Policies"; Value= $( $xmlArray_AllPatchPoliciesDetails | Measure-Object | Select-Object Count -ExpandProperty Count ) } )
$totalObjects += New-Object PSObject -Property ([ordered]@{ Name="eBooks"; Value= $( $xmlArray_AlleBookDetails | Measure-Object | Select-Object Count -ExpandProperty Count ) } )
$totalObjects += New-Object PSObject -Property ([ordered]@{ Name="Mobile Device Groups"; Value= $( $xmlArray_AllMobileDeviceGroupsDetails | Measure-Object | Select-Object Count -ExpandProperty Count ) } )
$totalObjects += New-Object PSObject -Property ([ordered]@{ Name="Mobile Device Config Profile"; Value= $( $xmlArray_AllMobileDeviceConfigProfileDetails | Measure-Object | Select-Object Count -ExpandProperty Count ) } )
$totalObjects += New-Object PSObject -Property ([ordered]@{ Name="Mobile Device App Store Apps"; Value= $( $xmlArray_AllMobileDeviceAppStoreAppDetails | Measure-Object | Select-Object Count -ExpandProperty Count ) } )
$totalObjects += New-Object PSObject -Property ([ordered]@{ Name="Sites"; Value= $( $xml_AllSites.sites.site | Measure-Object | Select-Object Count -ExpandProperty Count ) } )
$totalObjects | Export-Csv -Path "${saveDirectory}\${folderDate}\Report_Total Objects.csv" -Append -NoTypeInformation

Write-Host ""
Write-Host "Processing endpoints against defined criteria..."

# Call processEndpoints function to process each type.
$usedObjects += processEndpoints $xmlArray_AllPoliciesDetails $xml_AllComputerGroups
$usedObjects += processEndpoints $xmlArray_AllComputerConfigProfileDetails
$usedObjects += processEndpoints $xmlArray_AllRestrictedSoftwareItemDetails
$usedObjects += processEndpoints $xmlArray_AllComputerAppStoreAppDetails
$usedObjects += processEndpoints $xmlArray_AllPatchPoliciesDetails
$usedObjects += processEndpoints $xmlArray_AlleBookDetails
$usedObjects += processEndpoints $xmlArray_AllComputerGroupsDetails
$usedObjects += processEndpoints $xmlArray_AllMobileDeviceGroupsDetails
$usedObjects += processEndpoints $xmlArray_AllMobileDeviceConfigProfileDetails
$usedObjects += processEndpoints $xmlArray_AllMobileDeviceAppStoreAppDetails

# Sort the used objects by type.
ForEach ( $usedObject in $usedObjects ) {
    Switch ( $usedObject.type.LocalName ) {
        "computer_group" {
            $usedComputerGroups += $usedObject | Select-Object id, name
        }
        "mobile_device_group" {
            $usedMobileDeviceGroups += $usedObject | Select-Object id, name
        }
        "printer" {
            $usedPrinters += $usedObject | Select-Object id, name
        }
    }
}

# Find unused objects for each type of object.
findUnusedObjects $xmlArray_AllComputerGroupsDetails $usedComputerGroups "computer_group"
findUnusedObjects $xmlArray_AllMobileDeviceGroupsDetails $usedMobileDeviceGroups "mobile_device_group"
findUnusedObjects $xml_AllPrinters $usedPrinters "printer"

# Create report of all Sites.
$xml_AllSites.sites.site | Select-Object Name | Export-Csv -Path "${saveDirectory}\${folderDate}\Report_Sites.csv" -Append -NoTypeInformation

# Stopping the stop watch.
$StopWatch.Stop()
Write-Host ""
Write-Host "All Criteria has been processed."
Write-Host ""
Write-Host "Audit took" $StopWatch.Elapsed.Minutes "minutes and" $StopWatch.Elapsed.Seconds "seconds."

Write-Host ""
Write-Host "jamf_Audit Process:  COMPLETE"
