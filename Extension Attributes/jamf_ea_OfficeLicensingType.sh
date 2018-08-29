#!/bin/sh
#set -x

###################################################################################################
# Script Name:  jamf_ea_OfficeLicenseType.sh
# By:  Zack Thompson / Created:  8/28/2018
# Version:  1.0 / Updated:  8/28/2018 / By:  ZT
#
# Description:  This script gets the Office Licensing Type.
#
# This is a fork of:  https://github.com/pbowden-msft/Unlicense
#
###################################################################################################

TOOL_NAME="Microsoft Office 365/2019/2016 License Removal Tool"
TOOL_VERSION="3.0"

# Set to force --DetectOnly
DETECT=true

## Copyright (c) 2018 Microsoft Corp. All rights reserved.
## Scripts are not supported under any Microsoft standard support program or service. The scripts are provided AS IS without warranty of any kind.
## Microsoft disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a 
## particular purpose. The entire risk arising out of the use or performance of the scripts and documentation remains with you. In no event shall
## Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages whatsoever 
## (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary 
## loss) arising out of the use of or inability to use the sample scripts or documentation, even if Microsoft has been advised of the possibility
## of such damages.
## Feedback: pbowden@microsoft.com

# Constants
function SetConstants {
	O365PRODUCT="$HOME/Library/Group Containers/UBF8T346G9.Office"
	WORD2016PATH="/Applications/Microsoft Word.app"
	EXCEL2016PATH="/Applications/Microsoft Excel.app"
	POWERPOINT2016PATH="/Applications/Microsoft PowerPoint.app"
	OUTLOOK2016PATH="/Applications/Microsoft Outlook.app"
	VOLUMELICENSE="/Library/Preferences/com.microsoft.office.licensingV2.plist"
	SHAREDLICENSE="/Library/Application Support/Microsoft/Office365/com.microsoft.Office365.plist"
	O365SUBMAIN="$O365PRODUCT/com.microsoft.Office365.plist"
	O365SUBBAK1="$O365PRODUCT/com.microsoft.e0E2OUQxNUY1LTAxOUQtNDQwNS04QkJELTAxQTI5M0JBOTk4O.plist"
	O365SUBBAK2="$O365PRODUCT/e0E2OUQxNUY1LTAxOUQtNDQwNS04QkJELTAxQTI5M0JBOTk4O"
	O365SUBMAINB="$O365PRODUCT/com.microsoft.Office365V2.plist"
	O365SUBBAK1B="$O365PRODUCT/com.microsoft.O4kTOBJ0M5ITQxATLEJkQ40SNwQDNtQUOxATL1YUNxQUO2E0e.plist"
	O365SUBBAK2B="$O365PRODUCT/O4kTOBJ0M5ITQxATLEJkQ40SNwQDNtQUOxATL1YUNxQUO2E0e"
	REGISTRY="$HOME/Library/Group Containers/UBF8T346G9.Office/MicrosoftRegistrationDB.reg"
}

# HOME folder detection
function GetHomeFolder {
	HOME=$(dscl . read /Users/"$1" NFSHomeDirectory | cut -d ':' -f2 | cut -d ' ' -f2)
	if [ "$HOME" == "" ]; then
		if [ -d "/Users/$1" ]; then
			HOME="/Users/$1"
		else
			HOME=$(eval echo "~$1")
		fi
	fi
}


# Shows tool usage and parameters
function ShowUsage {
	echo $TOOL_NAME - $TOOL_VERSION
	echo "Purpose: Removes current Office 365/2019/2016 for Mac activation license and returns apps to unlicensed state"
	echo "Usage: $0 [--All] [--DetectOnly] [--O365] [--Volume] [--ForceClose] [--User] [--JamfUser]"
	echo "Example: $0 --All --ForceClose"
	echo
	exit 0
}

# Check if Registry exists
function CheckRegistryExists {
if [ ! -f "$REGISTRY" ]; then
	echo "ERROR: Registry DOES NOT exist at path $REGISTRY."
	exit 1
fi
}

# Check to see if we get a response from a URL request
function ContactURL {
	local URL="$1"
	URLRESULT=$(curl --head -s $URL | awk '/HTTP/' | cut -d ' ' -f2)
	echo $URLRESULT
}

