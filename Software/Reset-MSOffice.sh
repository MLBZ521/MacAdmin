#!/bin/bash

###################################################################################################
# Script Name:  Reset-Office.sh
# By:  Zack Thompson / Created:  10/14/2020
# Version:  2.0.0 / Updated:  2/11/2022 / By:  ZT
#
# Description:  Allows for users via a self service option to reset specific and optionally uninstall
#    all Microsoft apps.  Supports Office 2016 and newer.
#
# Utilizes Paul Bowden's Office Reset:  https://office-reset.com/macadmins/
#
###################################################################################################

echo -e "*****  %PROMPT_TITLE% Process:  START  *****\n"

##################################################
# Define Variables

# Set working directory
temp_pkg_dir=$( /usr/bin/dirname "${0}" )

# Get the filename of the .pkg file
pkg=$( /bin/ls "${temp_pkg_dir}" | /usr/bin/grep .pkg)

# Available options discovered in the .pkg
available_actions="%prompt_choices%"

##################################################
# Define Functions

exit_check() {
    if [[ $1 != 0 ]]; then
        echo "ERROR:  ${3}"
        echo "Reason:  ${2}"
        echo "Exit Code:  ${1}"
        echo "*****  Fix-IT - Adobe CC:  FAILED  *****"
        exit 2
    fi
}

# This is a helper function to interact with plists.
PlistBuddy_Helper() {
    key="${1}"
    type="${2}"
    value="${3}"
    plist="${4}"
    action="${5}"

    # Delete existing values if required
    if [[ "${action}" = "delete"  ]]; then

        /usr/libexec/PlistBuddy -c "Delete :${key} ${type}" "${plist}" > /dev/null 2>&1

    elif [[ "${action}" = "clear"  ]]; then

        /usr/libexec/PlistBuddy -c "clear ${type}" "${plist}" > /dev/null 2>&1

    fi

    # Configure values
    /usr/libexec/PlistBuddy -c "Add :${key} ${type} ${value}" "${plist}"  > /dev/null 2>&1 || /usr/libexec/PlistBuddy -c "Set :${key} ${value}" "${plist}" > /dev/null 2>&1

}

##################################################
# Bits staged...

if [[ $3 != "/" ]]; then
    echo "[ERROR] Target disk is not the startup disk."
    echo "*****  %PROMPT_TITLE% Process:  FAILED  *****"
    exit 1
fi

# Prompt user for action(s) to take
selected_actions=$( /usr/bin/osascript 2>/dev/null << EndOfScript
    tell application "System Events" 
        activate
        choose from list every paragraph of "${available_actions}" ¬
        with multiple selections allowed ¬
        with title "%PROMPT_TITLE%" ¬
        with prompt "Choose from one or more of the available actions:" ¬
        OK button name "Select" ¬
        cancel button name "Cancel"
    end tell
EndOfScript
)

if [[ "${selected_actions}" == "false" ]]; then

    echo -e "NOTICE:  User canceled the prompt.\n"
    echo "*****  %PROMPT_TITLE% Process:  COMPLETE  *****"
    exit 0

fi

echo "Selected Actions:  ${selected_actions}"

# Prompt user warning of potential data loss
accept_warning=$( /usr/bin/osascript 2>/dev/null << EndOfScript
    tell application "System Events" 
        activate
        display dialog "Warning - potential Data Loss \n\nThis action has the potential for data loss.  Please ensure all data stored in Microsoft applications is backed up and/or synced to the cloud.  \n\nDo you accept this risk?" ¬
        with title "%PROMPT_TITLE%" ¬
        buttons {"No", "I Accept"} default button 1 ¬
        giving up after 60 ¬
        with icon caution
    end tell
EndOfScript
)

# If you want to use JamfHelper
# Setup jamfHelper window
# jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
# title="%PROMPT_TITLE%"
# windowType="utility"
# Heading="Warning - potential Data Loss"
# Description="This action has the potential for data loss.  Please ensure all data stored in Microsoft applications is backed up and/or synced to the cloud.
# 
# Do you accept this risk?"
# Icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"
# extras="-button1 \"Accept\" -button2 \"Cancel\" -defaultButton 2"

# accept_warning=$( "${jamfHelper}" -windowType "${windowType}" -title "${title}" -icon "${Icon}" -heading "${Heading}" -description "${Description}" $extras 2>&1 > /dev/null )

# if [[ "${accept_warning}" != "0" ]]; then
if [[ "${accept_warning}" != "button returned:I Accept, gave up:false" ]]; then

    echo -e "NOTICE:  User did not accept potential data loss warning.\n"
    echo "*****  %PROMPT_TITLE% Process:  COMPLETE  *****"
    exit 0

fi

