#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_AvastConfig.sh
# By:  Zack Thompson / Created:  2/6/2018
# Version:  0.4 / Updated:  2/8/2018 / By:  ZT
#
# Description:  This script gets the configuration of Avast.
#		- This is currently in development!
#
###################################################################################################

/bin/echo "Checking the Avast configuration..."

##################################################
# Define Variables

mailShield=("MailShield" "/Library/Application Support/Avast/config/com.avast.proxy.conf" "mail" "ENABLED=" "1")
webShield=("WebShield" "/Library/Application Support/Avast/config/com.avast.proxy.conf" "web" "ENABLED=" "1")
fileShield=("FileShield" "/Library/Application Support/Avast/config/com.avast.fileshield.conf" "ENABLED=" "1")
virusDefUpdates=("DefinitionUpdates" "/Library/Application Support/Avast/config/com.avast.update.conf" "VPS_UPDATE_ENABLED=" "1")
programUpdates=("ProgramUpdates" "/Library/Application Support/Avast/config/com.avast.update.conf" "PROGRAM_UPDATE_ENABLED=" "1")
betaUpdates=("BetaUpdates" "/Library/Application Support/Avast/config/com.avast.update.conf" "BETA_CHANNEL=" "0")
licensedName=("Customer" "/Library/Application Support/Avast/config/license.avastlic" "CustomerName=" "Company Name")
licenseType=("License Type" "/Library/Application Support/Avast/config/license.avastlic" "LicenseType=" "99")
definitionStatus=("Virus Definitions" "/Library/Application Support/Avast/vps9/defs/aswdefs.ini" "Latest=")

disabled=""
license=""
virusDef=""
returnResult=""

##################################################
# Functions

searchType1() {
	if [[ -e "${2}" ]]; then
		result=$(/bin/cat "${2}" | /usr/bin/awk '/'"${3}"'/ {getline; print}' | /usr/bin/awk -F "${4}" '{print $2}')

		if [[ $result == "${5}" ]]; then
			/bin/echo "Desired State:  ${1}"
		else
			/bin/echo "Misconfigured:  ${1}"
			disabled+="${1},"
		fi
	fi
}

searchType2() {
	if [[ -e "${2}" ]]; then
		result=$(/bin/cat "${2}" | /usr/bin/awk -F "${3}" '{print $2}' | /usr/bin/xargs)

		if [[ $result == "${4}" ]]; then
			/bin/echo "Desired State:  ${1}"

		elif [[ "${1}" == "BetaUpdates" ]]; then
			/bin/echo "Misconfigured State:  ${1}"

		elif [[ "${1}" == "License Type" ]]; then
			/bin/echo "Misconfigured:  ${1}"
			case $result in
				0 )
					license+="License Type:  Standard (Premium),";;
				4 )
					license+="License Type:  Premium trial,";;
				13 )
					license+="License Type:  Free, unapproved,";;
				14 )
					license+="License Type:  Free, approved,";;
				16 )
					license+="License Type:  Temporary,";;
				* )
					license+="License Type:  Unknown Type,";;
			esac

		elif [[ "${1}" == "Customer" ]]; then
			# Unexpected Customer
			/bin/echo "Misconfigured:  ${1}"
			license+="Unexpected Customer: ${result},"

		elif [[ "${1}" == "Virus Definitions" ]]; then
			# Compare Virus Definition Dates
			dateCheck=$(( $(date "+%y%m%d") - ${result%??} ))

			if [[ $dateCheck -ge 1 ]]; then
				/bin/echo "Misconfigured:  ${1}"
				virusDef+="Virus Definitions are out of date"
			fi

		else
			/bin/echo "Misconfigured:  ${1}"
			disabled+="${1},"
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

if [[ -n "${disabled}" ]]; then
	returnResult+="Disabled:  ${disabled%?};"
fi

if [[ -n "${license}" ]]; then
	returnResult+="${license%?};"
fi

if [[ -n "${virusDef}" ]]; then
	returnResult+="${virusDef};"
fi

echo "${returnResult%?}"