# Get node_id value from Registry
function GetNodeId {
	local NAME="$1"
	local PARENT="$2"
	local NODEVALUE=$(sqlite3 "$REGISTRY" "SELECT node_id from HKEY_CURRENT_USER WHERE name='$NAME' AND parent_id=$PARENT;")
	if [ "$NODEVALUE" == '' ]; then
		echo "0"
	else
		echo "$NODEVALUE"
	fi
}

# Get node value from Registry
function GetNodeVal {
	local NAME="$1"
	local NODEID="$2"
	local NODEVALUE=$(sqlite3 "$REGISTRY" "SELECT node_id from HKEY_CURRENT_USER_values WHERE name='$NAME' AND parent_id=$NODEID;")
	if [ "$NODEVALUE" == '' ]; then
		echo "0"
	else
		echo "$NODEVALUE"
	fi
}

# Delete value from Registry
function DeleteValue {
	local NAME="$1"
	local NODEID="$2"
	sqlite3 "$REGISTRY" "DELETE FROM HKEY_CURRENT_USER_values WHERE name='$NAME' and node_id=$NODEID;"
}

# Remove all flighting keys from the specified app
function RemoveFlightData {
	local KEY_APP="$1"
	# If the flight keys are set, remove the existing values
	KEY_UPDATETIME=($GetNodeVal "FlightUpdateTime" "$KEY_APP")
	if [ "$KEY_UPDATETIME" != "0" ]; then
		DeleteValue "FlightUpdateTime" "$KEY_APP"
	fi
	KEY_ETAG=($GetNodeVal "ETag" "$KEY_APP")
	if [ "$KEY_ETAG" != "0" ]; then
		DeleteValue "ETag" "$KEY_APP"
	fi
	KEY_IMPRESSION=($GetNodeVal "ImpressionId" "$KEY_APP")
	if [ "$KEY_IMPRESSION" != "0" ]; then
		DeleteValue "ImpressionId" "$KEY_APP"
	fi
	KEY_EXPIRES=($GetNodeVal "Expires" "$KEY_APP")
	if [ "$KEY_EXPIRES" != "0" ]; then
		DeleteValue "Expires" "$KEY_APP"
	fi
	KEY_DEFERRED=($GetNodeVal "DeferredConfigs" "$KEY_APP")
	if [ "$KEY_DEFERRED" != "0" ]; then
		DeleteValue "DeferredConfigs" "$KEY_APP"
	fi
	KEY_CONFIGID=($GetNodeVal "ConfigIds" "$KEY_APP")
	if [ "$KEY_CONFIGID" != "0" ]; then
		DeleteValue "ConfigIds" "$KEY_APP"
	fi
	KEY_NUMBERLINES=($GetNodeVal "FlightNumberlines" "$KEY_APP")
	if [ "$KEY_NUMBERLINES" != "0" ]; then
		DeleteValue "FlightNumberlines" "$KEY_APP"
	fi
	KEY_TASREQ=($GetNodeVal "TasRequestPending" "$KEY_APP")
	if [ "$KEY_TASREQ" != "0" ]; then
		DeleteValue "TasRequestPending" "$KEY_APP"
	fi
	KEY_FLVER=($GetNodeVal "FlightingVersion" "$KEY_APP")
	if [ "$KEY_FLVER" != "0" ]; then
		DeleteValue "FlightingVersion" "$KEY_APP"
	fi
}

