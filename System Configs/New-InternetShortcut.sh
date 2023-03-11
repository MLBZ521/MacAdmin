#!/bin/bash

####################################################################################################
# Script Name:  New-InternetShortcut.sh
# By:  Zack Thompson / Created:  3/26/2018
# Version:  1.6.0 / Updated:  3/10/2023 / By:  ZT
#
# Description:  This script will create an internet shortcut
# 	in the specified location with the specified icon.
#
####################################################################################################

##################################################
# Define Variables

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
usage:   New-InternetShortcut.sh <filename> <URL> <icon> <location> [ <option> ]

Info:	The default action is to create an internet shortcut in the specified location \
with the specified icon.  Optionally, the script can replace or remove the shortcut.

Parameters:
	filename	The \"Display Name\" of the file.

	URL		The website the shortcut is to open.

	icon		The image that will be used for the icon.

	location	Where the shortcut will be saved.
			Supported options are:   [ Dock | Desktop ]

	option	Remove (delete) or replace icon if it exists
			Supported options are:   [ [ Remove | Delete ] | Replace ]
"
}

console_writer() {

	# Writes messages to console even when called via a Function

	local message="${1}"
	local special="${2}"

	if [[ "${special}" == "-e" ]]; then
		# Interpret backslash escape sequences
		echo -e "${message}" >&2
	elif [[ "${special}" == "-n" ]]; then
		# Do not print new line
		echo -n "${message}" >&2
	else
		echo "${message}" >&2
	fi

}

handle_exit() {

	local code="${1}"
	local message="${2}"
	local special="${3}"

	if [[ -n "${message}" ]]; then
		console_writer "${message}" "${special}"
	fi

	if [[ "${code}" -ne 0 ]]; then
		# Function get_help
		get_help

		console_writer "\n*****  Create Shortcut process:  FAILED  *****" "-e"
		exit "${code}"
	fi

	console_writer "\n*****  Create Shortcut process:  COMPLETE  *****" "-e"
	exit 0

}

xpath_tool() {

	if [[ $( /usr/bin/sw_vers -buildVersion ) > "20A" ]]; then
		/usr/bin/xpath -e "$@"
	else
		/usr/bin/xpath "$@"
	fi

}

PlistBuddy_Helper() {
	# Helper function to interact with plists.
	# All options utilize the "-c" option (non-interactive mode).
	# All options except a file path to be passed _except_ for the action "print_stdin"

	# Arguments
	# $1 = (str) action to perform on the plist; Supported options are:
		# "print_stdin" - expects to work with xml formatted text (passed to PlistBuddy via stdin)
		# "print_xml" - returns xml formatted text
		# "print" - returns PlistBuddy's standard descriptive text format
	# $2 = (str) Path to plist or generated xml
	# $3 = (str) Key or key path to read
	# $4 = (str) Type that will be used for the value
	# $5 = (str) Value to be set to the passed key

	local action="${1}"
	local plist="${2}"
	local key="${3}"
	local type="${4}"
	local value="${5}"

	# Delete existing values if required
	case "${action}" in
		"print_xml" )
			/usr/libexec/PlistBuddy -x -c "Print :${key}" "${plist}" || \
			/usr/libexec/PlistBuddy -x -c "Print" "${plist}"
		;;
		"print_stdin" )
			/usr/libexec/PlistBuddy -c "Print :${key}" /dev/stdin <<< "${plist}" || \
			/usr/libexec/PlistBuddy -c "Print" /dev/stdin <<< "${plist}"
		;;
		"print" )
			/usr/libexec/PlistBuddy -c "Print :${key}" "${plist}" || \
			/usr/libexec/PlistBuddy -c "Print" "${plist}"
		;;
		"add" )
			# Configure values
			/usr/libexec/PlistBuddy -c "Add :${key} ${type} ${value}" "${plist}" > /dev/null 2>&1 \
			|| /usr/libexec/PlistBuddy -c "Set :${key} ${value}" "${plist}" 2>&1
		;;
		"delete" )
			/usr/libexec/PlistBuddy -c "Delete :${key} ${type}" "${plist}" 2>&1
		;;
		"clear" )
			/usr/libexec/PlistBuddy -c "clear ${type}" "${plist}" 2>&1
		;;
	esac

}

