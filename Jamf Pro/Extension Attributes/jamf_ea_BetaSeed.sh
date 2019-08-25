#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_BetaSeed.sh
# By:  Zack Thompson / Created:  8/23/2019
# Version:  1.0.0 / Updated:  8/23/2019 / By:  ZT
#
# Description:  A Jamf Pro Extension Attribute to get the current Beta Seed a device is registered too.
#
###################################################################################################

seedUtil="/System/Library/PrivateFrameworks/Seeding.framework/Resources/seedutil"

if [[ -e "${seedUtil}" ]]; then

    currentSeed=$( "${seedUtil}" current | awk '/enrolled/{print $NF}' )

    if [[ "${currentSeed}" == "(null)" ]]; then
        echo "<result>None</result>"
    else
        echo "<result>${currentSeed}</result>"
    fi

else
    echo "<result>Unable to determine</result>"
fi

exit 0