# Check that all licensed applications are not running
function CheckRunning {
	OPENAPPS=0
	WORDRUNSTATE=$(CheckLaunchState "$WORD2016PATH")
	if [ "$WORDRUNSTATE" == "1" ]; then
		OPENAPPS=$(($OPENAPPS + 1))
		echo "ERROR: Word must be closed before license files can be removed."
	fi
	EXCELRUNSTATE=$(CheckLaunchState "$EXCEL2016PATH")
	if [ "$EXCELRUNSTATE" == "1" ]; then
		OPENAPPS=$(($OPENAPPS + 1))
		echo "ERROR: Excel must be closed before license files can be removed."
	fi
	POWERPOINTRUNSTATE=$(CheckLaunchState "$POWERPOINT2016PATH")
	if [ "$POWERPOINTRUNSTATE" == "1" ]; then
		OPENAPPS=$(($OPENAPPS + 1))
		echo "ERROR: PowerPoint must be closed before license files can be removed."
	fi
	OUTLOOKRUNSTATE=$(CheckLaunchState "$OUTLOOK2016PATH")
	if [ "$OUTLOOKRUNSTATE" == "1" ]; then
		OPENAPPS=$(($OPENAPPS + 1))
		echo "ERROR: Outlook must be closed before license files can be removed."
	fi
	if [ "$OPENAPPS" != "0" ]; then
		echo
		exit 1
	fi
}

# Checks to see if a process is running
function CheckLaunchState {
	local RUNNING_RESULT=$(ps ax | grep -v grep | grep "$1")
	if [ "${#RUNNING_RESULT}" -gt 0 ]; then
		echo "1"
	else
		echo "0"
	fi
}

# Forcibly terminates a running process
function ForceTerminate {
	$(ps ax | grep -v grep | grep "$1" | awk '{print $1}' | xargs kill -9 2> /dev/null)
}

# Force quit all Office apps that integrate with licensing
function ForceQuitApps {
	ForceTerminate "$WORD2016PATH"
	ForceTerminate "$EXCEL2016PATH"
	ForceTerminate "$POWERPOINT2016PATH"
	ForceTerminate "$OUTLOOK2016PATH"
}

# Checks to see if a volume license file is present
function DetectVolumeLicense {
	if [ -f "$VOLUMELICENSE" ]; then
		echo "1"
	else
		echo "0"
	fi
}

# Checks to see if an O365 subscription license file is present
function DetectO365License {
	if [ -f "$O365SUBMAIN" ] || [ -f "$O365SUBBAK1" ] || [ -f "$O365SUBBAK2" ] || [ -f "$O365SUBMAINB" ] || [ -f "$O365SUBBAK1B" ] || [ -f "$O365SUBBAK2B" ]; then
		echo "1"
	else
		echo "0"
	fi
}

# Removes the volume license file
function RemoveVolumeLicense {
	VLREADYTOREMOVE=$(DetectVolumeLicense)
	if [ "$VLREADYTOREMOVE" == "1" ]; then
		PRIVS=$(GetSudo)
		if [ "$PRIVS" == "1" ]; then
			echo "1"
			return
		else
			sudo rm -f "$VOLUMELICENSE"
			if [ "$?" == "0" ]; then
				echo "0"
			else
				echo "1"
			fi
		fi
	else
		echo "2"
	fi
}

# Removes the Office 365 Subscription license files
function RemoveO365License {
	O365READYTOREMOVE=$(DetectO365License)
	if [ "$O365READYTOREMOVE" == "1" ]; then
		if [ -f "$O365SUBMAIN" ]; then
			rm -f "$O365SUBMAIN"
		fi
		if [ -f "$O365SUBBAK1" ]; then
			rm -f "$O365SUBBAK1"
		fi
		if [ -f "$O365SUBBAK2" ]; then
			rm -f "$O365SUBBAK2"
		fi
		if [ -f "$O365SUBMAINB" ]; then
			rm -f "$O365SUBMAINB"
		fi
		if [ -f "$O365SUBBAK1B" ]; then
			rm -f "$O365SUBBAK1B"
		fi
		if [ -f "$O365SUBBAK2B" ]; then
			rm -f "$O365SUBBAK2B"
		fi
		if [ -f "$SHAREDLICENSE" ]; then
			rm -f "$SHAREDLICENSE"
		fi
		O365VERIFYREMOVAL=$(DetectO365License)
		if [ "$O365VERIFYREMOVAL" == "0" ]; then
			echo "0"
		else
			echo "1"
		fi
	else
		echo "2"
	fi
}

# Removes the package receipt metadata
function RemoveReceipt {
	local PKGARRAY=($(pkgutil --pkgs=$1))
	for p in "${PKGARRAY[@]}"
	do
		sudo pkgutil --forget $p
		if [ $? -eq 0 ] ; then
			echo "0"
		else
			echo "1"
		fi
	done
}

