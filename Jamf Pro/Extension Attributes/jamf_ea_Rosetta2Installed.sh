#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_Rosetta2Installed.sh
# By:  Zack Thompson / Created:  4/5/2021
# Version:  1.1.0 / Updated:  11/3/2021 / By:  ZT
#
# Description:  A Jamf Extension Attribute to determine if Rosetta 2 is installed.
#
###################################################################################################

if [[ $( /usr/bin/arch ) == "arm64" ]]; then

    if [[ $( /usr/bin/pgrep oahd > /dev/null 2>&1 ) ]]; then

        echo "<result>Installed</result>"

    else

        echo "<result>Not Installed</result>"

    fi

else

    echo "<result>Not Compatible</result>"

fi

exit 0