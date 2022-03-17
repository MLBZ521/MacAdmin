#!/bin/bash

###################################################################################################
# Script Name:  Move-DevicesToSite.sh
# By:  Zack Thompson / Created: 4/19/2018
# Version:  1.3.0 / Updated:  3/17/2022 / By:  ZT
#
# Description:  This script allows Site Admins to move devices between Sites that they have perms to.
#
###################################################################################################

echo "*****  MoveDevicesToSite process:  START  *****"

##################################################
# Define Variables

# Set custom Python binary path
python_binary="/opt/ManagedFrameworks/Python.framework/Versions/Current/bin/python3"

# JPS URL
jamfPS=$( /usr/bin/defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url | /usr/bin/awk -F "/$" '{print $1}' )
apiGetToken="${jamfPS}/uapi/auth/tokens"
apiGetDetails="${jamfPS}/uapi/auth"
computersbyID="${jamfPS}/JSSResource/computers/id"
mobileDevicesByID="${jamfPS}/JSSResource/mobiledevices/id"

# Jamf API User that will have permissions to move devices.
DecryptString() {
	# Usage: ~$ DecryptString "Encrypted String" "Salt" "Passphrase"
	echo "${1}" | /usr/bin/openssl enc -aes256 -d -a -A -S "${2}" -k "${3}"
}
jamfAPIUser=$(DecryptString "${5}" "<jamfAPIUser_Salt>" "<jamfAPIUser_Passphrase>")
jamfAPIPassword=$(DecryptString "${6}" "<jamfAPIPassword_Salt>" "<jamfAPIPassword_Passphrase>")

# Site Admin Credentials to get which Sites they have permissions too.
siteAdminUser=$( /usr/bin/osascript 2>/dev/null << EndOfScript
	tell application "System Events" 
		activate
		set userInput to the text returned of ¬
		( display dialog "Enter your Site Admin Username:" ¬
		default answer "" )
	end tell
EndOfScript
)
siteAdminPassword=$( /usr/bin/osascript 2>/dev/null << EndOfScript
	tell application "System Events" 
		activate
		set userInput to the text returned of ¬
		( display dialog "Enter your Site Admin Password:" ¬
		default answer "" ¬
		with hidden answer )
	end tell
EndOfScript
)

# Add -k (--insecure) to disable SSL verification
curlAPI=(--silent --show-error --fail --user "${jamfAPIUser}:${jamfAPIPassword}" --write-out "statusCode:%{http_code}" --output - --header "Accept: application/xml" --header "Content-Type: application/xml" --request)

# Exit Value
exitCode="0"

##################################################
# Setup Functions

xpath_tool() {

	if [[ $( /usr/bin/sw_vers -buildVersion ) > "20A" ]]; then

		/usr/bin/xpath -e "$@"

	else

		/usr/bin/xpath "$@"

	fi

}

actions() {
	case "${1}" in
		"Input" )
			# Prompt to enter Device ID
			devices=$(/usr/bin/osascript << EndOfScript
				tell application "System Events" 
					activate
					set userInput to the text returned of ¬
					( display dialog "Enter Device IDs (comma separated):" ¬
					default answer "" )
				end tell
EndOfScript
			)

			# Function canceled
			canceled "${devices}" "No devices were entered."

			# Split IDs into an array
			IFS=', ' read -a deviceIDs <<< "${devices}"
		;;
		"File" )
			# Prompt for csv file of IDs
			listLocation=$(/usr/bin/osascript << EndOfScript
				tell application "System Events" 
					activate
					return POSIX path of ¬
					( choose file ¬
					with prompt "Select file:" of type {"csv", "txt"} )
				end tell
EndOfScript
			)

			# Function canceled
			canceled "${listLocation}" "No file selection was made."

			# Read in the file and assign to an array
			while IFS=, read -a deviceID; do
				deviceIDs+=("${deviceID}")
			done < <(/bin/cat "${listLocation}")
		;;
		"Computer" )
			# Function getDevices
			getDevices $computersbyID computer
		;;
		"Mobile Device" )
			# Function getDevices
			getDevices $mobileDevicesByID mobile_device
		;;
		"SelectSite" )
			# Prompt User for Site Selection
			selectedSiteName=$( /usr/bin/osascript << EndOfScript
				tell application "System Events" 
					activate
					choose from list every paragraph of "${siteNames}" ¬
					with title "Select Site" ¬
					with prompt "Choose Site to move device(s) too:" ¬
					OK button name "Select" ¬
					cancel button name "Cancel"
				end tell
EndOfScript
			)

			# Function canceled
			canceled $selectedSiteName "No Site selection was made."

			echo "Site selected:  ${selectedSiteName}"
		;;
	esac
}

