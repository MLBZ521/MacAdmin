#!/bin/bash

###################################################################################################
# Script Name:  update_SPSS.sh
# By:  Zack Thompson / Created:  11/22//2017
# Version:  1.6.0 / Updated:  4/2/2018 / By:  ZT
#
# Description:  This script grabs the current location of the SPSSStatistics.app and injects it into the installer.properties file and then will upgrade an SPSS Installation.
#
###################################################################################################

echo "*****  Upgrade SPSS process:  START  *****"

##################################################
# Define Variables

# Set working directory
	pkgDir=$(/usr/bin/dirname $0)
# Version that's being updated (this will be set by the build_SPSS.sh script)
	version=
	majorVersion=$(echo $version | /usr/bin/awk -F "." '{print $1}')
# Get the location of SPSSStatistics.app
	appPath=$(/usr/bin/find -E /Applications -iregex ".*[${majorVersion}].*[/](SPSS) ?(Statistics) ?(${majorVersion})?[.]app" -type d -prune)
# Get the App Bundle name
	appName=$(echo "${appPath}" | /usr/bin/awk -F "/" '{print $NF}')
# Get only the install path
	installPath=$(echo "${appPath}" | /usr/bin/awk -F "/${appName}" '{print $1}')
# Get the current SPSS version
	currentVersion=$(/usr/bin/defaults read "${appPath}/Contents/Info.plist" CFBundleShortVersionString)

##################################################
# Bits staged...

if [[ -z "${appPath}" ]]; then
	/usr/bin/logger -s "A previous version SPSS was not found in the expected location!"
	/usr/bin/logger -s "*****  Upgrade SPSS process:  FAILED  *****"
	exit 1
fi

echo "Checking for a JDK..."
if [[ ! -d $(/usr/bin/find "/Library/Java/JavaVirtualMachines" -iname "*.jdk" -type d) ]]; then
	# Install prerequisite:  Java JDK
	echo "Installing prerequisite Java JDK from Jamf..."
	/usr/local/bin/jamf policy -id 721 -forceNoRecon
else
	echo "JDK exists...continuing..."
fi

echo "Upgrading SPSS Version:  ${currentVersion} at path:  ${appPath}"

# Inject the location to the installer.properties file
	LANG=C /usr/bin/sed -Ei '' 's,(#)?USER_INSTALL_DIR=.*,'"USER_INSTALL_DIR=${installPath}"',' "${pkgDir}/installer.properties"

# Make sure the Patch.bin file is executable
	/bin/chmod +x "${pkgDir}/SPSS_Statistics_Installer_Mac_Patch.bin"

# Silent upgrade using information in the installer.properties file
echo "Upgrading SPSS..."
	exitStatus=$("${pkgDir}/SPSS_Statistics_Installer_Mac_Patch.bin" -f "${pkgDir}/installer.properties")
	exitCode=$?

# Check for the expected exit code.
if [[ "${exitCode}" != "208" ]]; then
	echo "ERROR:  Upgrade failed!"
	echo "Exit Code:  ${exitCode}"
	echo "Exit Status:  ${exitStatus}"
	echo "*****  Upgrade SPSS process:  FAILED  *****"
	exit 2
elif [[ $(/usr/bin/defaults read "${appPath}/Contents/Info.plist" CFBundleShortVersionString) != "${version}" ]]; then
	echo "Injecting the proper version string into SPSS's Info.plist"
	# Inject the proper version into the Info.plist file -- this may not be required for every version; specifically for v24.0.0.2, it was needed
	/usr/bin/sed -Ei '' 's/'"${majorVersion}.0.0.[0-9]"'/'"${version}"'/g' "${appPath}/Contents/Info.plist"
fi

echo "Upgrade complete!"
echo "*****  Upgrade SPSS process:  COMPLETE  *****"

exit 0
