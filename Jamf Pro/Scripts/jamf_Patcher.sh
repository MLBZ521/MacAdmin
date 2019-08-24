#!/bin/bash

###################################################################################################
# Script Name:  jamf_Patcher.sh
# By:  Zack Thompson / Created:  7/10/2019
# Version:  1.0.0 / Updated:  7/10/2019 / By:  ZT
#
# Description:  This script handles patching of applications with user notifications.
#
###################################################################################################

echo "*****  jamf_Patcher process:  START  *****"

##################################################
# Define Script Parameters

departmentName="${4}" # "My Organization Technology Office"
applicationName="${5}" # "zoom"
iconID="${6}" # "https://jps.server.com:8443/icon?id=49167"
patchID="${7}"
policyID="${8}"

##################################################
# Define Variables

jamfPS=$( /usr/bin/defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url )
patchPlist="/Library/Preferences/com.github.mlbz521.jamf.patcher.plist"
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
launchDaemonLabel="com.github.mlbz521.jamf.patcher.${applicationName}"
launchDaemonLocation="/Library/LaunchDaemons/${launchDaemonLabel}.plist"
osMinorVersion=$( /usr/bin/sw_vers -productVersion | /usr/bin/awk -F '.' '{print $2}' )

##################################################
# Setup jamfHelper window for Download Complete message
title="Security Patch Notification"
windowType="hud"
if [[ -z $departmentName ]]; then
    heading="My Organization"
else
    heading="My Organization - ${departmentName}"
fi
description="${applicationName} will be updated to patch a security vulnerability.  Please quit ${applicationName} to apply this update.

If you have questions, please contact your Deskside support group."

descriptionForce="${applicationName} will be updated to patch a security vulnerability.  Please quit ${applicationName} with the allotted time to apply this update.

If you have questions, please contact your Deskside support group."

##################################################
# Functions

promptToPatch() {

    selection=$( "${jamfHelper}" -windowType "${windowType}" -title "${title}" -icon "/private/tmp/${applicationName}Icon.png" -heading "${heading}" -description "${description}" -button1 OK -timeout 3600 -countdown -countdownPrompt "If you wish to delay this patch, please make a selection in " -alignCountdown center -lockHUD -showDelayOptions ", 600, 3600, 86400" )

    return="${?}"
    echo "SELECTION:  ${selection}"
    echo "RETURN:  ${return}"
    # echo ""

    case "${return}" in
        0 ) # - Button 1 was clicked
            echo "SELECTED:  Button 1"

            # echo "Delay:  ${selection%?}"

            case "${selection%?}" in
                600 ) # - Button 1 was clicked with a value of XX seconds selected in the drop-down
                    echo "Delay 600 seconds"
                    delayDaemon $patchID 600
                ;;
                3600 ) # - Button 2 was clicked with a value of XX seconds selected in the drop-down
                    echo "Delay 3600 seconds"
                    delayDaemon $patchID 3600
                ;;
                86400 ) # - Button 2 was clicked with a value of XX seconds selected in the drop-down
                    echo "Delay 86400 seconds"
                    delayDaemon $patchID 86400
                ;;
                * )
                    killAndInstall
                ;;
            esac
        ;;
        1 ) # - The Jamf Helper was unable to launch
            echo "ERROR:  Failed to launch Jamf Helper"
        ;;
        # 2 ) # - Button 2 was clicked
        #     echo "SELECTED:  Button 2"
        # ;;
        # 3 ) # - Process was started as a launchd task
        #     echo "Started as launchd"
        # ;;
        # XX1 ) # - Button 1 was clicked with a value of XX seconds selected in the drop-down
        #     echo "Button 1 with seconds"
        # ;;
        # XX2 ) # - Button 2 was clicked with a value of XX seconds selected in the drop-down
        #     echo "Button 2 with seconds"
        # ;;
        # 239 ) # - The exit button was clicked
        #     echo "Exit Button"
        # ;;
        243 ) # - The window timed-out with no buttons on the screen
            echo "Timed-out, no selection made."
            killAndInstall
        ;;
        # 250 ) # - Bad "-windowType"
        #     echo "Invalid -windowType"
        # ;;
        # 255 ) # - No "-windowType"
        #     echo "-windowType not provided"
        # ;;
    esac
}

killAndInstall() {
    echo "Performing install..."

    # Get PID of the application
    pid=$( echo "${status}" | /usr/bin/awk -F " " '{print $1}' )

    # Kill PID
    /bin/kill $pid

    # Run Policy
    /usr/local/jamf/bin/jamf policy -id $policyID
}

