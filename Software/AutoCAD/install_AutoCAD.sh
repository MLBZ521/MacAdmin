#!/bin/bash

####################################################################################################
# Script Name:  Install-AutoCAD.sh
# By:  Zack Thompson / Created:  9/2/2020
# Version:  1.4.0 / Updated:  6/6/2024 / By:  ZT
#
# Description:  This script silently installs AutoCAD 2023 and newer.
#	Probably works for AutoCAD 2021+ as well.
#
# Note:  The "new" silent install method (using `[...]/Setup -silent`) does not work when it is
#	executed from a .pkg's postinstall script for some odd reason.
#
####################################################################################################

echo -e "*****  Install AutoCAD Process:  START  *****\n"

##################################################
# Helper Functions

status_code_check() {
	# Check the exit code of a process
	# Arguments
	# 	$1 = (int) exit code of a process
	local exit_code="${1}"
	local installed_what="${2}"

	if [[ $exit_code != 0 ]]; then
		echo -e "[Error] Failed to install!\nExit Code:  ${exit_code}"
		script_exit_code=2
	else
		echo -e "Successfully installed:  ${installed_what}"
	fi
}

exit_script() {
	# This function handles the exit process of the script.

	# Arguments
	# 	$1 = (int) exit code to exit the script with
	local exit_code="${1}"

	if [[ $exit_code -eq 0 ]]; then
		exist_status="COMPLETE"
	else
		exist_status="FAILED"
	fi

	echo -e "\n*****  Install AutoCAD Process:  ${exist_status}  *****"
	exit "${exit_code}"
}

##################################################
# Bits staged...

script_exit_code=0

echo "Searching for the Installer App..."
installer_apps=$( /usr/bin/find -E "/private/tmp" -iregex \
	".*/Install Autodesk AutoCAD [[:digit:]]{4} for Mac[.]app" -type d -maxdepth 1 -prune )

# If multiple were found, loop through them...
while IFS=$'\n' read -r installer_app; do

	echo "Installing:  ${installer_app}"
	"${installer_app}/Contents/Helper/Setup.app/Contents/MacOS/Setup" --silent
	exit_code=$?

	status_code_check $exit_code "${installer_app}"
	/bin/rm -Rf "${installer_app}"

done < <( echo "${installer_apps}" )

exit_script $script_exit_code