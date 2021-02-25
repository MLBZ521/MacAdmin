#!/bin/bash

###################################################################################################
# Script Name:  Install-AndroidSDKCMDLine-Tools.sh
# By:  Zack Thompson / Created:  2/19/2021
# Version:  1.0.0 / Updated:  2/19/2021 / By:  ZT
#
# Description:  This script configures the Android Studio Environment to use a custom SDK location
#   which enables easier remote management of the SDK.
#
###################################################################################################

echo "*****  Install AndroidSDKCMDLine-Tools process:  START  *****"

##################################################
# Define Variables

shared_location="/Users/Shared/Android"
launch_agent_label="com.github.mlbz521.AndroidStudioEnvironmentVariables"
launch_agent_location="/Library/LaunchAgents/${launch_agent_label}.plist"

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

if [[ ! -d "${shared_location}" ]]; then

    /bin/mkdir -p -m 775 "${shared_location}"
    /usr/sbin/chown root:staff "${shared_location}"

fi

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

# Create the updates.xml file to configure the updates settings
if [[ ! -x "${shared_location}/config/options/updates.xml" ]]; then

    echo "Creating:  ${shared_location}/config/options/updates.xml"

    /bin/cat > "${shared_location}/config/options/updates.xml" << EOF
<application>
  <component name="UpdatesConfigurable">
    <option name="CHECK_NEEDED" value="false" />
    <option name="UPDATE_CHANNEL_TYPE" value="release" />
  </component>
</application>
EOF

    /usr/sbin/chown root:wheel "${shared_location}/config/options/updates.xml"
    /bin/chmod 777 "${shared_location}/config/options/updates.xml"

fi

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

if [[ -z "${console_uid}" || "${console_user}" = "loginwindow" ]]; then

    echo "Notice:  A console user is not currently logged in, will not attempt to bootstrap the LaunchAgent"

else

    if [[ -e "${launch_agent_location}" ]]; then

        # Check if the LaunchDaemon is running before loading it again.
        # Determine proper launchctl syntax based on OS Version.
        # macOS 11+ or macOS 10.11+
        if [[ $( /usr/bin/bc <<< "${os_major_version} >= 11" ) -eq 1 || ( $( /usr/bin/bc <<< "${os_major_version} == 10") -eq 1 && $( /usr/bin/bc <<< "${os_minor_patch_version} >= 11" ) -eq 1 ) ]]; then

            exit_code=$( /bin/launchctl print gui/"${console_uid}"/"${launch_agent_label}" > /dev/null 2>&1; echo $? )

            if [[ $exit_code == 0 ]]; then
                echo "Stopping agent:  ${launch_agent_location}"
                /bin/launchctl bootout gui/"${console_uid}"/"${launch_agent_label}"

            fi

            echo "Starting agent:  ${launch_agent_location}"
            /bin/launchctl bootstrap gui/"${console_uid}" "${launch_agent_location}"
            /bin/launchctl enable gui/"${console_uid}"/"${launch_agent_label}"

        # macOS 10.x - macOS 10.10
        elif [[ $( /usr/bin/bc <<< "${os_major_version} == 10") -eq 1 && $( /usr/bin/bc <<< "${os_minor_patch_version} <= 10" ) -eq 1 ]]; then

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

echo "*****  Install AndroidSDKCMDLine-Tools process:  COMPLETE  *****"
exit 0