# Reset the first run experience for each licensed app
function ResetFRE {
	/usr/bin/defaults write com.microsoft.Word kSubUIAppCompletedFirstRunSetup1507 -bool FALSE
	/usr/bin/defaults write com.microsoft.Excel kSubUIAppCompletedFirstRunSetup1507 -bool FALSE
	/usr/bin/defaults write com.microsoft.Powerpoint kSubUIAppCompletedFirstRunSetup1507 -bool FALSE
	/usr/bin/defaults write com.microsoft.Outlook kSubUIAppCompletedFirstRunSetup1507 -bool FALSE
	/usr/bin/defaults write com.microsoft.Outlook FirstRunExperienceCompletedO15 -bool FALSE
}

# Reset the first run experience in sudo for each licensed app
function SudoResetFRE {
	sudo -u $USER /usr/bin/defaults write com.microsoft.Word kSubUIAppCompletedFirstRunSetup1507 -bool FALSE
	sudo -u $USER /usr/bin/defaults write com.microsoft.Excel kSubUIAppCompletedFirstRunSetup1507 -bool FALSE
	sudo -u $USER /usr/bin/defaults write com.microsoft.Powerpoint kSubUIAppCompletedFirstRunSetup1507 -bool FALSE
	sudo -u $USER /usr/bin/defaults write com.microsoft.Outlook kSubUIAppCompletedFirstRunSetup1507 -bool FALSE
	sudo -u $USER /usr/bin/defaults write com.microsoft.Outlook FirstRunExperienceCompletedO15 -bool FALSE
}

# Checks to see if 'msoCredentialSchemeADAL' entries are present in the keychain
function FindEntryMsoCredentialSchemeADAL {
	/usr/bin/security find-internet-password -s 'msoCredentialSchemeADAL' 2> /dev/null 1> /dev/null
	echo $?
}

# Removes the first 'msoCredentialSchemeADAL' entry from the keychain
function RemoveEntryMsoCredentialSchemeADAL {
	/usr/bin/security delete-internet-password -s 'msoCredentialSchemeADAL' 2> /dev/null 1> /dev/null
}

# Checks to see if 'msoCredentialSchemeLiveId' entries are present in the keychain
function FindEntryMsoCredentialSchemeLiveId {
	/usr/bin/security find-internet-password -s 'msoCredentialSchemeLiveId' 2> /dev/null 1> /dev/null
	echo $?
}

# Removes the first 'msoCredentialSchemeLiveId' entry from the keychain
function RemoveEntryMsoCredentialSchemeLiveId {
	/usr/bin/security delete-internet-password -s 'msoCredentialSchemeLiveId' 2> /dev/null 1> /dev/null
}

# Checks to see if 'MSOpenTech.ADAL.1*' entries are present in the keychain
function FindEntryMSOpenTechADAL1 {
	/usr/bin/security find-generic-password -G 'MSOpenTech.ADAL.1' 2> /dev/null 1> /dev/null
	echo $?
}

# Removes the first 'MSOpenTech.ADAL.1*' entry from the keychain
function RemoveEntryMSOpenTechADAL1 {
	/usr/bin/security delete-generic-password -G 'MSOpenTech.ADAL.1' 2> /dev/null 1> /dev/null
}

# Checks to see if the 'Microsoft Office Identities Cache 2' entry is present in the keychain (15.x builds)
function FindEntryOfficeIdCache2 {
	/usr/bin/security find-generic-password -l 'Microsoft Office Identities Cache 2' 2> /dev/null 1> /dev/null
	echo $?
}

# Removes the 'Microsoft Office Identities Cache 2' entry from the keychain (15.x builds)
function RemoveEntryOfficeIdCache2 {
	/usr/bin/security delete-generic-password -l 'Microsoft Office Identities Cache 2' 2> /dev/null 1> /dev/null
}

# Checks to see if the 'Microsoft Office Identities Cache 3' entry is present in the keychain (16.x builds)
function FindEntryOfficeIdCache3 {
	/usr/bin/security find-generic-password -l 'Microsoft Office Identities Cache 3' 2> /dev/null 1> /dev/null
	echo $?
}

