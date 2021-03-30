#!/bin/bash

###################################################################################################
# Script Name:  Manage-AndroidSDKCMDLineTools.sh
# By:  Zack Thompson / Created:  2/19/2021
# Version:  1.1.0 / Updated:  3/29/2021 / By:  ZT
#
# Description:  This script allows you to perform the initial configuration of the Android Studio 
#   Environment to use a custom SDK location which enables easier remote management of the SDK.
#   Also supports updating and installing SDK components.
#
# Note:  The initial configuration logic assumes that Android Studio (GUI) has not been launched.
#   If it has, existing settings will not be overwritten, but other configurations will be performed.
#
###################################################################################################

echo "*****  Manage AndroidSDKCMDLineTools process:  START  *****"

##################################################
# Script Parameters

# Action options are:
#   setup:  perform initial setup before or after installing the CLI Tools
#   update:  perform actions to update currently installed components
action="${4}"

shared_location="${5}" # default:  "/Users/Shared/Android"
sdk_components_to_install="${6}"
gui_enable_auto_update_checks="${7}" # options are:  "true" (default) or "false"
gui_update_channel="${8}" # "release" (aka stable; default)
launch_agent_label="${9}"
launch_agent_location="/Library/LaunchAgents/${launch_agent_label}.plist"

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

##################################################
# Functions

configure_updates() {

    # Configures the updates.xml file to configure the updates settings
    # Removed if statement since we're using bash and can't easily update XML
    # if [[ ! -x "${shared_location}/config/options/updates.xml" ]]; then

    echo "Configuring:  ${shared_location}/config/options/updates.xml"

    /bin/cat > "${shared_location}/config/options/updates.xml" << EOF
<application>
  <component name="UpdatesConfigurable">
    <option name="CHECK_NEEDED" value="$1" />
    <option name="UPDATE_CHANNEL_TYPE" value="$2" />
  </component>
</application>
EOF

    /usr/sbin/chown root:wheel "${shared_location}/config/options/updates.xml"
    /bin/chmod 777 "${shared_location}/config/options/updates.xml"

    # fi

}

# Install the passed SDK Components
install_components() {

    "${shared_location}/sdk/cmdline-tools/latest/bin/sdkmanager" --install "${1}"

}

##################################################
# Bits staged...

# Check if an action was supplied
if [[ -z "${action}" ]]; then

    echo "ERROR:  An \`action\` wasn't provided"
    echo "*****  Manage AndroidSDKCMDLineTools process:  FAILED  *****"
    exit 1

fi

# Set default values if not supplied
if [[ -z "${shared_location}" ]]; then

    shared_location="/Users/Shared/Android"

fi

# Turn on case-insensitive pattern matching
shopt -s nocasematch

# Perform initial setup before or after installing the CLI Tools
if [[ "${action}" == "setup" ]]; then

    # Turn off case-insensitive pattern matching
    shopt -u nocasematch

    # Set defaults if not passed 
    if [[ -z "${gui_enable_auto_update_checks}" ]]; then

        gui_enable_auto_update_checks="true"

    fi

    if [[ -z "${gui_update_channel}" ]]; then

        gui_update_channel="release"

    fi

    if [[ ! -d "${shared_location}" ]]; then

        /bin/mkdir -p -m 775 "${shared_location}"

    fi

    /usr/sbin/chown root:staff "${shared_location}"

    # Configure the idea.properties file
    if [[ ! -x "${shared_location}/idea.properties" ]]; then

        echo "Creating:  ${shared_location}/idea.properties"

        /bin/cat > "${shared_location}/idea.properties" << EOF
