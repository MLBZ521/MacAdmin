#!/bin/bash

###################################################################################################
# Script Name:  jamf_ea_EFIFirmwareCheck.sh
# By:  Zack Thompson / Created:  3/19/2018
# Version:  1.0 / Updated:  3/19/2018 / By:  ZT
#
# Description:  A Jamf Extension Attribute that uses the Duo-Labs "EFIgy" API tool to check a Macs' EFI version.
#
#	Details:  https://github.com/duo-labs/EFIgy
#
###################################################################################################

##################################################
# Define Variables
macModel=$(/usr/sbin/sysctl -n hw.model)
buildVersion=$(/usr/bin/sw_vers -buildVersion)
efiVersion=$(/usr/sbin/system_profiler SPHardwareDataType | /usr/bin/awk -F 'Boot ROM Version: ' '{print $2}' | /usr/bin/xargs)

##################################################
# Bits Staged

# Submit data to the API
curlReturn="$(/usr/bin/curl --silent --show-error --fail --write-out "statusCode:%{http_code}" --output - --header "Content-Type: application/json" --request GET https://api.efigy.io/apple/up2date/${macModel}/${buildVersion}/${efiVersion})"

# Get the statusCode of the API response
curlCode=$(echo "${curlReturn}" | /usr/bin/awk -F statusCode: '{print $2}')

# Compare the Status Code 
case $curlCode in
	200 )
		# Request successful; get the response only.
		response=$(echo "${curlReturn}" | /usr/bin/sed -e 's/statusCode\:.*//g' | /usr/bin/python -c "import sys, json; print json.load(sys.stdin)['msg']")

		# Compare the response
		case $response in
			up2date )
				# Indicates that the supplied EFI version is the one that is expected for the supplied combination of Mac model and OS build number.
				echo "<result>Current</result>"
			;;
			outofdate )
				# Indicates that the supplied EFI version is older than expected for the supplied combination of Mac model and OS build number.
				echo "<result>Out of Date</result>"
			;;
			newer )
				# Indicates that the supplied EFI version is the newer than expected for the supplied combination of Mac model and OS build number. This could be because the system previously had a beta or pre-release version of macOS installed and then downgraded to a stable OS version that shipped with older EFI firmware.
				echo "<result>Newer</result>"
			;;
			model_unknown )
				# Indicates the supplied Mac model was not one in the EFIgy Server dataset, or is in an incorrect format (use Mac model ID's in this format MacBookPro13,2).
				echo "<result>Unknown Model</result>"
			;;
			build_unknown )
				# Indicates the supplied OS build was not one in the EFIgy Server dataset.
				echo "<result>Unknown Build</result>"
			;;
			* )
				# Not an expect response.
				echo "<result>Error:  Unexpected response</result>"
			;;
		esac
	;;
	* )
		# Failed the API call.
		echo "<result>Error:  ${1} response</result>"
	;;
esac

exit 0