# Removes the 'Microsoft Office Identities Cache 3' entry from the keychain (16.x builds)
function RemoveEntryOfficeIdCache3 {
	/usr/bin/security delete-generic-password -l 'Microsoft Office Identities Cache 3' 2> /dev/null 1> /dev/null
}

# Checks to see if the 'Microsoft Office Identities Settings 2' entry is present in the keychain (15.x builds)
function FindEntryOfficeIdSettings2 {
	/usr/bin/security find-generic-password -l 'Microsoft Office Identities Settings 2' 2> /dev/null 1> /dev/null
	echo $?
}

# Removes the 'Microsoft Office Identities Settings 2' entry from the keychain (15.x builds)
function RemoveEntryOfficeIdSettings2 {
	/usr/bin/security delete-generic-password -l 'Microsoft Office Identities Settings 2' 2> /dev/null 1> /dev/null
}

# Checks to see if the 'Microsoft Office Identities Settings 3' entry is present in the keychain (16.x builds)
function FindEntryOfficeIdSettings3 {
	/usr/bin/security find-generic-password -l 'Microsoft Office Identities Settings 3' 2> /dev/null 1> /dev/null
	echo $?
}

# Removes the 'Microsoft Office Identities Settings 3' entry from the keychain (16.x builds)
function RemoveEntryOfficeIdSettings3 {
	/usr/bin/security delete-generic-password -l 'Microsoft Office Identities Settings 3' 2> /dev/null 1> /dev/null
}

# Checks to see if the 'Microsoft Office Ticket Cache' entry is present in the keychain (16.x builds)
function FindEntryOfficeTicketCache {
	/usr/bin/security find-generic-password -l 'Microsoft Office Ticket Cache' 2> /dev/null 1> /dev/null
	echo $?
}

# Removes the 'Microsoft Office Ticket Cache' entry from the keychain (16.x builds)
function RemoveEntryOfficeTicketCache {
	/usr/bin/security delete-generic-password -l 'Microsoft Office Ticket Cache' 2> /dev/null 1> /dev/null
}

# Checks to see if the 'com.microsoft.adalcache' entry is present in the keychain (16.x builds)
function FindEntryAdalCache {
	/usr/bin/security find-generic-password -l 'com.microsoft.adalcache' 2> /dev/null 1> /dev/null
	echo $?
}

# Removes the 'com.microsoft.adalcache' entry from the keychain (16.x builds)
function RemoveEntryAdalCache {
	/usr/bin/security delete-generic-password -l 'com.microsoft.adalcache' 2> /dev/null 1> /dev/null
}

# Checks to see if the 'com.helpshift.data_com.microsoft.Outlook' entry is present in the keychain
function FindEntryHelpShift {
	/usr/bin/security find-generic-password -l 'com.helpshift.data_com.microsoft.Outlook' 2> /dev/null 1> /dev/null
	echo $?
}

# Removes the 'com.helpshift.data_com.microsoft.Outlook' entry from the keychain
function RemoveEntryHelpShift {
	/usr/bin/security delete-generic-password -l 'com.helpshift.data_com.microsoft.Outlook' 2> /dev/null 1> /dev/null
}

# Checks to see if the 'MicrosoftOfficeRMSCredential' entry is present in the keychain
function FindEntryRMSCredential {
	/usr/bin/security find-generic-password -l 'MicrosoftOfficeRMSCredential' 2> /dev/null 1> /dev/null
	echo $?
}

# Removes the 'MicrosoftOfficeRMSCredential' entry from the keychain
function RemoveEntryRMSCredential {
	/usr/bin/security delete-generic-password -l 'MicrosoftOfficeRMSCredential' 2> /dev/null 1> /dev/null
}

# Checks to see if the 'MSProtection.framework.service' entry is present in the keychain
function FindEntryMSProtection {
	/usr/bin/security find-generic-password -l 'MSProtection.framework.service' 2> /dev/null 1> /dev/null
	echo $?
}

# Removes the 'MSProtection.framework.service' entry from the keychain
function RemoveEntryMSProtection {
	/usr/bin/security delete-generic-password -l 'MSProtection.framework.service' 2> /dev/null 1> /dev/null
}

