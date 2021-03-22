#!/bin/bash

###################################################################################################
# Script Name:  Remove-CrowdStrikeSensorMojaveHold.sh
# By:  Zack Thompson / Created:  3/12/2021
# Version:  1.1.0 / Updated:  3/22/2021 / By:  ZT
#
# Description:  This script removes the CrowdStrike Sensor Group Tag `mojave_hold` when the
#   required Configuration Profiles are installed.
#
###################################################################################################

echo -e "*****  Remove CrowdStrike Sensor Mojave Hold Process:  START  *****\n"

##################################################
# Define Variables

# Possible falconctl binary locations
falconctl_app_location="/Applications/Falcon.app/Contents/Resources/falconctl"
falconctl_old_location="/Library/CS/falconctl"

# Get OS Version Details
os_version=$( /usr/bin/sw_vers -productVersion )
os_major_version=$( echo "${os_version}" | /usr/bin/awk -F '.' '{print $1}' )
os_minor_patch_version=$( echo "${os_version}" | /usr/bin/awk -F '.' '{print $2"."$3}' )

##################################################
# Functions

# Function to handle exit checks
exit_check() {

    if [[ $1 != 0 ]]; then

        echo -e "${2}\n\n*****  Remove CrowdStrike Sensor Mojave Hold Process:  FAILED  *****"
        exit "${1}"

    fi

}

##################################################
# Bits staged...

