#!/bin/bash

###################################################################################################
# Script Name:  Uninstall-CoreShellHelper.sh
# By:  Zack Thompson / Created:  4/5/2021
# Version:  1.0.0 / Updated:  4/5/2021 / By:  ZT
#
# Description:  This script uninstalls CoreShell Helper.
#
###################################################################################################

echo "*****  Uninstall Core Shell Helper process:  START  *****"

##################################################
# Define Variables

# Get OS Version Details
os_version=$( /usr/bin/sw_vers -productVersion )
os_major_version=$( echo "${os_version}" | /usr/bin/awk -F '.' '{print $1}' )
os_minor_patch_version=$( echo "${os_version}" | /usr/bin/awk -F '.' '{print $2"."$3}' )

# Get the Console User
console_user=$( /usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk '/Name :/ && ! /loginwindow/ { print $3 }' )

# Get the Console Users' UniqueID
console_uid=$( /usr/bin/id -u "${console_user}" )

# Core Shell Details
launch_agent_label="E78WKS7W4U.io.coressh.helper"
launch_agent_location="/Library/LaunchAgents/${launch_agent_label}.plist"
coressh_helper="/Library/PrivilegedHelperTools/io.coressh.Helper.app"

##################################################
# Bits staged...

# Verify install is being performed on the boot volume
if [[ "${3}" = "/" ]]; then

    if [[ -z "${console_uid}" || "${console_user}" == "loginwindow" ]]; then

        echo "Notice:  A console user is not currently logged in, will not attempt to unload the LaunchAgent"

    else

        if [[ -e "${launch_agent_location}" ]]; then

            # Check if the LaunchAgent is running before loading it again.
            # Determine proper launchctl syntax based on OS Version.
            # macOS 11+ or macOS 10.11+
            if [[ $( /usr/bin/bc <<< "${os_major_version} >= 11" ) -eq 1 || ( "${os_major_version}" == 10 && $( /usr/bin/bc <<< "${os_minor_patch_version} >= 11" ) -eq 1 ) ]]; then

                launchctl_exit_code=$( /bin/launchctl print gui/"${console_uid}"/"${launch_agent_label}" > /dev/null 2>&1; echo $? )

                if [[ $launchctl_exit_code == 0 ]]; then
                    echo "Stopping agent:  ${launch_agent_location}"
                    /bin/launchctl bootout gui/"${console_uid}"/"${launch_agent_label}"

                fi

            # macOS 10.x - macOS 10.10
            elif [[ "${os_major_version}" == 10 && $( /usr/bin/bc <<< "${os_minor_patch_version} <= 10" ) -eq 1 ]]; then

                launchctl_exit_code=$( /bin/launchctl asuser "${console_uid}" /bin/launchctl list "${launch_agent_label}" > /dev/null 2>&1; echo $? )

                if [[ $launchctl_exit_code == 0 ]]; then
                    echo "Stopping agent:  ${launch_agent_location}"
                    /bin/launchctl asuser "${console_uid}" /bin/launchctl unload "${launch_agent_location}"

                fi

            fi

        fi

    fi

fi

# Remove files
if [[ -e "${launch_agent_location}" ]]; then

    echo "Removing LaunchAgent..."
    /bin/rm -rf "${launch_agent_location}"

fi

if [[ -e "${coressh_helper}" ]]; then

    echo "Removing CoreShell Helper..."
    /bin/rm -rf "${coressh_helper}"

fi

echo "*****  Uninstall Core Shell Helper process:  COMPLETE  *****"
exit 0