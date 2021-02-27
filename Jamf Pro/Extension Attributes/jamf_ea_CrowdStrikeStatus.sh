#!/bin/bash
# set -x

###################################################################################################
# Script Name:  jamf_ea_CrowdStrikeStatus.sh
# By:  Zack Thompson / Created:  1/8/2019
# Version:  2.2.0 / Updated:  2/26/2021 / By:  ZT
#
# Description:  This script gets the configuration of the CrowdStrike Falcon Sensor, if installed.
#
###################################################################################################

echo "Checking the Crowd Strike configuration..."

##################################################
## Set variables for your environment
# Set whether CrowdStrike Firmware Analysis is enabled in your environment ( true | false ).
csFirmwareAnalysisEnable="false"

# Define Variables for each item that we want to check for
expectedCSCustomerID="12345678-90AB-CDEF-1234-567890ABCDEF"

# The number of days before report device has not connected to the CS Cloud.
lastConnectedVariance=7

##################################################
# Functions

getFalconctlStats() {

    # Get the current stats.
    "${1}" stats agent_info Communications
    # Will eventually move to the --plist format, once it's fully supported
    # "${1}" stats agent_info Communications --plist

}

# Get the CS Major.Minor Version string
getCSMajorMinorVersion(){

    echo "${1}" | /usr/bin/awk -F "version:" '{print $2}' | /usr/bin/xargs | /usr/bin/awk -F '.' '{print $1"."$2}'

}

checkLastConnection() {

    # Check if the last connected date is older than seven days.
    if [[ $( /bin/date -j -f "%b %d %Y %H:%M:%S" "$( echo "${1}" | /usr/bin/sed 's/,//g; s/ at//g; s/ [AP]M//g' )" +"%s" ) -lt $( /bin/date -j -v-"${2}"d +"%s" ) ]]; then

        returnResult+=" Last Connected:  ${1};"

    fi

}

##################################################
# Bits staged, collect the information...

# Possible falconctl binary locations
falconctl_AppLocation="/Applications/Falcon.app/Contents/Resources/falconctl"
falconctl_OldLocation="/Library/CS/falconctl"

# Get OS Version Details
osVersion=$( /usr/bin/sw_vers -productVersion )
osMajorVersion=$( echo "${osVersion}" | /usr/bin/awk -F '.' '{print $1}' )
osMinorPatchVersion=$( echo "${osVersion}" | /usr/bin/awk -F '.' '{print $2"."$3}' )

# Hold statuses
returnResult=""

if [[ $( /usr/bin/bc <<< "${osMajorVersion} == 10" ) -eq 1 && $( /usr/bin/bc <<< "${osMinorPatchVersion} <= 12" ) -eq 1 ]]; then

    # macOS 10.12 or older -- technically 10.12 still communicates, but should be cut off on 12/9/2020 -- I'm calling it early here.
    echo "<result>OS Version Not Supported</result>"
    exit 0

elif  [[ -e "${falconctl_AppLocation}" && -e "${falconctl_OldLocation}" ]]; then

    # Multiple versions installed
    echo "<result>ERROR:  Multiple CS Versions installed</result>"
    exit 0

elif  [[ -e "${falconctl_AppLocation}" ]]; then

    # Get falconctl stats
    falconctlStats=$( getFalconctlStats "${falconctl_AppLocation}" )

    # Get the CS Major.Minor Version string
    csMajorMinorVersion=$( getCSMajorMinorVersion "${falconctlStats}" )

elif  [[ -e "${falconctl_OldLocation}" ]]; then

    # Get falconctl stats
    falconctlStats=$( getFalconctlStats "${falconctl_OldLocation}" )

    # Get the CS Major.Minor Version string
    csMajorMinorVersion=$( getCSMajorMinorVersion "${falconctlStats}" )

    if [[ -z "${csMajorMinorVersion}" ]]; then

        # Get the Crowd Strike version from sysctl for versions prior to v5.36.
        getCSVersion=$( /usr/sbin/sysctl -n cs.version )
        csVersionExitCode=$?

        if [[ $csVersionExitCode -eq 0 ]]; then

            # Get the CS Major.Minor Version string
            csMajorMinorVersion=$( getCSMajorMinorVersion "version: ${getCSVersion}" )

        else

            returnResult+="Not Running;"

        fi

    fi