getSites() {
	# Create a token based on user provided credentials
	authToken=$(/usr/bin/curl --silent --show-error --fail --user "${siteAdminUser}:${siteAdminPassword}" --output - --header "Accept: application/json" --request POST ${apiGetToken} | "${python_binary}" -c "import sys,json; print json.load(sys.stdin)['token']")

	echo "Getting a list of Sites..."
	# GET All User Details
	allDetails=$(/usr/bin/curl --silent --show-error --fail --output - --header "Accept: application/json" --header "Authorization: jamf-token ${authToken}" --request GET ${apiGetDetails})

	# Get a list of all the Site IDs that the Site Admin has Enroll Permissions too
	siteIDs=$(echo "${allDetails}" | "${python_binary}" -c '
import sys, json

objects = json.load(sys.stdin)

for key in objects["accountGroups"]:
    for privilege in key["privileges"]:
        if privilege == "Enroll Computers and Mobile Devices":
            print(key["siteId"])')

# For each Site ID, get the Site Name
	for siteID in $siteIDs; do
		siteName=$(echo "${allDetails}" | "${python_binary}" -c "
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

getDevices() {
	echo "Reading in ${deviceType} IDs..."

	# Read in the file and assign to variables
	while IFS=, read -a deviceID; do

		# PUT changes to the JSS.
		curlReturn="$(/usr/bin/curl "${curlAPI[@]}" GET ${1}/${deviceID})"

		# Check if the API call was successful or not.
		curlCode=$(echo "$curlReturn" | /usr/bin/awk -F statusCode: '{print $2}')
		checkStatusCode $curlCode $deviceID

		# Verify the Device exists
		if [[ $curlCode != *"200"* ]]; then
			continue
		fi

		# Regex to get the Site
		currentSite=$(echo "$curlReturn" | /usr/bin/sed -e 's/statusCode\:.*//g' | /usr/bin/xmllint --format - | xpath_tool /$2/general/site/name 2>/dev/null | LANG=C /usr/bin/sed -e 's/<[^/>]*>//g' | LANG=C /usr/bin/sed -e 's/<[^>]*>/\'$'\n/g')
		echo "${deviceType} ID ${deviceID} is in the ${currentSite} Site."

		# Verify device is from a site that the Site Admin has permissions too.
		if [[ $(printf '%s\n' ${siteNames[@]} | /usr/bin/grep -Eo "^(${currentSite})$") != "${currentSite}" ]]; then
			checkStatusCode "SiteError" $deviceID $currentSite
			continue
		fi

		# If the Current Site isn't the new Site, move it.
		if [[ "${currentSite}" != "${selectedSiteName}" ]]; then
			echo "Reassigning ${deviceType} ID ${deviceID} to ${selectedSiteName}"

			# PUT changes to the JSS.
			curlReturn="$(/usr/bin/curl "${curlAPI[@]}" PUT ${1}/${deviceID} --data "<$2><general><site><name>${selectedSiteName}</name></site></general></$2>")"

			# Check if the API call was successful or not.
			curlCode=$(echo "$curlReturn" | /usr/bin/awk -F statusCode: '{print $2}')
			checkStatusCode $curlCode $deviceID
		fi

	done < <(/usr/bin/printf '%s\n' "${deviceIDs[@]}")
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
			echo "${deviceType} ID:  ${2}  -> Successfully moved to ${selectedSiteName}."
		;;
		400)
			inform "${deviceType} ID:  ${2} -> Something went wrong!"
			echo "${deviceType} ID:  ${2}  Error 400 -> Bad request. Verify the syntax of the request specifically the XML body."
		;;
		401)
			inform "${deviceType} ID:  ${2} -> Authentication failed."
			echo "${deviceType} ID:  ${2}  Error 401 -> Authentication failed.  Verify the credentials being used for the request."
		;;
		403)
			inform "${deviceType} ID:  ${2} -> Invalid permissions"
			echo "${deviceType} ID:  ${2}  Error 403 -> Invalid permissions. Verify the account being used has the proper permissions for the object/resource you are trying to access."
		;;
		404)
			inform "${deviceType} ID:  ${2} -> Object/resource not found. Verify the Device ID exists!"
			echo "${deviceType} ID:  ${2}  Error 404 -> Object/resource not found. Verify the URL path is correct."
		;;
		409)
			inform "${deviceType} ID:  ${2} -> Conflict"
			echo "${deviceType} ID:  ${2}  Error 409 -> Conflict"
		;;
		500)
			inform "${deviceType} ID:  ${2} -> Internal server error. Retry the request and contact SSM support if the error is persistent."
			echo "${deviceType} ID:  ${2}  Error 403 -> Internal server error. Retry the request or contact Jamf support if the error is persistent."
		;;
		"SiteError" )
			inform "${deviceType} ID:  ${2} -> Error:  This device is not in a site you have enroll permissions too."
			echo "ERROR:  ${siteAdminUser} tried to move ${deviceType} ID ${2} from ${3}."
			exitCode="3"
		;;
	esac
}

