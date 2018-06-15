#!/bin/bash

###################################################################################################
# Script Name:  jamf_verifyVPPApps.sh
# By:  Zack Thompson / Created:  6/13/2018
# Version:  0.3 / Updated:  6/14/2018 / By:  ZT
#
# Description:  Gets details on all of the VPP Apps from the JSS and checks iTunes to see if they are 32bit and exports results to a csv file
#
###################################################################################################

echo "*****  verifyVPPApps process:  START  *****"

##################################################
# Define Variables
	# Either hard code or prompt for credentials
	# jamfAPIUser="APIUsername"
	# jamfAPIPassword="APIPassword"
	jamfAPIUser=$(/usr/bin/osascript -e 'set userInput to the text returned of (display dialog "Enter your Jamf Username:" default answer "")' 2>/dev/null)
	jamfAPIPassword=$(/usr/bin/osascript -e 'set userInput to the text returned of (display dialog "Enter your Jamf Password:" default answer "" with hidden answer)' 2>/dev/null)

	jamfPS="https://newjss.company.com:8443"
	mobileApps="${jamfPS}/JSSResource/mobiledeviceapplications"
	mobileAppsByID="${mobileApps}/id"
	# Add -k (--insecure) to disable SSL verification
	curlJamfAPI=(--silent --show-error --fail --user "${jamfAPIUser}:${jamfAPIPassword}" --write-out "statusCode:%{http_code}" --output - --header "Content-Type: application/xml" --request)

	iTunesAPI="https://uclient-api.itunes.apple.com/WebObjects/MZStorePlatform.woa/wa/lookup?version=1&p=mdm-lockup&caller=MDM&platform=itunes&cc=us&l=en&id="
	curliTunesAPI=(--silent --show-error --fail --write-out "statusCode:%{http_code}" --output - --header "Accept: application/JSON" --request)

	# Either use CLI arguments or prompt for choice
	if [[ "${4}" == "Jamf" ]]; then
		action=$(/usr/bin/osascript -e 'tell application (path to frontmost application as text)' -e 'set availableActions to {"Get VPP Apps", "Assign VPP Apps"}' -e 'set Action to choose from list availableActions with prompt "Select action:" default items {"Get VPP Apps"}' -e 'end tell' 2>/dev/null)
		ranBy="Jamf"
	else
		action="${1}"
		switch1="${2}"
		ranBy="CLI"
	fi

##################################################
# Setup Functions

getHelp() {
	echo "
usage:  jamf_verifyVPPApps.sh [-run | -r] [/path/to/file.csv] [-help]

Info:	Gets details on all of the VPP Apps from the JSS and checks iTunes to see if they are 32bit and exports results to a csv file.

Actions:
	-run | -r	Run the report and output to a csv file.
			Example:  jamf_verifyVPPApps.sh -run output.csv

	-help		Displays this help section.
			Example:  jamf_verifyVPPApps.sh -help
"
}

