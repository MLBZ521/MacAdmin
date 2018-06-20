#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_AvastStatus.sh
# By:  Zack Thompson / Created:  2/6/2018
# Version:  1.2 / Updated:  6/19/2018 / By:  ZT
#
# Description:  This script gets the configuration of Avast.
#
###################################################################################################

echo "Checking the Avast configuration..."

##################################################
# Define Array Variables for each item that we want to check for
# The last item in each array is the "desired" state (0 = Disabled and 1 = Enabled)

mailShield=("MailShield" "/Library/Application Support/Avast/config/com.avast.proxy.conf" "mailshield" "Enabled")
webShield=("WebShield" "/Library/Application Support/Avast/config/com.avast.proxy.conf" "webshield" "Enabled")
fileShield=("FileShield" "/Library/Application Support/Avast/config/com.avast.fileshield.conf" "fileshield" "Enabled")
virusDefUpdates=("DefinitionUpdates" "/Library/Application Support/Avast/config/com.avast.update.conf" "VPS_UPDATE_ENABLED=" "1")
programUpdates=("ProgramUpdates" "/Library/Application Support/Avast/config/com.avast.update.conf" "PROGRAM_UPDATE_ENABLED=" "1")
betaUpdates=("BetaUpdates" "/Library/Application Support/Avast/config/com.avast.update.conf" "BETA_CHANNEL=" "0")
licensedName=("Customer" "/Library/Application Support/Avast/config/license.avastlic" "CustomerName=" "Company Name")
licenseType=("License Type" "/Library/Application Support/Avast/config/license.avastlic" "LicenseType=" "0")
definitionStatus=("Virus Definitions" "/Library/Application Support/Avast/vps9/defs/aswdefs.ini" "Latest=")

# The number of days before trigger virus definitions are out of date.
virusDefVariance=7

# "Error" collection variables
disabled=""
license=""
virusDef=""
returnResult=""

##################################################
# Functions that perform searching routines

searchType1() {
	if [[ -e "${2}" ]]; then

		result=$(/bin/cat "${2}" | /usr/bin/python -c "import sys, json

objects = json.load(sys.stdin)
if \"${3}\" in objects:
    shield_info = objects[\"${3}\"]

    if 'enabled' in shield_info:
        print('Disabled')
    else:
        print('Enabled')
else:
    print('Enabled')")

		if [[ $result == "${4}" ]]; then
			echo "Desired State:  ${1}"
		else
			echo "Misconfigured:  ${1}"
			disabled+="${1},"
		fi
	fi
}

searchType2() {
	if [[ -e "${2}" ]]; then
		result=$(/bin/cat "${2}" | /usr/bin/awk -F "${3}" '{print $2}' | /usr/bin/xargs)

		if [[ $result == "${4}" ]]; then
			echo "Desired State:  ${1}"

		elif [[ "${1}" == "BetaUpdates" ]]; then
			echo "Misconfigured State:  ${1}"

		elif [[ "${1}" == "License Type" ]]; then
			echo "Misconfigured:  ${1}"
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
			echo "Misconfigured:  ${1}"
			license+="Unexpected Customer: ${result},"

		elif [[ "${1}" == "Virus Definitions" ]]; then
			# Compare Virus Definition Dates
			dateCheck=$(( $(date "+%y%m%d") - ${result%??} ))

			if [[ $dateCheck -gt $virusDefVariance ]]; then
				echo "Misconfigured:  ${1}"
				virusDef+="Virus Definitions are out of date"
			fi

		else
			echo "Misconfigured:  ${1}"
			disabled+="${1},"
		fi
	fi
}

##################################################
# Bits staged, collect the information...

searchType1 "${mailShield[@]}"
searchType1 "${webShield[@]}"
searchType1 "${fileShield[@]}"
searchType2 "${virusDefUpdates[@]}"
searchType2 "${programUpdates[@]}"
searchType2 "${betaUpdates[@]}"
searchType2 "${licensedName[@]}"
searchType2 "${licenseType[@]}"
searchType2 "${definitionStatus[@]}"

##################################################
# Check if each "error" collection variable is collected anything

if [[ -n "${disabled}" ]]; then
	returnResult+="Disabled:  ${disabled%?};"
fi

if [[ -n "${license}" ]]; then
	returnResult+="${license%?};"
fi

if [[ -n "${virusDef}" ]]; then
	returnResult+="${virusDef};"
fi

##################################################
# Return any errors or the all good.

if [[ -n "${returnResult}" ]]; then
	echo "<result>${returnResult%?}</result>"
else
	echo "<result>Desired State</result>"
fi

exit 0