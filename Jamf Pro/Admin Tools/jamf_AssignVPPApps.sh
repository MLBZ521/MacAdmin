#!/bin/bash

###################################################################################################
# Script Name:  jamf_AssignVPPApps.sh
# By:  Zack Thompson / Created:  2/16/2018
# Version:  0.9 / Updated:  2/19/2018 / By:  ZT
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
	mobileAppsByID="${mobileApps}/id"
	# Add -k (--insecure) to disable SSL verification
	curlAPI=(--silent --show-error --fail --user "${jamfAPIUser}:${jamfAPIPassword}" --header "Content-Type: text/xml" --request)
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
	appIDs=$(/usr/bin/curl "${curlAPI[@]}" GET $mobileApps | xmllint --format - | xpath /mobile_device_applications/mobile_device_application/id 2>/dev/null | LANG=C sed -e 's/<[^/>]*>//g' | LANG=C sed -e 's/<[^>]*>/\'$'\n/g')
	
	# Check if the API call was successful or not.
	exitCode $?

	/bin/echo "Adding headers to output file..."
	header="\"App ID\"\t\"App Name\"\t\"App Site\"\t\"Auto Install?\"\t\"Auto Deploy\"\t\"Manage App?\"\t\"Remove App?\"\t\"Scope to Group\""
	echo -e $header >> $outFile

	/bin/echo "Getting Mobile Device App info..."
	# For Each ID, get the Name and Site it is assigned too.
	for appID in $appIDs; do
		/usr/bin/curl "${curlAPI[@]}" GET ${mobileAppsByID}/${appID}/subset/General | xmllint --format - | xpath '/mobile_device_application/general/id | /mobile_device_application/general/name | /mobile_device_application/general/site/name | /mobile_device_application/general/deployment_type | /mobile_device_application/general/deploy_automatically | /mobile_device_application/general/deploy_as_managed_app | /mobile_device_application/general/remove_app_when_mdm_profile_is_removed' 2>/dev/null | LANG=C sed -e 's/Install Automatically\/Prompt Users to Install/true/g' | LANG=C sed -e 's/Make Available in Self Service/false/g' | LANG=C sed -e 's/<[^/>]*>/\'$'\"/g' | LANG=C sed -e 's/<[^>]*>/\'$'\"\t/g' | LANG=C sed -e 's/\'$'\t[^\t]*$//' >> $outFile
		# Check if the API call was successful or not.
		exitCode $?
	done

	/bin/echo "List has been saved to:  ${outFile}"
}

# Read in the App IDs and the Group Name to assign to them.
assignApps() {
	inputFile="${1}"
	/bin/echo "Scoping Mobile Device Apps..."

	# Read in the file and assign to variables
	while IFS=$'\t' read appID appName appSite autoInstall autoDeploy manageApp removeApp scopeGroup; do
		# echo "$appID"
		# echo "$groupName"

		# For sake of editing the csv, we're expecting a true or false value to "Auto Install" the App, but we need to reassign this value to what the JSS expects.
		if [[ $autoInstall == "true" ]]; then
			autoInstall="Install Automatically/Prompt Users to Install"
		else
			autoInstall="Self Service"
		fi

		# PUT changes to the JSS.
		$curlAPI PUT ${mobileAppsByID} --upload-file &> /dev/null <<XML
<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>
<mobile_device_application>
<general>
<id>$appID</id>
<deployment_type>$autoInstall</deployment_type>
<deploy_automatically>$autoDeploy</deploy_automatically>
<deploy_as_managed_app>$manageApp</deploy_as_managed_app>
<remove_app_when_mdm_profile_is_removed>$removeApp</remove_app_when_mdm_profile_is_removed>
</general>
<scope>
<mobile_devices/>
<mobile_device_groups>
<mobile_device_group>
<id>0</id>
<name>$scopeGroup</name>
</mobile_device_group>
</mobile_device_groups>
</scope>
</mobile_device_application>
XML

		# Function exitCode
		exitCode $?
	done < <(/usr/bin/tail -n +2 "${inputFile}") # Essentially, skip the header line.
}

exitCode() {
	if [[ $1 != "0" ]]; then
		/bin/echo " -> Failed"
		# exit 1
	else
		/bin/echo " -> Success!"
	fi
}

fileExists() {
	if [[ ! -e "${1}" ]]; then
		/bin/echo "ERROR:  Unable to find the input file!"
		/bin/echo "*****  AssignVPPApps process:  FAILED  *****"
		exit 1
	fi
}

##################################################
# Bits Staged

case $action in
	--get | -g )
		if [[ -n "${switch1}" ]]; then			
			# Function getApps
			getApps "${switch1}"
		else
			# Function getHelp
			getHelp
		fi
	;;
	--assign | -a )
		if [[ -n "${switch1}" ]]; then
			# Function fileExists 
			fileExists "${switch1}"

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

/bin/echo "*****  AssignVPPApps process:  COMPLETE  *****"

exit 0