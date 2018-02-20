#!/bin/bash

###################################################################################################
# Script Name:  jamf_AssignVPPApps.sh
# By:  Zack Thompson / Created:  2/16/2018
# Version:  0.13 / Updated:  2/20/2018 / By:  ZT
#
# Description:  This script is used to scope groups to VPP Apps.
#
###################################################################################################

echo "*****  AssignVPPApps process:  START  *****"

##################################################
# Define Variables
	# Either hard code or prompt for credentials
	# jamfAPIUser="APIUsername"
	# jamfAPIPassword="APIPassword"
	# jamfAPIPassword=$(/usr/bin/osascript -e 'set userInput to the text returned of (display dialog "Enter your Jamf Password:" default answer "" with hidden answer)' 2>/dev/null)
	jamfAPIUser=$(/usr/bin/osascript -e 'set userInput to the text returned of (display dialog "Enter your Jamf Username:" default answer "")' 2>/dev/null)
	jamfAPIPassword=$(/usr/bin/osascript -e 'set userInput to the text returned of (display dialog "Enter your Jamf Password:" default answer "" with hidden answer)' 2>/dev/null)

	#jamfPS="https://newjss.company.com:8443"
	mobileApps="${jamfPS}/JSSResource/mobiledeviceapplications"
	mobileAppsByID="${mobileApps}/id"
	# Add -k (--insecure) to disable SSL verification
	curlAPI=(--silent --show-error --fail --user "${jamfAPIUser}:${jamfAPIPassword}" --header "Content-Type: application/xml" --request)

	# Either use CLI arguments or prompt for choice
	if [[ "${4}" == "Jamf" ]]; then
		action=$(/usr/bin/osascript -e 'tell application (path to frontmost application as text)' -e 'set availableActions to {"Get VPP Apps", "Assign VPP Apps"}' -e 'set Action to choose from list availableActions with prompt "Select action:" default items {"Get VPP Apps"}' -e 'end tell' 2>/dev/null)
	else
		action="${1}"
		switch1="${2}"
	fi

##################################################
# Setup Functions

getHelp() {
	echo "
usage:  jamf_AssignVPPApps.sh [-get | -assign] [/path/to/file.txt] [-help]

Info:	Get a list of VPP Apps or assign VPP Apps to groups.

Actions:
	-get		Gets all the VPP Apps from the JSS and exports them to a txt file.
			Example:  jamf_AssignVPPApps.sh -get output.txt

	-assign		Read the provide file and assigns (scopes) VPP Apps to a Group.
			Example:  jamf_AssignVPPApps.sh -assign input.txt

	-help		Displays this help section.
			Example:  jamf_AssignVPPApps.sh -help
"
}

