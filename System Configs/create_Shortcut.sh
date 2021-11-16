#!/bin/bash

###################################################################################################
# Script Name:  create_Shortcut.sh
# By:  Zack Thompson / Created:  3/26/2018
# Version:  1.2.0 / Updated:  11/15/2021 / By:  ZT
#
# Description:  This script will create a website shortcut in a specified location with a specified icon.
#
###################################################################################################

echo "*****  Create Shortcut process:  START  *****"

##################################################
# Define Variables
# If using Jamf, change these values to:  4, 5, 6, 7
	fileName="${1}"
	URL="${2}"
	icon="${3}"
	location="${4}"

# Get the current user
	currentUser=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')
	defaultLocation="/Users/${currentUser}/Library/Shortcuts"

##################################################
# Setup Functions

getHelp() {
echo "
usage:  jamf_CreateShortcut.sh <filename> <URL> <icon> [<location> Dock | Desktop]

Info:	This script will create a website shortcut in a specified location with a specified icon.

Parameters:
	filename	The files' \"Display Name\".

	URL			The website the shortcut is for.

	icon		The image that will be used for the icon.

	location	Where the shortcut will be saved.
"
}

xpath_tool() {

	if [[ $( /usr/bin/sw_vers -buildVersion ) > "20A" ]]; then

		/usr/bin/xpath -e "$@"

	else

		/usr/bin/xpath "$@"

	fi

}

##################################################
# Bits staged...

# Check to make sure all parameters were provided.
if [[ -z "${fileName}" && -z "${URL}" && -z "${icon}" && -z "${location}" ]]; then
	echo "ERROR:  Missing required parameters!"	
	# Function getHelp
	getHelp
	echo "*****  Create Shortcut process:  FAILED  *****"
	exit 1
fi

echo "Provided configuration:"
echo -e "\t Filename:  ${fileName}"
echo -e "\t URL:  ${URL}"
echo -e "\t Icon:  ${icon}"
echo -e "\t Location:  ${location}"
echo ""
echo "Building shortcut:"

# Create the staging directory if it doesn't existing.
if [[ ! -d "${defaultLocation}" ]]; then
	/bin/mkdir "${defaultLocation}"
fi

# Create the shortcut file.
echo -e "\t Creating the requested shortcut..."
/usr/bin/printf  '%s\n' "[InternetShortcut]" "URL=${URL}" "" > "${defaultLocation}/${fileName}.url"

# If the icon provided is on a web server, download it.
if [[ "${icon}" == "http"* ]]; then
	echo -e "\t Downloading icon..."
	/usr/bin/curl --silent --show-error --fail "${icon}"  --output /tmp/icon.png
	# curlAPI=(--silent --show-error --fail --user --write-out "statusCode:%{http_code}")
	icon="/tmp/icon.png"
fi

# Set the icon on the shortcut file.
echo -e "\t Adding the requested icon to shortcut..."
/usr/bin/python -c "import Cocoa; import sys; Cocoa.NSWorkspace.sharedWorkspace().setIcon_forFile_options_(Cocoa.NSImage.alloc().initWithContentsOfFile_(sys.argv[1].decode('utf-8')), sys.argv[2].decode('utf-8'), 0) or sys.exit(\"Unable to set file icon\")" "${icon}" "${defaultLocation}/${fileName}.url"

echo ""
# Check where to place the file.
case "${location}" in
	Dock )
		echo "Determine if requested shortcut exists in the Dock..."
		# Setting a variable that holds whether the Dock item already exists or not (if it does, we don't want to unnecessarily edit and kill the Dock).
		alreadyExists=0

		# Get the number of items in the persistent-others node; then subtract one for Array value notation.
		indexItem=$(/usr/libexec/PlistBuddy -x -c "Print :persistent-others" "/Users/${currentUser}/Library/Preferences/com.apple.dock.plist" | /usr/bin/xmllint --format - | xpath_tool 'count(//plist/array/dict)' 2>/dev/null)
		indexItem=$((indexItem-1))

		# Loop through all the items in the persistent-others node and compare to the new item being added.
			for ((i=0; i<=$indexItem; ++i)); do
			indexLabel=$(/usr/libexec/PlistBuddy -c "Print :persistent-others:${i}:tile-data:file-label" "/Users/${currentUser}/Library/Preferences/com.apple.dock.plist")
			indexData=$(/usr/libexec/PlistBuddy -c "Print :persistent-others:${i}:tile-data:file-data:_CFURLString" "/Users/${currentUser}/Library/Preferences/com.apple.dock.plist")

			# Check if the current indexItem values equal the new items' values.
			if [[ "${indexLabel}" == "${fileName}" && "${indexData}" == "file://${defaultLocation}/"$(echo "${fileName}" | /usr/bin/sed 's/ /%20/g')".url" ]]; then
				alreadyExists=1
				echo -e "\t Shortcut already exists!"
			fi
		done

		# If the new item does not already exist, add it to the Dock.
		if [[ $alreadyExists == 0 ]]; then
			echo -e "\t Adding to the dock..."
			fileNameLocation=$(echo "${fileName}" | /usr/bin/sed 's/ /%20/g')
			/usr/bin/sudo -s -u "${currentUser}" /usr/bin/defaults write "/Users/${currentUser}/Library/Preferences/com.apple.dock" persistent-others -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>file://${defaultLocation}/${fileNameLocation}.url</string><key>_CFURLStringType</key><integer>15</integer></dict><key>file-label</key><string>${fileName}</string><key>file-type</key><integer>32</integer></dict><key>tile-type</key><string>file-tile</string></dict>"
			/usr/bin/killall Dock
		fi
	;;
	Desktop )
		# Move file to the specified location if not adding to the Dock.
		echo "Moving file to the Desktop..."
		/bin/mv "${defaultLocation}/${fileName}.url" "/Users/${currentUser}/Desktop"
	;;
	* )
		echo "ERROR:  The specified location is not configurable at this time."
		# Function getHelp
			getHelp
		echo "*****  Create Shortcut process:  FAILED  *****"
	;;
esac

echo "*****  Create Shortcut process:  COMPLETE  *****"
exit 0