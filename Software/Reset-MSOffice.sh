#!/bin/bash

###################################################################################################
# Script Name:  Reset-Office.sh
# By:  Zack Thompson / Created:  10/14/2020
# Version:  2.1.0 / Updated:  12/10/2022 / By:  ZT
#
# Description:  Allows for users via a self service option to reset specific and optionally uninstall
#    all Microsoft apps.  Supports Office 2016 and newer.
#
# Utilizes Paul Bowden's Office Reset:  https://office-reset.com/macadmins/
#
###################################################################################################

echo -e "*****  Fix-IT:  Reset Microsoft Office Process:  START  *****\n"

##################################################
# Define Variables

# Set working directory
temp_pkg_dir=$( /usr/bin/dirname "${0}" )

# Get the filename of the .pkg file
pkg=$( /bin/ls "${temp_pkg_dir}" | /usr/bin/grep .pkg)

# Available options discovered in the .pkg
available_choices="%prompt_choices%"

##################################################
# Define Functions

exit_check() {
    # Handles checking the exit code of tasks.
    exit_code="${1}"
    error_text="${2}"

    if [[ "${exit_code}" != 0 ]]; then
        echo -e "[ERROR] ${error_text}\nExit Code:  ${exit_code}"
        echo -e "\n*****  Fix-IT:  Reset Microsoft Office Process:  FAILED  *****"
        exit "${exit_code}"
    fi
}

osascript_timeout_check () {
    # Checks the results of an osascript dialog to determine if it timed out
    response="${1}"

    if [[ "${response}" =~ .*gave[[:space:]]up:true ]]; then
        echo "[NOTICE] Prompt timed out."
        echo -e "\n*****  Fix-IT:  Reset Microsoft Office Process:  ABORTED  *****"
        exit 0
    fi
}

PlistBuddy_helper() {
    # This is a helper function to interact with plists.
    key="${1}"
    type="${2}"
    value="${3}"
    plist="${4}"
    action="${5}"

    if [[ "${action}" = "delete"  ]]; then

        # Delete existing values
        /usr/libexec/PlistBuddy -c "Delete :${key} ${type}" "${plist}" > /dev/null 2>&1

    elif [[ "${action}" = "clear"  ]]; then

        # Clear existing values
        /usr/libexec/PlistBuddy -c "clear ${type}" "${plist}" > /dev/null 2>&1

    else

        # Configure values
        /usr/libexec/PlistBuddy -c "Add :${key} ${type} ${value}" "${plist}"  > /dev/null 2>&1 || /usr/libexec/PlistBuddy -c "Set :${key} ${value}" "${plist}" > /dev/null 2>&1

    fi
}

add_choices_helper() {
    # This is a helper function to add installer choices to a Plist.
    array_index="${1}"
    plist="${2}"
    choice_identifier="${3}"
 
    PlistBuddy_helper ":${array_index}:attributeSetting" "integer" "1" "${plist}"
    PlistBuddy_helper ":${array_index}:choiceAttribute" "string" "selected" "${plist}"
    PlistBuddy_helper ":${array_index}:choiceIdentifier" "string" "${choice_identifier}" "${plist}"
}

##################################################
# Bits staged...

if [[ $3 != "/" ]]; then
    exit_check "1" "Target disk is not the startup disk."
fi

# Prompt user for action(s) to take
selected_choices=$( /usr/bin/osascript 2>/dev/null << EndOfScript
    tell application "System Events" to set this_app to (name of (first application process whose frontmost is true))
    set time_out to 300

    do shell script "osascript -e 'delay " & time_out & " ' -e 'tell application \"System Events\" to tell application process \"" & this_app & "\" to keystroke \".\" using {command down}' > /dev/null 2>&1 & "
    tell application "System Events"
        activate
        set choices to ¬
            choose from list every paragraph of "${available_choices}" ¬
            with multiple selections allowed ¬
            with title "Fix-IT:  Reset Microsoft Office" ¬
            with prompt "Choose from one or more of the available actions:" ¬
            OK button name "Select" ¬
            cancel button name "Cancel"
    end tell
EndOfScript
)

