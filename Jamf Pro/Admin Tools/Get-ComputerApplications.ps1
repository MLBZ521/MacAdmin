<#

Script Name:  Get-ComputerApplications.ps1
By:  Zack Thompson / Created:  5/10/2019
Version:  1.0.0 / Updated:  5/10/2019 / By:  ZT

Description:  This script will pull Computer Application information and export to a file.

#>

[CmdletBinding(DefaultParameterSetName="SingleRun")]
param (
    [Parameter(Mandatory=$true, ParameterSetName="SingleRun")][string]$ApplicationName,
    [Parameter(ParameterSetName="SingleRun")][string]$Version,
    [Parameter(ParameterSetName="SingleRun")][string]$Inventory,
    [Parameter(ParameterSetName="SingleRun")][string]$FileName,

    [Parameter(Mandatory=$true, ParameterSetName="csv")][string]$csv
)

Write-Host "jamf_GetComputerApplications Process:  START"

# ============================================================
# Setup Environment
# ============================================================

# Setup instance of the Class
$JamfProSession = [PwshJamf]::new($(Get-Credential))
$JamfProSession.Server = "https://jps.company.com:8443"

$cwd = Get-Location

# ============================================================
# Functions
# ============================================================

function GetApplication() {
    param (
        [string]$ApplicationName,
        [string]$Version,
        [string]$Inventory,
        [string]$FileName
    )

    switch ( $PSBoundParameters.Count ) {
        2 {
            $Results = $JamfProSession.GetComputerApplicationByNameAndVersionAndInventory($ApplicationName)
        }

        3 {
            If ( $PSBoundParameters.ContainsKey("Version") ) {
                $Results = $JamfProSession.GetComputerApplicationByNameAndVersionAndInventory($ApplicationName, $Version)
            }
            ElseIf ( $PSBoundParameters.ContainsKey("Inventory") ) {
                $Results = $JamfProSession.GetComputerApplicationByNameAndVersionAndInventory($ApplicationName, $Inventory)
            }
        }

        4 {
            $Results = $JamfProSession.GetComputerApplicationByNameAndVersionAndInventory($ApplicationName, $Version, $Inventory)
        }
    }

    $Results.computer_applications.versions | ForEach-Object {
        $version = $_.number
        $_.computers | ForEach-Object { Add-Member -InputObject $_ -PassThru NoteProperty "version" $version  | Out-Null } }

    $Results.computer_applications.versions | Select-Object -ExpandProperty computers | Where-Object { $_.managed -eq "Managed" } | Export-Csv -Path "${cwd}\ApplicationReport_${FileName}.csv" -Append -NoTypeInformation
}

# ============================================================
# Bits Staged...
# ============================================================

If ( $PSCmdlet.ParameterSetName -ne "csv" ) {
    # Use command line parameters...
    GetApplication -ApplicationName $ApplicationName -Version $Version -Inventory $Inventory -FileName $FileName
}
Else {
    # A CSV was provided...
    $csvContents = Import-Csv "${csv}"

    ForEach ($Application in $csvContents) {
        $ApplicationName = "$(${Application}.Name)"
        $Version = "$(${Application}.Version)"
        $Inventory = "$(${Application}.Inventory)"
        $FileName = "$(${Application}.FileName)"

        GetApplication -ApplicationName $ApplicationName -Version $Version -Inventory $Inventory -FileName $FileName
    }
    Write-Host "All requested reports have been created!"
}

Write-Host "jamf_GetComputerApplications Process:  COMPLETE"