else

    echo "<result>Not Installed</result>"
    exit 0

fi

# Check CS Version
if [[ $( /usr/bin/bc <<< "${csMajorMinorVersion} >= 6" ) -eq 1 && $( /usr/bin/bc <<< "${osMajorVersion} >= 11" ) -eq 1 ]]; then

    # Get the Sensor State
    sensorState=$( echo "${falconctlStats}" | /usr/bin/awk -F "Sensor operational:" '{print $2}' | /usr/bin/xargs )

    # Verify Sensor State
    if [[ "${sensorState}" != "true" && -n "${sensorState}" ]]; then

        returnResult+=" Sensor State: ${sensorState};"

    fi

fi


# Check CS Version
if [[ $( /usr/bin/bc <<< "${csMajorMinorVersion} < 5.34" ) -eq 1 ]]; then

    echo "<result>Sensor Version Not Supported</result>"
    exit 0

elif [[ $( /usr/bin/bc <<< "${csMajorMinorVersion} < 5.36" ) -eq 1 ]]; then

    # Get the customer ID to compare.
    csCustomerID=$( /usr/sbin/sysctl -n cs.customerid 2>&1 )

else

    csCustomerID=$( echo "${falconctlStats}" | /usr/bin/awk -F "customerID:" '{print $2}' | /usr/bin/xargs )

fi

# Verify CS Customer ID (CID)
if [[ "${csCustomerID}" != "${expectedCSCustomerID}" ]]; then

    returnResult+=" Invalid Customer ID;"

fi

# Get the connection established dates.
connectionState=$( echo "${falconctlStats}" | /usr/bin/awk -F "State:" '{print $2}' | /usr/bin/xargs )
established=$( echo "${falconctlStats}" | /usr/bin/awk -F "[^Last] Established At:" '{print $2}' | /usr/bin/xargs )
lastEstablished=$( echo "${falconctlStats}" | /usr/bin/awk -F "Last Established At:" '{print $2}' | /usr/bin/xargs )

if [[ "${connectionState}" == "connected" ]]; then

    # Compare if both were available.
    if [[ -n "${established}" && -n "${lastEstablished}" ]]; then

        # Check which is more recent.
        if [[ $( /bin/date -j -f "%b %d %Y %H:%M:%S" "$(echo "${established}" | /usr/bin/sed 's/,//g; s/ at//g; s/ [AP]M//g')" +"%s" ) -ge $( /bin/date -j -f "%b %d %Y %H:%M:%S" "$(echo "${lastEstablished}" | /usr/bin/sed 's/,//g; s/ at//g; s/ [AP]M//g')" +"%s" ) ]]; then

            testConnectionDate="${established}"

        else

            testConnectionDate="${lastEstablished}"

        fi

        # Check if the more recent date is older than seven days
        checkLastConnection "${testConnectionDate}" $lastConnectedVariance

    elif [[ -n "${established}" ]]; then

        # If only the Established date was available, check if it is older than seven days.
        checkLastConnection "${established}" $lastConnectedVariance

    elif [[ -n "${lastEstablished}" ]]; then

        # If only the Last Established date was available, check if it is older than seven days.
        checkLastConnection "${lastEstablished}" $lastConnectedVariance

    else

        # If no connection date was available, return disconnected
        returnResult+=" Unknown Connection State;"

    fi

elif [[ -n "${connectionState}" ]]; then

    # If no connection date was available, return state
    returnResult+=" Connection State: ${connectionState};"

fi

# Get the status of SIP, if SIP is disabled, we don't need to check if the SysExts, KEXTs, nor FDA are enabled.
sipStatus=$( /usr/bin/csrutil status | /usr/bin/awk -F ': ' '{printf $2}' | /usr/bin/awk -F '.' '{printf $1}' )

