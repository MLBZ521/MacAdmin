#!/bin/bash

###################################################################################################
# Script Name:  jamf_getKEXTs.sh
# By:  Zack Thompson / Created: 5/2/2018
# Version:  1.1.0 / Updated:  11/29/2021 / By:  ZT
#
# Description:  This script asks for an output file and dumps all KEXT Info to the file.
#
# 	- Original script created by Richard Purves:  https://www.richard-purves.com/2017/11/09/mdm-and-the-kextpocalypse-2/
#
###################################################################################################

echo "*****  jamf_getKEXTs process:  START  *****"

##################################################
# Define Variables
outFile=$( /usr/bin/osascript 2>/dev/null << EndOfScript
	tell application "System Events" 
		activate
		return POSIX path of ¬
		( choose file name ¬
		with prompt "Provide a file name and location to save:" )
	end tell
EndOfScript
)

# Stop IFS linesplitting on spaces
OIFS=$IFS
IFS=$'\n'

##################################################
# Setup Functions

fileExists() {
	if [[ ! -e "${1}" && $2 == "create" ]]; then
		echo "Creating output file at location:  ${1}"
		/usr/bin/touch "${1}"
	fi
}

##################################################
# Bits Staged

echo "Searching Applications folder"
applic=($(/usr/bin/find /Applications -name "*.kext"))

echo "Searching Library Extensions folder"
libext=($(/usr/bin/find /Library/Extensions -name "*.kext" -maxdepth 1))

echo "Searching Library Application Support folder"
libapp=($(/usr/bin/find /Library/Application\ Support -name "*.kext"))

echo ""

# Merge the arrays together
results=("${applic[@]}" "${libext[@]}" "${libapp[@]}")
echo "Number of results:  ${#results[@]}"

if [ ${#results[@]} != "0" ]; then
	# Function fileExists
	fileExists "${outFile}" create
	
	for (( loop=0; loop<${#results[@]}; loop++ )); do
		# Get the Team Identifier for the kext
		teamid=$(/usr/bin/codesign -d -vvvv ${results[$loop]} 2>&1 | /usr/bin/grep "Authority=Developer ID Application:" | /usr/bin/cut -d"(" -f2 | /usr/bin/tr -d ")" )

		# Get the CFBundleIdentifier for the kext
		bundid=$(/usr/bin/defaults read "${results[$loop]}"/Contents/Info.plist CFBundleIdentifier)

		echo "KEXT:  ${results[$loop]}" >> "${outFile}"
		echo "Team ID:  ${teamid} | Bundle ID: ${bundid}" >> "${outFile}"
	done

	/usr/bin/osascript >/dev/null << EndOfScript
	tell application "System Events" 
		activate
		display dialog "List has been saved to:  ${outFile}" ¬
		buttons {"OK"} ¬
	end tell
EndOfScript

else

	/usr/bin/osascript >/dev/null << EndOfScript
	tell application "System Events" 
		activate
		display dialog "Either no KEXTs were found or there was a problem" ¬
		buttons {"OK"} ¬
	end tell
EndOfScript

fi

IFS=$OIFS
echo "*****  jamf_getKEXTs process:  COMPLETE  *****"
exit 0