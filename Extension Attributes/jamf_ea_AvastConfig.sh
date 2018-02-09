#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_AvastConfig.sh
# By:  Zack Thompson / Created:  2/6/2018
# Version:  0.3 / Updated:  2/7/2018 / By:  ZT
#
# Description:  This script gets the configuration of Avast.
#		- This is currently in development!
#
###################################################################################################

/bin/echo "Checking the Avast configuration on this Mac..."

##################################################
# Define Variables

mailShield=("/Library/Application Support/Avast/config/com.avast.proxy.conf" "mail" "ENABLED=" "1")
webShield=("/Library/Application Support/Avast/config/com.avast.proxy.conf" "web" "ENABLED=" "1")

fileShield=("/Library/Application Support/Avast/config/com.avast.fileshield.conf" "ENABLED=" "1")
virusDefUpdates=("/Library/Application Support/Avast/config/com.avast.update.conf" "VPS_UPDATE_ENABLED=" "1")
programUpdates=("/Library/Application Support/Avast/config/com.avast.update.conf" "PROGRAM_UPDATE_ENABLED=" "1")
betaUpdates=("/Library/Application Support/Avast/config/com.avast.update.conf" "BETA_CHANNEL=" "0")
licensedName=("/Library/Application Support/Avast/config/license.avastlic" "CustomerName=" "Company Name")

licenseType=("/Library/Application Support/Avast/config/license.avastlic" "LicenseType=" "0")

definitionStatus=("/Library/Application Support/Avast/vps9/defs/aswdefs.ini" "Latest=")

##################################################
# Functions


searchType1() {

if [[ -e "${1}" ]]; then

	result=$(/bin/cat "${1}" | /usr/bin/awk '/'"${2}"'/ {getline; print}' | /usr/bin/awk -F "${3}" '{print $2}')

	if [[ $result == "${4}" ]]; then
		/bin/echo "Desired State"
	else
		/bin/echo "Misconfigured"
	fi
fi

}

searchType2() {

if [[ -e "${1}" ]]; then
	result=$(/bin/cat "${1}" | /usr/bin/awk -F "${2}" '{print $2}' | /usr/bin/xargs)
	# echo "${2}"

	if [[ $result == "${3}" ]]; then
		/bin/echo "Desired State"
	elif [[ "${2}" == "LicenseType=" ]]; then
		case $result in
			0 )
				/bin/echo "Standard (Premium)"
				;;
			4 )
				/bin/echo "Premium trial"
				;;
			13 )
				/bin/echo "Free, unapproved"
				;;
			14 )
				/bin/echo "Free, approved"
				;;
			16 )
				/bin/echo "Temporary"
				;;
			* )
				/bin/echo "Unknown Type"
				;;
		esac
	elif [[ "${2}" == "Latest=" ]]; then
		echo "${result}"

	else
		echo "${result}"
		/bin/echo "Misconfigured"
	fi
fi
}

##################################################

searchType1 "${mailShield[@]}"
searchType1 "${webShield[@]}"
searchType2 "${fileShield[@]}"
searchType2 "${virusDefUpdates[@]}"
searchType2 "${programUpdates[@]}"
searchType2 "${betaUpdates[@]}"
searchType2 "${licensedName[@]}"
searchType2 "${licenseType[@]}"
searchType2 "${definitionStatus[@]}"
