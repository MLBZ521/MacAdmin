#!/bin/bash

###################################################################################################
# Script Name:  Run-BomgarSupportOnDemand.sh
# By:  Zack Thompson / Created:  5/11/2020
# Version:  1.3.0 / Updated:  5/12/2022 / By:  ZT
#
# Description:  Utilizing the Bomgar API, downloads a Bomgar Support Client and assigns it to the
#               supplied team's queue based on the passed parameters.
#
# Documentation:  
# 	https://www.beyondtrust.com/docs/remote-support/how-to/integrations/api/session-gen/index.htm
#
# Inspired by:  Neil Martin
#       - https://soundmacguy.wordpress.com/2017/04/18/integrating-bomgar-and-jamf-self-service/
#
###################################################################################################

echo "*****  Run BomgarSupportOnDemand Process:  START  *****"

##################################################
# Define Variables

issueCodeName="${4}"
bomgarSiteURL="${5}"
temp_dir="/private/tmp"

# Fail if an Issue Code Name isn't provided
if [[ "${issueCodeName}" == "" ]]; then
	echo "ERROR:  The OnDemand Support Group was not provided."
	echo "*****  Run BomgarSupportOnDemand Process:  FAILED  *****"
	exit 1
fi

# Set the Default URL if not provided
if [[ "${bomgarSiteURL}" == "" ]]; then

	bomgarSiteURL="bomgar.company.org"

fi

##################################################
# Define Functions

exitCheck() {
	if [[ $1 != 0 ]]; then
		echo "ERROR:  ${3}"
		echo "Reason:  ${2}"
		echo "Exit Code:  ${1}"
		echo "*****  Run BomgarSupportOnDemand Process:  FAILED  *****"
		exit 2
	fi
}

xpath_tool() {

	if [[ $( sw_vers -buildVersion ) > "20A" ]]; then

		/usr/bin/xpath -e "$@"

	else

		/usr/bin/xpath "$@"

	fi

}

find_bomgar_dmg() {

	# Find any download bomgar .dmg's in the specified directory
	/usr/bin/find -E "${temp_dir}" -iregex ".*bomgar-scc-.*[.]dmg" -type f -prune -maxdepth 1

}

bomgar_mounts() {

	# Find any mount Bomgar disk images
	/usr/bin/find -E "/Volumes" -iregex ".*bomgar.*" -type d -prune -maxdepth 1

}

eject_disks() {

	# Eject disk image if still mounted
	if [[ -e "${1}" ]]; then

		echo "Ejecting:  ${1}"
		/usr/bin/hdiutil eject "${1}"

	fi

}

delete_file() {

	# Delete file if it still exists
	if [[ -e "${1}" ]]; then

		echo "Deleting:  ${1}"
		/bin/rm "${1}"

	fi

}

lookup_model() {

	# Get the Friendly Model Name from Apple
	/usr/bin/curl -s "https://support-sp.apple.com/sp/product?cc=${1}" | 
		/usr/bin/xmllint --format - | xpath_tool "/root/configCode/text()" 2>/dev/null

}

##################################################
# Bits staged...

# Get the Serial Number
serialNumber=$( /usr/sbin/ioreg -c IOPlatformExpertDevice -d 2 | 
	/usr/bin/awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}' )

