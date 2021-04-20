#!/bin/bash

###################################################################################################
# Script Name:  license_Matlab.sh
# By:  Zack Thompson / Created:  1/10/2018
# Version:  1.2.0 / Updated:  4/19/2021 / By:  ZT
#
# Description:  This script applies the license for Matlab.
#
###################################################################################################

echo "*****  License Matlab process:  START  *****"

##################################################
# Define Variables

# Find all instances of Matlab
app_paths=$( /usr/bin/find /Applications -iname "Matlab*.app" -maxdepth 1 -type d )

# Verify that a Matlab version was found.
if [[ -z "${app_paths}" ]]; then

	echo "A version of Matlab was not found in the expected location!"
	echo "*****  License Matlab process:  FAILED  *****"
	exit 1

else

	# If the machine has multiple Matlab Applications, loop through them...
	while IFS=$'\n' read -r app_path; do

		# Get the Matlab version
		# shellcheck disable=SC2002
		app_version=$( /bin/cat "${app_path}/VersionInfo.xml" | /usr/bin/grep release | /usr/bin/awk -F "<(/)?release>" '{print $2}' )
		echo "Applying License for Version:  ${app_version}"

		# Build the license file location
		license_folder="${app_path}/licenses"
		license_file="${license_folder}/network.lic"

		if [[ ! -d "${license_folder}" ]]; then

			# shellcheck disable=SC2174
			/bin/mkdir -p -m 755 "${license_folder}"
			/usr/sbin/chown root:admin "${license_folder}"

		fi

		##################################################
		# Create the license file.

		echo "Creating license file..."

		/bin/cat > "${license_file}" <<licenseContents
SERVER license.server.com 11000 
USE_SERVER
licenseContents

		if [[ -e "${license_file}" ]]; then

			# Set permissions on the file for everyone to be able to read.
			echo "Applying permissions to license file..."
			/bin/chmod 644 "${license_file}"
			/usr/sbin/chown root:admin "${license_file}"

		else

			echo "ERROR:  Failed to create the license file!"
			echo "*****  License Matlab process:  FAILED  *****"
			exit 2

		fi

	done < <(echo "${app_paths}")

fi

echo "Matlab has been activated!"
echo "*****  License Matlab process:  COMPLETE  *****"
exit 0