#!/bin/bash

###################################################################################################
# Script Name:  jamf_MoveDevicesToSite.sh
# By:  Zack Thompson / Created: 4/19/2018
# Version:  0.3 / Updated:  5/2/2018 / By:  ZT
#
# Description:  This script allows Site Admins to move devices between Sites that they have perms to.
#
###################################################################################################

echo "*****  MoveDevicesToSite process:  START  *****"

##################################################
# Define Variables

# JPS URL
jamfPS="https://newjss.company.com:8443"
apiGetToken="${jamfPS}/uapi/auth/tokens"
apiGetSites="${jamfPS}/uapi/auth/current"
computersbyID="${jamfPS}/JSSResource/computers/id"
mobileDevicesByID="${jamfPS}/JSSResource/mobiledevices/id"

# Jamf API User that will have permissions to move devices.
jamfAPIUser=$(DecryptString $5 'Salt' 'Passphrase')
jamfAPIPassword=$(DecryptString $6 'Salt' 'Passphrase')

# Site Admin Credentials to get which Sites they have permissions too.
siteAdminUser=$(/usr/bin/osascript -e 'set userInput to the text returned of (display dialog "Enter your Jamf Username:" default answer "")' 2>/dev/null)
siteAdminPassword=$(/usr/bin/osascript -e 'set userInput to the text returned of (display dialog "Enter your Jamf Password:" default answer "" with hidden answer)' 2>/dev/null)

# Add -k (--insecure) to disable SSL verification
curlAPI=(--silent --show-error --fail --user "${jamfAPIUser}:${jamfAPIPassword}" --write-out "statusCode:%{http_code}" --output - --header "Content-Type: application/xml" --request)

##################################################
# Setup Functions

getSites() {
	# Create a token based on user provided credentials
	authToken=$(/usr/bin/curl --silent --show-error --fail --user "${siteAdminUser}:${siteAdminPassword}" --output - --header "Accept: application/json" --request POST ${apiGetToken} | python -c "import sys,json; print json.load(sys.stdin)['token']")

	echo "Getting a list of Sites..."
	# GET list of Sites that user has permissions to.
	getSites="$(/usr/bin/curl --silent --show-error --fail --output - --header "Content-Type: application/json" --header "Authorization: jamf-token ${authToken}" --request POST ${apiGetSites} | python -c 'import sys,json; print "\n".join( [i["name"] for i in json.loads( sys.stdin.read() )["sites"]] )')"

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
			# inform " -> Request successful"
		;;
		201)
			# Turn off success notifications
			# inform "Device ID:  ${2} -> Request to create or update object successful"
		;;
		400)
			inform "${deviceType} ID:  ${2} -> Bad request. Verify the syntax of the request specifically the XML body."
		;;
		401)
			inform "${deviceType} ID:  ${2} -> Authentication failed. Verify the credentials being used for the request."
		;;
		403)
			inform "${deviceType} ID:  ${2} -> Invalid permissions. Verify the account being used has the proper permissions for the object/resource you are trying to access."
		;;
		404)
			inform "${deviceType} ID:  ${2} -> Object/resource not found. Verify the URL path is correct."
		;;
		409)
			inform "${deviceType} ID:  ${2} -> Conflict"
		;;
		500)
			inform "${deviceType} ID:  ${2} -> Internal server error. Retry the request or contact Jamf support if the error is persistent."
		;;
	esac
}

fileExists() {
	if [[ ! -e "${1}" && $2 == "create" ]]; then
		echo "Creating output file at location:  ${1}"
		/usr/bin/touch "${1}"
	elif  [[ ! -e "${1}" && $2 == "trip" ]]; then
		inform "ERROR:  Unable to find the input file!"
		echo "*****  MoveDevicesToSite process:  FAILED  *****"
		exit 3
	fi
}

inform() {
	/usr/bin/osascript -e 'tell application (path to frontmost application as text) to display dialog "'"${1}"'" buttons {"OK"}' > /dev/null
}

##################################################
# Bits Staged

# Verify credentials were provided.
if [[ -z "${siteAdminUser}" && -z "${siteAdminPassword}" ]]; then
	inform "Site Admin credentials are required!"
	exit 1
else
	# Verify credentials that were provided by doing an API call and checking the result to verify permissions.
	echo "Verifying API credentials..."
	curlReturn="$(/usr/bin/curl $jamfPS/JSSResource/jssuser -i --silent --show-error --fail --user "${siteAdminUser}:${siteAdminPassword}" --write-out "statusCode:%{http_code}")"

	# Check if the API call was successful or not.
	curlCode=$(echo "$curlReturn" | /usr/bin/awk -F statusCode: '{print $2}')
	if [[ $curlCode != *"200"* ]]; then
		inform "ERROR:  Invalid Site Admin credentials provided!"
		echo "*****  MoveDevicesToSite process:  FAILED  *****"
		exit 2
	fi

	echo "API Credentials Valid -- continuing..."
fi

# Find out what device type we want to do move.
deviceType=$(/usr/bin/osascript -e 'tell application (path to frontmost application as text)' -e 'set availableActions to {"Computer", "Mobile Device"}' -e 'set Action to choose from list availableActions with prompt "Which device type do you want to move?" default items {"Computer"}' -e 'end tell' 2>/dev/null)

# Provide list of devices or single IDs?
methodType=$(/usr/bin/osascript -e 'tell application (path to frontmost application as text)' -e 'set availableActions to {"List", "Single"}' -e 'set Action to choose from list availableActions with prompt "Do you want to move a single device or provide a list of devices?" default items {"Single"}' -e 'end tell' 2>/dev/null)

# Get device IDs
if [[ $methodType == "Single" ]]; then
	# Prompt to enter Device ID
	devices=$()
else
	# Prompt for csv file of IDs
	devices=$(/usr/bin/osascript -e 'tell application (path to frontmost application as text)' -e 'return POSIX path of(choose file with prompt "Select file:" of type {"csv", "txt"})' -e 'end tell' 2>/dev/null)
fi

# Function getSites
getSites

case $deviceType in
	"Computer" )
	;;
	"Mobile Device" )
	;;
esac

inform "Script successfully completed!"
echo "*****  MoveDevicesToSite process:  COMPLETE  *****"
exit 0