# Determine the length and get the required characters and then get the Friendly Model Name
if [[ ${#serialNumber} -eq 10 ]]; then

	friendlyModelName=$( /usr/libexec/PlistBuddy -c "Print 0:product-name" \
		/dev/stdin <<< "$(/usr/sbin/ioreg -arc IOPlatformDevice -k product-name)" )

elif [[ ${#serialNumber} -eq 12 ]]; then

	friendlyModelName=$( lookup_model "$( echo "${serialNumber}" | /usr/bin/tail -c 5 )" )

elif [[ ${#serialNumber} -eq 11 ]]; then

	friendlyModelName=$( lookup_model "$( echo "${serialNumber}" | /usr/bin/tail -c 4 )" )

fi

# Assign Friendly Model Name and Serial Number to a Variable
customerDetails="${friendlyModelName}, ${serialNumber}"

# Get the Console User
consoleUser=$( /usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | 
	/usr/bin/awk '/Name :/ && ! /loginwindow/ { print $3 }' )

# Get the Console Users' Full Name
fullName=$( /usr/bin/dscl . -read "/Users/${consoleUser}" dsAttrTypeStandard:RealName | 
	/usr/bin/awk -F 'RealName:' '{print $1}' | /usr/bin/xargs )

# Check if any mounts already exist
pre_existing_bomgar_mounts=$( bomgar_mounts )

if [[ -n $pre_existing_bomgar_mounts ]]; then

	echo "Cleaning up old Bomgar mounts..."

	while IFS=$'\n' read -r mount_path; do

		eject_disks "${mount_path}"

	done < <(echo "${pre_existing_bomgar_mounts}")

fi

# Check if any dmg's already exist
pre_existing_dmg=$( find_bomgar_dmg )

if [[ -n $pre_existing_dmg ]]; then

	echo "Cleaning up old Bomgar disk images..."

	while IFS=$'\n' read -r dmg_path; do

		delete_file "${dmg_path}"

	done < <(echo "${pre_existing_dmg}")

fi

# Delete pre-existing failure file, just in case
/bin/rm "/private/tmp/start_session" > /dev/null 2>&1

echo "Downloading client..."

# Download the Support Application
# Using a User Agent here that downloads a .dmg as I 
# wasn't able get a .zip to extract via cli and work.
exitStatus1=$( /usr/bin/su - "${consoleUser}" -c "/usr/bin/curl \
	--silent --show-error --fail --location --request POST \
	--url \"https://${bomgarSiteURL}/api/start_session\" \
	--header 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_4) AppleWebKit/601.5.17 (KHTML, like Gecko) Version/9.1 Safari/601.5.17' \
	--header 'Content-Type: application/x-www-form-urlencoded' \
	--data-urlencode issue_menu=1 \
	--data-urlencode codeName=\"${issueCodeName}\" \
	--data-urlencode customer.name=\"${fullName} (${consoleUser})\" \
	--data-urlencode customer.details=\"${customerDetails}\" \
	--compressed \
	--remote-name \
	--remote-header-name \
	--output-dir \"${temp_dir}\""
)

exitCode1=$?
exitCheck $exitCode1 "${exitStatus1}" "Failed to download the Remote Support application!"

if [[ -e "/private/tmp/start_session" && $( /bin/cat "/private/tmp/start_session" ) =~ .*ERROR:[[:space:]]Sorry,[[:space:]]this[[:space:]]issue[[:space:]]code[[:space:]]name[[:space:]]is[[:space:]]not[[:space:]]valid\..* ]]; then

	/bin/rm "/private/tmp/start_session"
	echo "ERROR:  The specified issue code name is not valid"
	echo "*****  Run BomgarSupportOnDemand Process:  FAILED  *****"
	exit 3

fi

# Get the filename of the .dmg file
bomgarDMG=$( find_bomgar_dmg )

# Mount the dmg
if [[ -e "${bomgarDMG}" ]]; then

	echo "Mounting:  ${bomgarDMG}"
	su - "${consoleUser}" -c "/usr/bin/hdiutil attach \"${bomgarDMG}\" \
		-nobrowse -noverify -noautoopen -quiet"
	/bin/sleep 2

else

	exitCheck 1 "Missing .dmg" "Failed to locate the downloaded file!"

fi

# Get the name of the mount
bomgarMount=$( bomgar_mounts )

# Get the name of the app
app=$( /usr/bin/find -E "${bomgarMount}" -iregex ".*[.]app" -type d -prune -maxdepth 1 )

echo "Running client..."

# Run the Support Application
exitStatus2=$( su - "${consoleUser}" -c "/usr/bin/open \"${app}\"" & )
exitCode2=$?
exitCheck $exitCode2 "${exitStatus2}" "Failed to run the Remote Support application!"

# The Bomgar application should take care of itself, 
# so first give it time, but just in case it doesn't...
/bin/sleep 5

# Perform clean up if still mounted
eject_disks "${bomgarMount}"

# Perform clean up if the disk image still exists
delete_file "${bomgarDMG}"

echo "*****  Run BomgarSupportOnDemand Process:  COMPLETE  *****"
exit 0