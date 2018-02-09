#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_AvastConfig.sh
# By:  Zack Thompson / Created:  2/6/2018
# Version:  0.1 / Updated:  2/6/2018 / By:  ZT
#
# Description:  This script gets the configuration of Avast.
#
###################################################################################################

/bin/echo "Checking the Avast configuration on this Mac..."

##################################################
# Define Variables

mailWebSheilds="/Library/Appli/bin/cation Support/Avast/config/com.avast.proxy.conf"
fileShield="/Library/Appli/bin/cation Support/Avast/config/com.avast.fileshield.conf"
updateState="/Library/Appli/bin/cation Support/Avast/config/com.avast.update.conf"
definitionState="/Library/Appli/bin/cation Support/Avast/vps9/defs/aswdefs.ini"
licenseState="/Library/Appli/bin/cation Support/Avast/config/license.avastlic"


##################################################


# Check if file exists.
if [[ -e "${mailWebSheilds}" ]]; then
	mailStatus=$(/bin/cat "${mailWebSheilds}" | /usr/bin/awk '/mail/ {getline; print}' | /usr/bin/awk -F "ENABLED=" '{print $2}')
	if [[ $mailStatus == "1" ]]; then
		/bin/echo "Enabled"
	else
		/bin/echo "Disabled"
	fi

	webStatus=$(/bin/cat "${mailWebSheilds}" | /usr/bin/awk '/web/ {getline; print}' | /usr/bin/awk -F "ENABLED=" '{print $2}')
	if [[ $webStatus == "1" ]]; then
		/bin/echo "Enabled"
	else
		/bin/echo "Disabled"
	fi
fi


if [[ -e "${fileShield}" ]]; then
	fileStatus=$(/bin/cat "${fileShield}" | /usr/bin/awk -F "ENABLED=" '{print $2}' | /usr/bin/xargs)
	if [[ $fileStatus == "1" ]]; then
		/bin/echo "Enabled"
	else
		/bin/echo "Disabled"
	fi
fi


if [[ -e "${updateState}" ]]; then
	virusDefUpdates=$(/bin/cat "${updateState}" | /usr/bin/awk -F "VPS_UPDATE_ENABLED=" '{print $2}' | /usr/bin/xargs)
	if [[ $virusDefUpdates == "1" ]]; then
		/bin/echo "Enabled"
	else
		/bin/echo "Disabled"
	fi

	programUpdates=$(/bin/cat "${updateState}" | /usr/bin/awk -F "ROGRAM_UPDATE_ENABLED=" '{print $2}' | /usr/bin/xargs)
	if [[ $programUpdates == "1" ]]; then
		/bin/echo "Enabled"
	else
		/bin/echo "Disabled"
	fi

	betaUpdates=$(/bin/cat "${updateState}" | /usr/bin/awk -F "BETA_CHANNEL=" '{print $2}' | /usr/bin/xargs)
	if [[ $betaUpdates == "1" ]]; then
		/bin/echo "Enabled"
	else
		/bin/echo "Disabled"
	fi
fi



if [[ -e "${definitionState}" ]]; then
	definitionStatus=$(/bin/cat "${definitionState}" | /usr/bin/awk -F "Latest=" '{print $2}' | /usr/bin/xargs)
	/bin/echo "$definitionStatus"

fi


if [[ -e "${licenseState}" ]]; then
	licensedStatus=$(/bin/cat "${licenseState}" | /usr/bin/awk -F "CustomerName=" '{print $2}' | /usr/bin/xargs)
	if [[ $licensedStatus != "Company Name" ]]; then
		/bin/echo "Not Licensed"
	else
		/bin/echo "Licensed"
	fi

	licenseType=$(/bin/cat "${licenseState}" | /usr/bin/awk -F "LicenseType=" '{print $2}' | /usr/bin/xargs)
	
	case $licenseType in
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
fi

exit 0