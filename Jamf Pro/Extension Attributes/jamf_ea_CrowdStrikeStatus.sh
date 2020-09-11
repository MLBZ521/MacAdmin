#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_CrowdStrikeStatus.sh
# By:  Zack Thompson / Created:  1/8/2019
# Version:  1.10.0 / Updated:  9/11/2020 / By:  ZT
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
osMinorPatch=$( /usr/bin/sw_vers -productVersion | /usr/bin/awk -F '.' '{print $2"."$3}' )

# Hold statuses
returnResult=""

##################################################
# Functions

checkLastConnection() {
    # Check if the last connected date is older than seven days.
    [[ $( /bin/date -j -f "%b %d %Y %H:%M:%S" "$( echo "${1}" | /usr/bin/sed 's/,//g; s/ at//g; s/ [AP]M//g' )" +"%s" ) -lt $( /bin/date -j -v-"${2}"d +"%s" ) ]]
}


# Get the customer ID and compare.
checkCustomerID() {

    if [[ $( /usr/bin/bc <<< "${csVersion} < 5.36" ) -eq 1 ]]; then

        csCustomerID=$( /usr/sbin/sysctl -n cs.customerid 2>&1 )

    else

        csCustomerID=$( echo "${falconctlStats}" | /usr/bin/awk -F "customerID:" '{print $2}' | /usr/bin/xargs )

    fi

    if [[ "${csCustomerID}" != "${customerID}" ]]; then

        returnResult+="Invalid Customer ID;"

    fi

}

##################################################
# Bits staged, collect the information...

