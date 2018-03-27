#!/bin/bash

###################################################################################################
# Script Name:  jamf_CreateShortcut.sh
# By:  Zack Thompson / Created:  3/26/2018
# Version:  0.1 / Updated:  3/26/2018 / By:  ZT
#
# Description:  This script will create a website shortcut in a specified location with a specified icon.
#
###################################################################################################

echo "*****  Create Shortcut process:  START  *****"

##################################################
# Define Variables
	fileName="${1}"
	URL="${2}"
	icon="${3}"
	location="${4}"

# Get the current user
currentUser=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')

defaultLocation="/Users/${currentUser}/Library/Shortcuts/"

##################################################
# Setup Functions

getHelp() {
echo "
usage:  jamf_CreateShortcut.sh <filename> <URL> <icon> <location>

Info:	This script will create a website shortcut in a specified location with a specified icon.

Parameters:
	filename	Thise files' \"Display Name\".

	URL			The website the shortcut is for.

	icon		The image that will be used for the icon.

	location	Where the shortcut will be saved.
"
}

##################################################
# Bits staged...

# Check to make sure all parameters were provided.
# if [[ -z "${4}" && -z "${5}" && -z "${6}" && -z "${7}"]]; then
# 	echo "ERROR:  Missing required parameters!"	
# 	# Function getHelp
# 	getHelp
# 	echo "*****  Create Shortcut process:  FAILED  *****"
# 	exit 1
# fi

echo "Provided configuration:"
echo "Filename:  ${fileName}"
echo "URL:  ${URL}"
echo "Icon:  ${icon}"
echo "Location:  ${location}"


# Create the staging directory if it doesn't existing.
if [[ ! -d "${defaultLocation}" ]]; then
	/bin/mkdir "${defaultLocation}"
fi

# Create the file
echo "Creating the requested shortcut..."
/usr/bin/printf  '%s\n' "[InternetShortcut]" "URL=${URL}" "" > "${defaultLocation}/${fileName}.url"

# If the icon provided is on a web server, download it.
if [[ "${icon}" == "http"* ]]; then
	echo "Downloading icon..."
	/usr/bin/curl --silent --show-error --fail "${icon}"  --output /tmp/icon.png
	# curlAPI=(--silent --show-error --fail --user --write-out "statusCode:%{http_code}")
	icon="/tmp/icon.png"
fi

# Set the icon
echo "Adding the requested icon..."
/usr/bin/python -c "import Cocoa; import sys; Cocoa.NSWorkspace.sharedWorkspace().setIcon_forFile_options_(Cocoa.NSImage.alloc().initWithContentsOfFile_(sys.argv[1].decode('utf-8')), sys.argv[2].decode('utf-8'), 0) or sys.exit(\"Unable to set file icon\")" "${icon}" "${defaultLocation}/${fileName}.url"

# Check where to place the file.
if [[ "${location}" == "Dock" ]]; then
	# Add to dock
	echo "Adding to the dock..."
	/usr/bin/defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>file://${defaultLocation}/${fileName}.url</string><key>_CFURLStringType</key><integer>15</integer></dict><key>file-label</key><string>${fileName}.url</string><key>file-type</key><integer>32</integer></dict><key>tile-type</key><string>file-tile</string></dict>"
	/usr/bin/killall Dock
else
	echo "Moving file in place..."
	/bin/mv "${defaultLocation}" "${location}"
fi

echo "*****  Create Shortcut process:  COMPLETE  *****"
exit 0