getAppInfo() {
	echo "Requesting list of all App IDs..."
	# GET list of App IDs from the JSS.
	curlReturn="$(/usr/bin/curl "${curlJamfAPI[@]}" GET $mobileApps)"
	
	# Check if the API call was successful or not.
	curlCode=$(echo "${curlReturn}" | /usr/bin/awk -F statusCode: '{print $2}' | /usr/bin/xargs )
	
	# Regex down to just the ID numbers
	appIDs=$(echo "${curlReturn}" | /usr/bin/sed -e 's/statusCode\:.*//g' | /usr/bin/xmllint --format - | /usr/bin/xpath /mobile_device_applications/mobile_device_application/id 2>/dev/null | LANG=C /usr/bin/sed -e 's/<[^/>]*>//g' | LANG=C /usr/bin/sed -e 's/<[^>]*>/\'$'\n/g')

	informBy "Getting info for each App from the JSS..."

	# For Each ID, get additional information.
	for appID in $appIDs; do

		# Get each info for each AppID
		curlReturn="$(/usr/bin/curl "${curlJamfAPI[@]}" GET ${mobileAppsByID}/${appID}/subset/General)"

		# Check if the API call was successful or not.
		curlCode=$(echo "${curlReturn}" | /usr/bin/awk -F statusCode: '{print $2}' | /usr/bin/xargs )
		checkStatusCode $curlCode $appID

		# Regex down to the info we want.
		appInfo="$(echo "${curlReturn}" | /usr/bin/sed -e 's/statusCode\:.*//g' | /usr/bin/xmllint --format - | /usr/bin/xpath '/mobile_device_application/general/id | /mobile_device_application/general/name | /mobile_device_application/general/site/name | /mobile_device_application/general/bundle_id | /mobile_device_application/general/itunes_store_url' 2>/dev/null | LANG=C /usr/bin/sed -e 's/<[^/>]*>//g' | LANG=C /usr/bin/sed -e 's/<[^>]*>/\'$'\t/g' | LANG=C /usr/bin/sed -e 's/\'$'\t[^\t]*$//')"

		# Read in the App Info and assign to variables
		while IFS=$'\t' read appID appName bundle_id itunes_store_url appSite; do

			# Get the Adam ID which is needed for the iTunes API
			appAdamID=$(echo "${itunes_store_url}" | /usr/bin/sed -e 's/.*\/id\(.*\)?.*/\1/')

			# Get App info from iTunes
			iTunesCurlReturn="$(/usr/bin/curl "${curliTunesAPI[@]}" GET ${iTunesAPI}${appAdamID})"

			# Check if the API call was successful or not.
			curlCode=$(echo "${iTunesCurlReturn}" | /usr/bin/awk -F statusCode: '{print $2}' | /usr/bin/xargs )
			checkStatusCode $curlCode $appID "iTunes" $appAdamID

			# echo "AppID:  ${appID}  AdamID:  ${appAdamID}"
			# Check if the App still exists on iTunes
			appExists=$(echo "${iTunesCurlReturn}" | /usr/bin/sed -e 's/statusCode\:.*//g' | /usr/bin/python -c "
import sys, json

objects = json.load(sys.stdin)

if not objects.get('results'):
    print('No')
else:
    print('Yes')")

			# echo "App Exists:  ${appExists}"

			# Extract if the App is 32bit Only			
			bitness32=$(echo "${iTunesCurlReturn}" | /usr/bin/sed -e 's/statusCode\:.*//g' | /usr/bin/python -mjson.tool | /usr/bin/awk -F "is32bitOnly\": " '{print $2}' | /usr/bin/xargs | /usr/bin/sed 's/,//')

			# Output to File
			echo -e "${appInfo}\t${appExists}\t${bitness32}" >> "${outFile}"

			# Clear variable for next loop item
			unset appInfo

		done < <(/usr/bin/printf '%s\n' "${appInfo}")
	done

	informBy "List has been saved to:  ${outFile}"
}

checkStatusCode() {
	if [[ $1 != "200" ]]; then
		informBy "ERROR:  API call failed for ${2} with error:  ${1}!"
		
		if [[ $3 == "iTunes" ]]; then
			informBy "AdamID is:  ${4}"
		fi
	fi
}

fileExists() {
	if [[ ! -e "${1}" && $2 == "create" ]]; then
		echo "Creating output file at location:  ${1}"
		/usr/bin/touch "${1}"

		echo "Adding header to output file..."
		header="App ID\tApp Name\tBundle ID\tiTunes Store URL\tJamf Site\tAvailable\t32Bit"
		echo -e $header >> "${outFile}"
	elif  [[ ! -e "${1}" && $2 == "trip" ]]; then
		informBy "ERROR:  Unable to find the input file!"
		echo "*****  verifyVPPApps process:  FAILED  *****"
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
		echo "*****  verifyVPPApps process:  FAILED  *****"
		exit 2
	fi

	echo "API Credentials Valid -- continuing..."
fi

# Perform the request action.
case $action in
	--run | -r )
		if [[ -n "${switch1}" ]]; then
			outFile="${switch1}"
			# Function fileExists
				fileExists "${outFile}" create
			# Function getAppInfo
				getAppInfo
		else
			outFile=$(/usr/bin/osascript -e 'tell application (path to frontmost application as text)' -e 'return POSIX path of (choose file name with prompt "Provide a file name and location to save the configuration file:")' -e 'end tell' 2>/dev/null)
			# Function fileExists
				fileExists "${outFile}" create
			# Function getAppInfo
				getAppInfo
		fi
	;;
	-help | -h | * )
		# Function getHelp
		getHelp
	;;
esac

informBy "Script successfully completed!"
echo "*****  verifyVPPApps process:  COMPLETE  *****"
exit 0