#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_Hostname.sh
# By:  Zack Thompson / Created:  8/26/2019
# Version:  1.0.0 / Updated:  8/26/2019 / By:  ZT
#
# Description:  A Jamf Pro Extension Attribute to get the hostname of a device.
#
###################################################################################################

hostname=$( /bin/hostname -f )

if [[ $? == 0 ]]; then
    echo "<result>${hostname}</result>"
else
    echo "<result>Unknown</result>"
fi

exit 0