function GetSudo {
# Checks to see if the user has root-level permissions
	if [ "$EUID" != "0" ]; then
		sudo -p "Enter administrator password: " echo
		if [ $? -eq 0 ] ; then
			echo "0"
		else
			echo "1"
		fi
	fi
}

## Not using these options.
# Evaluate command-line arguments
# if [[ $# = 0 ]]; then
# 	ShowUsage
# else
# 	for KEY in "$@"
# 	do
# 	case $KEY in
# 		--Help|-h|--help)
# 		ShowUsage
# 		shift # past argument
# 		;;
# 		--All|-a|--all)
# 		REMOVEVL=true
# 		REMOVEO365=true
# 		shift # past argument
# 		;;
# 		--DetectOnly|-d|--detectonly)
# 		DETECT=true
# 		shift # past argument
# 		;;
# 		--O365|-o|--o365)
# 		REMOVEO365=true
# 		shift # past argument
# 		;;
# 		--Volume|-v|--volume)
# 		REMOVEVL=true
# 		shift # past argument
# 		;;
# 		--ForceClose|-f|--forceclose)
# 		FORCECLOSE=true
# 		shift # past argument
# 		;;
# 		--User:*|-u:*)
# 		USER=${KEY#*:}
# 		GetHomeFolder "$USER"
# 		shift # past argument
# 		;;
# 		--JamfUser)
# 		# 	Used to remove Office 365/2019/2016 activation for Jamf script. Example Self Service script.
# 		#  Parameter 4: --All, Parameter 5: --ForceClose, Parameter 6: --JamfUser
# 		USER=$3
# 		GetHomeFolder "$USER"
# 		shift # past argument
# 		;;
# 	esac
# 	shift # past argument or value
# 	done
# fi

## Main
SetConstants
# Check first for detection mode
if [ $DETECT ]; then
	VLPRESENT=$(DetectVolumeLicense)
	if [ "$VLPRESENT" == "1" ]; then
		echo "A volume license was detected."
		licenseType="Volume License"
	else
		echo "A volume license was NOT detected."
	fi
	
	O365PRESENT=$(DetectO365License)
	if [ "$O365PRESENT" == "1" ]; then
		echo "An Office 365 Subscription license was detected."
		licenseType="O365 License"
	else
		echo "An Office 365 Subscription license was NOT detected."
	fi
	
	if [ "$VLPRESENT" == "1" ] && [ "$O365PRESENT" == "1" ]; then
		echo "WARNING: Both volume and Office 365 Subscription licenses were detected. Only the volume license will be used."
		licenseType="Both"
	fi

	if [ "$VLPRESENT" == "0" ] && [ "$O365PRESENT" == "0" ]; then
		echo "No license detected"
		licenseType="Not Licensed"
	fi

	echo "<result>${licenseType}</result>"
	exit 0
fi

# Remove volume license
if [ $REMOVEVL ]; then
	VLPRESENT=$(DetectVolumeLicense)
	if [ "$VLPRESENT" == "1" ]; then
		if [ $FORCECLOSE ]; then
			ForceQuitApps
		else
			CheckRunning
		fi
		REMOVEVLFILES=$(RemoveVolumeLicense)
		if [ "$REMOVEVLFILES" == "0" ]; then
			SudoResetFRE
			echo "The volume license files were removed successfully."
		elif [ "$REMOVEVLFILES" == "2" ]; then
			echo "WARNING: No volume license files were present"
		else
			echo "ERROR: The volume license files could NOT be removed. Try using the sudo command to elevate permissions."
			exit 1
		fi
		REMOVEVLRECEIPT=$(RemoveReceipt "com.microsoft.pkg.licensing.volume")
	else
		echo "WARNING: No volume license files were present"
	fi
fi