canceled() {
	# Handle if the user selects the cancel button.
	if [[ "${1}" == "false" || "${1}" == "" ]]; then
		inform "Script canceled!"
		echo "${2}"
		echo "*****  MoveDevicesToSite process:  COMPLETE  *****"
		exit $exitCode
	fi
}

inform() {
	/usr/bin/osascript >/dev/null << EndOfScript
		tell application "System Events" 
			activate
			display dialog "${1}" ¬
			buttons {"OK"} default button 1 ¬
		end tell
EndOfScript
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
	deviceTypeAnswer=$( /usr/bin/osascript 2>/dev/null << EndOfScript
		tell application "System Events" 
			activate
			display dialog "Which device type do you want to move?" ¬
			with title "Select Device Type" ¬
			buttons {"Computer", "Mobile Device"} default button {"Computer"}
		end tell
EndOfScript
)
	deviceType=$( echo "${deviceTypeAnswer}" | /usr/bin/awk -F "button returned:" '{print $2}' )
	echo "Device Type selected:  ${deviceType}"

	# Function actions
	actions "SelectSite"

	# Provide File or Input Device IDs?
	methodTypeAnswer=$( /usr/bin/osascript 2>/dev/null << EndOfScript
		tell application "System Events" 
			activate
			display dialog "How do you want to provide the Jamf Pro ${deviceType} ID(s)?" ¬
			with title "Select Method" ¬
			buttons {"Input", "File"} default button {"Input"}
		end tell
EndOfScript
)
	methodType=$( echo "${methodTypeAnswer}" | /usr/bin/awk -F "button returned:" '{print $2}' )
	echo "Method Type selected:  ${methodType}"

	# Function actions
	actions "${methodType}"

	# Function actions
	actions "${deviceType}"

	# Prompt if we want to move another device.
	moveAnother=$( /usr/bin/osascript << EndOfScript
		tell application "System Events" 
			activate
			display dialog "Do you want to move another device?" ¬
			with title "Perform another move?" ¬
			buttons {"Yes", "No"}
		end tell
EndOfScript
	)

done

inform "Script successfully completed!"
echo "*****  MoveDevicesToSite process:  COMPLETE  *****"
exit $exitCode