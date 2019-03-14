#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_CrowdStrikeStatus.sh
# By:  Zack Thompson / Created:  1/8/2019
# Version:  1.4.0 / Updated:  3/13/2019 / By:  ZT
#
# Description:  This script gets the configuration of the CrowdStrike Falcon Sensor, if installed.
#
###################################################################################################

echo "Checking the Crowd Strike configuration..."

##################################################

# Define Variables for each item that we want to check for
customerID="12345678-90AB-CDEF-1234-567890ABCDEF"
cloudConnectionState="102"
# A value of 102 indicates the host is connected directly to the CrowdStrike cloud.
# A value of 126 indicates the host is connected to the CrowdStrike cloud via a proxy.

# The number of days before report device has not connected to the CS Cloud.
lastConnectedVariance=7

# Get the OS Minor.Micro Version
osMinorMicro=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F '.' '{print $2"."$3}')

# Hold statuses
returnResult=""

##################################################
# Bits staged, collect the information...

echo "Checking if Crowd Strike is installed..."

if [[ -e "/Library/CS/falconctl" ]]; then

	echo "Checking the Crowd Strike Version..."
	csVersion=$( /usr/sbin/sysctl -n cs.version | /usr/bin/awk -F '.' '{print $1"."$2}' )

    # Get the customer ID and compare.
    csCustomerID=$( /usr/sbin/sysctl -n cs.customerid 2>&1 )
    if [[ "${csCustomerID}" != "${customerID}" ]]; then
        returnResult+="Invalid Customer ID;"
    fi

    # Get the connection state and compare; version dependant.
    if [[ $(/usr/bin/bc <<< "${csVersion} <= 4.16") -eq 1 ]]; then
        csCloudConnectionState=$( /usr/sbin/sysctl -n cs.comms.cloud_connection_state 2>&1 )

        if [[ "${csCloudConnectionState}" != "${cloudConnectionState}" ]]; then
            returnResult+=" Disconnected State;"
        fi
    else
        csCloudConnectionState=$( /Library/CS/falconctl stats | awk -F "State:" '{print $2}' | xargs )

        if [[ $csCloudConnectionState != "connected" ]]; then
            lastConnected=$( /Library/CS/falconctl stats | awk -F "Last Established At:" '{print $2}' | xargs )

            # Check if the last connected date is older than seven days.
            if [[ $(date -j -f "%b %d %Y %H:%M:%S" "$(echo "${lastConnected}" | sed 's/,//g; s/ at//g; s/ PM//g')" +"%s" ) -ge $(date -j -v-"$($lastConnectedVariance)"d +"%s") ]]; then
                returnResult+="Last Connected:  ${lastConnected};"
            else
                returnResult+=" Disconnected State;"
            fi
        fi
    fi

    # Check if the OS version is 10.13.2 or newer, if it is, check if the KEXTs are enabled.
    if [[ $(/usr/bin/bc <<< "${osMinorMicro} >= 13.2") -eq 1 ]]; then

        if [[ $(/usr/bin/bc <<< "${csVersion} < 4.23") -eq 1 ]]; then
            expectedKEXTs="2"
        else
            expectedKEXTs="1"
        fi

        # Get how many KEXTs are loaded.
        kextsLoaded=$( /usr/sbin/kextstat | grep "com.crowdstrike" | /usr/bin/wc -l | /usr/bin/xargs )

        if [[ "${kextsLoaded}" != "${expectedKEXTs}" ]]; then
            # Get how many KEXTS are enabled from Jamf or by the user.
            jamfEnabledKEXTs=$( /usr/libexec/PlistBuddy -c "Print :AllowedKernelExtensions:X9E956P447" /Library/Managed\ Preferences/com.apple.syspolicy.kernel-extension-policy.plist -x | /usr/bin/xpath 'count(//string)' 2>/dev/null )
            userEnabledKEXTs=$( /usr/bin/sqlite3 /var/db/SystemPolicyConfiguration/KextPolicy "select * from kext_policy where team_id='X9E956P446' and allowed='0';" | /usr/bin/wc -l | /usr/bin/xargs )

            if [[ "${jamfEnabledKEXTs}" != "${expectedKEXTs}" && "${userEnabledKEXTs}" != "${expectedKEXTs}" ]]; then
                returnResult+="KEXTs not loaded or enabled;"
            else
                returnResult+="KEXTs are not loaded;"
            fi
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