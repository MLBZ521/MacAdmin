#!/bin/bash

###################################################################################################
# Script Name:  jamf_verifyVPPApps.sh
# By:  Zack Thompson / Created:  6/13/2018
# Version:  0.2 / Updated:  6/13/2018 / By:  ZT
#
# Description:  This script is used to scope groups to VPP Apps.
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
usage:  jamf_verifyVPPApps.sh [-get | -assign] [/path/to/file.txt] [-help]

Info:	Get a list of VPP Apps or assign VPP Apps to groups.

Actions:
	-get		Gets all the VPP Apps from the JSS and exports them to a txt file.
			Example:  jamf_verifyVPPApps.sh -get output.txt

	-assign		Read the provide file and assigns (scopes) VPP Apps to a Group.
			Example:  jamf_verifyVPPApps.sh -assign input.txt

	-help		Displays this help section.
			Example:  jamf_verifyVPPApps.sh -help
"
}

# Build a list of Mobile Device Apps from the JSS.
getAppInfo() {
	echo "Requesting list of all App IDs..."
	# GET list of App IDs from the JSS.
	curlReturn="$(/usr/bin/curl "${curlJamfAPI[@]}" GET $mobileApps)"
	
	# Check if the API call was successful or not.
	curlCode=$(echo "${curlReturn}" | awk -F statusCode: '{print $2}')
	if [[ $curlCode != "200" ]]; then
		informBy "ERROR:  API call failed with error:  ${curlCode}!"
		echo "*****  verifyVPPApps process:  FAILED  *****"
		exit 4
	fi
	
	# Regex down to just the ID numbers
	appIDs=$(echo "${curlReturn}" | sed -e 's/statusCode\:.*//g' | xmllint --format - | xpath /mobile_device_applications/mobile_device_application/id 2>/dev/null | LANG=C sed -e 's/<[^/>]*>//g' | LANG=C sed -e 's/<[^>]*>/\'$'\n/g')
	
	informBy "Getting info for each App from the JSS..."
	# For Each ID, get additional information.
	for appID in $appIDs; do
		curlReturn="$(/usr/bin/curl "${curlJamfAPI[@]}" GET ${mobileAppsByID}/${appID}/subset/General)"

		# Check if the API call was successful or not.
		curlCode=$(echo "${curlReturn}" | awk -F statusCode: '{print $2}')
		checkStatusCode $curlCode $appID

		# Regex down to the info we want and output to a tab delimited file
		appInfo="$(printf "${curlReturn}" | sed -e 's/statusCode\:.*//g' | xmllint --format - | xpath '/mobile_device_application/general/id | /mobile_device_application/general/name | /mobile_device_application/general/site/name | /mobile_device_application/general/bundle_id | /mobile_device_application/general/itunes_store_url' 2>/dev/null | LANG=C sed -e 's/<[^/>]*>//g' | LANG=C sed -e 's/<[^>]*>/\'$'\t/g' | LANG=C sed -e 's/\'$'\t[^\t]*$//')" #>> "${outFile}"


	# Read in the file and assign to variables
	while IFS=$'\t' read appID appName bundle_id itunes_store_url appSite; do


	#printf "${#appInfo[@]}"

		printf '%s\n' "itunes_store_url:  ${itunes_store_url}"
		appAdamID=$(printf "${itunes_store_url}" | sed -e 's/.*\/id\(.*\)?.*/\1/')
		printf '%s\n' "AdamID:  ${appAdamID}"
		# 
		#echo "${iTunesAPI}/${appAdamID}"
		iTunesCurlReturn="$(/usr/bin/curl "${curliTunesAPI[@]}" GET ${iTunesAPI}${appAdamID})"

		# Check if the API call was successful or not.
		curlCode=$(printf "${iTunesCurlReturn}" | awk -F statusCode: '{print $2}')
		checkStatusCode $curlCode $appID

		printf '%s\t' "${appInfo}"
		#32bitness=$(
		printf "${iTunesCurlReturn}" | sed -e 's/statusCode\:.*//g' | python -mjson.tool | awk -F "is32bitOnly\": " '{print $2}' | xargs | sed 's/,//' #)

		unset appInfo

		# echo "Adding header to output file..."
		# header="App ID\tApp Name\tBundle ID\tiTunes Store URL\tJamf Site\t\t32Bit"
		# echo -e $header >> "${outFile}"


	done < <(printf '%s\n' "${appInfo}")

	
	done

#	informBy "List has been saved to:  ${outFile}"
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
	curlCode=$(echo "$curlReturn" | awk -F statusCode: '{print $2}')
	if [[ $curlCode != *"200"* ]]; then
		informBy "ERROR:  Invalid API credentials provided!"
		echo "*****  verifyVPPApps process:  FAILED  *****"
		exit 2
	fi

	echo "API Credentials Valid -- continuing..."
fi

getAppInfo

# case $action in
# 	--get | -g | "Get VPP Apps" )
# 		if [[ -n "${switch1}" ]]; then
# 			outFile="${switch1}"
# 			# Function getApps
# 				getApps
# 		else
# 			outFile=$(/usr/bin/osascript -e 'tell application (path to frontmost application as text)' -e 'return POSIX path of (choose file name with prompt "Provide a file name and location to save the configuration file:")' -e 'end tell' 2>/dev/null)
# 			# Function fileExists
# 				fileExists "${outFile}" create
# 			# Function getApps
# 				getApps
# 		fi
# 	;;
# 	--assign | -a | "Assign VPP Apps" )
# 		if [[ -n "${switch1}" ]]; then
# 			inputFile="${switch1}"
# 			# Function fileExists
# 				fileExists "${inputFile}" trip
# 			# Function assignApps
# 				assignApps
# 		else
# 			inputFile=$(/usr/bin/osascript -e 'tell application (path to frontmost application as text)' -e 'return POSIX path of(choose file with prompt "Select configuration file to process:" of type {"txt"})' -e 'end tell' 2>/dev/null)
# 			# Function fileExists
# 				fileExists "${inputFile}" trip
# 			# Function assignApps
# 				assignApps
# 		fi
# 	;;
# 	-help | -h | * )
# 		# Function getHelp
# 		getHelp
# 	;;
# esac

informBy "Script successfully completed!"
echo "*****  verifyVPPApps process:  COMPLETE  *****"
exit 0