# Build a list of Mobile Device Apps from the JSS.
getApps() {
	echo "Building list of all Mobile Device App IDs..."
	# GET list of Mobile Device App IDs from the JSS.
	appIDs=$(/usr/bin/curl "${curlAPI[@]}" GET $mobileApps | xmllint --format - | xpath /mobile_device_applications/mobile_device_application/id 2>/dev/null | LANG=C sed -e 's/<[^/>]*>//g' | LANG=C sed -e 's/<[^>]*>/\'$'\n/g')
	
	# Check if the API call was successful or not.
	exitCode $? notify

	echo "Adding headers to output file..."
	header="\"App ID\"\t\"App Name\"\t\"Auto Install?\"\t\"Auto Deploy\"\t\"Manage App?\"\t\"Remove App?\"\t\"App Site\"\t\"Scope to Group\""
	echo -e $header >> "${outFile}"

	echo "Getting Mobile Device App info..."
	# For Each ID, get the Name and Site it is assigned too.
	for appID in $appIDs; do
		/usr/bin/curl "${curlAPI[@]}" GET ${mobileAppsByID}/${appID}/subset/General | xmllint --format - | xpath '/mobile_device_application/general/id | /mobile_device_application/general/name | /mobile_device_application/general/site/name | /mobile_device_application/general/deployment_type | /mobile_device_application/general/deploy_automatically | /mobile_device_application/general/deploy_as_managed_app | /mobile_device_application/general/remove_app_when_mdm_profile_is_removed' 2>/dev/null | LANG=C sed -e 's/Install Automatically\/Prompt Users to Install/true/g' | LANG=C sed -e 's/Make Available in Self Service/false/g' | LANG=C sed -e 's/<[^/>]*>/\'$'\"/g' | LANG=C sed -e 's/<[^>]*>/\'$'\"\t/g' | LANG=C sed -e 's/\'$'\t[^\t]*$//' >> "${outFile}"
		# Check if the API call was successful or not.
		exitCode $?
	done

	echo "List has been saved to:  ${outFile}"
}

# Read in the App IDs and the Group Name to assign to them.
assignApps() {
	echo "Scoping Mobile Device Apps..."

	# Read in the file and assign to variables
	while IFS=$'\t' read appID appName appSite autoInstall autoDeploy manageApp removeApp scopeGroup; do

		# For sake of editing the txt, we're expecting a true or false value to "Auto Install" the App, but we need to reassign this value to what the JSS expects.
		if [[ $autoInstall == "true" ]]; then
			autoInstall="Install Automatically/Prompt Users to Install"
		elif [[ $autoInstall == "false" ]]; then
			autoInstall="Make Available in Self Service"
		else
			echo "Unable to determine the install method for App ID:  ${appID}"
			continue
		fi

		# PUT changes to the JSS.
		/usr/bin/curl "${curlAPI[@]}" PUT ${mobileAppsByID}/${appID} --data "<mobile_device_application>
<general>
<deployment_type>$autoInstall</deployment_type>
<deploy_automatically>$autoDeploy</deploy_automatically>
<deploy_as_managed_app>$manageApp</deploy_as_managed_app>
<remove_app_when_mdm_profile_is_removed>$removeApp</remove_app_when_mdm_profile_is_removed>
</general>
<scope>
<mobile_device_groups>
<mobile_device_group>
<name>$scopeGroup</name>
</mobile_device_group>
</mobile_device_groups>
</scope>
</mobile_device_application>" 2>&1>/dev/null 

		# Function exitCode
		exitCode $?
	done < <(/usr/bin/tail -n +2 "${inputFile}") # Essentially, skip the header line.
}

exitCode() {
	if [[ $1 != "0" ]]; then
		if [[ $2 == "notify" ]]; then
			# Notify only if told too. 
			echo " -> An action failed"
		fi
	else
		if [[ $2 == "notify" ]]; then
			# Notify only if told too. 
			echo " -> Success!"
		fi
	fi
}

fileExists() {
	if [[ ! -e "${1}" && $2 == "create" ]]; then
		echo "Creating output file at location:  ${1}"
		/usr/bin/touch "${1}"
	elif  [[ ! -e "${1}" && $2 == "trip" ]]; then
		echo "ERROR:  Unable to find the input file!"
		echo "*****  AssignVPPApps process:  FAILED  *****"
		exit 2
	fi
}

##################################################
# Bits Staged

if [[ -z "${jamfAPIUser}" && -z "${jamfAPIPassword}" ]]; then
	echo "Jamf credentials are required!"
	exit 1
fi

case $action in
	--get | -g | "Get VPP Apps" )
		if [[ -n "${switch1}" ]]; then
			outFile="${switch1}"
			# Function getApps
				getApps
		else
			outFile=$(/usr/bin/osascript -e 'tell application (path to frontmost application as text)' -e 'return POSIX path of (choose file name with prompt "Provide a file name and location to save the configuration file:")' -e 'end tell' 2>/dev/null)
			# Function fileExists
				fileExists "${outFile}" create
			# Function getApps
				getApps
		fi
	;;
	--assign | -a | "Assign VPP Apps" )
		if [[ -n "${switch1}" ]]; then
			inputFile="${switch1}"
			# Function fileExists
				fileExists "${inputFile}" trip
			# Function assignApps
				assignApps
		else
			inputFile=$(/usr/bin/osascript -e 'tell application (path to frontmost application as text)' -e 'return POSIX path of(choose file with prompt "Select configuration file to process:" of type {"txt"})' -e 'end tell' 2>/dev/null)
			# Function fileExists
				fileExists "${inputFile}" trip
			# Function assignApps
				assignApps
		fi
	;;
	-help | -h | * )
		# Function getHelp
		getHelp
	;;
esac

echo "*****  AssignVPPApps process:  COMPLETE  *****"
exit 0