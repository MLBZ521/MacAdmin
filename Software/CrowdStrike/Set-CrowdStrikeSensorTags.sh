#!/bin/bash

###################################################################################################
# Script Name:  Set-CrowdStrikeSensorTags.sh
# By:  Zack Thompson / Created:  3/2/2021
# Version:  1.0.0 / Updated:  3/2/2021 / By:  ZT
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

# Possible falconctl binary locations
falconctl_app_location="/Applications/Falcon.app/Contents/Resources/falconctl"
falconctl_old_location="/Library/CS/falconctl"

# Only accepted action is "Self Service" and is only used if you want 
# to allow users to select their sensor group.
action="${5}"

# Used if hard coding a sensor group tag
selected_group=${4}

##################################################
# Functions

get_sensor_version() {

    csAgentInfo=$( "${1}" stats agent_info --plist )
    /usr/libexec/PlistBuddy -c "Print :agent_info:version" /dev/stdin <<< "$( echo ${csAgentInfo} )" | /usr/bin/awk -F '.' '{print $1"."$2}'

}

exit_check() {

    if [[ $1 != 0 ]]; then

        echo -e "${2}\n\n*****  CrowdStrike Sensor Tag Process:  FAILED  *****"
        exit "${1}"

    fi

}

##################################################
# Bits staged...

# Check which location exists
if  [[ -e "${falconctl_app_location}" && -e "${falconctl_old_location}" ]]; then

    exit_check 2 "ERROR:  Multiple versions installed"

elif  [[ -e "${falconctl_app_location}" ]]; then

    cs_version=$( get_sensor_version "${falconctl_app_location}" )

    falconctl="${falconctl_app_location}"

elif  [[ -e "${falconctl_old_location}" ]]; then

    cs_version=$( get_sensor_version "${falconctl_old_location}" )
    falconctl="${falconctl_old_location}"

else

    exit_check 3 "ERROR:  CrowdStrike Falcon is not installed"

fi

if [[ -z "${cs_version}" ]]; then

    # Get the Crowd Strike version from sysctl for versions prior to v5.36.
    get_cs_version=$( /usr/sbin/sysctl -n cs.version )
    cs_version_exit_code=$?

    if [[ $cs_version_exit_code -eq 0 ]]; then

        cs_version=$( echo "${get_cs_version}" | /usr/bin/awk -F '.' '{print $1"."$2}' )
        falconctl="${falconctl_old_location}"

    else

        exit_check 4 "ERROR:  Unable to determine the installed sensor version"

    fi

fi

# Check CS Version
if [[ $( /usr/bin/bc <<< "${cs_version} < 5.30" ) -eq 1 ]]; then

    exit_check 5 "Sensor version does not support tagging"

fi

# Check if the plist exists; this is how we'll inform the device which Site it is in
if [[ ! -e "${configured_plist_domain}" ]]; then

    exit_check 1 "WARNING:  preference domain not configured"

else

    site_tag=$( /usr/bin/defaults read "${configured_plist_domain}" "Site" | /usr/bin/sed 's/[.]/-/g' | /usr/bin/sed 's/ /_/g' )

fi

# Turn on case-insensitive pattern matching
shopt -s nocasematch

# If script is offered via Self Service...
if [[ "${action}" == "Self Service" ]]; then

    # Prompt user for actions to take
    prompt_for_choice="tell application (path to frontmost application as text) to choose from list every paragraph of \"${available_groups}\" with multiple selections allowed with title \"Falcon Sensor Group\" with prompt \"Choose which testing group to join:\" OK button name \"Select\" cancel button name \"Cancel\""
    selected_group=$( /usr/bin/osascript -e "${prompt_for_choice}" )

fi

# Test the sensor group tag based on the provided or selected group
if [[ "${selected_group}" == "false" ]]; then

    echo "NOTICE:  User canceled the prompt"
    echo -e "\n*****  CrowdStrike Sensor Tag Process:  CANCELED  *****"
    exit 0

elif [[ "${selected_group}" == *"Production"* ]]; then

    sensor_group_tag=""

elif [[ "${selected_group}" == *"Test"* ]]; then

    sensor_group_tag="sensor/test"

elif [[ "${selected_group}" == *"Beta"* ]]; then

    sensor_group_tag="sensor/beta"

else

    exit_check 10 "ERROR:  Passed sensor group is not supported"

fi

# Turn off case-insensitive pattern matching
shopt -u nocasematch

# Combine the sensor tags
if [[ -z "${sensor_group_tag}" ]]; then

    sensor_tags="ent/${site_tag}"

else

    sensor_tags="ent/${site_tag},${sensor_group_tag}"

fi

# Check the current tags, before applying
current_tags=$( "${falconctl}" grouping-tags get | /usr/bin/awk -F 'Grouping tags: ' '{print $2}' )

if [[ "${current_tags}" == "${sensor_tags}" ]]; then

    echo "NOTICE:  Sensors tags are current, no change required."

else

echo -e "Current Sensor Tags:  ${current_tags} \nNew Sensor Tags:  ${sensor_tags}"

    echo "Applying sensor tags..."
    exit_status=$( "${falconctl}" grouping-tags set "${sensor_tags}" )
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then

        exit_check 6 "ERROR:  Failed to set the sensor tags! \nError Output:  ${exit_status}"

    fi

    echo "Reloading sensor..."
    unload_exit_status=$( "${falconctl}" unload )
    unload_exit_code=$?

    if [[ $unload_exit_code -ne 0 ]]; then

        exit_check 7 "ERROR:  Failed to unload the sensor! \nError Output:  ${unload_exit_status}"

    fi

    load_exit_status=$( "${falconctl}" load )
    load_exit_code=$?

    if [[ $load_exit_code -ne 0 ]]; then

        exit_check 8 "ERROR:  Failed to load the sensor! \nError Output:  ${load_exit_status}"

    fi

fi

echo -e "\n*****  CrowdStrike Sensor Tag Process:  COMPLETE  *****"
exit 0