#!/bin/bash

###################################################################################################
# Script Name:  Run-BomgarSupportOnDemand.sh
# By:  Zack Thompson / Created:  5/11/2020
# Version:  1.0.0 / Updated:  5/11/2020 / By:  ZT
#
# Description:  Utilizing the Bomgar API, downloads a Bomgar Support Client and assigns it to the
#               supplied team's queue based on the passed parameters.
#
# Documentation:  https://www.beyondtrust.com/docs/remote-support/how-to/integrations/api/session-gen/index.htm
#
# Inspired by:  Neil Martin
#       - https://soundmacguy.wordpress.com/2017/04/18/integrating-bomgar-and-jamf-self-service/
#
###################################################################################################

echo "*****  Run BomgarSupportOnDemand Process:  START  *****"

##################################################
# Define Variables

echo "Building attributes..."

issueCodeName="${4}"
bomgarSiteURL="${5}"

# Set the Default URL if not provided
if [[ "${bomgarSiteURL}" == "" ]]; then

    bomgarSiteURL="bomgar.company.org"

fi

# Fail if an Issue Code Name isn't provided
if [[ "${issueCodeName}" == "" ]]; then
    echo "ERROR:  The OnDemand Support Group was not provided."
    echo "*****  Run BomgarSupportOnDemand Process:  FAILED  *****"
    exit 1
fi

# Gett he Serial Number
serialNumber=$( /usr/sbin/ioreg -c IOPlatformExpertDevice -d 2 | /usr/bin/awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}' )

# Determine the length and get the required characters
if [[ ${#serialNumber} -eq 12 ]]; then

    serialIdentifer=$( echo "${serialNumber}" | /usr/bin/tail -c 5 )

elif [[ ${#serialNumber} -eq 11 ]]; then

    serialIdentifer=$( echo "${serialNumber}" | /usr/bin/tail -c 4 )

fi

# Get the Friendly Model Name
friendlyModelName=$( /usr/bin/curl -s "https://support-sp.apple.com/sp/product?cc=${serialIdentifer}" | /usr/bin/xmllint --format - | /usr/bin/xpath "/root/configCode/text()" 2>/dev/null )

# Assign Firnedly Model Name and Serial Number to a Variable
customerDetails="${friendlyModelName}, ${serialNumber}"

# Get the Console User
consoleUser=$( /usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk '/Name :/ && ! /loginwindow/ { print $3 }' )

# Get the Console Users' Full Name
fullName=$( /usr/bin/dscl . -read "/Users/${consoleUser}" dsAttrTypeStandard:RealName | /usr/bin/awk -F 'RealName:' '{print $1}' | /usr/bin/xargs )

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

##################################################
# Bits staged...

echo "Downloading client..."

# Download the Support Application -- Using a User Agent that downloads a .dmg as I wasn't able get a .zip to extract via cli and work
exitStatus1=$(  su - "${consoleUser}" -c "cd /private/tmp/ && /usr/bin/curl \
    --silent --show-error --fail \
    --url \"https://${bomgarSiteURL}/api/start_session\" \
    --header 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_4) AppleWebKit/601.5.17 (KHTML, like Gecko) Version/9.1 Safari/601.5.17' \
    -d issue_menu=1 \
    -d codeName=\"${issueCodeName}\" \
    -d customer.name=\"${fullName} (${consoleUser})\" \
    -d customer.details=\"${customerDetails}\" \
    --compressed \
    --remote-name \
    --remote-header-name"
    )
exitCode1=$?
exitCheck $exitCode1 "${exitStatus1}" "Failed to download the Remote Support application!"

# Get the filename of the .dmg file
bomgarDMG="/private/tmp/$( /bin/ls "/private/tmp/" | /usr/bin/grep -E "bomgar-scc-.*[.]dmg" )"

# Mount the dmg
if [[ -e "${bomgarDMG}" ]]; then

    echo "Mounting:  ${bomgarDMG}"
	su - "${consoleUser}" -c "/usr/bin/hdiutil attach \"${bomgarDMG}\" -nobrowse -noverify -noautoopen -quiet"
	/bin/sleep 2

else

    exitCheck 1 "Missing .dmg" "Failed to locate the downloaded file!"

fi

# Get the name of the mount
bomgarMount=$( /bin/ls /Volumes/ | /usr/bin/grep bomgar )

# Get the name of the app
app=$( /bin/ls "/Volumes/${bomgarMount}/" | /usr/bin/grep .app )

echo "Running client..."

# Run the Support Application
exitStatus2=$( su - "${consoleUser}" -c "/usr/bin/open \"/Volumes/${bomgarMount}/${app}\"" & )
exitCode2=$?
exitCheck $exitCode2 "${exitStatus2}" "Failed to run the Remote Support application!"

# Perform clean up if still mounted
if [[ -e "/Volumes/${bomgarMount}/" ]]; then

    echo "Ejecting:  /Volumes/${bomgarMount}/"
    /usr/bin/hdiutil eject "/Volumes/${bomgarMount}"
fi

# Perform clean up is the disk image still exists
if [[ -e "${bomgarDMG}" ]]; then

    echo "Removing:  ${bomgarDMG}"
	/bin/rm "${bomgarDMG}"

fi

echo "*****  Run BomgarSupportOnDemand Process:  COMPLETE  *****"
exit 0