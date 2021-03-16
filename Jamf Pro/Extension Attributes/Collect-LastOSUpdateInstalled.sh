#!/bin/bash

###################################################################################################
# Script Name:  Collect-LastOSUpdateInstalled.sh
# By:  Zack Thompson / Created:  3/16/2021
# Version:  1.0.0 / Updated:  3/16/2021 / By:  ZT
#
# Description:  A Jamf Extension Attribute to collect the results of Get-LastOSUpdateInstalled.py.
#
###################################################################################################

local_inventory="/opt/ManagedFrameworks/Inventory.plist"

if [[ -e $local_inventory ]]; then

    last_update=$( /usr/bin/defaults read "${local_inventory}" last_os_update_installed )

    if [[ -n $last_update ]]; then
    
        echo "<result>${last_update}</result>"

    else

        echo "<result>No Updates Installed</result>"

    fi

else

    echo "<result>Missing local inventory register</result>"

fi

exit 0