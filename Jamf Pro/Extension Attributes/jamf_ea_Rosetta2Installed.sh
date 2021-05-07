#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_Rosetta2Installed.sh
# By:  Zack Thompson / Created:  4/5/2021
# Version:  1.0.0 / Updated:  4/5/2021 / By:  ZT
#
# Description:  A Jamf Extension Attribute to determine if Rosetta 2 is installed.
#
###################################################################################################

arch=$( /usr/bin/arch )

if [[ "${arch}" == "arm64" ]]; then

    if [[ -f "/Library/Apple/System/Library/LaunchDaemons/com.apple.oahd.plist" ]]; then

        echo "<result>Installed<result>"

    else

        echo "<result>Not Installed<result>"

    fi

else

    echo "<result>Not Compatible<result>"

fi

exit 0