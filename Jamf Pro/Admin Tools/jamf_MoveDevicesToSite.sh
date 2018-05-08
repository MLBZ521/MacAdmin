#!/bin/bash

###################################################################################################
# Script Name:  jamf_MoveDevicesToSite.sh
# By:  Zack Thompson / Created: 4/19/2018
# Version:  0.6 / Updated:  5/8/2018 / By:  ZT
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

actions() {
	case "${1}" in
		"Input" )
			# Prompt to enter Device ID
			devices=$(/usr/bin/osascript -e 'set userInput to the text returned of (display dialog "Enter Device IDs (comma separated):" default answer "")')

			# Function canceled
			canceled "${devices}" "No devices were entered."

			# Split IDs into an array
			IFS=', ' read -a deviceIDs <<< "${devices}"
		;;
		"File" )
			# Prompt for csv file of IDs
			listLocation=$(/usr/bin/osascript -e 'tell application (path to frontmost application as text)' -e 'return POSIX path of(choose file with prompt "Select file:" of type {"csv", "txt"})' -e 'end tell')

			# Function canceled
			canceled "${listLocation}" "No file selection was made."

			# Read in the file and assign to an array
			while IFS=, read -a deviceID; do
				deviceIDs+=("${deviceID}")
			done < <(/bin/cat "${listLocation}")
		;;
		"Computer" )
			# Function getComputers
			getComputers
		;;
		"Mobile Device" )
			# Function getMobileDevice
			getMobileDevice
		;;
		"SelectSite" )
			# Set the osascript parameters and prompt User for Printer Selection.
			promptForChoice="tell application (path to frontmost application as text) to choose from list every paragraph of \"$siteNames\" with prompt \"Choose Site to move device(s) too:\" OK button name \"Select\" cancel button name \"Cancel\""
			selectedSiteName=$(osascript -e "$promptForChoice")

			# Function canceled
			canceled $selectedSiteName "No Site selection was made."

			echo "Site selected:  ${selectedSiteName}"
		;;
	esac
}

