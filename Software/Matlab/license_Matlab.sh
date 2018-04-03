#!/bin/bash

###################################################################################################
# Script Name:  license_Matlab.sh
# By:  Zack Thompson / Created:  1/10/2018
# Version:  1.1.1 / Updated:  4/2/2018 / By:  ZT
#
# Description:  This script applies the license for Matlab applications.
#
###################################################################################################

echo "*****  License Matlab process:  START  *****"

##################################################
# Define Variables

# Find all instances of Matlab
appPaths=$(/usr/bin/find /Applications -iname "Matlab*.app" -maxdepth 1 -type d)

# Verify that a Matlab version was found.
if [[ -z "${appPaths}" ]]; then
	echo "A version of Matlab was not found in the expected location!"
	echo "*****  License Matlab process:  FAILED  *****"
	exit 1
else
	# If the machine has multiple Matlab Applications, loop through them...
	while IFS="\n" read -r appPath; do

		# Get the Matlab version
			appVersion=$(/bin/cat "${appPath}/VersionInfo.xml" | /usr/bin/grep release | /usr/bin/awk -F "<(/)?release>" '{print $2}')
			echo "Applying License for Version:  ${appVersion}"

		# Build the license file location
		licenseFile="${appPath}/licenses/network.lic"

		##################################################
		# Create the license file.

		echo "Creating license file..."

		/bin/cat > "${licenseFile}" <<licenseContents
SERVER license.server.com 11000 
USE_SERVER
licenseContents

		if [[ -e "${licenseFile}" ]]; then
			# Set permissions on the file for everyone to be able to read.
			echo "Applying permissions to license file..."
			/bin/chmod 644 "${licenseFile}"
		else
			echo "ERROR:  Failed to create the license file!"
			echo "*****  License Matlab process:  FAILED  *****"
			exit 2
		fi
	done < <(echo "${appPaths}")
fi

echo "Matlab has been activated!"
echo "*****  License Matlab process:  COMPLETE  *****"
exit 0