delayDaemon() {

    # Write to plist stating a delay has already happened.
    /usr/bin/defaults write "${patchPlist}" "${applicationName}" "Delayed"

    # Create the Launch Daemon...
    echo "Creating the jamf_Patcher.sh LaunchDaemon..."

    cat > "${launchDaemonLocation}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.github.mlbz521.jamf.patcher</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/local/jamf/bin/jamf</string>
		<string>policy</string>
		<string>-id</string>
EOF
    # Insert code
    echo "		<string>${1}</string>" >> "${launchDaemonLocation}"

/bin/cat >> "${launchDaemonLocation}" <<'EOF'
   </array>
	<key>StartInterval</key>
EOF
    # Insert code
    echo "	<integer>${2}</integer>" >> "${launchDaemonLocation}"

    /bin/cat >> "${launchDaemonLocation}" <<'EOF'
	<key>AbandonProcessGroup</key>
	<true/>
</dict>
</plist>
EOF

    if [[ -e "${launchDaemonLocation}" ]]; then
        # Check if the LaucnhDaemon is running, if so restart it in case a change was made to the plist file.
        # Determine proper launchctl syntax based on OS Version 
        if [[ $osMinorVersion -ge 11 ]]; then
            exitCode=$( /bin/launchctl print system/$launchDaemonLabel > /dev/null 2>&1; echo $? )

            if [[ $exitCode == 0 ]]; then
                echo "LaunchDaemon is currently started; stopping now..."
                /bin/launchctl bootout system/$launchDaemonLabel
            fi

            echo "Loading LaunchDaemon..."
            /bin/launchctl bootstrap system "${launchDaemonLocation}"
            /bin/launchctl enable system/$launchDaemonLabel

        elif [[ $osMinorVersion -le 10 ]]; then
            exitCode=$( /bin/launchctl list $launchDaemonLabel > /dev/null 2>&1; echo $? )

            if [[ $exitCode == 0 ]]; then
                echo "LaunchDaemon is currently started; stopping now..."
                /bin/launchctl unload "${launchDaemonLocation}"
            fi

            echo "Loading LaunchDaemon..."
            /bin/launchctl load "${launchDaemonLocation}"
        fi
    fi
}

##################################################
# Bits staged...

# Check if application is running.
status=$( /bin/ps -ax -o pid,command | /usr/bin/grep -E "/Applications/${applicationName}" | /usr/bin/grep -v "grep" )

if [[ -z "${status}" ]]; then
    echo "${applicationName} is not running, install now."
    /usr/local/jamf/bin/jamf policy -id $policyID

else
    echo "${applicationName} is running, prompt user."

    # Download the icon from the JPS
    /usr/bin/curl --silent "${jamfPS}icon?id=${iconID}" > "/private/tmp/${applicationName}Icon.png"

    if [[ -e "${patchPlist}" ]]; then

        check=$( /usr/bin/defaults read "${patchPlist}" "${applicationName}" 2> /dev/null )

        if [[ $check == "Delayed" ]]; then
            echo "Patch has already been delayed; forcing upgrade."

            # Prompt user with one last warning.
            "${jamfHelper}" -windowType "${windowType}" -title "${title}" -icon "/private/tmp/${applicationName}Icon.png" -heading "${heading}" -description "${descriptionForce}" -button1 OK -timeout 600 -countdown -countdownPrompt "${applicationName} will be force closed in " -alignCountdown center -lockHUD > /dev/null 2>&1

            killAndInstall

            echo "Performing some cleanup..."

            # Delete the app value.
            /usr/bin/defaults delete "${patchPlist}" "${applicationName}"

            # Check if the LaunchDaemon is running.
            # Determine proper launchctl syntax based on OS Version.
            if [[ $osMinorVersion -ge 11 ]]; then
                exitCode=$( /bin/launchctl print system/$launchDaemonLabel > /dev/null 2>&1; echo $? )

                if [[ $exitCode == 0 ]]; then
                    echo "Stopping the Delay launchDaemon..."
                    /bin/launchctl bootout system/$launchDaemonLabel
                fi

            elif [[ $osMinorVersion -le 10 ]]; then
                exitCode=$( /bin/launchctl list $launchDaemonLabel > /dev/null 2>&1; echo $? )

                if [[ $exitCode == 0 ]]; then
                    echo "Stopping the Delay launchDaemon..."
                    /bin/launchctl unload "${launchDaemonLocation}"
                fi
            fi

            /bin/rm -f "${launchDaemonLocation}"

        else
            promptToPatch
        fi
    else
        promptToPatch
    fi
fi

echo "*****  jamf_Patcher process:  SUCCESS  *****"
exit 0