if [[ "${sipStatus}" == "enabled" ]]; then

    ##### System Extension Verification #####
    # Check if the OS version is 10.15.4 or newer, if it is, check if the System Extension is enabled.
    if [[ $( /usr/bin/bc <<< "${osMajorVersion} >= 11" ) -eq 1 ]]; then
    # A KEXT will be used on 10.15.4+ until Apple resolves an System Extension issue per CrowdStrike.
    ## The below condition will be replace the one above, once the issue is resolved and implemented in a future version of CrowdStrike.
    # if [[ $( /usr/bin/bc <<< "${osMinorPatchVersion} >= 15.4" ) -eq 1 || $( /usr/bin/bc <<< "${osMajorVersion} >= 11" ) -eq 1 ]]; then

        if [[ -e "/Library/SystemExtensions/db.plist" ]]; then

            extensionEnabled=$( /usr/bin/systemextensionsctl list | /usr/bin/awk -F 'X9E956P446.+\\[|\\]' '{printf $2}' )

            # Verify Extension is Activated and Enabled
            if [[ "${extensionEnabled}" != "activated enabled" ]]; then

                if [[ -n "${extensionEnabled}" ]]; then

                    returnResult+=" SysExt: ${extensionEnabled};"

                else

                    returnResult+=" SysExt not loaded"

                fi

                teamIDAllowed=$( /usr/libexec/PlistBuddy -c "Print :extensionPolicies:0:allowedTeamIDs" /Library/SystemExtensions/db.plist 2> /dev/null )
                extensionAllowed=$( /usr/libexec/PlistBuddy -c "Print :extensionPolicies:0:allowedExtensions:X9E956P446" /Library/SystemExtensions/db.plist 2> /dev/null )
                extensionTypesAllowed=$( /usr/libexec/PlistBuddy -c "Print :extensionPolicies:0:allowedExtensionTypes:X9E956P446" /Library/SystemExtensions/db.plist 2> /dev/null )

                if [[ "${teamIDAllowed}" != *"X9E956P446"*  && "${extensionAllowed}" != *"com.crowdstrike.falcon.Agent"* ]]; then

                    returnResult+=" SysExt not managed;"

                fi

                if [[ "${extensionTypesAllowed}" != *"com.apple.system_extension.network_extension"* || "${extensionTypesAllowed}" != *"com.apple.system_extension.endpoint_security"* ]]; then

                    returnResult+=" SysExt Types not managed;"

                fi

            fi

        else

            returnResult+=" SysExt not enabled or managed;"

        fi

    fi

    ##### Kernel Extension Verification #####
    # Check if the OS version is 10.13.2 or newer, if it is, check if the KEXT is enabled.
    ## Support for 10.13 is dropping at end of 2020!
    ### A KEXT will be used on macOS 11 until Apple releases an System Extension API for Firmware Analysis.
    if [[ $( /usr/bin/bc <<< "${osMinorPatchVersion} >= 13.2" ) -eq 1 || ( $( /usr/bin/bc <<< "${osMajorVersion} >= 11" ) -eq 1 && "${csFirmwareAnalysisEnable}" == "true" ) ]]; then

    # A KEXT will be used on 10.15.4+ until Apple resolves an System Extension issue per CrowdStrike.
    ## The below condition will be replace the one above, once the issue is resolved and implemented in a future version of CrowdStrike.
    # if [[ ( $( /usr/bin/bc <<< "${osMinorPatchVersion} >= 13.2" ) -eq 1 && $( /usr/bin/bc <<< "${osMinorPatchVersion} <= 15.3" ) -eq 1 ) || ( $( /usr/bin/bc <<< "${osMajorVersion} >= 11" ) -eq 1 && "${csFirmwareAnalysisEnable}" == "true" ) ]]; then

        # Get how many KEXTs are loaded.
        kextsLoaded=$( /usr/sbin/kextstat | /usr/bin/grep "com.crowdstrike" | /usr/bin/wc -l | /usr/bin/xargs )

        # Compare loaded KEXTs versus expected KEXTs
        if [[ "${kextsLoaded}" -eq 0 ]]; then

            returnResult+=" KEXT not loaded;"

            # Check if the kernel extension is enabled (whether approved by MDM or by a user).
            mdm_cs_sensor=$( /usr/bin/sqlite3 /var/db/SystemPolicyConfiguration/KextPolicy "select allowed from kext_policy_mdm where team_id='X9E956P446';" )
            user_cs_sensor=$( /usr/bin/sqlite3 /var/db/SystemPolicyConfiguration/KextPolicy "select allowed from kext_policy where team_id='X9E956P446' and bundle_id='com.crowdstrike.sensor';" )

            if [[ -n "${mdm_cs_sensor}" || -n "${user_cs_sensor}" ]]; then

                # Combine the results -- not to concerned how it's enabled as long as it _is_ enabled.
                cs_sensor=$(( mdm_cs_sensor + user_cs_sensor ))

                if [[ "${cs_sensor}" -eq 0 ]]; then

                    returnResult+=" KEXT not enabled;"

                fi

            fi

        fi

    fi

    ##### Privacy Preferences Profile Control Verification #####
    # Check if Full Disk Access is enabled.
    if [[ $( /usr/bin/bc <<< "${osMinorPatchVersion} >= 14" ) -eq 1 || $( /usr/bin/bc <<< "${osMajorVersion} >= 11" ) -eq 1 ]]; then

        # Get the TCC Database versions
        tccdbVersion=$( /usr/bin/sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "select value from admin where key == 'version';" )

        # Check if FDA is enabled (whether by MDM or by a user).
        if [[ $( /usr/bin/bc <<< "${csMajorMinorVersion} >= 6" ) -eq 1 ]]; then
        # If running CrowdStrike v6.x+

            if [[ -e "/Library/Application Support/com.apple.TCC/MDMOverrides.plist" ]]; then

                mdm_fda_enabled=$( /usr/libexec/PlistBuddy -c "Print :com.crowdstrike.falcon.Agent:kTCCServiceSystemPolicyAllFiles:Allowed" "/Library/Application Support/com.apple.TCC/MDMOverrides.plist" 2>/dev/null )

            fi

            # Check which version of the TCC database being accessed
            if [[ $tccdbVersion -eq 15 ]]; then

                user_fda_enabled=$( /usr/bin/sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "select allowed from access where service = 'kTCCServiceSystemPolicyAllFiles' and client like 'com.crowdstrike.falcon.Agent';" )

            elif [[ $tccdbVersion -eq 19 ]]; then

                user_fda_enabled=$( /usr/bin/sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "select auth_value from access where service = 'kTCCServiceSystemPolicyAllFiles' and client like 'com.crowdstrike.falcon.Agent';" )

            fi

        else
            # If running CrowdStrike v5.x.x

            if [[ -e "/Library/Application Support/com.apple.TCC/MDMOverrides.plist" ]]; then

                mdm_fda_enabled=$( /usr/libexec/PlistBuddy -c "Print :/Library/CS/falcond:kTCCServiceSystemPolicyAllFiles:Allowed" "/Library/Application Support/com.apple.TCC/MDMOverrides.plist" 2>/dev/null )

            fi

            # Check which version of the TCC database being accessed
            if [[ $tccdbVersion -eq 15 ]]; then

                user_fda_enabled=$( /usr/bin/sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "select allowed from access where service = 'kTCCServiceSystemPolicyAllFiles' and client like '/Library/CS/falcond';" )

            elif [[ $tccdbVersion -eq 19 ]]; then

                user_fda_enabled=$( /usr/bin/sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "select auth_value from access where service = 'kTCCServiceSystemPolicyAllFiles' and client like '/Library/CS/falcond';" )

            fi

        fi

        # Not to concerned how it's enabled as long as it _is_ enabled.
        if [[ "${mdm_fda_enabled}" != "true" && "${mdm_fda_enabled}" -ne 1 && "${user_fda_enabled}" -ne 1 ]]; then

            returnResult+=" FDA not enabled;"

        fi

    fi

fi

# Return the EA Value.
if [[ -n "${returnResult}" ]]; then

    # Trim leading space
    returnResult="${returnResult## }"
    # Trim trailing ;
    echo "<result>${returnResult%%;}</result>"

else

    echo "<result>Running</result>"

fi

exit 0