#!/bin/bash

###################################################################################################
# Script Name:  uninstall_Avast.sh
# By:  Zack Thompson / Created:  8/16/2019
# Version:  1.2.0 / Updated:  1/24/2020 / By:  ZT
#
# Description:  Uninstalls Avast using the built in uninstall script.
#
###################################################################################################

echo "*****  Uninstall Avast process:  START  *****"

##################################################
# Define Variables
exit="0"
jamfBin='/usr/local/jamf/bin/jamf'

##################################################
# Bits staged...

echo "Searching for existing Avast instances..."

appPaths=$( /usr/bin/find -E / -iregex ".*[/]Avast[.]app" -type d -prune 2>&1 | /usr/bin/grep -v "Operation not permitted" )

# Verify Avast exists in the expected location
if [[ -d "${appPath}" ]]; then

while IFS="\n" read -r appPath; do

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
				echo "*****  Uninstall Avast process:  FAILED  *****"
				exit 3
			;;
		esac

		if [[ $? = 0 ]]; then
			echo " -> Success"

			# If Avast was uninstalled successfully, then run a recon
			"${jamfBin}" recon
		else
			echo " -> Failed"
			exit="2"
		fi

	done < <(echo "${appPaths}")

else
	echo "ERROR:  Unable to locate Avast at the expected location!"
	exit="1"
fi

echo "*****  Uninstall Avast process:  COMPLETE  *****"
exit $exit