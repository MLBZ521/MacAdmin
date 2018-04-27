#!/bin/bash

###################################################################################################
# Script Name:  jamf_MoveDevicesToSite.sh
# By:  Zack Thompson / Created: 4/19/2018
# Version:  0.2 / Updated:  4/25/2018 / By:  ZT
#
# Description:  This script allows Site Admins to move devices between Sites that they have perms to.
#
###################################################################################################

echo "*****  MoveDevicesToSite process:  START  *****"

##################################################
# Define Variables
	# Either hard code or prompt for credentials
	# jamfAPIUser="APIUsername"
	# jamfAPIPassword="APIPassword"
	
	jamfPS="https://newjss.company.com:8443"
	#usersByName="${jamfPS}/JSSResource/users/name"
	apiGetToken="${jamfPS}/uapi/auth/tokens"
	apiGetSites="${jamfPS}/uapi/auth/current"
	computersbyID="${jamfPS}/JSSResource/computers/id"
	mobileDevicesByID="${jamfPS}/JSSResource/mobiledevices/id"

	# Either use CLI arguments or prompt for choice
	if [[ "${4}" == "Jamf" ]]; then
		action=$(/usr/bin/osascript -e 'tell application (path to frontmost application as text)' -e 'set availableActions to {"Computers", "Mobile Devices"}' -e 'set Action to choose from list availableActions with prompt "Which device type do you want to move?" default items {"Computers"}' -e 'end tell' 2>/dev/null)
		ranBy="Jamf"
		#siteAdmin="${3}"
		jamfAPIUser=$(DecryptString $5 'Salt' 'Passphrase')
		jamfAPIPassword=$(DecryptString $6 'Salt' 'Passphrase')
	else
		action="${1}"
		switch1="${2}"
		ranBy="CLI"
		jamfAPIUser=$(/usr/bin/osascript -e 'set userInput to the text returned of (display dialog "Enter your Jamf Username:" default answer "")' 2>/dev/null)
		jamfAPIPassword=$(/usr/bin/osascript -e 'set userInput to the text returned of (display dialog "Enter your Jamf Password:" default answer "" with hidden answer)' 2>/dev/null)
	fi

	# Add -k (--insecure) to disable SSL verification
	curlAPI=(--silent --show-error --fail --user "${jamfAPIUser}:${jamfAPIPassword}" --write-out "statusCode:%{http_code}" --output - --header "Content-Type: application/xml" --request)

##################################################
# Setup Functions

getHelp() {
	echo "
usage:  jamf_MoveDevicesToSite.sh [--computers | --mobile] [/path/to/file.txt] [--help]

Info:	Provide device ID(s) to move to another Site.

Actions:
	--computers		Gets all the VPP Apps from the JSS and exports them to a txt file.
			Example:  jamf_MoveDevicesToSite.sh --computers input.list

	--mobile		Read the provide file and assigns (scopes) VPP Apps to a Group.
			Example:  jamf_MoveDevicesToSite.sh --mobile input.list

	--help		Displays this help section.
			Example:  jamf_MoveDevicesToSite.sh -help
"
}

