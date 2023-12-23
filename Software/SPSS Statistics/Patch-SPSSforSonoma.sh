#!/bin/bash

####################################################################################################
# Script Name:  Patch-SPSSforSonoma.sh
# By:  Zack Thompson / Created:  12/12/2023
# Version:  1.0.0 / Updated:  12/12/2023 / By:  ZT
#
# Description:  Patches SPSS v29 to support macOS 14 Sonoma.
#
####################################################################################################

echo -e "\n*****  Patch SPSS for Sonoma Process:  START  *****\n"

##################################################
# Define Variables

# Set working directory
pkg_dir=$( /usr/bin/dirname "${0}" )

# Default notification icon
icon="/System/Library/CoreServices/Problem Reporter.app/Contents/Resources/ProblemReporter.icns"

##################################################
# Functions

app_running() {

	# Arguments
	# $1 = (regex str) A Regex string to pass to `grep -E` to parse for a running application

	local app="${1}"

	# Check if app is running
	/bin/ps -ax -o pid,command | /usr/bin/grep -E "${app}" | /usr/bin/grep -v "grep"

}

jamf_helper() {

	# Arguments
	# $1 = (str) Window Type
	# $2 = (str) Path to an icon
	# $3 = (str) Title
	# $4 = (str) Heading
	# $5 = (str) Description
	# $6 = (str) Extra parameters

	local binary="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
	local window_type="${1}"
	local icon="${2}"
	local title="${3}"
	local heading="${4}"
	local description="${5}"
	local extra_parameters="${6}"

	# Prompt user via Jamf Helper
	# shellcheck disable=SC2086
	"${binary}" -windowType "${window_type}" -title "${title}" -icon "${icon}" \
		-heading "${heading}" -description "${description}" $extra_parameters > /dev/null 2>&1

}

##################################################
# Bits staged...

if [[ ! -e "${pkg_dir}" ]]; then
	echo "Patch directory could not be found!"
	exit 1
fi

echo "Searching for existing SPSS instances..."
app_paths=$( /usr/bin/find -E /Applications \
	-iregex ".*[/](SPSS) ?(Statistics) ?([0-9]{2})?[.]app" -type d -prune )

if [[ -z "${app_paths}" ]]; then
	echo "[WARNING] Did not find an instance SPSS!"
else

	# If the machine has multiple SPSS Applications, loop through them...
	while IFS=$'\n' read -r app_path; do

		# Check if this app bundle is major version 29
		if [[ $( /usr/bin/defaults read \
			"${app_path}/Contents/Info.plist" CFBundleShortVersionString ) =~ ^29[.0-9]+$ ]]; then

			echo "Found:  ${app_path}"

			# Check if SPSS is running
			running=$( app_running "${app_path}" )

			while [[ -n "${running}" ]]; do

				echo " -> SPSS is currently running, prompting user to patch..."
				user_was_prompted="true"

				spss_icon_file_name=$( /usr/bin/defaults read \
					"${app_path}/Contents/Info.plist" "CFBundleIconFile" )

				if [[ -e "${app_path}/Contents/Resources/${spss_icon_file_name}" ]]; then
					icon="${app_path}/Contents/Resources/${spss_icon_file_name}"
				fi

				if [[
					-e \
					"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
				]]; then

					window_type="utility"
					title="Patch Notification"
					heading="Arizona State University"
					description="A patch is available for SPSS Statistics to support macOS 14 Sonoma.  Please quit SPSS Statistics and click 'OK' to apply this update.

Clicking 'Cancel' will allow you to delay the patch.  You will be prompted again to apply the patch.

If you have questions, please contact your deskside support group."

					# Prompt user via Jamf Helper
					jamf_helper "${window_type}" "${icon}" "${title}" "${heading}" \
						"${description}" "-button1 \"OK\" -button2 \"Cancel\""

				else

					if [[ ! -e "${app_path}/Contents/Resources/${spss_icon_file_name}" ]]; then
						icon="caution"
					fi

					/usr/bin/osascript > /dev/null 2>&1 << EndOfScript
						tell application "installer"
							activate
							display dialog "To install the patch, please quit SPSS Statistics and click 'OK' for SPSS Statistics to support macOS 14 Sonoma." ¬
							with title "Arizona State University - Patch Notification" ¬
							buttons {"OK", "Cancel"} ¬
							with icon POSIX file "${icon}"
						end tell
EndOfScript

				fi

				user_selection=$?

				if [[ $user_selection == 0 ]]; then
					# Give the user ten seconds to quit before checking again
					/bin/sleep 10
					# Check if SPSS is running
					running=$( app_running "${app_path}" )
				elif [[ $user_selection == 2 || $user_selection == 1 ]]; then
					echo "[WARNING] User canceled the process.  Aborting..."
					echo "*****  Patch SPSS for Sonoma Process:  CANCELED  *****"
					exit 0
				fi

			done

			# Backup file
			echo " -> Backing up..."
			/bin/mv "${app_path}/Contents/lib/libplatdep.dylib" \
				"${app_path}/Contents/lib/libplatdep.dylib.bak"

			# Copy in patched file
			echo " -> Patching..."
			/bin/cp "${pkg_dir}/libplatdep.dylib" "${app_path}/Contents/lib/libplatdep.dylib"

			# Set permissions on the file
			echo " -> Applying permissions..."
			/bin/chmod 755 "${app_path}/Contents/lib/libplatdep.dylib"

			# Set ownership on the file
			echo " -> Setting ownership..."
			/usr/sbin/chown -R root:admin "${app_path}/Contents/lib/libplatdep.dylib"

			if [[ "${user_was_prompted}" == "true" ]]; then

				descriptionComplete="SPSS Statistics has been patched!

SPSS v29 is now compatible with macOS 14 Sonoma!"

				if [[
					-e \
					"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
				]]; then

					# Prompt user via Jamf Helper
					jamf_helper "${window_type}" "${icon}" "${title}" "${heading}" \
						"${descriptionComplete}" "-button1 \"Close\" -defaultButton 1"

				else

					if [[ ! -e "${app_path}/Contents/Resources/${spss_icon_file_name}" ]]; then
						icon="caution"
					fi

					/usr/bin/osascript > /dev/null 2>&1 << EndOfScript
						tell application "installer"
							activate
							display dialog "SPSS Statistics has been patched!\n\nSPSS v29 is now compatible with macOS 14 Sonoma!" ¬
							with title "Arizona State University - Patch Notification" ¬
							buttons {"OK"} ¬
							with icon POSIX file "${icon}"
						end tell
EndOfScript

				fi

			fi

		fi

	done < <(echo "${app_paths}")

fi

echo -e "\n*****  Patch SPSS for Sonoma Process:  COMPLETE  *****"
exit 0
