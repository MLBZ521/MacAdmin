#!/bin/bash
# set -x

####################################################################################################
# Script Name:  Collect-MgmtFrmwrkHealth.sh
# By:  Zack Thompson / Created:  4/26/2024
# Version:  1.0.0 / Updated:  4/26/2024 / By:  ZT
#
# Description:  This script collects the results from the Get-MgmtFrmwrkHealth.sh script
#	which checks the state of the Jamf Pro Management Framework and MDM Client.
#
####################################################################################################

##################################################
# Define variables

local_ea_inventory="/opt/ManagedFrameworks/Inventory.plist"
local_ea_inventory_identifier="jamf_mgmt_frmwrk_health_check"

##################################################
# Bits staged, collect the information...

if [[ -e "${local_ea_inventory}" ]]; then
    local_ea_value=$( /usr/bin/defaults read "${local_ea_inventory}" \
        "${local_ea_inventory_identifier}" 2> /dev/null )

    if [[ -z "${local_ea_value}" ]]; then
        report=""
    else
        report="${local_ea_value}"
    fi

else
    report="Missing local inventory register"
fi

echo "<result>${report}</result>"
exit 0