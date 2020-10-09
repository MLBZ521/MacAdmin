<#

Script Name:  Report-FileVaultEncryption.ps1
By:  Zack Thompson / Created:  6/19/2020
Version:  1.0.0 / Updated:  6/19/2020 / By:  ZT

Description:  This script will create a report on device encryption.

#>

# Define Smart Groups
$fv_prk_valid_group = "FileVault2 - Enabled - Valid PRK"
$fv_prk_missing_group = "FileVault2 - Enabled - Missing PRK"

Write-Host "Enter your Jamf Pro credentials"

# Setup Session
$Session = [PwshJamf]::new( $( Get-Credential ) )
$Session.Server = "https://jps.server.com:8443/"
$Session.Headers['Accept'] = "application/xml"
$Session.VerifyAPICredentials()

# Get All the Computers
$Computers = $Session.GetComputers()

# Set where to save the output
$SaveDirectory = ( $( Read-Host "Provide directiory to save the report" ) -replace '"' )

# Create a time stamp for the file
$TimeStamp=$( Get-Date -UFormat %m-%d-%y_%H:%M:%S )

# File to save report too
$OutputFile = "${SaveDirectory}/Encryption Report_${TimeStamp}.csv"

# Write Header to file
Out-File -FilePath "${OutputFile}" -InputObject "computer_id`tsite`tcomputer_name`tserial_number`tfv2_status`t`tfv2_complete`tfv2_valid_prk`taccounts_fv2_enabled`taccounts_not_fv2_enabled`t"

# Loop through all the computres
ForEach ( $Computer in $Computers.computers.computer ) {

    # Get the computers inventory
    $computer = $Session.GetComputerSubsetByID( $computer.computer.general.id, "General&Hardware&Groups_Accounts" )

    # Get the BootPartition
    $BootParition = $computer.computer.hardware.storage.device.partitions.partition | Where-Object { $_.name -match "(Boot Partition)" }

    # FileVault2 Status
    $FV2_status = $BootParition.filevault2_status
    
    # FileVault2 Percentage complete
    if ( $BootParition.filevault2_percent -eq 100 ) {

        $FV2_complete = $true

    }
    else {

        $FV2_complete = $false

    }

    if ( $fv_prk_valid_group -in $computer.computer.groups_accounts.computer_group_memberships.group ) {
        
        $fv2_valid_prk = $true

    }
    elseif ( $fv_prk_missing_group -in $computer.computer.groups_accounts.computer_group_memberships.group ) {
        
        $fv2_valid_prk = $false

    }

    # Easy way to check which users are FV2 Enabled
    # $computer.computer.hardware.filevault2_users

    # Create Arrays
    $FV2_enabled_accounts = @()
    $FV2_nonenabeld_accounts = @()

    # Get where accounts are FV2 enabled or not
    ForEach ( $User in $computer.computer.groups_accounts.local_accounts.user ) {

        if ( $User.filevault_enabled -eq $true ) {

            $FV2_enabled_accounts += $user.name

        }
        else {

            $FV2_nonenabeld_accounts += $user.name

        }

    }

    # Store information
    $export_info = "$($computer.computer.general.id)`t$($computer.computer.general.site.name)`t$($computer.computer.general.name)`t$($computer.computer.general.serial_number)`t${FV2_status}`t${FV2_complete}`t${fv2_valid_prk}`t${FV2_enabled_accounts}`t${FV2_nonenabeld_accounts}"

    # Write information to file
    Out-File -FilePath  "${OutputFile}" -InputObject "${export_info}" -Append

}

Write-Host "Report complete!"
