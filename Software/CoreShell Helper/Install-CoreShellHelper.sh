#!/bin/bash

###################################################################################################
# Script Name:  Install-CoreShellHelper.sh
# By:  Zack Thompson / Created:  4/5/2021
# Version:  1.0.0 / Updated:  4/5/2021 / By:  ZT
#
# Description:  This script installs CoreShell Helper.
#
###################################################################################################

echo "*****  Install Core Shell Helper process:  START  *****"

##################################################
# Define Variables

# Core Shell Details
launch_agent_label="E78WKS7W4U.io.coressh.helper"
launch_agent_location="/Library/LaunchAgents/${launch_agent_label}.plist"
coressh_helper_container_dir="/Library/PrivilegedHelperTools"
coressh_helper="${coressh_helper_container_dir}/io.coressh.Helper.app"

# Get OS Version Details
os_version=$( /usr/bin/sw_vers -productVersion )
os_major_version=$( echo "${os_version}" | /usr/bin/awk -F '.' '{print $1}' )
os_minor_patch_version=$( echo "${os_version}" | /usr/bin/awk -F '.' '{print $2"."$3}' )

# Get the Console User
console_user=$( /usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk '/Name :/ && ! /loginwindow/ { print $3 }' )

# Get the Console Users' UniqueID
console_uid=$( /usr/bin/id -u "${console_user}" )

##################################################
# Bits staged...

if [[ -d "${coressh_helper}" ]]; then

    echo "Creating the CoreShell LaunchAgent..."

    /bin/cat > "${launch_agent_location}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>KeepAlive</key>
    <false/>
    <key>Label</key>
    <string>E78WKS7W4U.io.coressh.helper</string>
    <key>LimitLoadToSessionType</key>
    <string>Aqua</string>
    <key>MachServices</key>
    <dict>
        <key>E78WKS7W4U.io.coressh.helper</key>
        <true/>
    </dict>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>ProgramArguments</key>
    <array>
        <string>$coressh_helper/Contents/MacOS/io.coressh.Helper</string>
    </array>
</dict>
</plist>
EOF

    /usr/sbin/chown root:wheel "${launch_agent_location}"
    /bin/chmod 644 "${launch_agent_location}"

    # Verify install is being performed on the boot volume
    if [[ "${3}" = "/" ]]; then

        if [[ -z "${console_uid}" || "${console_user}" == "loginwindow" ]]; then

            echo "Notice:  A console user is not currently logged in, will not attempt to bootstrap the LaunchAgent"

        else

            if [[ -e "${launch_agent_location}" ]]; then

                # Check if the LaunchDaemon is running before loading it again.
                # Determine proper launchctl syntax based on OS Version.
                # macOS 11+ or macOS 10.11+
                if [[ $( /usr/bin/bc <<< "${os_major_version} >= 11" ) -eq 1 || ( "${os_major_version}" == 10 && $( /usr/bin/bc <<< "${os_minor_patch_version} >= 11" ) -eq 1 ) ]]; then

                    launchctl_exit_code=$( /bin/launchctl print gui/"${console_uid}"/"${launch_agent_label}" > /dev/null 2>&1; echo $? )

                    if [[ $launchctl_exit_code == 0 ]]; then
                        echo "Stopping agent:  ${launch_agent_location}"
                        /bin/launchctl bootout gui/"${console_uid}"/"${launch_agent_label}"

                    fi

                    echo "Starting agent:  ${launch_agent_location}"
                    /bin/launchctl bootstrap gui/"${console_uid}" "${launch_agent_location}"
                    /bin/launchctl enable gui/"${console_uid}"/"${launch_agent_label}"

                # macOS 10.x - macOS 10.10
                elif [[ "${os_major_version}" == 10 && $( /usr/bin/bc <<< "${os_minor_patch_version} <= 10" ) -eq 1 ]]; then

                    launchctl_exit_code=$( /bin/launchctl asuser "${console_uid}" /bin/launchctl list "${launch_agent_label}" > /dev/null 2>&1; echo $? )

                    if [[ $launchctl_exit_code == 0 ]]; then
                        echo "Stopping agent:  ${launch_agent_location}"
                        /bin/launchctl asuser "${console_uid}" /bin/launchctl unload "${launch_agent_location}"

                    fi

                    echo "Starting agent:  ${launch_agent_location}"
                    /bin/launchctl asuser "${console_uid}" /bin/launchctl load "${launch_agent_location}"
                    /bin/launchctl asuser "${console_uid}" /bin/launchctl start "${launch_agent_location}"

                fi

            fi

        fi

    fi

else

    echo "ERROR:  CoreShell Helper application isn't in the expected location!"
    echo "*****  Install Core Shell Helper process:  FAILED  *****"
    exit 1

fi

echo "*****  Install Core Shell Helper process:  COMPLETE  *****"
exit 0