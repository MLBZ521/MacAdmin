#!/bin/bash

###################################################################################################
# Script Name:  license_Matlab.sh
# By:  Zack Thompson / Created:  1/10/2018
# Version:  1.0 / Updated:  1/10/2018 / By:  ZT
#
# Description:  This script applies the license for Matlab applications.
#
###################################################################################################

/usr/bin/logger -s "*****  License Matlab process:  START  *****"

##################################################
# Define Variables

# If the machine has multiple Matlab Applications, loop through them...
/usr/bin/find /Applications -name "Matlab*.app" -maxdepth 1 -type d | while IFS="\n" read -r appPath; do

	# Get the Matlab version
		appVersion=$(/usr/bin/defaults read "${appPath}/Contents/Info.plist" CFBundleShortVersionString)
		/usr/bin/logger -s "Apply License for Matlab Version:  ${appVersion}"

	# Build the license file location
	licenseFile="${appPath}/licenses/network.lic"

	##################################################
	# Create the license file.

	/usr/bin/logger -s "Creating license file..."

	/bin/cat > "${licenseFile}" <<licenseContents
SERVER license.server.com 11000
USE_SERVER
licenseContents

	if [[ -e "${licenseFile}" ]]; then
		# Set permissions on the file for everyone to be able to read.
		/usr/bin/logger -s "Applying permissions to license file..."
		/bin/chmod 644 "${licenseFile}"
	else
		/usr/bin/logger -s "ERROR:  Failed to create the license file!"
		/usr/bin/logger -s "*****  License Matlab process:  FAILED  *****"
		exit 1
	fi
done

/usr/bin/logger -s "Matlab has been activated!"
/usr/bin/logger -s "*****  License Matlab process:  COMPLETE  *****"

exit 0