# Create an empty array
PlistBuddy_Helper "" "array" "" "${temp_pkg_dir}/choices.plist" "clear"

# Setting starting point for the array
array_item=0

# In case multiple actions were selected, loop through them...
while read -r action; do

    # Determine requested task
    case "${action}" in

        # Selected = 1 = Install
        # Selected = 0 = Do Not Install

        "Reset Word" )
            PlistBuddy_Helper "${array_item}:attributeSetting" "integer" "1" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper "${array_item}:choiceAttribute" "string" "selected" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper "${array_item}:choiceIdentifier" "string" "com.microsoft.reset.Word" "${temp_pkg_dir}/choices.plist"
        ;;

        "Reset Excel" )
            PlistBuddy_Helper ":${array_item}:attributeSetting" "integer" "1" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceAttribute" "string" "selected" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceIdentifier" "string" "com.microsoft.reset.Excel" "${temp_pkg_dir}/choices.plist"
        ;;

        "Reset PowerPoint" )
            PlistBuddy_Helper ":${array_item}:attributeSetting" "integer" "1" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceAttribute" "string" "selected" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceIdentifier" "string" "com.microsoft.reset.PowerPoint" "${temp_pkg_dir}/choices.plist"
        ;;

        "Reset Outlook" )
            PlistBuddy_Helper ":${array_item}:attributeSetting" "integer" "1" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceAttribute" "string" "selected" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceIdentifier" "string" "com.microsoft.reset.Outlook" "${temp_pkg_dir}/choices.plist"
        ;;

        "Reset OneNote" )
            PlistBuddy_Helper ":${array_item}:attributeSetting" "integer" "1" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceAttribute" "string" "selected" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceIdentifier" "string" "com.microsoft.reset.OneNote" "${temp_pkg_dir}/choices.plist"
        ;;

        "Reset OneDrive" )
            PlistBuddy_Helper ":${array_item}:attributeSetting" "integer" "1" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceAttribute" "string" "selected" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceIdentifier" "string" "com.microsoft.reset.OneDrive" "${temp_pkg_dir}/choices.plist"
        ;;

        "Reset Teams" )
            PlistBuddy_Helper ":${array_item}:attributeSetting" "integer" "1" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceAttribute" "string" "selected" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceIdentifier" "string" "com.microsoft.reset.Teams" "${temp_pkg_dir}/choices.plist"
        ;;

        "Reset AutoUpdate" )
            PlistBuddy_Helper ":${array_item}:attributeSetting" "integer" "1" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceAttribute" "string" "selected" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceIdentifier" "string" "com.microsoft.reset.AutoUpdate" "${temp_pkg_dir}/choices.plist"
        ;;

        "Reset Credentials" )
            PlistBuddy_Helper ":${array_item}:attributeSetting" "integer" "1" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceAttribute" "string" "selected" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceIdentifier" "string" "com.microsoft.reset.Credentials" "${temp_pkg_dir}/choices.plist"
        ;;

        "Remove SkypeForBusiness" )
            PlistBuddy_Helper ":${array_item}:attributeSetting" "integer" "1" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceAttribute" "string" "selected" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceIdentifier" "string" "com.microsoft.remove.SkypeForBusiness" "${temp_pkg_dir}/choices.plist"
        ;;

        "Remove Office" )
            PlistBuddy_Helper ":${array_item}:attributeSetting" "integer" "1" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceAttribute" "string" "selected" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceIdentifier" "string" "com.microsoft.remove.Office" "${temp_pkg_dir}/choices.plist"
        ;;

        "Remove ZoomPlugin" )
            PlistBuddy_Helper ":${array_item}:attributeSetting" "integer" "1" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceAttribute" "string" "selected" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceIdentifier" "string" "com.microsoft.remove.ZoomPlugin" "${temp_pkg_dir}/choices.plist"
        ;;

        "Remove WebExPT" )
            PlistBuddy_Helper ":${array_item}:attributeSetting" "integer" "1" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceAttribute" "string" "selected" "${temp_pkg_dir}/choices.plist"
            PlistBuddy_Helper ":${array_item}:choiceIdentifier" "string" "com.microsoft.remove.WebExPT" "${temp_pkg_dir}/choices.plist"
        ;;

        * )
            echo "ERROR:  Requested task is invalid"
            echo "*****  %PROMPT_TITLE% Process:  FAILED  *****"
            exit 2
        ;;

    esac

    # Increase array count
    array_item=$(( array_item+1 ))

done < <( echo "${selected_actions}" | /usr/bin/tr ',' '\n' )

echo "*****  %PROMPT_TITLE% Process:  COMPLETE  *****"
exit 0