# Only considering removing tag if running Big Sur or Catalina
if [[ $( /usr/bin/bc <<< "${os_major_version} >= 11" ) -eq 1 || "${os_minor_patch_version}" =~ "15"* ]]; then

    # Check which location exists
    if  [[ -e "${falconctl_app_location}" && -e "${falconctl_old_location}" ]]; then

        exit_check 1 "ERROR:  Multiple versions installed"

    elif  [[ -e "${falconctl_app_location}" ]]; then

        falconctl="${falconctl_app_location}"

    elif  [[ -e "${falconctl_old_location}" ]]; then

        falconctl="${falconctl_old_location}"

    else

        exit_check 2 "ERROR:  CrowdStrike Falcon is not installed"

    fi

    # Get the CS Agent Info which contains the version
    # Will eventually move to the --plist format, but it's supported on 5.34 (aka High Sierra)
    # cs_agent_info=$( "${falconctl}" stats agent_info --plist 2> /dev/null )
    cs_agent_info=$( "${falconctl}" stats agent_info 2> /dev/null )

    # Get the version string
    # cs_version=$( /usr/libexec/PlistBuddy -c "Print :agent_info:version" /dev/stdin <<< "${cs_agent_info}" 2> /dev/null | /usr/bin/awk -F '.' '{print $1"."$2}' )
    cs_version=$( echo "${cs_agent_info}" | /usr/bin/awk -F "version:" '{print $2}' | /usr/bin/xargs | /usr/bin/awk -F '.' '{print $1"."$2}' )
    # plistBuddyExitCode=$?

    # if [[ $plistBuddyExitCode -ne 0 ]]; then
    if [[ -z $cs_version ]]; then

        # Get the Crowd Strike version from sysctl for versions prior to v5.36.
        get_cs_version=$( /usr/sbin/sysctl -n cs.version )
        cs_version_exit_code=$?

        if [[ $cs_version_exit_code -eq 0 ]]; then

            cs_version=$( echo "${get_cs_version}" | /usr/bin/awk -F '.' '{print $1"."$2}' )
            falconctl="${falconctl_old_location}"

        else

            exit_check 3 "ERROR:  CrowdStrike Falcon is not able to run or not in a healthy state; unable to determine the installed sensor version"

        fi

    fi

    # Check CS Version
    if [[ $( /usr/bin/bc <<< "${cs_version} < 5.30" ) -eq 1 ]]; then

        exit_check 4 "ERROR:  Sensor version does not support tagging"

    fi

    # Get the current tags
    current_tags=$( "${falconctl}" grouping-tags get | /usr/bin/awk -F 'Grouping tags: ' '{print $2}' )

    if [[ "${current_tags}" =~ "mojave_hold" ]]; then

        # Check the version of the profiles utility
        profiles_version=$( /usr/bin/profiles version | /usr/bin/awk -F 'version: ' '{print $2}' | /usr/bin/xargs )

        if [[ $( /usr/bin/bc <<< "${profiles_version} >= 6" ) -eq 1 ]]; then

            profiles_cmd_results=$( /usr/bin/profiles list -verbose )

        else

            profiles_cmd_results=$( /usr/bin/profiles -C -v )

        fi

        # Get the installed profiles, specifically just their names
        installed_profiles=$( echo "${profiles_cmd_results}" | /usr/bin/grep attribute | /usr/bin/awk '/name/{$1=$2=$3=""; print $0}' | /usr/bin/sed 's/^ *//' )

        # Groups subscribed to all managed services
        # Matched as Regex!!
        declare -a required_profiles_all_services=( \
            "Kernel Extensions v1\.5" \
            "Privacy Preferences v1\.1" \
            "System Extensions v1\.0" \
            "CrowdStrike Falcon Web Content Filter v1\.0" \
            "CrowdStrike Falcon Notifications v1\.0"
        )

        # Groups subscribed to the Falcon Only Service
        # Matched as Regex!!
        declare -a required_profiles_falcon_only=( \
            "CrowdStrike Falcon Kernel Extensions v1\.1" \
            "CrowdStrike Falcon Privacy Preferences v1\.1" \
            "CrowdStrike Falcon System Extensions v1\.0" \
            "CrowdStrike Falcon Web Content Filter v1\.0" \
            "CrowdStrike Falcon Notifications v1\.0"
        )

        if [[ -n $installed_profiles ]]; then

            # Since we have no way to test which group a device is in,
            # check against both groups of required profiles
            test_array_one=()
            while IFS=$'\n' read -r profile; do

                [[ "${installed_profiles[*]}" =~ ${profile} ]] || test_array_one+=("${profile}")

            done < <( /usr/bin/printf '%s\n' "${required_profiles_all_services[@]}" )

            test_array_two=()
            while IFS='' read -r profile; do

                [[ "${installed_profiles[*]}" =~ ${profile} ]] || test_array_two+=("${profile}")

            done < <( /usr/bin/printf '%s\n' "${required_profiles_falcon_only[@]}" )

            # If one of the arrays comes back clean, the device has the required profiles
            if [[ -z ${test_array_one[*]} || -z ${test_array_two[*]} ]]; then

                # Remove the mojave_hold tag from the current tags
                updated_tags=$( echo "${current_tags}" | /usr/bin/awk -F ",mojave_hold" '{print $1}' )

                echo -e "Current Sensor Tags:  ${current_tags} \nNew Sensor Tags:  ${updated_tags}"

                echo "Applying sensor tags..."
                exit_status=$( "${falconctl}" grouping-tags set "${updated_tags}" 2>&1 )
                exit_code=$?

                if [[ $exit_code -ne 0 ]]; then

                    exit_check 5 "ERROR:  Failed to set the sensor tags! \nError Output:  ${exit_status}"

                fi

                echo "Reloading sensor..."
                unload_exit_status=$( "${falconctl}" unload 2>&1 )
                unload_exit_code=$?

                if [[ $unload_exit_code -ne 0 ]]; then

                    if [[ "${unload_exit_status}" == "Error: A maintenance token is required to unload. Specify one with -t." ]]; then

                        echo "NOTICE:  Sensor Group Tag will not be updated until a reboot"
                        echo -e "\n*****  Remove CrowdStrike Sensor Mojave Hold Process:  COMPLETE  *****"
                        exit 0

                    else

                        exit_check 6 "ERROR:  Failed to unload the sensor! \nError Output:  ${unload_exit_status}"

                    fi

                fi

                load_exit_status=$( "${falconctl}" load 2>&1 )
                load_exit_code=$?

                if [[ $load_exit_code -ne 0 ]]; then

                    exit_check 7 "ERROR:  Failed to load the sensor! \nError Output:  ${load_exit_status}"

                fi

            else

                # Device does not have the required profiles
                exit_check 8 "WARNING:  This device does not have the require profiles installed yet!"

            fi

        else

            echo "WARNING:  Failed to find any installed Configuration Profiles!"

        fi

    else

        echo "This device is not tagged"

    fi

else

    echo "WARNING:  The 'mojave_hold' tag should only removed when on Catalina or newer!"

fi

echo -e "\n*****  Remove CrowdStrike Sensor Mojave Hold Process:  COMPLETE  *****"
exit 0