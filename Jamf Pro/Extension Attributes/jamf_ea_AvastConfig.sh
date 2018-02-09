#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_AvastConfig.sh
# By:  Zack Thompson / Created:  2/6/2018
# Version:  0.2 / Updated:  2/7/2018 / By:  ZT
#
# Description:  This script gets the configuration of Avast.
#		- This is currently in development!
#
###################################################################################################

/bin/echo "Checking the Avast configuration on this Mac..."

##################################################
# Define Variables

mailSheild=("/Library/Application Support/Avast/config/com.avast.proxy.conf" "mail" "ENABLED=" "1")
webSheild=("/Library/Application Support/Avast/config/com.avast.proxy.conf" "web" "ENABLED=" "1")

fileshield=("/Library/Application Support/Avast/config/com.avast.fileshield.conf" "ENABLED=" "1")
virusDefUpdates=("/Library/Application Support/Avast/config/com.avast.update.conf" "VPS_UPDATE_ENABLED=" "1")
programUpdates=("/Library/Application Support/Avast/config/com.avast.update.conf" "PROGRAM_UPDATE_ENABLED=" "1")
betaUpdates=("/Library/Application Support/Avast/config/com.avast.update.conf" "BETA_CHANNEL=" "0")

definitionStatus=("/Library/Application Support/Avast/vps9/defs/aswdefs.ini" "Latest=")

licensedName=("/Library/Application Support/Avast/config/license.avastlic" "CustomerName=" "Company Name")
licenseType=("/Library/Application Support/Avast/config/license.avastlic" "LicenseType=" "0")


##################################################
# Functions

confirmExists() {
	if [[ -e "${1}" ]]; then
		# continue
	fi
}


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

	if [[ $result == "${3}" ]]; then
		/bin/echo "Desired State"
	else
		/bin/echo "Misconfigured"
	fi
fi
}



##################################################

searchType1 "${mailSheild[@]}"
searchType1 "${webSheild[@]}"
searchType1 "${fileSheild[@]}"
searchType1 "${virusDefUpdates[@]}"
searchType1 "${programUpdates[@]}"
searchType1 "${betaUpdates[@]}"
searchType1 "${definitionStatus[@]}"
searchType1 "${licensedName[@]}"
searchType1 "${licenseType[@]}"
