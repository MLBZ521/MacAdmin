<#

Script Name:  jamf_createSite.ps1
By:  Zack Thompson / Created:  5/11/2018
Version:  0.5 / Updated:  5/23/2018 / By:  ZT

Description:  This script will automate the creation of a new Site as much as possible with the information provided.

#>

param (
    [Parameter][string]$csv,
    [string]$SiteName,
    [string]$Department,
    [string]$NestSecurityGroup
    #[Parameter(Mandatory=$true)][string]$,
 )

Write-Host "jamf_createSite Process:  START"

# ============================================================
# Define Variables
# ============================================================

# Setup Credentials
$jamfAPIUser = $(Read-Host "JPS Account")
$jamfAPIPassword = $(Read-Host -AsSecureString "JPS Password")
$APIcredentials = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $jamfAPIUser, $jamfAPIPassword

# Setup API URLs
$jamfPS="https://jss.company.com:8443"
$apiSite="${jamfPS}/JSSResource/sites/id/0"
$apiGroup="${jamfPS}/JSSResource/accounts/groupid/0"
$apiDepartment="${jamfPS}/JSSResource/departments/id/0"
$apiCategory="${jamfPS}/JSSResource/categories/id/0"
$apiComputerGroup="${jamfPS}/JSSResource/computergroups/id/0"
$apiMobileGroup="${jamfPS}/JSSResource/mobiledevicegroups/id/0"
$apiPolicy="${jamfPS}/JSSResource/policies/id/0"

# Active Directory OU Location for Endpoint Management Security Group
$OU = "DC=Security Groups,DC=ad,DC=contoso,DC=com"

# ============================================================
# Functions
# ============================================================

function apiDo($uri, $method, $config) {
    Try {
        $Response = Invoke-RestMethod -Uri "${uri}" -Method $method -ContentType "application/xml" -Credential $APIcredentials -Body $config -ErrorVariable RestError -ErrorAction SilentlyContinue
    }
    Catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $statusDescription = $_.Exception.Response.StatusDescription

        If ($statusCode -notcontains "200") {
            Write-host " -> Failed!"
            Write-Host "  --> Response:  ${statusCode}/${statusDescription}: $($RestError.Message | ForEach { $_.Split(":")[1];} | ForEach { $_.Split([Environment]::NewLine)[0];})"
        }
    }
}