# Custom Android Studio properties
idea.config.path=$shared_location/config
idea.system.path=$shared_location/system
idea.plugins.path=$shared_location/config/plugins
idea.log.path=$shared_location/system/log
EOF

        /usr/sbin/chown root:wheel "${shared_location}/idea.properties"
        /bin/chmod 755 "${shared_location}/idea.properties"

    fi

    if [[ ! -d "${shared_location}/config/options" ]]; then

        /bin/mkdir -p -m 775 "${shared_location}/config/options"
        /usr/sbin/chown root:staff "${shared_location}/config/options"
        /bin/chmod 775 "${shared_location}/config"

    fi

    # Create the androidStudioFirstRun.xml file to prevent the import and setup wizard
    if [[ ! -x "${shared_location}/config/options/androidStudioFirstRun.xml" ]]; then

        echo "Creating:  ${shared_location}/config/options/androidStudioFirstRun.xml"

        /bin/cat > "${shared_location}/config/options/androidStudioFirstRun.xml" << EOF
<application>
  <component name="AndroidFirstRunPersistentData">
    <version>1</version>
  </component>
</application>
EOF

        /usr/sbin/chown root:wheel "${shared_location}/config/options/androidStudioFirstRun.xml"
        /bin/chmod 777 "${shared_location}/config/options/androidStudioFirstRun.xml"

    fi

    if [[ ! -x "${shared_location}/config/options/updates.xml" ]]; then

        # Function
        configure_updates "${gui_enable_auto_update_checks}" "${gui_update_channel}"

    fi

    # Agree to Licenses
    yes | "${shared_location}/sdk/cmdline-tools/latest/bin/sdkmanager" --licenses > /dev/null 2>&1

    # Create a LaunchAgent to set the Environment Variables for GUI Apps
    echo "Creating:  ${launch_agent_location}"

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
            <string>launchctl setenv ANDROID_SDK_ROOT $shared_location/sdk; 
            launchctl setenv STUDIO_PROPERTIES $shared_location/idea.properties; 
            launchctl setenv STUDIO_JDK /Applications/Android\ Studio.app/Contents/jre/jdk/Contents/Home; 
            launchctl setenv ANDROID_PREFS_ROOT $shared_location/.android; 
            launchctl setenv GRADLE_USER_HOME $shared_location/.gradle</string>
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

                exit_code=$( /bin/launchctl asuser "${console_uid}" /bin/launchctl list "${launch_agent_label}" > /dev/null 2>&1; echo $? )

                if [[ $exit_code == 0 ]]; then
                    echo "Stopping agent:  ${launch_agent_location}"
                    /bin/launchctl asuser "${console_uid}" /bin/launchctl unload "${launch_agent_location}"

                fi

                echo "Starting agent:  ${launch_agent_location}"
                /bin/launchctl asuser "${console_uid}" /bin/launchctl load "${launch_agent_location}"
                /bin/launchctl asuser "${console_uid}" /bin/launchctl start "${launch_agent_location}"

            fi

        fi

    fi

    # If supplied, install the passed components
    if [[ -n "${sdk_components_to_install}" ]]; then

        # Function
        install_components "${sdk_components_to_install}"

    fi

# Turn on case-insensitive pattern matching
shopt -s nocasematch

# Perform update actions
elif [[ "${action}" == "update" ]]; then

    # Turn off case-insensitive pattern matching
    shopt -u nocasematch

    # If supplied, configure the update settings
    if [[ -n "${gui_enable_auto_update_checks}" && -n "${gui_update_channel}" ]]; then

        # Function
        configure_updates "${gui_enable_auto_update_checks}" "${gui_update_channel}"

    fi

    # If supplied, install the passed components
    if [[ -n "${sdk_components_to_install}" ]]; then

        # Function
        install_components "${sdk_components_to_install}"

    fi

    # Update installed components
    "${shared_location}/sdk/cmdline-tools/latest/bin/sdkmanager" --update

else

    echo "ERROR:  An unknown \`action\` was provided:  ${action}"
    echo "*****  Manage AndroidSDKCMDLineTools process:  FAILED  *****"
    exit 1

fi

echo "*****  Manage AndroidSDKCMDLineTools process:  COMPLETE  *****"
exit 0