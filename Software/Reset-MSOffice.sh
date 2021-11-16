#!/bin/bash

###################################################################################################
# Script Name:  Reset-Office.sh
# By:  Zack Thompson / Created:  10/14/2020
# Version:  1.1.0 / Updated:  11/12/2021 / By:  ZT
#
# Description:  Allows for users via self service or a Site Admin to reset (and optionally uninstall) 
#    specific or all Microsoft apps.  Supports Office 2016 and newer.
#
# Based on Paul Bowden's Office Reset:  https://office-reset.com/macadmins/
#
###################################################################################################

echo -e "*****  Reset Office Process:  START  *****\n"

##################################################
# Define Variables

action="${4}"
force_uninstall="false"

available_actions="Word
Excel
PowerPoint
Outlook
OneNote
OneDrive
Teams
Skype for Business
Microsoft AutoUpdate
Sign-In Credentials
All Apps"
# Uninstall All"

if [[ "${action}" == "Self Service" ]]; then

    # Prompt user for actions to take
    selectedAction=$( /usr/bin/osascript << EndOfScript
        tell application "System Events" 
            activate
            choose from list every paragraph of "${available_actions}" ¬
            with multiple selections allowed ¬
            with title "Fix-IT:  Reset Microsoft Office" ¬
            with prompt "Choose application(s) to reset:" ¬
            OK button name "Select" ¬
            cancel button name "Cancel"
        end tell
EndOfScript
    )

    if [[ "${selectedAction}" == "false" ]]; then

        echo -e "NOTICE:  User canceled the prompt.\n"
        echo "*****  Reset Office Process:  COMPLETE  *****"
        exit 0

    elif [[ "${selectedAction}" == *"All Apps"* ]]; then

        apps="All"

    elif [[ "${selectedAction}" == "Uninstall All" ]]; then

        apps="All"
        force_uninstall="true"

    else

        apps="${selectedAction}"

    fi

    echo "Selected Action:  ${selectedAction}"

    # Prompt user warning of potential data loss
    acceptWarning=$( /usr/bin/osascript << EndOfScript
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
    # title="Reset Microsoft Office"
    # windowType="utility"
    # Heading="Warning - potential Data Loss"
    # Description="This action has the potential for data loss.  Please ensure all data stored in Microsoft applications is backed up and/or synced to the cloud.
# 
# Do you accept this risk?"
    # Icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"
    # extras="-button1 \"Accept\" -button2 \"Cancel\" -defaultButton 2"

    # acceptWarning=$( "${jamfHelper}" -windowType "${windowType}" -title "${title}" -icon "${Icon}" -heading "${Heading}" -description "${Description}" $extras 2>&1 > /dev/null )

    # if [[ "${acceptWarning}" != "0" ]]; then
    if [[ "${acceptWarning}" != "button returned:I Accept, gave up:false" ]]; then

        echo -e "NOTICE:  User did not accept potential data loss warning.\n"
        echo "*****  Reset Office Process:  COMPLETE  *****"
        exit 0

    fi

elif [[ "${action}" == "Auto" ]]; then

    # Performed actions in specified apps in $5
    apps="${5}"

    if [[ "${6}" == "true" || "${6}" == "Yes" ]]; then

        force_uninstall="true"

    fi

else

    echo -e "ERROR:  Requested action is not supported!\n"
    echo "*****  Reset Office Process:  FAILED  *****"
    exit 1

fi

##################################################
# Define Functions

# Get the Logged In Console User
GetLoggedInUser() {

	LOGGEDIN=$( echo "show State:/Users/ConsoleUser" | /usr/sbin/scutil | /usr/bin/awk '/Name :/&&!/loginwindow/{print $3}' )

	if [[ "${LOGGEDIN}" = "" ]]; then

		echo "${USER}"

	else

		echo "${LOGGEDIN}"

	fi

}

# Get the passed accounts' home directory
SetHomeFolder() {

	HOME=$( /usr/bin/dscl . read /Users/"${1}" NFSHomeDirectory | /usr/bin/cut -d ':' -f2 | /usr/bin/cut -d ' ' -f2 )

	if [[ "${HOME}" = "" ]]; then

		if [[ -d "/Users/${1}" ]]; then

			HOME="/Users/${1}"

		else

			HOME=$(eval echo "~${1}")

		fi

	fi

}

# Kill the passed app name
kill_App() {

    app="${1}"
    /usr/bin/pkill -9 "${app}"

}

# Stop and unload the passed service name
stop_Service() {

    service="${1}"
    /bin/launchctl stop "${service}"
    /bin/launchctl unload "${service}"

}

# Delete the passed path
uninstall_App() {

    app="${1}"
    app_location="${2}"

    if [ -d "${app_location}" ]; then

        /bin/rm -rf "${app_location}"

    else

        echo "${app} was not found in the default location"

    fi

}

# Reset Microsoft Word
reset_Word() {

    kill_App "Microsoft Word"

    if [[ "${force_uninstall}" == "true" ]]; then

        uninstall_App "Microsoft Word" "/Applications/Microsoft Word.app"

    fi

    echo "Microsoft Word:  Removing configuration data..."
    /bin/rm -f "/Library/Preferences/com.microsoft.Word.plist"
    /bin/rm -f "/Library/Managed Preferences/com.microsoft.Word.plist"
    /bin/rm -f "${HOME}/Library/Preferences/com.microsoft.Word.plist"
    /bin/rm -rf "${HOME}/Library/Containers/com.microsoft.Word"
    /bin/rm -rf "${HOME}/Library/Application Scripts/com.microsoft.Word"
    /bin/rm -rf "/Applications/Microsoft Word.app.installBackup"
    /bin/rm -rf "/Library/Application Support/Microsoft/Office365/User Content.localized/Startup.localized/Word"
    /bin/rm -rf "/Library/Application Support/Microsoft/Office365/User Content.localized/Templates.localized/*.dot"
    /bin/rm -rf "/Library/Application Support/Microsoft/Office365/User Content.localized/Templates.localized/*.dotx"
    /bin/rm -rf "/Library/Application Support/Microsoft/Office365/User Content.localized/Templates.localized/*.dotm"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Startup.localized/Word"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Templates.localized/*.dot"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Templates.localized/*.dotx"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Templates.localized/*.dotm"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/mip_policy"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/FontCache"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/ComRPC32"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/TemporaryItems"
    /bin/rm -f "${HOME}/Library/Group Containers/UBF8T346G9.Office/Microsoft Office ACL*"
    /bin/rm -f "${HOME}/Library/Group Containers/UBF8T346G9.Office/MicrosoftRegistrationDB.reg"

}

# Reset Microsoft Excel
reset_Excel() {

    kill_App "Microsoft Excel"

    if [[ "${force_uninstall}" == "true" ]]; then

        uninstall_App "Microsoft Excel" "/Applications/Microsoft Excel.app"

    fi

    echo "Microsoft Excel:  Removing configuration data..."
    /bin/rm -f "/Library/Preferences/com.microsoft.Excel.plist"
    /bin/rm -f "/Library/Managed Preferences/com.microsoft.Excel.plist"
    /bin/rm -f "${HOME}/Library/Preferences/com.microsoft.Excel.plist"
    /bin/rm -rf "${HOME}/Library/Containers/com.microsoft.Excel"
    /bin/rm -rf "${HOME}/Library/Application Scripts/com.microsoft.Excel"
    /bin/rm -rf "/Applications/Microsoft Excel.app.installBackup"
    /bin/rm -rf "/Library/Application Support/Microsoft/Office365/User Content.localized/Startup.localized/Excel"
    /bin/rm -rf "/Library/Application Support/Microsoft/Office365/User Content.localized/Templates.localized/*.xlt"
    /bin/rm -rf "/Library/Application Support/Microsoft/Office365/User Content.localized/Templates.localized/*.xltx"
    /bin/rm -rf "/Library/Application Support/Microsoft/Office365/User Content.localized/Templates.localized/*.xltm"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Startup.localized/Excel"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Templates.localized/*.xlt"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Templates.localized/*.xltx"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Templates.localized/*.xltm"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/mip_policy"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/ComRPC32"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/TemporaryItems"
    /bin/rm -f "${HOME}/Library/Group Containers/UBF8T346G9.Office/MicrosoftRegistrationDB.reg"

}

# Reset Microsoft PowerPoint
reset_PowerPoint() {

    kill_App "Microsoft PowerPoint"

    if [[ "${force_uninstall}" == "true" ]]; then

        uninstall_App "Microsoft PowerPoint" "/Applications/Microsoft PowerPoint.app"

    fi

    echo "Microsoft PowerPoint:  Removing configuration data..."
    /bin/rm -f "/Library/Preferences/com.microsoft.Powerpoint.plist"
    /bin/rm -f "/Library/Managed Preferences/com.microsoft.Powerpoint.plist"
    /bin/rm -f "${HOME}/Library/Preferences/com.microsoft.Powerpoint.plist"
    /bin/rm -rf "${HOME}/Library/Containers/com.microsoft.Powerpoint"
    /bin/rm -rf "${HOME}/Library/Application Scripts/com.microsoft.Powerpoint"
    /bin/rm -rf "/Applications/Microsoft PowerPoint.app.installBackup"
    /bin/rm -rf "/Library/Application Support/Microsoft/Office365/User Content.localized/Startup.localized/PowerPoint"
    /bin/rm -rf "/Library/Application Support/Microsoft/Office365/User Content.localized/Templates.localized/*.pot"
    /bin/rm -rf "/Library/Application Support/Microsoft/Office365/User Content.localized/Templates.localized/*.potx"
    /bin/rm -rf "/Library/Application Support/Microsoft/Office365/User Content.localized/Templates.localized/*.potm"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Startup.localized/PowerPoint"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Templates.localized/*.pot"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Templates.localized/*.potx"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Templates.localized/*.potm"
    /bin/rm -rf "/Library/Application Support/Microsoft/Office365/User Content.localized/Add-Ins/*.ppam"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Add-Ins/*.ppam"
    /bin/rm -rf "/Library/Application Support/Microsoft/Office365/User Content.localized/Themes"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Themes"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/mip_policy"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/FontCache"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/ComRPC32"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/TemporaryItems"
    /bin/rm -f "${HOME}/Library/Group Containers/UBF8T346G9.Office/Microsoft Office ACL*"
    /bin/rm -f "${HOME}/Library/Group Containers/UBF8T346G9.Office/MicrosoftRegistrationDB.reg"

}

# Reset Microsoft Outlook
reset_Outlook() {

    kill_App "Microsoft Outlook"

    if [[ "${force_uninstall}" == "true" ]]; then

        uninstall_App "Microsoft Outlook" "/Applications/Microsoft Outlook.app"

    fi

    echo "Microsoft Outlook:  Removing configuration data..."
    /bin/rm -f "/Library/Preferences/com.microsoft.Outlook.plist"
    /bin/rm -f "/Library/Managed Preferences/com.microsoft.Outlook.plist"
    /bin/rm -f "${HOME}/Library/Preferences/com.microsoft.Outlook.plist"
    /bin/rm -rf "${HOME}/Library/Containers/com.microsoft.Outlook"
    /bin/rm -rf "${HOME}/Library/Application Scripts/com.microsoft.Outlook"
    /bin/rm -rf "/Library/Application Support/Microsoft/WebExPlugin"
    /bin/rm -rf "/Library/Application Support/Microsoft/ZoomOutlookPlugin"
    /bin/rm -rf "/Users/Shared/ZoomOutlookPlugin"
    /bin/rm -rf "/Library/Application Support/Microsoft/Office365/User Content.localized/Startup.localized/Word/NormalEmail.dotm"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Startup.localized/Word/NormalEmail.dotm"
    /bin/rm -f "${HOME}/Library/Group Containers/UBF8T346G9.Office/DRM_Evo.plist"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/mip_policy"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/FontCache"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/ComRPC32"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/TemporaryItems"
    /bin/rm -f "${HOME}/Library/Group Containers/UBF8T346G9.Office/Microsoft Office ACL*"
    /bin/rm -f "${HOME}/Library/Group Containers/UBF8T346G9.Office/MicrosoftRegistrationDB.reg"
    /bin/rm -rf "/Applications/Microsoft Outlook.app.installBackup"
    /bin/rm -f "${HOME}/Library/Preferences/com.microsoft.Outlook.plist"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/Outlook"
    /bin/rm -f "${HOME}/Library/Group Containers/UBF8T346G9.Office/OutlookProfile.plist"

    KeychainHasLogin=$( /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security list-keychains | /usr/bin/grep 'login.keychain' )

    if [[ "${KeychainHasLogin}" == "" ]]; then

        /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security list-keychains -s "${HOME}/Library/Keychains/login.keychain-db"

    fi

    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-internet-password -s 'msoCredentialSchemeADAL'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-internet-password -s 'msoCredentialSchemeLiveId'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -G 'MSOpenTech.ADAL.1'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -G 'MSOpenTech.ADAL.1'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Microsoft Office Identities Cache 2'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Microsoft Office Identities Cache 3'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Microsoft Office Identities Settings 2'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Microsoft Office Identities Settings 3'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Microsoft Office Ticket Cache'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'com.microsoft.adalcache'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Microsoft Office Ticket Cache'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'com.microsoft.adalcache'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'com.helpshift.data_com.microsoft.Outlook'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'com.helpshift.data_com.microsoft.Outlook'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'com.helpshift.data_com.microsoft.Outlook'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'com.helpshift.data_com.microsoft.Outlook'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'MicrosoftOfficeRMSCredential'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'MicrosoftOfficeRMSCredential'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'MSProtection.framework.service'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'MSProtection.framework.service'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'

}

# Reset Microsoft OneNote
reset_OneNote() {

    kill_App "Microsoft OneNote"

    if [[ "${force_uninstall}" == "true" ]]; then

        uninstall_App "Microsoft OneNote" "/Applications/Microsoft OneNote.app"

    fi

    echo "Microsoft OneNote:  Removing configuration data..."
    /bin/rm -f "/Library/Preferences/com.microsoft.onenote.mac.plist"
    /bin/rm -f "/Library/Managed Preferences/com.microsoft.onenote.mac.plist"
    /bin/rm -f "${HOME}/Library/Preferences/com.microsoft.onenote.mac.plist"
    /bin/rm -rf "${HOME}/Library/Containers/com.microsoft.onenote.mac"
    /bin/rm -rf "${HOME}/Library/Containers/com.microsoft.onenote.mac.shareextension"
    /bin/rm -rf "${HOME}/Library/Application Scripts/com.microsoft.onenote.mac"
    /bin/rm -rf "/Applications/Microsoft OneNote.app.installBackup"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T369G9.Office/OneNote"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T369G9.Office/FontCache"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T369G9.Office/TemporaryItems"

}

# Reset Microsoft OneDrive
reset_OneDrive() {

    kill_App "OneDrive"
    kill_App "FinderSync"
    kill_App "OneDriveStandaloneUpdater"
    kill_App "OneDriveUpdater"

    if [[ "${force_uninstall}" == "true" ]]; then

        uninstall_App "OneDrive" "/Applications/OneDrive.app"

    fi

    echo "Microsoft OneDrive:  Removing configuration data..."
    /bin/rm -rf "${HOME}/Library/Caches/OneDrive"
    /bin/rm -rf "${HOME}/Library/Caches/com.microsoft.OneDrive"
    /bin/rm -rf "${HOME}/Library/Caches/com.microsoft.OneDriveUpdater"
    /bin/rm -rf "${HOME}/Library/Caches/com.microsoft.OneDriveStandaloneUpdater"
    /bin/rm -f "${HOME}/Library/Cookies/com.microsoft.OneDrive.binarycookies"
    /bin/rm -f "${HOME}/Library/Cookies/com.microsoft.OneDriveUpdater.binarycookies"
    /bin/rm -f "${HOME}/Library/Cookies/com.microsoft.OneDriveStandaloneUpdater.binarycookies"
    /bin/rm -rf "${HOME}/Library/WebKit/com.microsoft.OneDrive"
    /bin/rm -rf "${HOME}/Library/Containers/com.microsoft.OneDrive-mac"
    /bin/rm -rf "${HOME}/Library/Containers/com.microsoft.OneDrive.FinderSync"
    /bin/rm -rf "${HOME}/Library/Containers/com.microsoft.OneDrive-mac.FinderSync"
    /bin/rm -rf "${HOME}/Library/Containers/com.microsoft.OneDriveLauncher"
    /bin/rm -rf "${HOME}/Library/Logs/OneDrive"
    /bin/rm -rf "${HOME}/Library/Application Support/OneDrive"
    /bin/rm -rf "${HOME}/Library/Application Support/com.microsoft.OneDrive"
    /bin/rm -rf "${HOME}/Library/Application Support/com.microsoft.OneDriveUpdater"
    /bin/rm -rf "${HOME}/Library/Application Support/com.microsoft.OneDriveStandaloneUpdater"
    /bin/rm -rf "${HOME}/Library/Application Support/OneDriveUpdater"
    /bin/rm -rf "${HOME}/Library/Application Support/OneDriveStandaloneUpdater"
    /bin/rm -rf "${HOME}/Library/Application Scripts/com.microsoft.OneDrive.FinderSync"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.OfficeOneDriveSyncIntegration"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.OneDriveStandaloneSuite"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.OneDriveSyncClientSuite"
    /bin/rm -f "${HOME}/Library/Preferences/com.microsoft.OneDrive.plist"
    /bin/rm -f "${HOME}/Library/Preferences/com.microsoft.OneDriveStandaloneUpdater.plist"
    /bin/rm -f "${HOME}/Library/Preferences/com.microsoft.OneDriveUpdater.plist"
    /bin/rm -f "${HOME}/Library/Preferences/UBF8T346G9.OneDriveStandaloneSuite.plist"
    /bin/rm -f "/Library/Preferences/com.microsoft.OneDrive.plist"
    /bin/rm -f "/Library/Preferences/com.microsoft.OneDriveStandaloneUpdater.plist"
    /bin/rm -f "/Library/Preferences/com.microsoft.OneDriveUpdater.plist"
    /bin/rm -f "/Library/Preferences/com.microsoft.OneDrive.plist"
    /bin/rm -f "/Library/Managed Preferences/com.microsoft.OneDriveStandaloneUpdater.plist"
    /bin/rm -f "/Library/Managed Preferences/com.microsoft.OneDriveUpdater.plist"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.com.microsoft.oneauth"

    KeychainHasLogin=$( /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security list-keychains | /usr/bin/grep 'login.keychain' )

    if [[ "${KeychainHasLogin}" == "" ]]; then

        /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security list-keychains -s "${HOME}/Library/Keychains/login.keychain-db"

    fi

    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'com.microsoft.OneDrive.FinderSync.HockeySDK'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'com.microsoft.OneDrive.HockeySDK'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'com.microsoft.OneDriveUpdater.HockeySDK'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'com.microsoft.OneDriveStandaloneUpdater.HockeySDK'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'OneDrive Standalone Cached Credential Business - Business1'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'OneDrive Standalone Cached Credential'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -s 'OneAuthAccount'

}

# Reset Microsoft Teams
reset_Teams() {

    kill_App "Microsoft Teams"
    kill_App "Microsoft Teams Helper"

    if [[ "${force_uninstall}" == "true" ]]; then

        uninstall_App "Microsoft Teams" "/Applications/Microsoft Teams.app"

    fi

    echo "Microsoft Teams:  Removing configuration data..."
    /bin/rm -rf "${HOME}/Library/Application Support/Microsoft/Teams"
    /bin/rm -rf "${HOME}/Library/Application Support/com.microsoft.teams"
    /bin/rm -rf "${HOME}/Library/Application Support/com.microsoft.teams.helper"
    /bin/rm -rf "${HOME}/Library/Caches/com.microsoft.teams"
    /bin/rm -rf "${HOME}/Library/Caches/com.microsoft.teams.helper"
    /bin/rm -f "${HOME}/Library/Cookies/com.microsoft.teams.binarycookies"
    /bin/rm -rf "${HOME}/Library/Logs/Microsoft Teams"
    /bin/rm -rf "${HOME}/Library/Saved Application State/com.microsoft.teams.savedState"
    /bin/rm -rf "/Library/Application Support/TeamsUpdaterDaemon"
    /bin/rm -f "${HOME}/Library/Preferences/com.microsoft.teams.plist"
    /bin/rm -f "/Library/Managed Preferences/com.microsoft.teams.plist"
    /bin/rm -f "/Library/Preferences/com.microsoft.teams.plist"
    /bin/rm -f "${HOME}/Library/Preferences/com.microsoft.teams.helper.plist"
    /bin/rm -f "/Library/Managed Preferences/com.microsoft.teams.helper.plist"
    /bin/rm -f "/Library/Preferences/com.microsoft.teams.helper.plist"

    KeychainHasLogin=$( /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security list-keychains | /usr/bin/grep 'login.keychain' )

    if [[ "${KeychainHasLogin}" == "" ]]; then

        /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security list-keychains -s "${HOME}/Library/Keychains/login.keychain-db"

    fi

    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Microsoft Teams Identities Cache'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'com.microsoft.teams.HockeySDK'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'com.microsoft.teams.helper.HockeySDK'

}

# Reset Skype for Business
reset_Skype() {

    kill_App "Skype for Business"

    if [[ "${force_uninstall}" == "true" ]]; then

        uninstall_App "Skype for Business" "/Applications/Skype for Business.app"

    fi

    echo "Skype for Business:  Removing configuration data..."
    /bin/rm -rf "${HOME}/Library/Application Scripts/com.microsoft.SkypeForBusiness"
    /bin/rm -rf "${HOME}/Library/Containers/com.microsoft.SkypeForBusiness"
    /bin/rm -rf "${HOME}/Library/Preferences/com.microsoft.OutlookSkypeIntegration.plist"
    /bin/rm -f "/Library/Preferences/com.microsoft.SkypeForBusiness.plist"
    /bin/rm -f "/Library/Managed Preferences/com.microsoft.SkypeForBusiness.plist"
    /bin/rm -f "${HOME}/Library/Preferences/com.microsoft.SkypeForBusiness.plist"

    KeychainHasLogin=$( /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security list-keychains | /usr/bin/grep 'login.keychain' )

    if [[ "${KeychainHasLogin}" == "" ]]; then

        /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security list-keychains -s "${HOME}/Library/Keychains/login.keychain-db"

    fi

    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'com.microsoft.SkypeForBusiness.HockeySDK'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Skype for Business'

}

# Reset Microsoft AutoUpdate
reset_MAU() {

    kill_App "Skype for Business"
    kill_App 'Microsoft AutoUpdate'
    kill_App 'Microsoft Update Assistant'
    kill_App 'Microsoft AU Daemon'
    kill_App 'Microsoft AU Bootstrapper'
    kill_App 'com.microsoft.autoupdate.helper'
    kill_App 'com.microsoft.autoupdate.helpertool'
    kill_App 'com.microsoft.autoupdate.bootstrapper.helper'

    stop_Service /Library/LaunchAgents/com.microsoft.update.agent.plist
    stop_Service /Library/LaunchAgents/com.microsoft.autoupdate.helper.plist
    stop_Service /Library/LaunchDaemons/com.microsoft.autoupdate.helper
    stop_Service /Library/LaunchDaemons/com.microsoft.autoupdate.helper.plist

    if [[ "${force_uninstall}" == "true" ]]; then

        uninstall_App "Microsoft AutoUpdate" "/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app"
        uninstall_App "Microsoft AutoUpdate LaunchAgent com.microsoft.update.agent.plist" /Library/LaunchAgents/com.microsoft.update.agent.plist
        uninstall_App "Microsoft AutoUpdate LaunchAgent com.microsoft.autoupdate.helper.plist" /Library/LaunchAgents/com.microsoft.autoupdate.helper.plist
        uninstall_App "Microsoft AutoUpdate LaunchADaemon com.microsoft.autoupdate.helper" /Library/LaunchDaemons/com.microsoft.autoupdate.helper
        uninstall_App "Microsoft AutoUpdate LaunchADaemon com.microsoft.autoupdate.helper.plist" /Library/LaunchDaemons/com.microsoft.autoupdate.helper.plist

    fi

    echo "Microsoft AutoUpdate:  Removing configuration data..."
    /bin/rm -f "${HOME}/Library/Preferences/com.microsoft.autoupdate2.plist"
    /bin/rm -f "${HOME}/Library/Preferences/com.microsoft.autoupdate.fba.plist"
    /bin/rm -f "/Library/Preferences/com.microsoft.autoupdate2.plist"
    /bin/rm -f "/Library/Preferences/com.microsoft.autoupdate.fba.plist"
    /bin/rm -f "/var/root/Library/Preferences/com.microsoft.autoupdate2.plist"
    /bin/rm -f "/var/root/Library/Preferences/com.microsoft.autoupdate.fba.plist"
    /bin/rm -rf "${HOME}/Library/Caches/com.microsoft.autoupdate2"
    /bin/rm -rf "${HOME}/Library/Caches/com.microsoft.autoupdate.fba"
    /bin/rm -rf "${HOME}/Library/Application Support/Microsoft AU Daemon"
    /bin/rm -rf "/Library/Application Support/Microsoft/MERP2.0"

    /usr/bin/defaults write /Library/Preferences/com.microsoft.autoupdate2 AcknowledgedDataCollectionPolicy -string 'RequiredDataOnly'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/defaults write "${HOME}/Library/Preferences/com.microsoft.autoupdate2" IgnoreUIOpenAfterInstall -bool TRUE

}

# Reset Stored Microsoft Office Credentials
reset_Office_Credentials() {

    echo "Microsoft Office Credentials:  Quitting all apps gracefully"
    /usr/bin/pkill -HUP 'Microsoft Word'
    /usr/bin/pkill -HUP 'Microsoft Excel'
    /usr/bin/pkill -HUP 'Microsoft PowerPoint'
    /usr/bin/pkill -HUP 'Microsoft Outlook'
    /usr/bin/pkill -HUP 'Microsoft OneNote'

    KeychainHasLogin=$( /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security list-keychains | /usr/bin/grep 'login.keychain' )

    if [[ "${KeychainHasLogin}" == "" ]]; then

        /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security list-keychains -s "${HOME}/Library/Keychains/login.keychain-db"

    fi

    echo "Microsoft Office Credentials:  Removing KeyChain data..."
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -s 'OneAuthAccount'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-internet-password -s 'msoCredentialSchemeADAL'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-internet-password -s 'msoCredentialSchemeLiveId'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -G 'MSOpenTech.ADAL.1'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -G 'MSOpenTech.ADAL.1'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -G 'MSOpenTech.ADAL.1'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Microsoft Office Identities Cache 2'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Microsoft Office Identities Cache 3'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Microsoft Office Identities Settings 2'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Microsoft Office Identities Settings 3'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Microsoft Office Ticket Cache'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'com.microsoft.adalcache'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'com.helpshift.data_com.microsoft.Outlook'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'com.helpshift.data_com.microsoft.Outlook'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'com.helpshift.data_com.microsoft.Outlook'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'com.helpshift.data_com.microsoft.Outlook'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'MicrosoftOfficeRMSCredential'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'MicrosoftOfficeRMSCredential'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'MSProtection.framework.service'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'MSProtection.framework.service'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/security delete-generic-password -l 'Exchange'

    echo "Microsoft Office Credentials:  Removing credential and license files"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/mip_policy"
    /bin/rm -f "${HOME}/Library/Group Containers/UBF8T346G9.Office/DRM_Evo.plist"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.com.microsoft.oneauth"
    /bin/rm -f "/Library/Application Support/Microsoft/Office365/com.microsoft.Office365.plist"
    /bin/rm -f "/Library/Application Support/Microsoft/Office365/com.microsoft.Office365V2.plist"
    /bin/rm -f "${HOME}/Library/Group Containers/UBF8T346G9.Office/com.microsoft.Office365.plist"
    /bin/mv "${HOME}/Library/Group Containers/UBF8T346G9.Office/com.microsoft.Office365V2.plist" "${HOME}/Library/Group Containers/UBF8T346G9.Office/com.microsoft.Office365V2.backup"
    /bin/rm -f "${HOME}/Library/Group Containers/UBF8T346G9.Office/com.microsoft.e0E2OUQxNUY1LTAxOUQtNDQwNS04QkJELTAxQTI5M0JBOTk4O.plist"
    /bin/rm -f "${HOME}/Library/Group Containers/UBF8T346G9.Office/e0E2OUQxNUY1LTAxOUQtNDQwNS04QkJELTAxQTI5M0JBOTk4O"
    /bin/rm -f "${HOME}/Library/Group Containers/UBF8T346G9.Office/com.microsoft.O4kTOBJ0M5ITQxATLEJkQ40SNwQDNtQUOxATL1YUNxQUO2E0e.plist"
    /bin/rm -f "${HOME}/Library/Group Containers/UBF8T346G9.Office/O4kTOBJ0M5ITQxATLEJkQ40SNwQDNtQUOxATL1YUNxQUO2E0e"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office/Licenses"
    /bin/rm -rf "${HOME}/Library/Containers/com.microsoft.RMS-XPCService"
    /bin/rm -rf "${HOME}/Library/Application Scripts/com.microsoft.Office365ServiceV2"
    /bin/rm -rf "${HOME}/Library/Containers/com.microsoft.Word/Data/Library/Application Support/Microsoft"
    /bin/rm -rf "${HOME}/Library/Containers/com.microsoft.Excel/Data/Library/Application Support/Microsoft"
    /bin/rm -rf "${HOME}/Library/Containers/com.microsoft.Powerpoint/Data/Library/Application Support/Microsoft"
    /bin/rm -rf "${HOME}/Library/Containers/com.microsoft.Outlook/Data/Library/Application Support/Microsoft"
    /bin/rm -rf "${HOME}/Library/Containers/com.microsoft.onenote.mac/Data/Library/Application Support/Microsoft"
    /bin/rm -f "${HOME}/Library/Group Containers/UBF8T346G9.Office/MicrosoftRegistrationDB.reg"

    echo "Microsoft Office Credentials:  Changing preferences"
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/defaults delete "${HOME}/Library/Preferences/com.microsoft.office" OfficeActivationEmailAddress
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/defaults write "${HOME}/Library/Preferences/com.microsoft.office" OfficeAutoSignIn -bool TRUE
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/defaults write "${HOME}/Library/Preferences/com.microsoft.office" HasUserSeenFREDialog -bool TRUE
    /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/defaults write "${HOME}/Library/Preferences/com.microsoft.office" HasUserSeenEnterpriseFREDialog -bool TRUE

    if [ -d "${HOME}/Library/Containers/com.microsoft.Word/Data/Library/Preferences" ]; then

        /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/defaults write "${HOME}/Library/Containers/com.microsoft.Word/Data/Library/Preferences/com.microsoft.Word" kSubUIAppCompletedFirstRunSetup1507 -bool FALSE

    fi

    if [ -d "${HOME}/Library/Containers/com.microsoft.Excel/Data/Library/Preferences" ]; then

        /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/defaults write "${HOME}/Library/Containers/com.microsoft.Excel/Data/Library/Preferences/com.microsoft.Excel" kSubUIAppCompletedFirstRunSetup1507 -bool FALSE

    fi

    if [ -d "${HOME}/Library/Containers/com.microsoft.Powerpoint/Data/Library/Preferences" ]; then

        /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/defaults write "${HOME}/Library/Containers/com.microsoft.Powerpoint/Data/Library/Preferences/com.microsoft.Powerpoint" kSubUIAppCompletedFirstRunSetup1507 -bool FALSE

    fi

    if [ -d "${HOME}/Library/Containers/com.microsoft.Outlook/Data/Library/Preferences" ]; then

        /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/defaults write "${HOME}/Library/Containers/com.microsoft.Outlook/Data/Library/Preferences/com.microsoft.Outlook" kSubUIAppCompletedFirstRunSetup1507 -bool FALSE

    fi

    if [ -d "${HOME}/Library/Containers/com.microsoft.onenote.mac/Data/Library/Preferences" ]; then

        /usr/bin/sudo -u "${LoggedInUser}" /usr/bin/defaults write "${HOME}/Library/Containers/com.microsoft.onenote.mac/Data/Library/Preferences/com.microsoft.onenote.mac" kSubUIAppCompletedFirstRunSetup1507 -bool FALSE

    fi

    /usr/bin/killall cfprefsd

}

# Delete all the things
full_uninstall() {

    stop_Service /Library/LaunchAgents/com.microsoft.OneDriveStandaloneUpdater.plist
    stop_Service /Library/LaunchDaemons/com.microsoft.OneDriveUpdaterDaemon.plist
    stop_Service /Library/LaunchDaemons/com.microsoft.teams.TeamsUpdaterDaemon.plist

    echo "Microsoft Office Full Uninstall:  Removing preferences and containers..."
    /bin/rm -rf "/Library/Logs/Microsoft/autoupdate.log"
    /bin/rm -rf "/Library/Logs/Microsoft/InstallLogs"
    /bin/rm -rf "/Library/Logs/Microsoft/Teams"
    /bin/rm -rf "/Library/Logs/Microsoft/OneDrive"
    /bin/rm -f "${HOME}/Library/Preferences/com.microsoft.shared.plist"
    /bin/rm -f "${HOME}/Library/Preferences/com.microsoft.office.plist"
    /bin/rm -f "/Library/Preferences/com.microsoft.shared.plist"
    /bin/rm -f "/Library/Preferences/com.microsoft.office.plist"
    /bin/rm -f "/Library/Managed Preferences/com.microsoft.shared.plist"
    /bin/rm -f "/Library/Managed Preferences/com.microsoft.office.plist"
    /bin/rm -rf "${HOME}/Library/Application Support/Microsoft"
    /bin/rm -rf "/Library/Application Support/Microsoft/Office365"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.Office"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.ms"
    /bin/rm -rf "${HOME}/Library/Group Containers/UBF8T346G9.OfficeOsfWebHost"
    /bin/rm -rf "${HOME}/Library/Containers/com.microsoft.errorreporting"
    /bin/rm -rf "${HOME}/Library/Containers/com.microsoft.netlib.shipassertprocess"
    /bin/rm -rf "${HOME}/Library/Containers/com.microsoft.Office365ServiceV2"
    /bin/rm -f "${HOME}/Library/Preferences/com.microsoft.autoupdate2.plist"
    /bin/rm -f "/Library/Preferences/com.microsoft.autoupdate2.plist"

    echo "Microsoft Office Full Uninstall:  Removing app data"
    /bin/rm -rf "/Library/Application Support/Microsoft"
    /bin/rm -f "/Library/LaunchAgents/com.microsoft.update.agent.plist"
    /bin/rm -f "/Library/LaunchAgents/com.microsoft.OneDriveStandaloneUpdater.plist"
    /bin/rm -f "/Library/LaunchAgents/com.microsoft.autoupdate.helper.plist"
    /bin/rm -f "/Library/LaunchDaemons/com.microsoft.autoupdate.helper.plist"
    /bin/rm -f "/Library/LaunchDaemons/com.microsoft.office.licensingV2.helper.plist"
    /bin/rm -f "/Library/LaunchDaemons/com.microsoft.OneDriveStandaloneUpdaterDaemon.plist"
    /bin/rm -f "/Library/LaunchDaemons/com.microsoft.OneDriveUpdaterDaemon.plist"
    /bin/rm -f "/Library/LaunchDaemons/com.microsoft.teams.TeamsUpdaterDaemon.plist"
    /bin/rm -f "/Library/PrivilegedHelperTools/com.microsoft.autoupdate.helper"
    /bin/rm -f "/Library/PrivilegedHelperTools/com.microsoft.autoupdate.helpertool"
    /bin/rm -f "/Library/PrivilegedHelperTools/com.microsoft.office.licensingV2.helper"
    /bin/rm -rf "/Library/Logs/Microsoft"
    /bin/rm -rf "${HOME}/Library/Caches/Microsoft"
    /bin/rm -f "/Library/Preferences/com.microsoft.office.licensingV2.plist"

    OneDriveFolder=$( /bin/ls "${HOME}" | /usr/bin/grep 'OneDrive' --max-count=1 )

    if [ "${OneDriveFolder}" != "" ]; then

        IsOneDrive=$( /usr/bin/xattr "${HOME}/${OneDriveFolder}" | /usr/bin/grep 'com.apple.fileutil.SyncRootProviderRootContextList' )

        if [ "${IsOneDrive}" = "com.apple.fileutil.SyncRootProviderRootContextList" ]; then

            echo "Microsoft Office Full Uninstall:  Removing OneDrive folder ${OneDriveFolder}"
            /bin/rm -rf "${HOME}/${OneDriveFolder}"

        fi
    fi

    echo "Microsoft Office Full Uninstall:  Forgetting pkg recipes..."
    /usr/sbin/pkgutil --forget com.microsoft.Word
    /usr/sbin/pkgutil --forget com.microsoft.Excel
    /usr/sbin/pkgutil --forget com.microsoft.Powerpoint
    /usr/sbin/pkgutil --forget com.microsoft.Outlook
    /usr/sbin/pkgutil --forget com.microsoft.onenote.mac
    /usr/sbin/pkgutil --forget com.microsoft.OneDrive-mac
    /usr/sbin/pkgutil --forget com.microsoft.package.Microsoft_Word.app
    /usr/sbin/pkgutil --forget com.microsoft.package.Microsoft_Excel.app
    /usr/sbin/pkgutil --forget com.microsoft.package.Microsoft_PowerPoint.app
    /usr/sbin/pkgutil --forget com.microsoft.package.Microsoft_Outlook.app
    /usr/sbin/pkgutil --forget com.microsoft.package.Microsoft_OneNote.app
    /usr/sbin/pkgutil --forget com.microsoft.package.Microsoft_AutoUpdate.app
    /usr/sbin/pkgutil --forget com.microsoft.package.Microsoft_AU_Bootstrapper.app
    /usr/sbin/pkgutil --forget com.microsoft.package.Proofing_Tools
    /usr/sbin/pkgutil --forget com.microsoft.package.Fonts
    /usr/sbin/pkgutil --forget com.microsoft.package.DFonts
    /usr/sbin/pkgutil --forget com.microsoft.package.Frameworks
    /usr/sbin/pkgutil --forget com.microsoft.pkg.licensing
    /usr/sbin/pkgutil --forget com.microsoft.pkg.licensing.volume
    /usr/sbin/pkgutil --forget com.microsoft.teams
    /usr/sbin/pkgutil --forget com.microsoft.OneDrive
    /usr/sbin/pkgutil --forget com.microsoft.SkypeForBusiness

}


##################################################
# Bits staged...

LoggedInUser=$( GetLoggedInUser )
SetHomeFolder "${LoggedInUser}"
echo "Running as:  ${LoggedInUser}"
echo "Home Folder:  ${HOME}"

# Turn on case-insensitive pattern matching
shopt -s nocasematch

# In case multiple applications were provided, loop through them...
while read -r app; do

    # Determine requested task.
    case "${app}" in

        "All" )
            reset_Word
            reset_Excel
            reset_PowerPoint
            reset_Outlook
            reset_OneNote
            reset_OneDrive
            reset_Teams
            reset_Skype
            reset_MAU

            if [[ "${force_uninstall}" == "true" ]]; then

                full_uninstall

            else

                reset_Office_Credentials

            fi
        ;;
        "Word" )
            reset_Word
        ;;

        "Excel" )
            reset_Excel
        ;;

        "PowerPoint" )
            reset_PowerPoint
        ;;

        "Outlook" )
            reset_Outlook
        ;;

        "OneNote" )
            reset_OneNote
        ;;

        "OneDrive" )
            reset_OneDrive
        ;;

        "Teams" )
            reset_Teams
        ;;

        "Skype for Business" )
            reset_Skype
        ;;

        "MAU" | "Microsoft AutoUpdate" )
            reset_MAU
        ;;

        "Credentials" | "Sign-In Credentials" )
            reset_Office_Credentials
        ;;

        * )
            echo "ERROR:  Requested task is invalid"
            echo "*****  Reset Office Process:  FAILED  *****"
            exit 2
        ;;

    esac

done < <( echo "${apps}" | /usr/bin/tr ',' '\n' )

# Turn off case-insensitive pattern matching
shopt -u nocasematch

echo "*****  Reset Office Process:  COMPLETE  *****"
exit 0