create_shortcut() {

	console_writer "\nProvided configuration:\n\t * Filename:  ${file_name}\n\t * URL:  ${URL} \
		\n\t * Icon:  ${icon}\n\t * Location:  ${location}\n\nCreating shortcut:" "-e"

	# Create the staging directory if it doesn't existing.
	if [[ ! -d "${default_location}" ]]; then
		/bin/mkdir "${default_location}"
	fi

	# Create the shortcut file.
	console_writer "\t * Staging file..." "-e"
	/usr/bin/printf '%s\n' "[InternetShortcut]" "URL=${URL}" "" > "${default_location}/${file_name}"

	# If the icon provided is on a web server, download it.
	if [[ "${icon}" =~ [Hh][Tt][Tt][Pp]* ]]; then
		console_writer "\t * Downloading icon..." "-e"
		/usr/bin/curl --silent --show-error --fail "${icon}"  --output /tmp/icon.png
		icon="/tmp/icon.png"
	fi

	# Set the icon on the shortcut file.
	console_writer "\t * Adding icon to shortcut..." "-e"
	"${python_binary}" -c "\
import Cocoa, sys
Cocoa.NSWorkspace.sharedWorkspace().setIcon_forFile_options_(Cocoa.NSImage.alloc().\
initWithContentsOfFile_(sys.argv[1]), sys.argv[2], 0) or sys.exit(\"Unable to set file icon\")" \
"${icon}" "${default_location}/${file_name}"

}

check_shortcut_exists() {

	# Check if the shortcut exists
	# Results values:
		# false = Does not Exist
		# true = Exists
	# Exit/Return code:
		# (int) = the index of the shortcut in the `persistent-others` array

	case "${location}" in
		"Dock" )
			console_writer "Determine if shortcut exists in the Dock..."

			# Get the number of items in the persistent-others node.
			index_item=$( PlistBuddy_Helper "print_xml" "${dock_plist}" ":persistent-others" | \
			/usr/bin/xmllint --format - | xpath_tool 'count(//plist/array/dict )' 2>/dev/null )

			# Loop through all the items in the persistent-others node
			# and determine if the shortcut has already been added.
			for ((i=0; i<$index_item; ++i)); do
				index_label=$( PlistBuddy_Helper "print" "${dock_plist}" \
					":persistent-others:${i}:tile-data:file-label" )
				index_data=$( PlistBuddy_Helper "print" "${dock_plist}" \
					":persistent-others:${i}:tile-data:file-data:_CFURLString" )

				# Check if the current index_item values equal the script parameter values.
				if [[ "${index_label}" == "${file_name}" &&
					"${index_data}" == "file://${default_location}/$( echo ${file_name} | \
					/usr/bin/sed 's/ /%20/g' )"
				]]; then
					echo "true"
					return "${i}"
				fi
			done
		;;
		"Desktop" )
			console_writer "Determine if shortcut exists on the Desktop..."
			if [[ -e "/Users/${current_user}/Desktop/${file_name}" ]]; then
				echo "true"
				return
			fi
		;;
		esac

		console_writer "\t * Shortcut does not exist" "-e"
		echo "false"
}

remediate_shortcut() {

	# Remediate shortcut
	console_writer "\t * Removing shortcut" "-e"

	case "${location}" in
		"Desktop" )
			/bin/rm "/Users/${current_user}/Desktop${file_name}"
		;;
		"Dock" )
			PlistBuddy_Helper "delete" "${dock_plist}" ":persistent-others:${index_match}" "dict"
		;;
	esac

}

##################################################
# Bits staged...

console_writer "*****  Create Shortcut process:  START  *****\n\n" "-e"

file_name="${4}.url"
URL="${5}"
icon="${6}"

# Turn on case-insensitive pattern matching
shopt -s nocasematch

case "${7}" in
	"Dock" )
		location="Dock"
		dock_plist="/Users/${current_user}/Library/Preferences/com.apple.dock.plist"
	;;
	"Desktop" )
		location="Desktop"
	;;
	* )
		handle_exit 1 "ERROR:  The specified location is not supported."
	;;
esac

case "${8}" in
	"Remove" | "Delete" )
		option="Remove"
	;;
	"Replace" )
		option="Replace"
	;;
	"" )
		# No option passed
	;;
	* )
		handle_exit 2 "ERROR:  The specified option is not supported."
	;;
esac

# Turn off case-insensitive pattern matching
shopt -u nocasematch

# Check to make sure all parameters were provided.
if [[ -z "${file_name}" && -z "${URL}" && -z "${icon}" && -z "${location}" ]]; then
	handle_exit 3 "ERROR:  Missing required parameters!"
fi

shortcut_exists=$( check_shortcut_exists )
index_match=$?

if [[ "${shortcut_exists}" == "true" ]]; then
	console_writer "\t * Shortcut exists!" "-e"

	if [[ -n "${option}" ]]; then
		# Remediate as requested
		remediate_shortcut
	else
		# Do not remediate
		handle_exit 0
	fi

fi

if [[ "${shortcut_exists}" == "true" && "${option}" == "Remove" ]]; then
	/usr/bin/killall Dock

elif [[ ( "${shortcut_exists}" == "false" || "${option}" == "Replace" )
		&& "${option}" != "Remove"
]]; then

	# Function create_shortcut
	create_shortcut

	# Check where to place the file.
	case "${location}" in
		"Desktop" )
		# Move shortcut to the Desktop.
		console_writer "\nAdding to the Desktop..." "-e"
		/bin/mv "${default_location}/${file_name}" "/Users/${current_user}/Desktop"
	;;
	"Dock" )
		console_writer "\nAdding to the Dock..." "-e"
		file_name_location=$( echo "${file_name}" | /usr/bin/sed 's/ /%20/g' )

		/usr/bin/sudo -s -u "${current_user}" /usr/bin/defaults write \
			"/Users/${current_user}/Library/Preferences/com.apple.dock" persistent-others \
			-array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString\
</key><string>file://${default_location}/${file_name_location}</string><key>_CFURLStringType</key>\
<integer>15</integer></dict><key>file-label</key><string>${file_name}</string><key>file-type</key>\
<integer>32</integer></dict><key>tile-type</key><string>file-tile</string></dict>"
		/usr/bin/killall Dock
	;;
	esac

fi

handle_exit 0