getSites() {
	# Create a token based on user provided credentials
	authToken=$(/usr/bin/curl --silent --show-error --fail --user "${jamfAPIUser}:${jamfAPIPassword}" --output - --header "Accept: application/json" --request POST ${apiGetToken} | python -c "import sys,json; print json.load(sys.stdin)['token']")

	echo "Getting a list of Sites..."
	# GET list of Sites that user has permissions to.
	# curlReturn="$(/usr/bin/curl "${curlAPI[@]}" GET ${usersByName}/${siteAdmin})"
	getSites="$(/usr/bin/curl --silent --show-error --fail --output - --header "Content-Type: application/json" --header "Authorization: jamf-token ${authToken}" --request POST ${apiGetSites} | python -c 'import sys,json; print "\n".join( [i["name"] for i in json.loads( sys.stdin.read() )["sites"]] )')"


	# Check if the API call was successful or not.
	# curlCode=$(echo "$curlReturn" | /usr/bin/awk -F statusCode: '{print $2}')
	# if [[ $curlCode != "200" ]]; then
	# 	informBy "ERROR:  API call failed with error:  ${curlCode}!"
	# 	echo "*****  MoveDevicesToSite process:  FAILED  *****"
	# 	exit 4
	# fi

	# Regex down to just the Site names
	# adminSites=$(echo "$curlReturn" | /usr/bin/sed -e 's/statusCode\:.*//g' | /usr/bin/xmllint --format - | /usr/bin/xpath /user/sites/site/name 2>/dev/null | LANG=C /usr/bin/sed -e 's/<[^/>]*>//g' | LANG=C /usr/bin/sed -e 's/<[^>]*>/\'$'\n/g')


	# Set the osascript parameters and prompt User for Printer Selection.
	promptForChoice="tell application (path to frontmost application as text) to choose from list every paragraph of \"$getSites\" with prompt \"Choose Site to move device(s) too:\" OK button name \"Select\" cancel button name \"Cancel\""
	selectedSiteName=$(osascript -e "$promptForChoice")

	# Handle if the user pushes the cancel button.
	if [[ $selectedSiteName == "false" ]]; then
		echo "No Site selection was made."
		createAnother="button returned:No"
		return
	fi

}

getComputers() {



}


getMobileDevice() {



}


checkStatusCode() {
	case $1 in
		200 )
			# Turn off success notifications
			# informBy " -> Request successful"
		;;
		201)
			# Turn off success notifications
			# informBy "App ID:  ${appID} -> Request to create or update object successful"
		;;
		400)
			informBy "App ID:  ${appID} -> Bad request. Verify the syntax of the request specifically the XML body."
		;;
		401)
			informBy "App ID:  ${appID} -> Authentication failed. Verify the credentials being used for the request."
		;;
		403)
			informBy "App ID:  ${appID} -> Invalid permissions. Verify the account being used has the proper permissions for the object/resource you are trying to access."
		;;
		404)
			informBy "App ID:  ${appID} -> Object/resource not found. Verify the URL path is correct."
		;;
		409)
			informBy "App ID:  ${appID} -> Conflict"
		;;
		500)
			informBy "App ID:  ${appID} -> Internal server error. Retry the request or contact Jamf support if the error is persistent."
		;;
	esac
}

fileExists() {
	if [[ ! -e "${1}" && $2 == "create" ]]; then
		echo "Creating output file at location:  ${1}"
		/usr/bin/touch "${1}"
	elif  [[ ! -e "${1}" && $2 == "trip" ]]; then
		informBy "ERROR:  Unable to find the input file!"
		echo "*****  MoveDevicesToSite process:  FAILED  *****"
		exit 3
	fi
}

informBy() {
	case $ranBy in
		Jamf )
			/usr/bin/osascript -e 'tell application (path to frontmost application as text) to display dialog "'"${1}"'" buttons {"OK"}' > /dev/null
		;;
		CLI )
			echo "${1}"
		;;
	esac
}

##################################################
# Bits Staged

# Verify credentials were provided.
if [[ -z "${jamfAPIUser}" && -z "${jamfAPIPassword}" ]]; then
	informBy "Jamf credentials are required!"
	exit 1
else
	# Verify credentials that were provided by doing an API call and checking the result to verify permissions.
	echo "Verifying API credentials..."
	curlReturn="$(/usr/bin/curl $jamfPS/JSSResource/jssuser -i --silent --show-error --fail --user "${jamfAPIUser}:${jamfAPIPassword}" --write-out "statusCode:%{http_code}")"

	# Check if the API call was successful or not.
	curlCode=$(echo "$curlReturn" | /usr/bin/awk -F statusCode: '{print $2}')
	if [[ $curlCode != *"200"* ]]; then
		informBy "ERROR:  Invalid API credentials provided!"
		echo "*****  MoveDevicesToSite process:  FAILED  *****"
		exit 2
	fi

	echo "API Credentials Valid -- continuing..."
fi

case $action in
	--computers | -c | "Computers" )
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
	--mobile | -m | "Mobile Devices" )
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
	--help | -h | * )
		# Function getHelp
		getHelp
	;;
esac

informBy "Script successfully completed!"
echo "*****  MoveDevicesToSite process:  COMPLETE  *****"
exit 0