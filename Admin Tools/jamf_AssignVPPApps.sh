#!/bin/bash

###################################################################################################
# Script Name:  jamf_AssignVPPApps.sh
# By:  Zack Thompson / Created:  2/16/2018
# Version:  0.5 / Updated:  2/16/2018 / By:  ZT
#
# Description:  This script is used to scope groups to VPP Apps.
#
###################################################################################################

/bin/echo "*****  AssignVPPApps process:  START  *****"

##################################################
# Define Variables
	jamfPS="https://newjss.company.com:8443"
	mobileApps="${jamfPS}/JSSResource/mobiledeviceapplications"
	mobileAppsByID="${jamfPS}/${mobileApps}/id"
	jamfAPIUser="APIUsername"
	jamfAPIPassword="APIPassword"

	action="${1}"
	switch1="${2}"
	#switch2="${3}"

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

getApps() {

	outFile="${1}"
	# Get Mobile Device Apps from the JSS (add -k, --insecure to disabled SSL verification)
	/bin/echo "Getting a list of all Mobile Device Apps..."

	appIDs=$(/usr/bin/curl --silent --show-error --fail --user "${jamfAPIUser}:${jamfAPIPassword}" "https://orchard.asu.edu:8443/JSSResource/mobiledeviceapplications" --header "Content-Type: text/xml" --request GET | xmllint --format - | xpath /mobile_device_applications/mobile_device_application/id 2>/dev/null | LANG=C sed -e 's/<[^/>]*>//g' | LANG=C sed -e 's/<[^>]*>/\'$'\n/g')
	
	for appID in $appIDs; do
		/usr/bin/curl --silent --show-error --fail --user "${jamfAPIUser}:${jamfAPIPassword}" "https://orchard.asu.edu:8443/JSSResource/mobiledeviceapplications/id/${appID}/subset/General" --header "Content-Type: text/xml" --request GET | xmllint --format - | xpath '/mobile_device_application/general/id | /mobile_device_application/general/name | /mobile_device_application/general/site/name' 2>/dev/null | LANG=C sed -e 's/<[^/>]*>/\'$'\"/g' | LANG=C sed -e 's/<[^>]*>/\'$'\",/g'  | LANG=C sed -e 's/,[^,]*$//' >> $outFile
	done

}


assignApps() {

	inputFile="${1}"
	while IFS= read -r line; do
		if [[ -n $line ]]; then
			appID=$(echo "$line" | awk -F ',' '{print $1}')
			groupName=$(echo "$line" | awk -F ',' '{print $2}')

			# Assigns Mobile Device Apps to Groups (add -k, --insecure to disabled SSL verification)
				/bin/echo "Getting a list of all Mobile Device Apps..."
				/usr/bin/curl --silent --show-error --fail --user "${jamfAPIUser}:${jamfAPIPassword}" "${mobileApps}/" --header "Content-Type: text/xml" --request PUT --upload-file &> /dev/null <<XML
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
		fi
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
