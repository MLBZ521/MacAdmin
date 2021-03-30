#!/bin/bash

###################################################################################################
# Script Name:  Setup-Xcode.sh
# By:  Zack Thompson / Created:  3/29/2021
# Version:  1.0.0 / Updated:  3/29/2021 / By:  ZT
#
# Description:  This script customizes and sets up the Xcode environment for immediate use.
#
###################################################################################################

echo "*****  Setup Xcode Process:  START  *****"

##################################################
# Define Variables

# Specify whether or not to rename the Xcode.app bundle; options are:
#   true:  "Xcode 12.app"
#   false:  "Xcode.app"
include_version_in_app_name="${4}"

# Specify setting developer permissions; options are:
#   everyone = adds the "everyone" group as a member of "_developer" group
#   launchagent = use a LaunchAgent to add "$USER" as a member of the "_developer" group
#   null (no value) = do nothing
set_developer_perms="${5}"
launch_agent_label="${6}"
launch_agent_location="/Library/LaunchAgents/${launch_agent_label}.plist"

# Specify wether or not to edit the authorizationdb to allow any member of "_developer" group 
# to be able to install Apple-provided software; options are:
#   true:  edits the authorizationdb to allow any member of _developer to install Apple-provided software
#   false:  does nothing
allow_devs_auth="${7}"

# Default path
xcode_path="/Applications/Xcode.app"

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

if [[ -d "${xcode_path}" ]]; then

    # Remove quarantine bit just in case.
    /usr/bin/xattr -dr com.apple.quarantine "${xcode_path}"

    # Turn on case-insensitive pattern matching
    shopt -s nocasematch

    if [[ $include_version_in_app_name == "true" ]]; then

        # Turn off case-insensitive pattern matching
        shopt -u nocasematch

        # Get the major version of the current Xcode app
        xcode_version=$( /usr/bin/defaults read "${xcode_path}/Contents/Info.plist" CFBundleShortVersionString )
        xcode_major_version=$( echo "${xcode_version}" | /usr/bin/awk -F '.' '{print $1}' )
        new_xcode_path="/Applications/Xcode ${xcode_major_version}.app"

        # Update the Xcode app name
        /bin/mv "${xcode_path}" "${new_xcode_path}"

        # Specify the version of Xcode to use
        /usr/bin/xcode-select --switch "${new_xcode_path}"

    else

        # Specify the version of Xcode to use
        /usr/bin/xcode-select --switch "${xcode_path}"

    fi

else

    echo "ERROR:  Xcode is not in the expected location!"
    echo "*****  Setup Xcode Process:  FAILED  *****"
    exit 1

fi

# Change the authorization policies to allow members of the admin and _developer groups to be 
# able to authenticate to use the Apple-code-signed debugger or performance analysis tools
/usr/sbin/DevToolsSecurity -enable

# Accept the Xcode license
/usr/bin/xcodebuild -license accept

# Install all additional components
/usr/bin/xcodebuild -runFirstLaunch

# Turn on case-insensitive pattern matching
shopt -s nocasematch

if [[ "${allow_devs_auth}" == "true" ]]; then

    echo "Editing the authorizationdb to allow members of \`_developer\` group to install Apple-provided software"
    # Allow any member of _developer to install Apple-provided software
    /usr/bin/security authorizationdb write system.install.apple-software authenticate-developer

fi

if [[ -z "${set_developer_perms}" ]]; then

    echo "Not configuring the developer permissions..."

elif [[ "${set_developer_perms}" == "everyone" ]]; then

    echo "Adding the \`everyone\` group as a member of the \`_developer\` group."
    # Add the "everyone" group as a member of "_developer" group
    /usr/sbin/dseditgroup -o edit -a everyone -t group _developer

elif [[ "${set_developer_perms}" == "launchagent" ]]; then

    # Turn off case-insensitive pattern matching
    shopt -u nocasematch

    echo "Creating LaunchAgent to manage the \`_developer\` group:  ${launch_agent_location}"
    # Create a LaunchAgent
    echo "LaunchAgent is:  ${launch_agent_location}"

    /bin/cat > "${launch_agent_location}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>Label</key>
        <string>$launch_agent_label</string>
        <key>ProgramArguments</key>
        <array>
            <string>sh</string>
            <string>-c</string>
            <string>/usr/sbin/dseditgroup -o edit -a "${USER}" -t user _developer</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
    </dict>
</plist>
EOF

    /usr/sbin/chown root:wheel "${launch_agent_location}"
    /bin/chmod 644 "${launch_agent_location}"

    if [[ -z "${console_uid}" || "${console_user}" == "loginwindow" ]]; then

        echo "Notice:  A console user is not currently logged in, will not attempt to bootstrap the LaunchAgent"

    else

        if [[ -e "${launch_agent_location}" ]]; then

            # Check if the LaunchDaemon is running before loading it again.
            # Determine proper launchctl syntax based on OS Version.
            # macOS 11+ or macOS 10.11+
            if [[ $( /usr/bin/bc <<< "${os_major_version} >= 11" ) -eq 1 || ( "${os_major_version}" == 10 && $( /usr/bin/bc <<< "${os_minor_patch_version} >= 11" ) -eq 1 ) ]]; then

                exit_code=$( /bin/launchctl print gui/"${console_uid}"/"${launch_agent_label}" > /dev/null 2>&1; echo $? )

                if [[ $exit_code == 0 ]]; then
                    echo "Stopping agent:  ${launch_agent_location}"
                    /bin/launchctl bootout gui/"${console_uid}"/"${launch_agent_label}"

                fi

                echo "Starting agent:  ${launch_agent_location}"
                /bin/launchctl bootstrap gui/"${console_uid}" "${launch_agent_location}"
                /bin/launchctl enable gui/"${console_uid}"/"${launch_agent_label}"

            # macOS 10.x - macOS 10.10
            elif [[ "${os_major_version}" == 10 && $( /usr/bin/bc <<< "${os_minor_patch_version} <= 10" ) -eq 1 ]]; then

                exit_code=$( /bin/launchctl asuser "${console_uid}"/bin/launchctl list "${launch_agent_label}" > /dev/null 2>&1; echo $? )

                if [[ $exit_code == 0 ]]; then
                    echo "Stopping agent:  ${launch_agent_location}"
                    /bin/launchctl asuser "${console_uid}"/bin/launchctl unload "${launch_agent_location}"

                fi

                echo "Starting agent:  ${launch_agent_location}"
                /bin/launchctl asuser "${console_uid}"/bin/launchctl load "${launch_agent_location}"
                /bin/launchctl asuser "${console_uid}"/bin/launchctl start "${launch_agent_location}"

            fi

        fi

    fi

fi

echo "*****  Setup Xcode Process:  COMPLETE  *****"
exit 0