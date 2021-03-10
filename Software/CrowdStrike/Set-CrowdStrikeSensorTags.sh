#!/bin/bash

###################################################################################################
# Script Name:  Set-CrowdStrikeSensorTags.sh
# By:  Zack Thompson / Created:  3/2/2021
# Version:  1.2.0 / Updated:  3/9/2021 / By:  ZT
#
# Description:  This script sets the CrowdStrike Sensor Group Tags.
#
###################################################################################################

echo -e "*****  CrowdStrike Sensor Tag Process:  START  *****\n"

##################################################
# Define Variables

# Define the available groups
available_groups="Production Group
Test Group
Beta Group"

# This plist domain will contain which Site the device is assigned to
# Example:  Use Configuration Profile Variables to configure a custom plist
configured_plist_domain="/Library/Managed Preferences/edu.asu.AboutMac.plist"

# Used if hard coding a sensor group tag
selected_group=${4}

# Action options are:
#   "Self Service" - use if you want to allow users to select their sensor group
#   "Reset" - use if you want to force reset the Sensor Version Test Group
action="${5}"

# Possible falconctl binary locations
falconctl_app_location="/Applications/Falcon.app/Contents/Resources/falconctl"
falconctl_old_location="/Library/CS/falconctl"

# Get OS Version Details
osVersion=$( /usr/bin/sw_vers -productVersion )
osMajorVersion=$( echo "${osVersion}" | /usr/bin/awk -F '.' '{print $1}' )
osMinorPatchVersion=$( echo "${osVersion}" | /usr/bin/awk -F '.' '{print $2"."$3}' )

# Turn on case-insensitive pattern matching
shopt -s nocasematch

##################################################
# Functions

# Function to handle exit checks
exit_check() {

    if [[ $1 != 0 ]]; then

        echo -e "${2}\n\n*****  CrowdStrike Sensor Tag Process:  FAILED  *****"
        exit "${1}"

    fi

}

# Reusable display dialog box helper
osascript_dialog_helper() {

    if [[ "${action}" == "Self Service" ]]; then

        /usr/bin/osascript -e 'tell application (path to frontmost application as text)' -e 'display dialog "'"${1}"'" buttons {"OK"} with icon POSIX file "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"' -e 'end tell' &

    fi

}

##################################################
# Bits staged...

# Check is both an action and a sensor group were passed...
if [[ -n "${action}" && -n "${selected_group}" ]]; then

    exit_check 1 "ERROR:  Providing both an Action and preselected Sensor Group is not supported"


# Check if Self Service or a sensor group was passed...
elif [[ "${action}" == "Self Service" || -n "${selected_group}" ]]; then

    # Only supporting 10.15 or newer to test newer versions of the Falcon Sensor
    if [[ $( /usr/bin/bc <<< "${osMajorVersion} == 10" ) -eq 1 && $( /usr/bin/bc <<< "${osMinorPatchVersion} < 15" ) -eq 1 ]]; then

        osascript_dialog_helper "Testing new versions of CrowdStrike Falcon is only supported on macOS 10.15 Catalina or newer."
        exit_check 4 "WARNING:  Testing new versions of CrowdStrike Falcon is only supported on macOS 10.15 Catalina or newer."

    fi

fi

# Check which location exists
if  [[ -e "${falconctl_app_location}" && -e "${falconctl_old_location}" ]]; then

    osascript_dialog_helper "CrowdStrike Falcon not in a healthy state."
    exit_check 2 "ERROR:  Multiple versions installed"

elif  [[ -e "${falconctl_app_location}" ]]; then

    falconctl="${falconctl_app_location}"

elif  [[ -e "${falconctl_old_location}" ]]; then

    falconctl="${falconctl_old_location}"

else

    osascript_dialog_helper "CrowdStrike Falcon not installed!"
    exit_check 3 "ERROR:  CrowdStrike Falcon is not installed"

fi

# Get the CS Agent Info which contains the version
cs_agent_info=$( "${falconctl}" stats agent_info --plist 2> /dev/null )

# Get the version string
cs_version=$( /usr/libexec/PlistBuddy -c "Print :agent_info:version" 2> /dev/null /dev/stdin <<< "$( echo ${cs_agent_info} )" | /usr/bin/awk -F '.' '{print $1"."$2}' )

if [[ -z "${cs_version}" ]]; then

    # Get the Crowd Strike version from sysctl for versions prior to v5.36.
    get_cs_version=$( /usr/sbin/sysctl -n cs.version )
    cs_version_exit_code=$?

    if [[ $cs_version_exit_code -eq 0 ]]; then

        cs_version=$( echo "${get_cs_version}" | /usr/bin/awk -F '.' '{print $1"."$2}' )
        falconctl="${falconctl_old_location}"

    else

        osascript_dialog_helper "CrowdStrike Falcon not in a healthy state."
        exit_check 5 "ERROR:  CrowdStike Falcon is not able to run or not in a healthy state; unable to determine the installed sensor version"

    fi

fi

