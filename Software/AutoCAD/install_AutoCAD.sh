#!/bin/bash

####################################################################################################
# Script Name:  Install-AutoCAD.sh
# By:  Zack Thompson / Created:  9/2/2020
# Version:  1.5.0 / Updated:  6/6/2024 / By:  ZT
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

delete_file() {
	# Delete file if it exists
	# Arguments
	# 	$1 = (str) Path to a file or directory that will be deleted
	local path="${1}"

	if [[ -e "${path}" ]]; then
		echo "Deleting:  ${path}"
		/bin/rm -Rf "${path}"
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

	exec 5>&1
	echo "Installing:  ${installer_app}"
	install_result=$( "${installer_app}/Contents/Helper/Setup.app/Contents/MacOS/Setup" \
		--silent 2>&1 | /usr/bin/tee >( /bin/cat - >&5 ) )
	exit_code=$?

	if [[
		"${install_result}" == *"The application with bundle ID com.autodesk.install is running setugid(), which is not allowed. Exiting."*
	]]; then
		echo "Experienced known issue when installing AutoCAD 2025...  Imploring work around..."
		# See:  https://www.autodesk.com/support/technical/article/caas/sfdcarticles/sfdcarticles/The-application-with-bundle-ID-com-autodesk-install-is-running-setugid-which-is-not-allowed-Exiting.html

		echo "Searching for the downloaded ODIS Installer..."
		odis_installer_app=$( /usr/bin/find -E "/private/tmp" -iregex \
			".*/odis_download_dest/.*/AdODIS-installer[.]app" -type d -prune )

		if [[ ! -e "${odis_installer_app}" ]]; then
			echo "Unable to locate a cached ODIS installer, will download it..."

			/usr/bin/curl --silent --show-error --fail --location --request GET \
			--url "https://emsfs.autodesk.com/utility/odis/1/installer/latest/Darwin.dmg" \
			--remote-name \
			--remote-header-name \
			--output-dir "/private/tmp" # Only supported in 7.73.0+
			odis_dmg="/private/tmp/Darwin.dmg"

			echo "Mounting:  ${odis_dmg}"
			mount_dir="/Volumes/ODIS"
			/usr/bin/hdiutil attach "${odis_dmg}" \
				-nobrowse -noverify -noautoopen -mountpoint "${mount_dir}"
			/bin/sleep 2

			echo "Searching for Installer App..."
			mounted_odis_installer_app=$( /usr/bin/find -E "${mount_dir}" \
				-iregex ".*[.]app" -type d -maxdepth 1 -prune )
			echo "Found:  ${mounted_odis_installer_app}"
			odis_installer_app_filename=$( echo "${mounted_odis_installer_app}" | \
				/usr/bin/awk -F '/' '{print $NF}' )

			odis_installer_app="/private/tmp/${odis_installer_app_filename}"
			/bin/cp -R "${mounted_odis_installer_app}" "${odis_installer_app}"
			# Remove quarantine bits before attempting to install...
			/usr/bin/xattr -rc "${odis_installer_app}"

			/usr/bin/hdiutil eject "${mount_dir}"
		fi

		echo "Installing:  ${odis_installer_app}"
		"${odis_installer_app}/Contents/MacOS/installbuilder.sh" \
			--unattendedmodeui "none" --mode "unattended"
		exit_code_odis=$?
		status_code_check $exit_code_odis "${installer_app}"

		echo "Installing:  ${installer_app}"
		"${installer_app}/Contents/Helper/Setup.app/Contents/MacOS/Setup" --silent
		exit_code=$?
	fi

	status_code_check $exit_code "${installer_app}"
	delete_file "${installer_app}"
	delete_file "${odis_dmg}"
	delete_file "${odis_installer_app}"

done < <( echo "${installer_apps}" )

exit_script $script_exit_code