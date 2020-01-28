#!/bin/bash

###################################################################################################
# Script Name:  uninstall_Avast.sh
# By:  Zack Thompson / Created:  8/16/2019
# Version:  1.3.0 / Updated:  1/24/2020 / By:  ZT
#
# Description:  Uninstalls Avast using the built in uninstall script.
#
###################################################################################################

echo "*****  Uninstall Avast process:  START  *****"

##################################################
# Define Variables
jamfBin='/usr/local/jamf/bin/jamf'
currentUser=$( /usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk '/Name :/ && ! /loginwindow/ { print $3 }' )

##################################################
# Bits staged...

echo "Searching for existing Avast instances..."

appPaths=$( /usr/bin/find -E /Applications "/Users/${currentUser}" -iregex ".*[/]Avast[.]app" -type d -prune 2>&1 | /usr/bin/grep -v "Operation not permitted" )

while IFS="\n" read -r appPath; do
	echo "Checking path:  ${appPath}"

	# Verify Avast exists in the expected location
	if [[ -d "${appPath}" ]]; then

		appVersion=$( /usr/bin/defaults read "${appPath}/Contents/Info.plist" CFBundleShortVersionString | /usr/bin/awk -F '.' '{print $1}' )

		echo "Uninstalling:  Avast v${appVersion}"
		
		# Run the built-in uninstall process
		case $appVersion in
			"11" | "12" )
				"/Library/Application Support/Avast/components/uninstall/com.avast.uninstall.app/Contents/Resources/uninstall.sh"
			;;
			"13" | "14" )
				if [[ -e "${appPath}/Contents/Backend/utils/com.avast.uninstall.app/Contents/Resources/uninstall.sh" ]]; then
					"${appPath}/Contents/Backend/utils/com.avast.uninstall.app/Contents/Resources/uninstall.sh"
				elif [[ -e "${appPath}/Contents/Backend/hub/uninstall.sh" ]]; then
					"${appPath}/Contents/Backend/hub/uninstall.sh"
				fi
			;;
			* )
				echo "ERROR:  Unable to uninstall this version!"
				continue
			;;
		esac

		if [[ $? = 0 ]]; then
			echo " -> Success"
			successfulExit="0"
		else
			echo " -> Failed"
			exit="1"
		fi

	else
		echo " -> Not an uninstallable Avast package"
		exit="2"
	fi

done < <(echo "${appPaths}")

if [[ "${successfulExit}" != "" ]]; then
	echo "*****  Uninstall Avast process:  COMPLETE  *****"
	# If Avast was uninstalled successfully, then run a recon
	"${jamfBin}" recon
	exit 0
else
	echo "*****  Uninstall Avast process:  FAILED  *****"
	exit $exit
fi