function SiteCreation {

# ============================================================
# Define Variables for current run...

$SecurityGroup = "EndPntMgmt.Apple ${SiteName}"

[xml]$configSites = "<?xml version='1.0' encoding='UTF-8'?><site>
    <name>${SiteName}</name>
</site>"

[xml]$configSecurityGroup = "<?xml version='1.0' encoding='UTF-8'?><group>
  <name>${SecurityGroup}</name>
  <access_level>Site Access</access_level>
  <privilege_set>Custom</privilege_set>
  <ldap_server>
    <id>1</id>
    <name>AD Connector</name>
  </ldap_server>
  <site>
    <name>${SiteName}</name>
  </site>
  <privileges>
    <jss_objects>
      <privilege>Create Advanced Computer Searches</privilege>
      <privilege>Read Advanced Computer Searches</privilege>
      <privilege>Update Advanced Computer Searches</privilege>
      <privilege>Delete Advanced Computer Searches</privilege>
      <privilege>Create Advanced Mobile Device Searches</privilege>
      <privilege>Read Advanced Mobile Device Searches</privilege>
      <privilege>Update Advanced Mobile Device Searches</privilege>
      <privilege>Delete Advanced Mobile Device Searches</privilege>
      <privilege>Create Advanced User Searches</privilege>
      <privilege>Read Advanced User Searches</privilege>
      <privilege>Update Advanced User Searches</privilege>
      <privilege>Delete Advanced User Searches</privilege>
      <privilege>Create Advanced User Content Searches</privilege>
      <privilege>Read Advanced User Content Searches</privilege>
      <privilege>Update Advanced User Content Searches</privilege>
      <privilege>Delete Advanced User Content Searches</privilege>
      <privilege>Create Classes</privilege>
      <privilege>Read Classes</privilege>
      <privilege>Update Classes</privilege>
      <privilege>Delete Classes</privilege>
      <privilege>Create Computer Enrollment Invitations</privilege>
      <privilege>Read Computer Enrollment Invitations</privilege>
      <privilege>Update Computer Enrollment Invitations</privilege>
      <privilege>Delete Computer Enrollment Invitations</privilege>
      <privilege>Create Computer PreStage Enrollments</privilege>
      <privilege>Read Computer PreStage Enrollments</privilege>
      <privilege>Update Computer PreStage Enrollments</privilege>
      <privilege>Delete Computer PreStage Enrollments</privilege>
      <privilege>Create Computers</privilege>
      <privilege>Read Computers</privilege>
      <privilege>Update Computers</privilege>
      <privilege>Delete Computers</privilege>
      <privilege>Create Device Enrollment Program Instances</privilege>
      <privilege>Read Device Enrollment Program Instances</privilege>
      <privilege>Update Device Enrollment Program Instances</privilege>
      <privilege>Delete Device Enrollment Program Instances</privilege>
      <privilege>Create eBooks</privilege>
      <privilege>Read eBooks</privilege>
      <privilege>Update eBooks</privilege>
      <privilege>Delete eBooks</privilege>
      <privilege>Create Enrollment Profiles</privilege>
      <privilege>Read Enrollment Profiles</privilege>
      <privilege>Update Enrollment Profiles</privilege>
      <privilege>Delete Enrollment Profiles</privilege>
      <privilege>Create Licensed Software</privilege>
      <privilege>Read Licensed Software</privilege>
      <privilege>Update Licensed Software</privilege>
      <privilege>Delete Licensed Software</privilege>
      <privilege>Create Mac Applications</privilege>
      <privilege>Read Mac Applications</privilege>
      <privilege>Update Mac Applications</privilege>
      <privilege>Delete Mac Applications</privilege>
      <privilege>Create Managed Preference Profiles</privilege>
      <privilege>Read Managed Preference Profiles</privilege>
      <privilege>Update Managed Preference Profiles</privilege>
      <privilege>Delete Managed Preference Profiles</privilege>
      <privilege>Create Mobile Device Applications</privilege>
      <privilege>Read Mobile Device Applications</privilege>
      <privilege>Update Mobile Device Applications</privilege>
      <privilege>Delete Mobile Device Applications</privilege>
      <privilege>Create iOS Configuration Profiles</privilege>
      <privilege>Read iOS Configuration Profiles</privilege>
      <privilege>Update iOS Configuration Profiles</privilege>
      <privilege>Delete iOS Configuration Profiles</privilege>
      <privilege>Create Mobile Device Enrollment Invitations</privilege>
      <privilege>Read Mobile Device Enrollment Invitations</privilege>
      <privilege>Update Mobile Device Enrollment Invitations</privilege>
      <privilege>Delete Mobile Device Enrollment Invitations</privilege>
      <privilege>Create Mobile Device Managed App Configurations</privilege>
      <privilege>Read Mobile Device Managed App Configurations</privilege>
      <privilege>Update Mobile Device Managed App Configurations</privilege>
      <privilege>Delete Mobile Device Managed App Configurations</privilege>
      <privilege>Create Mobile Device PreStage Enrollments</privilege>
      <privilege>Read Mobile Device PreStage Enrollments</privilege>
      <privilege>Update Mobile Device PreStage Enrollments</privilege>
      <privilege>Delete Mobile Device PreStage Enrollments</privilege>
      <privilege>Create Mobile Devices</privilege>
      <privilege>Read Mobile Devices</privilege>
      <privilege>Update Mobile Devices</privilege>
      <privilege>Delete Mobile Devices</privilege>
      <privilege>Create Network Integration</privilege>
      <privilege>Read Network Integration</privilege>
      <privilege>Update Network Integration</privilege>
      <privilege>Delete Network Integration</privilege>
      <privilege>Create OS X Configuration Profiles</privilege>
      <privilege>Read OS X Configuration Profiles</privilege>
      <privilege>Update OS X Configuration Profiles</privilege>
      <privilege>Delete OS X Configuration Profiles</privilege>
      <privilege>Create Patch Reporting Software Titles</privilege>
      <privilege>Read Patch Reporting Software Titles</privilege>
      <privilege>Update Patch Reporting Software Titles</privilege>
      <privilege>Delete Patch Reporting Software Titles</privilege>
      <privilege>Create Personal Device Configurations</privilege>
      <privilege>Read Personal Device Configurations</privilege>
      <privilege>Update Personal Device Configurations</privilege>
      <privilege>Delete Personal Device Configurations</privilege>
      <privilege>Create Personal Device Profiles</privilege>
      <privilege>Read Personal Device Profiles</privilege>
      <privilege>Update Personal Device Profiles</privilege>
      <privilege>Delete Personal Device Profiles</privilege>
      <privilege>Create Policies</privilege>
      <privilege>Read Policies</privilege>
      <privilege>Update Policies</privilege>
      <privilege>Delete Policies</privilege>
      <privilege>Create PreStages</privilege>
      <privilege>Read PreStages</privilege>
      <privilege>Update PreStages</privilege>
      <privilege>Delete PreStages</privilege>
      <privilege>Create Restricted Software</privilege>
      <privilege>Read Restricted Software</privilege>
      <privilege>Update Restricted Software</privilege>
      <privilege>Delete Restricted Software</privilege>
      <privilege>Create Smart Computer Groups</privilege>
      <privilege>Read Smart Computer Groups</privilege>
      <privilege>Update Smart Computer Groups</privilege>
      <privilege>Delete Smart Computer Groups</privilege>
      <privilege>Create Smart Mobile Device Groups</privilege>
      <privilege>Read Smart Mobile Device Groups</privilege>
      <privilege>Update Smart Mobile Device Groups</privilege>
      <privilege>Delete Smart Mobile Device Groups</privilege>
      <privilege>Create Smart User Groups</privilege>
      <privilege>Read Smart User Groups</privilege>
      <privilege>Update Smart User Groups</privilege>
      <privilege>Delete Smart User Groups</privilege>
      <privilege>Create Static Computer Groups</privilege>
      <privilege>Read Static Computer Groups</privilege>
      <privilege>Update Static Computer Groups</privilege>
      <privilege>Delete Static Computer Groups</privilege>
      <privilege>Create Static Mobile Device Groups</privilege>
      <privilege>Read Static Mobile Device Groups</privilege>
      <privilege>Update Static Mobile Device Groups</privilege>
      <privilege>Delete Static Mobile Device Groups</privilege>
      <privilege>Create Static User Groups</privilege>
      <privilege>Read Static User Groups</privilege>
      <privilege>Update Static User Groups</privilege>
      <privilege>Delete Static User Groups</privilege>
      <privilege>Create User</privilege>
      <privilege>Read User</privilege>
      <privilege>Update User</privilege>
      <privilege>Delete User</privilege>
      <privilege>Create VPP Administrator Accounts</privilege>
      <privilege>Read VPP Administrator Accounts</privilege>
      <privilege>Update VPP Administrator Accounts</privilege>
      <privilege>Delete VPP Administrator Accounts</privilege>
      <privilege>Create VPP Assignment</privilege>
      <privilege>Read VPP Assignment</privilege>
      <privilege>Update VPP Assignment</privilege>
      <privilege>Delete VPP Assignment</privilege>
      <privilege>Create VPP Invitations</privilege>
      <privilege>Read VPP Invitations</privilege>
      <privilege>Update VPP Invitations</privilege>
      <privilege>Delete VPP Invitations</privilege>
    </jss_objects>
    <jss_actions>
      <privilege>Allow User to Enroll</privilege>
      <privilege>Change Password</privilege>
      <privilege>Dismiss Notifications</privilege>
      <privilege>Enroll Computers and Mobile Devices</privilege>
      <privilege>Flush Policy Logs</privilege>
      <privilege>Send Blank Pushes to Mobile Devices</privilege>
      <privilege>Send Computer Delete User Account Command</privilege>
      <privilege>Send Computer Remote Command to Download and Install OS X Update</privilege>
      <privilege>Send Computer Remote Lock Command</privilege>
      <privilege>Send Computer Remote Wipe Command</privilege>
      <privilege>Send Computer Unlock User Account Command</privilege>
      <privilege>Send Computer Unmanage Command</privilege>
      <privilege>Send Email to End Users via JSS</privilege>
      <privilege>Send Inventory Requests to Mobile Devices</privilege>
      <privilege>Send Messages to Self Service Mobile</privilege>
      <privilege>Send Mobile Device Diagnostics and Usage Reporting and App Analytics Commands</privilege>
      <privilege>Send Mobile Device Disable Data Roaming Command</privilege>
      <privilege>Send Mobile Device Disable Voice Roaming Command</privilege>
      <privilege>Send Mobile Device Enable Data Roaming Command</privilege>
      <privilege>Send Mobile Device Enable Voice Roaming Command</privilege>
      <privilege>Send Mobile Device Lost Mode Command</privilege>
      <privilege>Send Mobile Device Managed Settings Command</privilege>
      <privilege>Send Mobile Device Mirroring Command</privilege>
      <privilege>Send Mobile Device Remote Command to Download and Install iOS Update</privilege>
      <privilege>Send Mobile Device Remote Lock Command</privilege>
      <privilege>Send Mobile Device Remote Wipe Command</privilege>
      <privilege>Send Mobile Device Remove Passcode Command</privilege>
      <privilege>Send Mobile Device Remove Restrictions Password Command</privilege>
      <privilege>Send Mobile Device Restart Device Command</privilege>
      <privilege>Send Mobile Device Set Device Name Command</privilege>
      <privilege>Send Mobile Device Set Wallpaper Command</privilege>
      <privilege>Send Mobile Device Shared iPad Commands</privilege>
      <privilege>Send Mobile Device Shut Down Command</privilege>
      <privilege>Send Update Passcode Lock Grace Period Command</privilege>
      <privilege>Unmanage Mobile Devices</privilege>
      <privilege>View Activation Lock Bypass Code</privilege>
      <privilege>View Disk Encryption Recovery Key</privilege>
      <privilege>View Event Logs</privilege>
      <privilege>View JSS Information</privilege>
      <privilege>View License Serial Numbers</privilege>
      <privilege>View Mobile Device Lost Mode Location</privilege>
    </jss_actions>
    <recon>
      <privilege>Add Computers Remotely</privilege>
    </recon>
    <casper_remote>
      <privilege>Use Casper Remote</privilege>
      <privilege>Install/Uninstall Software Remotely</privilege>
      <privilege>Run Scripts Remotely</privilege>
      <privilege>Map Printers Remotely</privilege>
      <privilege>Add Dock Items Remotely</privilege>
      <privilege>Manage Local User Accounts Remotely</privilege>
      <privilege>Change Management Account Remotely</privilege>
      <privilege>Bind to Active Directory Remotely</privilege>
      <privilege>Set Open Firmware/EFI Passwords Remotely</privilege>
      <privilege>Reboot Computers Remotely</privilege>
      <privilege>Perform Maintenance Tasks Remotely</privilege>
      <privilege>Search for Files/Processes Remotely</privilege>
      <privilege>Enable Disk Encryption Configurations Remotely</privilege>
      <privilege>Screen Share with Remote Computers</privilege>
      <privilege>Screen Share with Remote Computers Without Asking</privilege>
    </casper_remote>
    <casper_imaging/>
  </privileges>
</group>"

[xml]$configDepartment = "<?xml version='1.0' encoding='UTF-8'?><department>
    <name>${Department}</name>
</department>"

[xml]$configCategory = "<?xml version='1.0' encoding='UTF-8'?><category>
    <name>Testing - ${Department}</name>
</category>"

[xml]$configComputerGroup = "<?xml version='1.0' encoding='UTF-8'?><computer_group>
  <id>45</id>
  <name>[Deskside] ${SiteName}</name>
  <is_smart>true</is_smart>
  <site>
    <name>${SiteName}</name>
  </site>
  <criteria>
    <size>2</size>
    <criterion>
      <name>Department</name>
      <priority>0</priority>
      <and_or>and</and_or>
      <search_type>is not</search_type>
      <value>COMMON</value>
      <opening_paren>false</opening_paren>
      <closing_paren>false</closing_paren>
    </criterion>
    <criterion>
      <name>Department</name>
      <priority>1</priority>
      <and_or>and</and_or>
      <search_type>is not</search_type>
      <value>SERVERS</value>
      <opening_paren>false</opening_paren>
      <closing_paren>false</closing_paren>
    </criterion>
  </criteria>
  </computer_group>"

[xml]$configMobileGroup = "<?xml version='1.0' encoding='UTF-8'?><mobile_device_group>
  <name>[Deskside] ${SiteName}</name>
  <is_smart>true</is_smart>
  <site>
    <name>${SiteName}</name>
  </site></mobile_device_group>"

[xml]$configPolicy = "<?xml version='1.0' encoding='UTF-8'?><policy>
  <general>
    <name>Configure Department Data - ${SiteName}</name>
    <enabled>true</enabled>
    <trigger_checkin>true</trigger_checkin>
    <trigger_enrollment_complete>true</trigger_enrollment_complete>
    <frequency>Once every week</frequency>
    <category>
      <name>Deskside Setup</name>
    </category>
    <site>
      <name>${SiteName}</name>
    </site>
  </general>
  <scope>
    <all_computers>true</all_computers>
  </scope>
  <files_processes>
    <run_command>/usr/local/jamf/bin/jamf recon -department $Department</run_command>
  </files_processes>
</policy>"

# ============================================================

# Some Verbosity
Write-Host "Site:  ${SiteName}"
Write-Host "Department:  ${Department}"
Write-Host "Nested Security Group:  ${NestSecurityGroup}"
Write-Host ""

# Active Directory Setup
    Write-Host "Creating Endpoint Management Security Group:  ${SecurityGroup}"
    New-ADGroup -Name $SecurityGroup -DisplayName $SecurityGroup -SamAccountName $SecurityGroup -GroupCategory Security -GroupScope Universal -Path "${OU}" -Description "This group manages the ${SiteName} Jamf Site." #-Credential 

    Write-Host "Nesting the Securty Group:  ${NestSecurityGroup} into:  ${SecurityGroup}"
    Add-ADGroupMember -Identity $SecurityGroup -Members $NestSecurityGroup

    # Jamf Setup
    Write-host "Creating Site:  ${SiteName}"
    apiDo "${apiSite}" "Post" $configSites

    Write-host "Creating Management Group:  ${SecurityGroup}  and setting permissions..."
    apiDo "${apiGroup}" "Post" $configSecurityGroup

    Write-host "Creating Department:  ${Department}"
    apiDo "${apiDepartment}" "Post" $configDepartment
    
    Write-host "Creating Category:  Testing - ${Department}"
    apiDo "${apiCategory}" "Post" $configCategory
    
    Write-host "Creating Computer Group:  [Deskside] ${SiteName}"
    apiDo "${apiComputerGroup}" "Post" $configComputerGroup
    
    Write-host "Creating Mobile Device Group:  [Deskside] ${SiteName}"
    apiDo "${apiMobileGroup}" "Post" $configMobileGroup
    
    Write-host "Creating Policy:  Department Loading Policy - ${Department}"
    apiDo "${apiPolicy}" "Post" $configPolicy
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
        Write-Host "jamf_assignSiteEA Process:  FAILED"
        Exit
    }
}

Write-Host "API Credentials Valid -- continuing..."

If ( $csv.Length -eq 0) {
    # Use command line parameters...
    siteCreation
}
Else {
    # A CSV was provided...
    $csvContents = Import-Csv "${csv}"

    ForEach ($Site in $csvContents) {
        $SiteName = "$(${Site}.SiteName)"
        $Department = "$(${Site}.Department)"
        $NestSecurityGroup = "$(${Site}.SecurityGroup)"

        siteCreation
        Write-Host ""
    }
    Write-Host "All provided Sites have been created!"
}

Write-Host "jamf_createSite Process:  COMPLETE"