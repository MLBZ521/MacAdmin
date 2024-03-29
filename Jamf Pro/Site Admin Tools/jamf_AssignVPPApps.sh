#!/bin/bash

###################################################################################################
# Script Name:  jamf_AssignVPPApps.sh
# By:  Zack Thompson / Created:  2/16/2018
# Version:  1.1.1 / Updated:  11/29/2021 / By:  ZT
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
	jamfAPIUser=$( /usr/bin/osascript 2>/dev/null << EndOfScript
		tell application "System Events" 
			activate
			set userInput to the text returned of ¬
			( display dialog "Enter your Site Admin Username:" ¬
			default answer "" )
		end tell
EndOfScript
	)
	jamfAPIPassword=$( /usr/bin/osascript 2>/dev/null << EndOfScript
		tell application "System Events" 
			activate
			set userInput to the text returned of ¬
			( display dialog "Enter your Site Admin Password:" ¬
			default answer "" ¬
			with hidden answer )
		end tell
EndOfScript
	)

	jamfPS=$( /usr/bin/defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url | /usr/bin/awk -F "/$" '{print $1}' )
	mobileApps="${jamfPS}/JSSResource/mobiledeviceapplications"
	mobileAppsByID="${mobileApps}/id"
	# Add -k (--insecure) to disable SSL verification
	curlAPI=(--silent --show-error --fail --user "${jamfAPIUser}:${jamfAPIPassword}" --write-out "statusCode:%{http_code}" --output - --header "Content-Type: application/xml" --request)

	# Either use CLI arguments or prompt for choice
	if [[ "${4}" == "Jamf" ]]; then
		actions="Get VPP Apps
		Assign VPP Apps"
		action=$( /usr/bin/osascript 2>/dev/null << EndOfScript
			tell application "System Events" 
				activate
				choose from list every paragraph of "${actions}" ¬
				with title "Assign VPP Apps" ¬
				with prompt "Select action:" ¬
				default items {"Get VPP Apps"}
			end tell
EndOfScript
		)
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

xpath_tool() {

	if [[ $( /usr/bin/sw_vers -buildVersion ) > "20A" ]]; then

		/usr/bin/xpath -e "$@"

	else

		/usr/bin/xpath "$@"

	fi

}

# Build a list of Mobile Device Apps from the JSS.
getApps() {
	echo "Requesting list of all App IDs..."
	# GET list of App IDs from the JSS.
	curlReturn="$(/usr/bin/curl "${curlAPI[@]}" GET $mobileApps)"
	
	# Check if the API call was successful or not.
	curlCode=$(echo "$curlReturn" | /usr/bin/awk -F statusCode: '{print $2}')
	if [[ $curlCode != "200" ]]; then
		informBy "ERROR:  API call failed with error:  ${curlCode}!"
		echo "*****  AssignVPPApps process:  FAILED  *****"
		exit 4
	fi
	
	# Regex down to just the ID numbers
	appIDs=$(echo "$curlReturn" | /usr/bin/sed -e 's/statusCode\:.*//g' | /usr/bin/xmllint --format - | xpath_tool /mobile_device_applications/mobile_device_application/id 2>/dev/null | LANG=C /usr/bin/sed -e 's/<[^/>]*>//g' | LANG=C /usr/bin/sed -e 's/<[^>]*>/\'$'\n/g')
	
	echo "Adding header to output file..."
	header="App ID\tApp Name\tAuto Deploy\tRemove App\tTake Over\tApp Site\tScope to Group"
	echo -e $header >> "${outFile}"

	informBy "Requesting info for each App..."
	# For Each ID, get additional information.
	for appID in $appIDs; do
		curlReturn="$(/usr/bin/curl "${curlAPI[@]}" GET ${mobileAppsByID}/${appID}/subset/General)"

		# Check if the API call was successful or not.
		curlCode=$(echo "$curlReturn" | /usr/bin/awk -F statusCode: '{print $2}')
		checkStatusCode $curlCode $appID

		# Regex down to the info we want and output to a tab delimited file
		echo "$curlReturn" | /usr/bin/sed -e 's/statusCode\:.*//g' | /usr/bin/xmllint --format - | xpath_tool '/mobile_device_application/general/id | /mobile_device_application/general/name | /mobile_device_application/general/site/name | /mobile_device_application/general/deploy_automatically | /mobile_device_application/general/remove_app_when_mdm_profile_is_removed | /mobile_device_application/general/take_over_management' 2>/dev/null | LANG=C /usr/bin/sed -e 's/<[^/>]*>//g' | LANG=C /usr/bin/sed -e 's/<[^>]*>/\'$'\t/g' | LANG=C /usr/bin/sed -e 's/\'$'\t[^\t]*$//' >> "${outFile}"
	done

	informBy "List has been saved to:  ${outFile}"
}

# Read in the App IDs and configuration parameters and the Group Name to assign to each.
assignApps() {
	echo "Scoping Apps to Groups..."

	# Read in the file and assign to variables
	while IFS=$'\t' read appID appName autoDeploy removeApp takeOver appSite scopeGroup; do

		# PUT changes to the JSS.
		curlReturn="$(/usr/bin/curl "${curlAPI[@]}" PUT ${mobileAppsByID}/${appID} --data "<mobile_device_application>
<general>
<deploy_automatically>$autoDeploy</deploy_automatically>
<remove_app_when_mdm_profile_is_removed>$removeApp</remove_app_when_mdm_profile_is_removed>
<take_over_management>$takeOver</take_over_management>
</general>
<scope>
<mobile_device_groups>
<mobile_device_group>
<name>$scopeGroup</name>
</mobile_device_group>
</mobile_device_groups>
</scope>
</mobile_device_application>")"

		# Check if the API call was successful or not.
		curlCode=$(echo "$curlReturn" | /usr/bin/awk -F statusCode: '{print $2}')
		checkStatusCode $curlCode $appID

	done < <(/usr/bin/tail -n +2 "${inputFile}") # Essentially, skip the header line.
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
		echo "*****  AssignVPPApps process:  FAILED  *****"
		exit 3
	fi
}

informBy() {
	case $ranBy in
		Jamf )
			/usr/bin/osascript >/dev/null << EndOfScript
			tell application "System Events" 
				activate
				display dialog "${1}" ¬
				buttons {"OK"} default button 1 ¬
			end tell
EndOfScript
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
		echo "*****  AssignVPPApps process:  FAILED  *****"
		exit 2
	fi

	echo "API Credentials Valid -- continuing..."
fi

case $action in
	--get | -g | "Get VPP Apps" )
		if [[ -n "${switch1}" ]]; then
			outFile="${switch1}"
			# Function getApps
				getApps
		else
			outFile=$( /usr/bin/osascript 2>/dev/null << EndOfScript
				tell application "System Events" 
					activate
					return POSIX path of ¬
					( choose file name ¬
					with prompt "Provide a file name and location to save the configuration file:" )
				end tell
EndOfScript
			)
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
			inputFile=$( /usr/bin/osascript 2>/dev/null << EndOfScript
				tell application "System Events" 
					activate
					return POSIX path of ¬
					( choose file ¬
					with prompt "Select configuration file to process:" of type {"txt"} )
				end tell
EndOfScript
			)
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

informBy "Script successfully completed!"
echo "*****  AssignVPPApps process:  COMPLETE  *****"
exit 0