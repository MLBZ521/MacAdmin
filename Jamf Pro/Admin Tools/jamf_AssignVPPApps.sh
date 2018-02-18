#!/bin/bash

###################################################################################################
# Script Name:  jamf_AssignVPPApps.sh
# By:  Zack Thompson / Created:  2/16/2018
# Version:  0.6 / Updated:  2/17/2018 / By:  ZT
#
# Description:  This script is used to scope groups to VPP Apps.
#
###################################################################################################

/bin/echo "*****  AssignVPPApps process:  START  *****"

##################################################
# Define Variables
	jamfAPIUser="APIUsername"
	jamfAPIPassword="APIPassword"
	jamfPS="https://newjss.company.com:8443"
	mobileApps="${jamfPS}/JSSResource/mobiledeviceapplications"
	mobileAppsByID="${jamfPS}/${mobileApps}/id"
	# Add -k (--insecure) to disable SSL verification
	curlAPI=$(/usr/bin/curl --silent --show-error --fail --user "${jamfAPIUser}:${jamfAPIPassword}" --header "Content-Type: text/xml" --request)
	action="${1}"
	switch1="${2}"

##################################################
# Setup Functions

getHelp() {
	echo "
usage:  jamf_AssignVPPApps.sh [-get | -assign] [-file /path/to/file.csv] [-help]

Info:	Get a list of VPP Apps or assign VPP Apps to groups.

Actions:
	-get		Gets all the VPP Apps from the JSS and exports them to a csv file.
			Example:  jamf_AssignVPPApps.sh -get output.csv

	-assign		Read the provide file and assigns (scopes) VPP Apps to a Group.
			Example:  jamf_AssignVPPApps.sh -assign input.csv

	-help		Displays this help section.
			Example:  jamf_AssignVPPApps.sh -help
"
}

# Build a list of Mobile Device Apps from the JSS.
getApps() {
	outFile="${1}"
	/bin/echo "Building list of all Mobile Device App IDs..."
	# GET list of Mobile Device App IDs from the JSS.
	appIDs=$($curlAPI GET $mobileApps | xmllint --format - | xpath /mobile_device_applications/mobile_device_application/id 2>/dev/null | LANG=C sed -e 's/<[^/>]*>//g' | LANG=C sed -e 's/<[^>]*>/\'$'\n/g')
	
	# For Each ID, get the Name and Site it is assigned too.
	for appID in $appIDs; do
		$curlAPI GET ${mobileAppsByID}/${appID}/subset/General | xmllint --format - | xpath '/mobile_device_application/general/id | /mobile_device_application/general/name | /mobile_device_application/general/site/name' 2>/dev/null | LANG=C sed -e 's/<[^/>]*>/\'$'\"/g' | LANG=C sed -e 's/<[^>]*>/\'$'\",/g'  | LANG=C sed -e 's/,[^,]*$//' >> $outFile
	done

	/bin/echo "List has been saved to:  ${outFile}"
}

# Read in the App IDs and the Group Name to assign to them.
assignApps() {
	inputFile="${1}"
	# Read in the file and assign to variables
	while IFS=$'\t' read appID appName appSite groupName; do
		# echo "$appID"
		# echo "$groupName"

		# PUT changes to the JSS.
		/bin/echo "Getting a list of all Mobile Device Apps..."

			$curlAPI PUT ${mobileAppsByID} --upload-file &> /dev/null <<XML
<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>
<mobile_device_application>
<general>
<id>$appID</id>
</general>
<scope>
<mobile_devices/>
<mobile_device_groups>
<mobile_device_group>
<id>0</id>
<name>$groupName</name>
</mobile_device_group>
</mobile_device_groups>
</scope>
</mobile_device_application>
XML

		# Function exitCode
		exitCode $?
	done < "${inputFile}"
}

##################################################
# Bits Staged

case $action in
	--get | -g )
		if [[ -n "${switch1}" ]]; then
			# # Function fileExists 
			# fileExists "${input2}"
			
			# Function getApps
			getApps "${switch1}"
		else
			# Function getHelp
			getHelp
		fi
	;;
	--assign | -a )
		if [[ -n "${switch1}" ]]; then
			# # Function fileExists 
			# fileExists "${input3}" "${input2}"

			# Function assignApps
			assignApps "${switch1}"
		else
			# Function getHelp
			getHelp
		fi
	;;
	-help | -h | * )
		# Function getHelp
		getHelp
	;;
esac

exit 0
