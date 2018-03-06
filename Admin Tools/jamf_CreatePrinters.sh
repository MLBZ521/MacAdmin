#!/bin/bash

###################################################################################################
# Script Name:  jamf_CreatePrinters.sh
# By:  Zack Thompson / Created:  3/1/2018
# Version:  0.1 / Updated:  3/5/2018 / By:  ZT
#
# Description:  The purpose of this script is to assist Site Admins in creating Printers in Jamf without needing to use the Jamf Admin utility.
#
###################################################################################################

echo "*****  CreatePrinters process:  START  *****"

##################################################
# Either use CLI arguments or prompt for choice
	if [[ "${4}" == "Jamf" ]]; then
		ranBy="Jamf"
	else
		action="${1}"
		ranBy="CLI"

		case $action in
			-help | -h | * )
				# Function getHelp
				getHelp
			;;
		esac
	fi

# Define Variables
	# Either hard code or prompt for credentials
	# jamfAPIUser="APIUsername"
	# jamfAPIPassword="APIPassword"
	jamfAPIUser=$(/usr/bin/osascript -e 'set userInput to the text returned of (display dialog "Enter your Jamf Username:" default answer "")' 2>/dev/null)
	jamfAPIPassword=$(/usr/bin/osascript -e 'set userInput to the text returned of (display dialog "Enter your Jamf Password:" default answer "" with hidden answer)' 2>/dev/null)

	jamfPS="https://jss.company.com:8443"
	apiPrinters="${jamfPS}/JSSResource/printers/id"

	# Add -k (--insecure) to disable SSL verification
	curlAPI=(--silent --show-error --fail --user "${jamfAPIUser}:${jamfAPIPassword}" --write-out "statusCode:%{http_code}" --output - --header "Content-Type: application/xml" --request)

##################################################
# Setup Functions

getHelp() {
	echo "
usage:  jamf_CreatePrinters.sh [-help]

Info:	Finds locally installed printers, prompts for choice and then creates a new printer in the JSS using the API. 

Actions:
	-help		Displays this help section.
			Example:  jamf_CreatePrinters.sh -help
"
}

createPrinter() {

	# Set the osascript parameters and prompt User for Printer Selection
	promptForChoice="choose from list every paragraph of \"$printerNames\" with prompt \"Choose printer to create in the JSS:\" OK button name \"Select\" cancel button name \"Cancel\""
	selectedPrinterName=$(osascript -e "$promptForChoice")

	# Get the Printer ID of the selected printer.
	printerID=$(printf $selectedPrinterName | cut -c 1)

	# Get only the selected printers info.
	selectedPrinterInfo=$(printf '%s\n' "$printerInfo" | xmllint --format - | xpath "/printers/printer[$printerID]/display_name | /printers/printer[$printerID]/cups_name | /printers/printer[$printerID]/location | /printers/printer[$printerID]/device_uri | /printers/printer[$printerID]/model" 2>/dev/null | LANG=C sed -e 's/<[^/>]*>//g' | LANG=C sed -e 's/<[^>]*>/,/g')

	while IFS="," read -r printerName printerCUPsName printerLocation printerIP printerModel; do
		if [[ -e "/private/etc/cups/ppd/${printerCUPsName}.ppd" ]]; then
			printerPPDContents=$(printf "/private/etc/cups/ppd/${printerCUPsName}.ppd")
		else
			echo "Unable to locate the PPD file."
		fi

		# PUT changes to the JSS.
		curlReturn="$(/usr/bin/curl "${curlAPI[@]}" PUT ${apiPrinters} --data "<printer>
<name>$printerName</name>
<uri>$printerIP</uri>
<CUPS_name>$printerCUPsName</CUPS_name>
<location>$printerLocation</location>
<model>$printerModel</model>
<notes>Created by the jamf_CreatePrinters.sh script.</notes>
<make_default>$printerDefault</make_default>
<ppd>${printerCUPsName}.ppd</ppd>
<ppd_contents>$(cat $printerPPDContents)</ppd_contents>
<ppd_path>/Library/Printers/PPDs/Contents/Resources/${printerCUPsName}.ppd</ppd_path>
</printer>")"

		# Check if the API call was successful or not.
		curlCode=$(echo "$curlReturn" | awk -F statusCode: '{print $2}')
		checkStatusCode $curlCode $appID

	done < <(printf '%s\n' "${selectedPrinterInfo}")

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
		echo "*****  CreatePrinters process:  FAILED  *****"
		exit 2
	fi

	echo "API Credentials Valid -- continuing..."
fi

# Get a list of all printer configurations.
printerInfo=$(sudo jamf listprinters | xmllint --format - | xpath /printers 2>/dev/null)

# Get the number of printers.
numberOfPrinters=$(echo $(printf '%s\n' "$printerInfo") | xmllint --format - | xpath 'count(//printers/printer)' 2>/dev/null)

# Clear the variable, in case we're rerunning the process.
unset printerNames

# Loop through each printer to only get the printer name and add in it's printer "ID" -- node number in the xml.
for ((i=1; i<=$numberOfPrinters; ++i)); do
	printerName=$(echo $(printf '%s\n' "$printerInfo") | xmllint --format - | xpath /printers/printer[$i]/display_name 2>/dev/null| LANG=C sed -e 's/<[^/>]*>//g' | LANG=C sed -e 's/<[^>]*>/\'$'\n/g')
	printerNames+=$"${i}) ${printerName}\n"
done

# Drop the final \n (newline).
printerNames=$(echo -e ${printerNames} | perl -pe 'chomp if eof')

informBy "Script successfully completed!"
echo "*****  CreatePrinters process:  COMPLETE  *****"
exit 0