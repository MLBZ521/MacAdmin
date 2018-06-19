#!/bin/bash

###################################################################################################
# Script Name:  jamf_CreatePrinters.sh
# By:  Zack Thompson / Created:  3/1/2018
# Version:  1.5.2 / Updated:  6/18/2018 / By:  ZT
#
# Description:  The purpose of this script is to assist Site Admins in creating Printers in Jamf without needing to use the Jamf Admin utility.
#
###################################################################################################

echo "*****  CreatePrinters process:  START  *****"

##################################################
# Define Variables
	jamfPS="https://jss.company.com:8443"
	apiPrinters="${jamfPS}/JSSResource/printers/id"

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
	exit 0
}

DecryptString() {
	# Usage: ~$ DecryptString "Encrypted String" "Salt" "Passphrase"
	echo "${1}" | /usr/bin/openssl enc -aes256 -d -a -A -S "${2}" -k "${3}"
}

createPrinter() {

	# Set the osascript parameters and prompt User for Printer Selection.
	promptForChoice="tell application (path to frontmost application as text) to choose from list every paragraph of \"$printerNames\" with prompt \"Choose printer to create in the JSS:\" OK button name \"Select\" cancel button name \"Cancel\""
	selectedPrinterName=$(osascript -e "$promptForChoice")

	# Handle if the user pushes the cancel button.
	if [[ $selectedPrinterName == "false" ]]; then
		echo "No printer selection was made."
		createAnother="button returned:No"
		return
	fi

	# Get the Printer ID of the selected printer.
	printerID=$(/usr/bin/printf "${selectedPrinterName}" | cut -c 1)

	# Get only the selected printers info.
	selectedPrinterInfo=$(/usr/bin/printf '%s\n' "$printerInfo" | /usr/bin/xmllint --format - | /usr/bin/xpath "/printers/printer[$printerID]/display_name | /printers/printer[$printerID]/cups_name | /printers/printer[$printerID]/location | /printers/printer[$printerID]/device_uri | /printers/printer[$printerID]/model" 2>/dev/null | LANG=C /usr/bin/sed -e 's/<[^/>]*>//g' | LANG=C /usr/bin/sed -e 's/<[^>]*>/\'$'\n/g')

	# Define array to hold the printer info 
	printerSettings=()

	# Read the printer info into the array.
	while IFS=$'\n' read -r printerSetting; do
		printerSettings+=("${printerSetting}")
	done < <(/usr/bin/printf '%s\n' "${selectedPrinterInfo}")

	# Set the expected PPD File.
	printerPPDFile=$(/usr/bin/printf "/private/etc/cups/ppd/${printerSettings[1]}.ppd")

	# Verify the PPD file exists and get it's contents
	if [[ -e "${printerPPDFile}" ]]; then
		printerPPDContents=$(/bin/cat "${printerPPDFile}" | /usr/bin/sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g' )
	else
		informBy "Error:  Unable to locate the PPD file -- unable to create the printer."
		echo "Error:  Unable to locate the PPD file -- unable to create the printer."
		return
	fi

	echo " "
	echo "*****  Selected Printer Configuration  *****"
	echo " "
	echo "Display Name:  ${printerSettings[0]}"
	echo "CUPS Name:  ${printerSettings[1]}"
	echo "Location:  ${printerSettings[2]}"
	echo "IP Address:  ${printerSettings[3]}"
	echo "Driver Model:  ${printerSettings[4]}"
	echo "PPD File:  ${printerPPDFile}"
	echo " "

		# POST changes to the JSS.
		curlReturn="$(/usr/bin/curl "${curlAPI[@]}" POST ${apiPrinters}/0 --data @- <<printerConfig
<printer>
<name>${printerSettings[0]}</name>
<category>Printers</category>
<uri>${printerSettings[3]}</uri>
<CUPS_name>${printerSettings[1]}</CUPS_name>
<location>${printerSettings[2]}</location>
<model>${printerSettings[4]}</model>
<notes>Created by ${createdByUser} running the jamf_CreatePrinters.sh script.</notes>
<ppd>${printerSettings[1]}.ppd</ppd>
<ppd_contents>${printerPPDContents}</ppd_contents>
<ppd_path>/Library/Printers/PPDs/Contents/Resources/${printerSettings[1]}.ppd</ppd_path>
</printer>
printerConfig)"

		# Get the Exit Code
		exitCode=$?

		if [[ $exitCode != 0 ]]; then
			informBy "API Request Failed!"
			echo "ERROR:  curl failed!"
			echo "Exit Code:  ${exitCode}"
		fi

		# Check if the API call was successful or not.
		curlCode=$(echo "$curlReturn" | /usr/bin/awk -F statusCode: '{print $2}')
		echo "Curl Status Code is:  ${curlCode}"
		checkStatusCode $curlCode

		# Prompt if we want to create another printer.
		createAnother=$(/usr/bin/osascript -e 'tell application (path to frontmost application as text) to display dialog "Do you want to create another printer?" buttons {"Yes", "No"}')
}

checkStatusCode() {
	case $1 in
		200 )
			# Request successful
			informBy "Printer created successfully!"
		;;
		201)
			informBy "Request to create or update object successful"
		;;
		400)
			informBy "Bad request. Verify the syntax of the request specifically the XML body."
		;;
		401)
			informBy "Authentication failed. Verify the credentials being used for the request."
		;;
		403)
			informBy "Invalid permissions. Verify the account being used has the proper permissions for the object/resource you are trying to access."
		;;
		404)
			informBy "Object/resource not found. Verify the URL path is correct."
		;;
		409)
			informBy "Conflict!  A resource by this printer name likely already exists."
		;;
		500)
			informBy "Internal server error. Retry the request or contact Jamf support if the error is persistent."
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

