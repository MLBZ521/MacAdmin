#!/bin/bash

###################################################################################################
# Script Name:  Collect-LastOSUpdateInstalled.sh
# By:  Zack Thompson / Created:  3/16/2021
# Version:  1.1.0 / Updated:  5/20/2022 / By:  ZT
#
# Description:  A Jamf Pro Extension Attribute to collect the results of Get-LastOSUpdateInstalled.py.
#
###################################################################################################

##################################################
#  Define Variables

local_inventory="/opt/ManagedFrameworks/Inventory.plist"
local_ea_history="/opt/ManagedFrameworks/EA_History.log"

#############################################n#####
# Functions

write_to_log() {
    message="${1}"
    time_stamp=$( /bin/date +%Y-%m-%d\ %H:%M:%S )
    echo "${time_stamp}:  ${message}" >> "${local_ea_history}"
}

##################################################
# Bits staged, collect the information...

if [[ -e $local_inventory ]]; then

    last_update=$( /usr/bin/defaults read "${local_inventory}" "last_os_update_installed" 2> /dev/null )
    # last_reported_update=$( /usr/bin/defaults read "${local_inventory}" "last_reported_os_update_installed" 2> /dev/null )

    if [[ -z $last_update ]]; then

        report="No updates installed"

    else

    # if [[ -z $last_reported_update || "${last_reported_update}" == "${last_update}" ]]; then

    /usr/bin/defaults write "${local_inventory}" "last_reported_os_update_installed" "${last_update}"

    # fi

    report="${last_update}"

    fi

else

    report="Missing local inventory register"

fi

write_to_log "Last OS Update Installed:  ${report}"
echo "<result>${report}</result>"
exit 0