getSites() {
	# Create a token based on user provided credentials
	authToken=$(/usr/bin/curl --silent --show-error --fail --user "${siteAdminUser}:${siteAdminPassword}" --output - --header "Accept: application/json" --request POST ${apiGetToken} | python -c "import sys,json; print json.load(sys.stdin)['token']")

	echo "Getting a list of Sites..."
	# GET All User Details
	allDetails=$(/usr/bin/curl --silent --show-error --fail --output - --header "Content-Type: application/json" --header "Authorization: jamf-token ${authToken}" --request GET ${apiGetDetails})

	# Get a list of all the Site IDs that the Site Admin has Enroll Permissions too
	siteIDs=$(/usr/bin/printf "${allDetails}" | python -c '
import sys, json

objects = json.load(sys.stdin)

for key in objects["accountGroups"]:
    for privilege in key["privileges"]:
        if privilege == "Enroll Computers and Mobile Devices":
            print(key["siteId"])')

# For each Site ID, get the Site Name
	for siteID in $siteIDs; do
		siteName=$(/usr/bin/printf "${allDetails}" | python -c "
import sys, json

objects = json.load(sys.stdin)

for key in objects['sites']:
    if key['id'] == ${siteID}:
        print(key['name'])")

		siteNames+=$"${siteName}\n"
	done

	# Drop the final \n (newline).
	siteNames=$(echo -e ${siteNames} | /usr/bin/perl -pe 'chomp if eof')
}

getComputers() {
	echo "Reading in device IDs..."

	# Read in the file and assign to variables
	while IFS=, read deviceID; do

		# PUT changes to the JSS.
		curlReturn="$(/usr/bin/curl "${curlAPI[@]}" GET ${computersbyID}/${deviceID})"

		# Check if the API call was successful or not.
		curlCode=$(echo "$curlReturn" | /usr/bin/awk -F statusCode: '{print $2}')
		checkStatusCode $curlCode $deviceID

		# Regex to get the Site
		currentSite=$(echo "$curlReturn" | /usr/bin/sed -e 's/statusCode\:.*//g' | /usr/bin/xmllint --format - | /usr/bin/xpath /computer/site/name 2>/dev/null | LANG=C /usr/bin/sed -e 's/<[^/>]*>//g' | LANG=C /usr/bin/sed -e 's/<[^>]*>/\'$'\n/g')

		if [[ "${currentSite}" != "${selectedSiteName}" ]]; then
			echo "Reassigning device:  ${deviceID}  to:  ${selectedSiteName}"

			# PUT changes to the JSS.
			curlReturn="$(/usr/bin/curl "${curlAPI[@]}" PUT ${computersbyID}/${deviceID} --data "<computer><site><name>$selectedSiteName</name></site></computer>")"

			# Check if the API call was successful or not.
			curlCode=$(echo "$curlReturn" | /usr/bin/awk -F statusCode: '{print $2}')
			checkStatusCode $curlCode $deviceID
		fi

	done < <(echo "${devices}")
}

getMobileDevice() {
	echo "Reading in device IDs..."

	# Read in the file and assign to variables
	while IFS=, read deviceID; do

		# PUT changes to the JSS.
		curlReturn="$(/usr/bin/curl "${curlAPI[@]}" GET ${mobileDevicesByID}/${deviceID})"

		# Check if the API call was successful or not.
		curlCode=$(echo "$curlReturn" | /usr/bin/awk -F statusCode: '{print $2}')
		checkStatusCode $curlCode $deviceID

		# Regex to get the Site
		currentSite=$(echo "$curlReturn" | /usr/bin/sed -e 's/statusCode\:.*//g' | /usr/bin/xmllint --format - | /usr/bin/xpath /mobileDevice/site/name 2>/dev/null | LANG=C /usr/bin/sed -e 's/<[^/>]*>//g' | LANG=C /usr/bin/sed -e 's/<[^>]*>/\'$'\n/g')

		if [[ "${currentSite}" != "${selectedSiteName}" ]]; then
			echo "Reassigning device:  ${deviceID}  to:  ${selectedSiteName}"

			# PUT changes to the JSS.
			curlReturn="$(/usr/bin/curl "${curlAPI[@]}" PUT ${mobileDevicesByID}/${deviceID} --data "<mobileDevice><site><name>$selectedSiteName</name></site></mobileDevice>")"

			# Check if the API call was successful or not.
			curlCode=$(echo "$curlReturn" | /usr/bin/awk -F statusCode: '{print $2}')
			checkStatusCode $curlCode $deviceID
		fi

	done < <(echo "${devices}")
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

canceled() {
	# Handle if the user selects the cancel button.
	if [[ "${1}" == "false" || "${1}" == "" ]]; then
		inform "Script canceled!"
		echo "${2}"
		echo "*****  MoveDevicesToSite process:  COMPLETE  *****"
		exit 0
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

# Function getSites
getSites

# Either prompt to move another device or complete script.
until [[ "${moveAnother}" == "button returned:No" ]]; do

	# Clear the variable, in case we're rerunning the process.
	unset deviceIDs

	# Find out what device type we want to do move.
	deviceType=$(/usr/bin/osascript -e 'tell application (path to frontmost application as text) to display dialog "Which device type do you want to move?" buttons {"Computer", "Mobile Device"} default button {"Computer"}' 2>/dev/null | awk -F "button returned:" '{print $2}')
	echo "Device Type selected:  ${deviceType}"

	# Function actions
	actions "SelectSite"

	# Provide File or Input Device IDs?
	methodType=$(/usr/bin/osascript -e 'tell application (path to frontmost application as text) to display dialog "How do you want to provide the Device ID(s)?" buttons {"Input", "File"} default button {"Input"}' 2>/dev/null | awk -F "button returned:" '{print $2}')
	echo "Method Type selected:  ${methodType}"

	# Function actions
	actions "${methodType}"

	# Function actions
	actions "${deviceType}"

	# Prompt if we want to move another device.
	moveAnother=$(/usr/bin/osascript -e 'tell application (path to frontmost application as text) to display dialog "Do you want to move another device?" buttons {"Yes", "No"}')

done

inform "Script successfully completed!"
echo "*****  MoveDevicesToSite process:  COMPLETE  *****"
exit 0