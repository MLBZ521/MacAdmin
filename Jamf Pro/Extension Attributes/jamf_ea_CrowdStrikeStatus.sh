#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_CrowdStrikeStatus.sh
# By:  Zack Thompson / Created:  1/8/2019
# Version:  1.1.1 / Updated:  1/31/2019 / By:  ZT
#
# Description:  This script gets the configuration of Crowd Strike, if installed.
#
###################################################################################################

echo "Checking the Crowd Strike configuration..."

##################################################
# Get the OS Minor.Micro Version
osMinorMicro=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F '.' '{print $2"."$3}')

# Define Variables for each item that we want to check for
customerID="12345678-90AB-CDEF-1234-567890ABCDEF"
cloudConnectionState="102"
# A value of 102 indicates the host is connected directly to the CrowdStrike cloud.
# A value of 126 indicates the host is connected to the CrowdStrike cloud via a proxy.

# Hold statuses
returnResult=""

##################################################
# Bits staged, collect the information...

echo "Checking if Crowd Strike is installed..."

if [[ -e "/Library/CS/falconctl" ]]; then

    # Get the customer ID and compare.
    csCustomerID=$( /usr/sbin/sysctl -n cs.customerid 2>&1 )
    if [[ "${csCustomerID}" != "${customerID}" ]]; then
        returnResult+="Invalid Customer ID;" 
    fi

    # Get the connection state and compare.
    csCloudConnectionState=$( /usr/sbin/sysctl -n cs.comms.cloud_connection_state 2>&1 )
    if [[ "${csCloudConnectionState}" != "${cloudConnectionState}" ]]; then
        returnResult+=" Disconnected State;" 
    fi

    # Check if the OS version is 10.13.2 or newer, if it it, check if the KEXTs are enabled.
    if [[ $(/usr/bin/bc <<< "${osMinorMicro} >= 13.2") -eq 1 ]]; then
        kextsEnabled=$( /usr/bin/sqlite3 /var/db/SystemPolicyConfiguration/KextPolicy "select * from kext_policy where team_id='X9E956P446' and allowed='0';" | /usr/bin/wc -l | /usr/bin/xargs )

        if [[ "${kextsEnabled}" != "2" ]]; then
            returnResult+=" KEXTs are not enabled;" 
        fi
    fi

    # Return the EA Value.
    if [[ -n "${returnResult}" ]]; then
        echo "<result>${returnResult%?}</result>"
    else
        echo "<result>Running</result>"
    fi

else
	echo "<result>Not Installed</result>"
fi

exit 0