# Remove subscription license
if [ $REMOVEO365 ]; then
	O365PRESENT=$(DetectO365License)
	if [ "$O365PRESENT" == "1" ]; then
		if [ $FORCECLOSE ]; then
			ForceQuitApps
		else
			CheckRunning
		fi
		# Find and remove 'msoCredentialSchemeADAL' entries
		MAXCOUNT=0
		KEYNOTPRESENT=$(FindEntryMsoCredentialSchemeADAL)
		while [ "$KEYNOTPRESENT" == "0" ] || [ $MAXCOUNT -gt 20 ]; do
			RemoveEntryMsoCredentialSchemeADAL
			let MAXCOUNT=MAXCOUNT+1
			KEYNOTPRESENT=$(FindEntryMsoCredentialSchemeADAL)
		done
		
		# Find and remove 'msoCredentialSchemeLiveId' entries
		MAXCOUNT=0
		KEYNOTPRESENT=$(FindEntryMsoCredentialSchemeLiveId)
		while [ "$KEYNOTPRESENT" == "0" ] || [ $MAXCOUNT -gt 20 ]; do
			RemoveEntryMsoCredentialSchemeLiveId
			let MAXCOUNT=MAXCOUNT+1
			KEYNOTPRESENT=$(FindEntryMsoCredentialSchemeLiveId)
		done
		
		# Find and remove 'MSOpenTech.ADAL.1*' entries
		MAXCOUNT=0
		KEYNOTPRESENT=$(FindEntryMSOpenTechADAL1)
		while [ "$KEYNOTPRESENT" == "0" ] || [ $MAXCOUNT -gt 20 ]; do
			RemoveEntryMSOpenTechADAL1
			let MAXCOUNT=MAXCOUNT+1
			KEYNOTPRESENT=$(FindEntryMSOpenTechADAL1)
		done
		
		# Find and remove 'Microsoft Office Identities Cache 2' entries
		MAXCOUNT=0
		KEYNOTPRESENT=$(FindEntryOfficeIdCache2)
		while [ "$KEYNOTPRESENT" == "0" ] || [ $MAXCOUNT -gt 20 ]; do
			RemoveEntryOfficeIdCache2
			let MAXCOUNT=MAXCOUNT+1
			KEYNOTPRESENT=$(FindEntryOfficeIdCache2)
		done
		
		# Find and remove 'Microsoft Office Identities Cache 3' entries
		MAXCOUNT=0
		KEYNOTPRESENT=$(FindEntryOfficeIdCache3)
		while [ "$KEYNOTPRESENT" == "0" ] || [ $MAXCOUNT -gt 20 ]; do
			RemoveEntryOfficeIdCache3
			let MAXCOUNT=MAXCOUNT+1
			KEYNOTPRESENT=$(FindEntryOfficeIdCache3)
		done
		
		# Find and remove 'Microsoft Office Identities Settings 2' entries
		MAXCOUNT=0
		KEYNOTPRESENT=$(FindEntryOfficeIdSettings2)
		while [ "$KEYNOTPRESENT" == "0" ] || [ $MAXCOUNT -gt 20 ]; do
			RemoveEntryOfficeIdSettings2
			let MAXCOUNT=MAXCOUNT+1
			KEYNOTPRESENT=$(FindEntryOfficeIdSettings2)
		done
		
		# Find and remove 'Microsoft Office Identities Settings 3' entries
		MAXCOUNT=0
		KEYNOTPRESENT=$(FindEntryOfficeIdSettings3)
		while [ "$KEYNOTPRESENT" == "0" ] || [ $MAXCOUNT -gt 20 ]; do
			RemoveEntryOfficeIdSettings3
			let MAXCOUNT=MAXCOUNT+1
			KEYNOTPRESENT=$(FindEntryOfficeIdSettings3)
		done
		
		# Find and remove 'Microsoft Office Ticket Cache' entries
		MAXCOUNT=0
		KEYNOTPRESENT=$(FindEntryOfficeTicketCache)
		while [ "$KEYNOTPRESENT" == "0" ] || [ $MAXCOUNT -gt 20 ]; do
			RemoveEntryOfficeTicketCache
			let MAXCOUNT=MAXCOUNT+1
			KEYNOTPRESENT=$(FindEntryOfficeTicketCache)
		done

		# Find and remove 'com.microsoft.adalcache' entries
		MAXCOUNT=0
		KEYNOTPRESENT=$(FindEntryAdalCache)
		while [ "$KEYNOTPRESENT" == "0" ] || [ $MAXCOUNT -gt 20 ]; do
			RemoveEntryAdalCache
			let MAXCOUNT=MAXCOUNT+1
			KEYNOTPRESENT=$(FindEntryAdalCache)
		done
		#echo "Default keychain entries removed"

		# Find and remove 'MicrosoftOfficeRMSCredential' entries
		MAXCOUNT=0
		KEYNOTPRESENT=$(FindEntryRMSCredential)
		while [ "$KEYNOTPRESENT" == "0" ] || [ $MAXCOUNT -gt 20 ]; do
			RemoveEntryRMSCredential
			let MAXCOUNT=MAXCOUNT+1
			KEYNOTPRESENT=$(FindEntryRMSCredential)
		done
		
		# Find and remove 'MSProtection.framework.service' entries
		MAXCOUNT=0
		KEYNOTPRESENT=$(FindEntryMSProtection)
		while [ "$KEYNOTPRESENT" == "0" ] || [ $MAXCOUNT -gt 20 ]; do
			RemoveEntryMSProtection
			let MAXCOUNT=MAXCOUNT+1
			KEYNOTPRESENT=$(FindEntryMSProtection)
		done
		#echo "Rights Management keychain entries removed"

		# Find and remove 'com.helpshift.data_com.microsoft.Outlook' entries
		MAXCOUNT=0
		KEYNOTPRESENT=$(FindEntryHelpShift)
		while [ "$KEYNOTPRESENT" == "0" ] || [ $MAXCOUNT -gt 20 ]; do
			RemoveEntryHelpShift
			let MAXCOUNT=MAXCOUNT+1
			KEYNOTPRESENT=$(FindEntryHelpShift)
		done
		#echo "HelpShift keychain entries removed"

		REMOVEO365FILES=$(RemoveO365License)
		if [ "$REMOVEO365FILES" == "0" ]; then
			ResetFRE
			echo "The Office 365 Subscription license files were removed successfully."
		elif [ "$REMOVEO365FILES" == "2" ]; then
			echo "WARNING: No Office 365 Subscription license files were present"
		else
			echo "ERROR: The Office 365 Subscription license files could NOT be removed."
			exit 1
		fi
	else
		echo "WARNING: No Office 365 Subscription license files were present"
	fi
