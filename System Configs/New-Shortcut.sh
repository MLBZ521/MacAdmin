#!/bin/bash

###################################################################################################
# Script Name:  New-Shortcut.sh
# By:  Zack Thompson / Created:  3/26/2018
# Version:  1.5.0 / Updated:  3/9/2023 / By:  ZT
#
# Description:  This script will create an internet shortcut
# 	in the specified location with the specified icon.
#
###################################################################################################

echo -e "*****  Create Shortcut process:  START  *****\n"

##################################################
# Define Variables

# If using Jamf Pro, change these values to:  4, 5, 6, 7
file_name="${1}.url"
URL="${2}"
icon="${3}"
location="${4}"

# Get the current user
current_user=$( /usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | \
	/usr/bin/awk '/Name :/ && ! /loginwindow/ { print $3 }' )
default_location="/Users/${current_user}/Library/Shortcuts"

# Set custom Python binary path
python_binary="/opt/ManagedFrameworks/Python.framework/Versions/Current/bin/python3"

##################################################
# Setup Functions

get_help() {
echo "
usage:   New-Shortcut.sh <filename> <URL> <icon> <location>

Info:	This script will create an internet shortcut \
in the specified location with the specified icon.

Parameters:
	filename	The \"Display Name\" of the file.

	URL			The website the shortcut is to open.

	icon		The image that will be used for the icon.

	location	Where the shortcut will be saved.
				Supported options are:   \"Dock\" or \"Desktop\"
"
}

xpath_tool() {

	if [[ $( /usr/bin/sw_vers -buildVersion ) > "20A" ]]; then
		/usr/bin/xpath -e "$@"
	else
		/usr/bin/xpath "$@"
	fi

}

create_shortcut() {

	echo -e "\nProvided configuration:\n\t * Filename:  ${file_name}\n\t * URL:  ${URL} \
		\n\t * Icon:  ${icon}\n\t * Location:  ${location}\n\nCreating the shortcut:"

	# Create the staging directory if it doesn't existing.
	if [[ ! -d "${default_location}" ]]; then
		/bin/mkdir "${default_location}"
	fi

	# Create the shortcut file.
	/usr/bin/printf '%s\n' "[InternetShortcut]" "URL=${URL}" "" > "${default_location}/${file_name}"

	# If the icon provided is on a web server, download it.
	if [[ "${icon}" =~ http* ]]; then
		echo -e "\t * Downloading icon..."
		/usr/bin/curl --silent --show-error --fail "${icon}"  --output /tmp/icon.png
		icon="/tmp/icon.png"
	fi

	# Set the icon on the shortcut file.
	echo -e "\t * Adding icon to shortcut..."
	"${python_binary}" -c "\
import Cocoa, sys
Cocoa.NSWorkspace.sharedWorkspace().setIcon_forFile_options_(Cocoa.NSImage.alloc().\
initWithContentsOfFile_(sys.argv[1]), sys.argv[2], 0) or sys.exit(\"Unable to set file icon\")" \
"${icon}" "${default_location}/${file_name}"

}

##################################################
# Bits staged...

# Check to make sure all parameters were provided.
if [[ -z "${file_name}" && -z "${URL}" && -z "${icon}" && -z "${location}" ]]; then
	echo "ERROR:  Missing required parameters!"
	# Function get_help
	get_help
	echo -e "\n*****  Create Shortcut process:  FAILED  *****"
	exit 1
fi

echo ""
# Check where to place the file.
case "${location}" in
	Dock )
		echo "Determine if requested shortcut exists in the Dock..."
		# Track whether the Dock item already exists; if it does,
		# do not unnecessarily edit and kill the Dock.
		already_exists=0

		# Get the number of items in the persistent-others node.
		index_item=$( /usr/libexec/PlistBuddy -x -c "Print :persistent-others" \
			"/Users/${current_user}/Library/Preferences/com.apple.dock.plist" | \
			/usr/bin/xmllint --format - | xpath_tool 'count(//plist/array/dict )' 2>/dev/null)
		# Then subtract one for array value notation.
		index_item=$((index_item-1))

		# Loop through all the items in the persistent-others node
		# and determine if the shortcut has already been added.
		for ((i=0; i<=$index_item; ++i)); do
			index_label=$( /usr/libexec/PlistBuddy -c "Print \
				:persistent-others:${i}:tile-data:file-label" \
				"/Users/${current_user}/Library/Preferences/com.apple.dock.plist" )
			index_data=$( /usr/libexec/PlistBuddy -c "Print \
				:persistent-others:${i}:tile-data:file-data:_CFURLString" \
				"/Users/${current_user}/Library/Preferences/com.apple.dock.plist" )

			# Check if the current index_item values equal the new items' values.
			if [[ "${index_label}" == "${file_name}" &&
				"${index_data}" == "file://${default_location}/$( echo ${file_name} | \
				/usr/bin/sed 's/ /%20/g' )"
			]]; then
				already_exists=1
				echo -e "\t * Shortcut already exists!"
				break
			fi
		done

		if [[ $already_exists == 0 ]]; then
			echo -e "\t * Shortcut does not exist"

			# Function create_shortcut
			create_shortcut

			echo -e "\t * Adding to the Dock..."
			file_name_location=$( echo "${file_name}" | /usr/bin/sed 's/ /%20/g' )
			/usr/bin/sudo -s -u "${current_user}" /usr/bin/defaults write \
				"/Users/${current_user}/Library/Preferences/com.apple.dock" persistent-others \
				-array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>\
_CFURLString</key><string>file://${default_location}/${file_name_location}</string>\
<key>_CFURLStringType</key><integer>15</integer></dict><key>file-label</key>\
<string>${file_name}</string><key>file-type</key><integer>32</integer></dict>\
<key>tile-type</key><string>file-tile</string></dict>"
			/usr/bin/killall Dock

		fi
	;;
	Desktop )
		echo "Determine if requested shortcut exists on the Desktop..."

		if [[ -e "/Users/${current_user}/Desktop/${file_name}" ]]; then
			echo -e "\t * Shortcut already exists!"
		else
			# Function create_shortcut
			create_shortcut

			# Move shortcut to the Desktop.
			echo "Adding to the Desktop..."
			/bin/mv "${default_location}/${file_name}" "/Users/${current_user}/Desktop"
		fi
	;;
	* )
		echo "ERROR:  The specified location is not configurable at this time."
		# Function get_help
		get_help
		echo -e "\n*****  Create Shortcut process:  FAILED  *****"
	;;
esac

echo -e "\n*****  Create Shortcut process:  COMPLETE  *****"
exit 0