# Check CS Version
if [[ $( /usr/bin/bc <<< "${cs_version} < 5.30" ) -eq 1 ]]; then

    osascript_dialog_helper "Running an outdated version of CrowdStrike Falcon is not supported."
    exit_check 6 "ERROR:  Sensor version does not support tagging"

fi

# Check if the plist exists; this is how we'll inform the device which Site it is in
if [[ ! -e "${configured_plist_domain}" ]]; then

    exit_check 7 "WARNING:  preference domain not configured"

else

    site_tag=$( /usr/bin/defaults read "${configured_plist_domain}" "Site" | /usr/bin/sed 's/[.]/-/g' | /usr/bin/sed 's/ /_/g' )

fi

# Check the current tags, before applying
current_tags=$( "${falconctl}" grouping-tags get | /usr/bin/awk -F 'Grouping tags: ' '{print $2}' )

# Check which action was passed...
if [[ "${action}" == "Reset" ]]; then

    # sensor_tags="ent/${site_tag}"
    echo "Resetting sensor version group tag..."

elif [[ "${action}" == "Self Service" ]]; then

    # Prompt user for actions to take
    prompt_for_choice="tell application (path to frontmost application as text) to choose from list every paragraph of \"${available_groups}\" with multiple selections allowed with title \"Falcon Sensor Group\" with prompt \"Choose which testing group to join:\" OK button name \"Select\" cancel button name \"Cancel\""
    selected_group=$( /usr/bin/osascript -e "${prompt_for_choice}" )

elif [[ -n "${action}" ]]; then

    exit_check 8 "ERROR:  Unknown action specified"

fi

# Combine the sensor tags
if [[ -z "${selected_group}" && -z "${action}" ]]; then

    # Potentially re-setting the `site_tag`; in this case, re-use the current `sensor_version_group_tag`
    current_sensor_version_group_tag=$( echo "${current_tags}" | /usr/bin/awk -F 'sensor/' '{print $2}' )

    if [[ -n "${current_sensor_version_group_tag}" ]]; then
    
        sensor_tags="ent/${site_tag},sensor/${current_sensor_version_group_tag}"

    else

        sensor_tags="ent/${site_tag}"

    fi

else

    # Check the sensor group tag based on the provided or selected group
    if [[ "${selected_group}" == "false" ]]; then

        echo "NOTICE:  User canceled the prompt"
        echo -e "\n*****  CrowdStrike Sensor Tag Process:  CANCELED  *****"
        exit 0

    elif [[ "${selected_group}" == *"Production"* ]]; then

        sensor_version_group_tag=""

    elif [[ "${selected_group}" == *"Test"* ]]; then

        sensor_version_group_tag=",sensor/test"

    elif [[ "${selected_group}" == *"Beta"* ]]; then

        sensor_version_group_tag=",sensor/beta"

    elif [[ -n "${selected_group}" ]]; then

        exit_check 9 "ERROR:  Passed sensor version group is not supported"

    fi

    sensor_tags="ent/${site_tag}${sensor_version_group_tag}"

fi

# Turn off case-insensitive pattern matching
shopt -u nocasematch

# Apply tags if different
if [[ "${current_tags}" == "${sensor_tags}" ]]; then

    echo "NOTICE:  Sensors tags are current, no change required."

else

    echo -e "Current Sensor Tags:  ${current_tags} \nNew Sensor Tags:  ${sensor_tags}"

    echo "Applying sensor tags..."
    exit_status=$( "${falconctl}" grouping-tags set "${sensor_tags}" 2>&1 )
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then

        osascript_dialog_helper "Failed to apply the test group, please contact your Deskside support group for assistance."
        exit_check 10 "ERROR:  Failed to set the sensor tags! \nError Output:  ${exit_status}"

    fi

    echo "Reloading sensor..."
    unload_exit_status=$( "${falconctl}" unload 2>&1 )
    unload_exit_code=$?

    if [[ $unload_exit_code -ne 0 ]]; then

        if [[ "${unload_exit_status}" == "Error: A maintenance token is required to unload. Specify one with -t." ]]; then

            osascript_dialog_helper "A reboot is required to complete the change."
            echo "NOTICE:  Sensor Group Tag will not be updated until a reboot"
            echo -e "\n*****  CrowdStrike Sensor Tag Process:  COMPLETE  *****"
            exit 0


        else

            osascript_dialog_helper "Failed to apply the test group, please contact your Deskside support group for assistance."
            exit_check 11 "ERROR:  Failed to unload the sensor! \nError Output:  ${unload_exit_status}"

        fi

    fi

    load_exit_status=$( "${falconctl}" load 2>&1 )
    load_exit_code=$?

    if [[ $load_exit_code -ne 0 ]]; then

        osascript_dialog_helper "Failed to apply the test group, please contact your Deskside support group for assistance."
        exit_check 12 "ERROR:  Failed to load the sensor! \nError Output:  ${load_exit_status}"

    fi

fi

echo -e "\n*****  CrowdStrike Sensor Tag Process:  COMPLETE  *****"
exit 0