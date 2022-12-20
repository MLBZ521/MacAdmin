#!/bin/bash
# set -x
###################################################################################################
# Script Name:  Setup-Xcode.sh
# By:  Zack Thompson / Created:  3/29/2021
# Version:  1.1.0 / Updated:  12/17/2022 / By:  ZT
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

if [[ -z "${launch_agent_label}" ]]; then
    launch_agent_label="com.github.mlbz521.XcodeEnableDeveloper"
fi

launch_agent_location="/Library/LaunchAgents/${launch_agent_label}.plist"

# Specify wether or not to edit the authorizationdb to allow any member of "_developer" group
# to be able to install Apple-provided software; options are:
#   true:  edits the authorizationdb to allow any member of _developer to install Apple-provided software
#   false:  does nothing
allow_devs_auth="${7}"

# Default path
xcode_path_default="/Applications/Xcode.app"

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

get_app_bundle_version() {
    # Get version of an app bundle
    local path="${1}"
    local app_version

    app_version=$( /usr/bin/defaults read "${path}/Contents/Info.plist" CFBundleShortVersionString )
    echo "${app_version}"
}

get_app_bundle_major_version() {
    # Get the major version of an app bundle
    local path="${1}"
    local app_version
    local app_major_version

    app_version=$( get_app_bundle_version "${path}" )
    app_major_version=$( echo "${app_version}" | /usr/bin/awk -F '.' '{print $1}' )
    echo "${app_major_version}"

}

determine_newest_version() {
    # Get the newest (largest) version of a passed set of app bundle locations
    local array=("$@")
    local path
    local version_array
    local newest
    declare -a version_array

    for path in "${array[@]}"; do
        version_array+=( $( get_app_bundle_version "${path}" ) )
    done

    old_IFS=$IFS
    IFS=$'\n'
    newest=($( sort --version-sort --reverse <<< "${version_array[*]}" ))
    IFS=$old_IFS

    for i in "${!version_array[@]}"; do
        [[ "${version_array[$i]}" == "${newest[0]}" ]] && break
    done

    echo "${array[${i}]}"
}

##################################################
# Bits staged...

if [[ -d "${xcode_path_default}" ]]; then
    # Acting as if this is a "new" install...

    if [[ $include_version_in_app_name =~ [Tt][Rr][Uu][Ee] ]]; then

        xcode_major_version=$( get_app_bundle_major_version "${xcode_path_default}" )
        new_xcode_path="/Applications/Xcode ${xcode_major_version}.app"

        if [[ -e "${new_xcode_path}" ]]; then
            echo "Deleting previous major version..."
            /bin/rm -Rf "${new_xcode_path}"
        fi

        # Update the Xcode app name
        echo "Renaming Xcode app bundle..."
        /bin/mv "${xcode_path_default}" "${new_xcode_path}"

    fi

    xcode_path="${xcode_path_default}"

fi

# Determine the Xcode app bundle to work on...
if [[ -z "${xcode_path}" ]]; then

    # Find Xcode app bundles
    app_paths=$( /usr/bin/find -E /Applications -iregex ".*/Xcode(.*)?[.]app" -type d -prune -maxdepth 1 )

    # Verify that at least one app bundle version was found.
    if [[ -z "${app_paths}" ]]; then

        echo "ERROR:  Xcode is not in the expected location!"
        echo "*****  Setup Xcode Process:  FAILED  *****"
        exit 1

    else

        # If the machine has multiple app bundles Applications, loop through them...
        declare -a app_path_array
        while IFS=$'\n' read -r app_path; do
            app_path_array+=("${app_path}")
        done < <(echo "${app_paths}")

        if [[ ${#app_path_array[@]} -gt 1 ]]; then
            xcode_path=$( determine_newest_version "${app_path_array[@]}" )
        else
            xcode_path="${app_path_array[0]}"
        fi

    fi

fi

# Ensure an app bundle was identified
if [[ -z "${xcode_path}" ]]; then
    echo "ERROR:  Xcode could not be found!"
    echo "*****  Setup Xcode Process:  FAILED  *****"
    exit 2
fi

# Remove quarantine bit just in case
/usr/bin/xattr -dr com.apple.quarantine "${xcode_path}"

# Specify the version of Xcode to use
echo "Selecting ${xcode_path} as the default for Xcode CMD Line Tools..."
/usr/bin/xcode-select --switch "${xcode_path}"

# Change the authorization policies to allow members of the admin and _developer groups to be
# able to authenticate to use the Apple-code-signed debugger or performance analysis tools
echo "Allowing the admin and developer groups to use Xcode tools..."
/usr/sbin/DevToolsSecurity -enable

# Accept the Xcode license
echo "Accepting the Xcode license..."
/usr/bin/xcodebuild -license accept

# Install all additional components
echo "Running Xcode first launch..."
/usr/bin/xcodebuild -runFirstLaunch

if [[ "${allow_devs_auth}" =~ [Tt][Rr][Uu][Ee] ]]; then
    echo "Editing the authorizationdb to allow members of \`_developer\` group to install Apple-provided software"
    # Allow any member of _developer to install Apple-provided software
    /usr/bin/security authorizationdb write system.install.apple-software authenticate-developer
fi

if [[ -z "${set_developer_perms}" ]]; then

    echo "Not configuring the developer permissions..."

elif [[ "${set_developer_perms}" =~ [Ee][Vv][Ee][Rr][Yy][Oo][Nn][Ee] ]]; then

    echo "Adding the \`everyone\` group as a member of the \`_developer\` group."
    # Add the "everyone" group as a member of "_developer" group
    /usr/sbin/dseditgroup -o edit -a everyone -t group _developer

elif [[ "${set_developer_perms}" =~ [Ll][Aa][Uu][Nn][Cc][Hh][Aa][Gg][Ee][Nn][Tt] ]]; then

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