# Set how to display verbose messages.
	if [[ "${4}" == "Jamf" ]]; then
		ranBy="Jamf"
		createdByUser="${3}"
		jamfAPIUser=$(DecryptString $5 'Salt' 'Passphrase')
		jamfAPIPassword=$(DecryptString $6 'Salt' 'Passphrase')
	else
		action="${1}"
		ranBy="CLI"

		case $action in
			-help | -h )
				# Function getHelp
				getHelp
			;;
		esac

		# Prompt for credentials.
		jamfAPIUser=$(/usr/bin/osascript -e 'set userInput to the text returned of (display dialog "Enter your Jamf Username:" default answer "")' 2>/dev/null)
		jamfAPIPassword=$(/usr/bin/osascript -e 'set userInput to the text returned of (display dialog "Enter your Jamf Password:" default answer "" with hidden answer)' 2>/dev/null)
	fi

	# Define the curl switches.  Add -k (--insecure) to disable SSL verification.
	curlAPI=(--silent --show-error --fail --user "${jamfAPIUser}:${jamfAPIPassword}" --write-out "statusCode:%{http_code}" --output - --header "Content-Type: application/xml" --request)

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
		echo "*****  CreatePrinters process:  FAILED  *****"
		exit 2
	fi

	echo "API Credentials Valid -- continuing..."
fi

# Get a list of all printer configurations.
	printerInfo=$(/usr/local/bin/jamf listprinters | /usr/bin/xmllint --format - | /usr/bin/xpath /printers 2>/dev/null)
# Get the number of printers.
	numberOfPrinters=$(echo $(/usr/bin/printf '%s\n' "$printerInfo") | /usr/bin/xmllint --format - | /usr/bin/xpath 'count(//printers/printer)' 2>/dev/null)
# Clear the variable, in case we're rerunning the process.
	unset printerNames

# Loop through each printer to only get the printer name and add in it's printer "ID" -- node number in the xml.
for ((i=1; i<=$numberOfPrinters; ++i)); do
	printerName=$(echo $(/usr/bin/printf '%s\n' "$printerInfo") | /usr/bin/xmllint --format - | /usr/bin/xpath /printers/printer[$i]/display_name 2>/dev/null | LANG=C /usr/bin/sed -e 's/<[^/>]*>//g' | LANG=C /usr/bin/sed -e 's/<[^>]*>/\'$'\n/g')
	printerNames+=$"${i}) ${printerName}\n"
done

# Drop the final \n (newline).
	printerNames=$(echo -e ${printerNames} | /usr/bin/perl -pe 'chomp if eof')

# We prompt to create another printer in the function; either continue create printers or complete script.
until [[ $createAnother == "button returned:No" ]]; do
	# Function createPrinter
	createPrinter
done

informBy "Script successfully completed!"
echo "*****  CreatePrinters process:  COMPLETE  *****"
exit 0