if [[ "${selected_choices}" == "false" ]]; then

    echo "[NOTICE] User canceled the prompt or prompt timed out."
    echo -e "\n*****  Fix-IT:  Reset Microsoft Office Process:  ABORTED  *****"
    exit 0

fi

echo "Selected choices:  ${selected_choices}"

# Prompt user warning of potential data loss
accept_warning=$( /usr/bin/osascript 2>/dev/null << EndOfScript
    tell application "System Events" 
        activate
        display dialog "Warning - potential Data Loss \n\nThis action has the potential for data loss.  Please ensure all data stored in Microsoft applications is backed up and/or synced to the cloud.  \n\nDo you accept this risk?" ¬
        with title "Fix-IT:  Reset Microsoft Office" ¬
        buttons {"No", "I Accept"} default button 1 ¬
        giving up after 60 ¬
        with icon caution
    end tell
EndOfScript
)

# If you want to use JamfHelper
# Setup jamfHelper window
# jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
# title="Fix-IT:  Reset Microsoft Office"
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

    echo "NOTICE:  User did not accept potential data loss warning."
    echo -e "\n*****  Fix-IT:  Reset Microsoft Office Process:  COMPLETE  *****"
    exit 0

fi

osascript_timeout_check "${accept_warning}"

choices_plist="${temp_pkg_dir}/choices.plist"

# Create an empty array
PlistBuddy_helper "" "array" "" "${choices_plist}" "clear"

# Setting starting point for the array
array_item=0

# In case multiple choices were selected, loop through them...
while read -r choice; do

    # Determine requested choice
    case "${choice}" in
        # Selected = 1 = Install
        # Selected = 0 = Do Not Install
        "Reset Word" )
            add_choices_helper "${array_item}" "${choices_plist}" "com.microsoft.reset.Word"
        ;;
        "Reset Excel" )
            add_choices_helper "${array_item}" "${choices_plist}" "com.microsoft.reset.Excel"
        ;;
        "Reset PowerPoint" )
            add_choices_helper "${array_item}" "${choices_plist}" "com.microsoft.reset.PowerPoint"
        ;;
        "Reset Outlook" )
            add_choices_helper "${array_item}" "${choices_plist}" "com.microsoft.reset.Outlook"
        ;;
        "Reset OneNote" )
            add_choices_helper "${array_item}" "${choices_plist}" "com.microsoft.reset.OneNote"
        ;;
        "Reset OneDrive" )
            add_choices_helper "${array_item}" "${choices_plist}" "com.microsoft.reset.OneDrive"
        ;;
        "Reset Teams" )
            add_choices_helper "${array_item}" "${choices_plist}" "com.microsoft.reset.Teams"
        ;;
        "Reset AutoUpdate" )
            add_choices_helper "${array_item}" "${choices_plist}" "com.microsoft.reset.AutoUpdate"
        ;;
        "Reset Credentials" )
            add_choices_helper "${array_item}" "${choices_plist}" "com.microsoft.reset.Credentials"
        ;;
        "Remove SkypeForBusiness" )
            add_choices_helper "${array_item}" "${choices_plist}" "com.microsoft.remove.SkypeForBusiness"
        ;;
        "Remove Office" )
            add_choices_helper "${array_item}" "${choices_plist}" "com.microsoft.remove.Office"
        ;;
        "Remove ZoomPlugin" )
            add_choices_helper "${array_item}" "${choices_plist}" "com.microsoft.remove.ZoomPlugin"
        ;;
        "Remove WebExPT" )
            add_choices_helper "${array_item}" "${choices_plist}" "com.microsoft.remove.WebExPT"
        ;;
        * )
            exit_check "2" "Requested task is invalid"
        ;;
    esac

    # Increase array count
    array_item=$(( array_item+1 ))

done < <( echo "${selected_choices}" | /usr/bin/tr ',' '\n' )

/usr/sbin/installer -applyChoiceChangesXML "${choices_plist}" -pkg "${pkg}" -target "/"
exit_check $? "Failed to apply choices to the installer."

echo -e "\n*****  Fix-IT:  Reset Microsoft Office Process:  COMPLETE  *****"
exit 0