# Check if Crowd Strike is installed.
if [[ -e "/Library/CS/falconctl" ]]; then

    # Get the Crowd Strike version.
    getCSVersion=$( /usr/sbin/sysctl -n cs.version )
    csVersionExitCode=$?

    if [[ $csVersionExitCode == "0" ]]; then
        csVersion=$( echo "${getCSVersion}" | /usr/bin/awk -F '.' '{print $1"."$2}' )

        # Get the connection state and compare; version dependant.
        if [[ $( /usr/bin/bc <<< "${csVersion} <= 4.16" ) -eq 1 ]]; then

            # Function
            checkCustomerID

            csCloudConnectionState=$( /usr/sbin/sysctl -n cs.comms.cloud_connection_state 2>&1 )

            if [[ "${csCloudConnectionState}" != "${cloudConnectionState}" ]]; then

                returnResult+=" Disconnected State;"

            fi

        else
            # Get the current stats.
            falconctlStats=$( sudo /Library/CS/falconctl stats agent_info Communications )
            # Will eventually move to the --plist format, once it's fully supported
            # falconctlStats=$( sudo /Library/CS/falconctl stats agent_info Communications --plist )

            # Function
            checkCustomerID

            # Get the connection established dates.
            established=$( echo "${falconctlStats}" | /usr/bin/awk -F "[^Last] Established At:" '{print $2}' | /usr/bin/xargs )
            lastEstablished=$( echo "${falconctlStats}" | /usr/bin/awk -F "Last Established At:" '{print $2}' | /usr/bin/xargs )

            # Compare if both were available.
            if [[ -n "${established}" && -n "${lastEstablished}" ]]; then

                # Check which is more recent.
                if [[ $( /bin/date -j -f "%b %d %Y %H:%M:%S" "$(echo "${established}" | /usr/bin/sed 's/,//g; s/ at//g; s/ [AP]M//g')" +"%s" ) -ge $( /bin/date -j -f "%b %d %Y %H:%M:%S" "$(echo "${lastEstablished}" | /usr/bin/sed 's/,//g; s/ at//g; s/ [AP]M//g')" +"%s" ) ]]; then
                    testConnectionDate="${established}"
                else
                    testConnectionDate="${lastEstablished}"
                fi

                # Check if the more recent date is older than seven days
                if [[ $( checkLastConnection "${testConnectionDate}" $lastConnectedVariance ) ]]; then
                    returnResult+="Last Connected:  ${testConnectionDate};"
                fi

            elif [[ -n "${established}" ]]; then

                # If only the Established date was available, check if it is older than seven days.
                if [[ $( checkLastConnection "${established}" $lastConnectedVariance ) ]]; then
                    echo "Last Connected:  ${established};"
                fi

            elif [[ -n "${lastEstablished}" ]]; then

                # If only the Last Established date was available, check if it is older than seven days.
                if [[ $( checkLastConnection "${lastEstablished}" $lastConnectedVariance ) ]]; then
                    returnResult+="Last Connected:  ${lastEstablished};"
                fi

            else
                # If no connection date was available, return disconnected
                returnResult+=" Disconnected State;"
            fi
        fi

        # Get the status of SIP, if SIP is disabled, we don't need to check if the KEXTs are enabled.
        sipStatus=$( /usr/bin/csrutil status | /usr/bin/awk -F ': ' '{printf $2}' | /usr/bin/awk -F '.' '{printf $1}' )

        # Check if the OS version is 10.13.2 or newer, if it is, check if the KEXTs are enabled.
        if [[ $(/usr/bin/bc <<< "${osMinorPatch} >= 13.2") -eq 1 && "${sipStatus}" == "enabled" ]]; then

            # Get how many KEXTs are loaded.
            kextsLoaded=$( /usr/sbin/kextstat | /usr/bin/grep "com.crowdstrike" | /usr/bin/wc -l | /usr/bin/xargs )

            # Mac sensor version 4.23.8501 and later only contains the “com.crowdstrike.sensor” kernel extension, earlier versions also included the “com.crowdstrike.platform” kernel extension.
            if [[ $(/usr/bin/bc <<< "${csVersion} < 4.23") -eq 1 ]]; then
                # Expecting two KEXTs for earlier versions.
                expectedKEXTs="2"
                kextPlural="s"
            else
                # Expecting one KEXT for later versions.
                expectedKEXTs="1"
            fi

            # Compare loaded KEXTs verus expected KEXTs
            if [[ "${kextsLoaded}" -eq "${expectedKEXTs}" ]]; then

                # Check if the kernel extensions are enabled (where approved by MDM or by a user).
                mdm_cs_sensor=$( /usr/bin/sqlite3 /var/db/SystemPolicyConfiguration/KextPolicy "select allowed from kext_policy_mdm where team_id='X9E956P446' and bundle_id='com.crowdstrike.sensor';" )
                user_cs_sensor=$( /usr/bin/sqlite3 /var/db/SystemPolicyConfiguration/KextPolicy "select allowed from kext_policy where team_id='X9E956P446' and bundle_id='com.crowdstrike.sensor';" )
                mdm_cs_platform=$( /usr/bin/sqlite3 /var/db/SystemPolicyConfiguration/KextPolicy "select allowed from kext_policy_mdm where team_id='X9E956P446' and bundle_id='com.crowdstrike.platform';" )
                user_cs_platform=$( /usr/bin/sqlite3 /var/db/SystemPolicyConfiguration/KextPolicy "select allowed from kext_policy where team_id='X9E956P446' and bundle_id='com.crowdstrike.platform';" )

                # Combine the results -- not to concerned which how they're enabled as long as they _are_ enabled.
                cs_sensor=$(( mdm_cs_sensor + user_cs_sensor ))
                cs_platform=$(( mdm_cs_platform + user_cs_platform ))

                if [[ $(/usr/bin/bc <<< "${csVersion} < 4.23") -eq 1 ]]; then
                    if [[ "${cs_sensor}" -ge "1" && "${cs_platform}" -ge "1" ]]; then
                        returnResult+="KEXTs not enabled;"
                    fi
                else
                    if [[ "${cs_sensor}" -lt "${expectedKEXTs}" ]]; then
                        returnResult+="KEXT not enabled;"
                    fi
                fi

            else
                returnResult+="KEXT${kextPlural} not loaded;"
            fi
        fi

        # Return the EA Value.
        if [[ -n "${returnResult}" ]]; then
            echo "<result>${returnResult%?}</result>"
        else
            echo "<result>Running</result>"
        fi

    else
        echo "<result>Not Running</result>"
    fi

else
    echo "<result>Not Installed</result>"
fi

exit 0