fi

if [ $REMOVEVL ] || [ $REMOVEO365 ]; then
	# Check that MicrosoftRegistryDB.reg actually exists.
	CheckRegistryExists
	# Check to see if the flighting server is online
	FLIGHTRESPONSE=$(ContactURL "https://client-office365-tas.msedge.net/ab?")
	echo "Contacting flighting server: $FLIGHTRESPONSE"
	# Walk the registry to find the id of the node that we need
	KEY_SOFTWARE=$(GetNodeId "Software" '-1')
	KEY_MICROSOFT=$(GetNodeId "Microsoft" "$KEY_SOFTWARE")
	KEY_OFFICE=$(GetNodeId "Office" "$KEY_MICROSOFT")
	KEY_VERSION=$(GetNodeId "16.0" "$KEY_OFFICE")
	KEY_COMMON=$(GetNodeId "Common" "$KEY_VERSION")
	KEY_TAS=$(GetNodeId "ExperimentTAS" "$KEY_COMMON")
	KEY_WORD=$(GetNodeId "word" "$KEY_TAS")
	KEY_EXCEL=$(GetNodeId "excel" "$KEY_TAS")
	KEY_POWERPOINT=$(GetNodeId "powerpoint" "$KEY_TAS")
	KEY_OUTLOOK=$(GetNodeId "outlook" "$KEY_TAS")
	KEY_ONENOTE=$(GetNodeId "onenote" "$KEY_TAS")
	KEY_LICENSING=$(GetNodeId "licensingdaemon" "$KEY_TAS")

	RemoveFlightData "$KEY_WORD"
	RemoveFlightData "$KEY_EXCEL"
	RemoveFlightData "$KEY_POWERPOINT"
	RemoveFlightData "$KEY_OUTLOOK"
	RemoveFlightData "$KEY_ONENOTE"
	RemoveFlightData "$KEY_LICENSING"

	echo "Existing flight data removed."
fi

exit 0