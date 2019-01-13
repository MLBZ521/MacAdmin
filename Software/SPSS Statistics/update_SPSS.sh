#!/bin/bash

###################################################################################################
# Script Name:  update_SPSS.sh
# By:  Zack Thompson / Created:  11/22//2017
# Version:  1.7.0 / Updated:  1/12/2019 / By:  ZT
#
# Description:  This script grabs the current location of the SPSSStatistics.app and injects it into the installer.properties file and then will upgrade an SPSS Installation.
#
###################################################################################################

echo "*****  Upgrade SPSS process:  START  *****"

##################################################
# Define Variables

# Set working directory
pkgDir=$( /usr/bin/dirname "${0}" )
# Version that's being updated (this will be set by the build_SPSS.sh script)
version=
majorVersion=$( echo $version | /usr/bin/awk -F "." '{print $1}' )
# Get the location of SPSSStatistics.app
appPath=$( /usr/bin/find -E /Applications -iregex ".*[${majorVersion}].*[/](SPSS) ?(Statistics) ?(${majorVersion})?[.]app" -type d -prune )
# Get the App Bundle name
appName=$( echo "${appPath}" | /usr/bin/awk -F "/" '{print $NF}' )
# Get only the install path
installPath=$( echo "${appPath}" | /usr/bin/awk -F "/${appName}" '{print $1}' )
# Get the current SPSS version
currentVersion=$( /usr/bin/defaults read "${appPath}/Contents/Info.plist" CFBundleShortVersionString )

##################################################
# Bits staged...

if [[ -z "${appPath}" ]]; then
	echo "A previous version SPSS was not found in the expected location!"
	echo "*****  Upgrade SPSS process:  FAILED  *****"
	exit 1
fi

echo "Checking for a JDK..."
if [[ ! -d $( /usr/bin/find "/Library/Java/JavaVirtualMachines" -iname "*.jdk" -type d ) ]]; then
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
exitStatus=$( "${pkgDir}/SPSS_Statistics_Installer_Mac_Patch.bin" -f "${pkgDir}/installer.properties" )
exitCode=$?

# Check for the expected exit code.
if [[ "${exitCode}" != "208" ]]; then
	echo "ERROR:  Upgrade failed!"
	echo "Exit Code:  ${exitCode}"
	echo "Exit Status:  ${exitStatus}"
	echo "*****  Upgrade SPSS process:  FAILED  *****"
	exit 2
elif [[ $( /usr/bin/defaults read "${appPath}/Contents/Info.plist" CFBundleShortVersionString ) != "${version}" ]]; then
	echo "Injecting the proper version string into SPSS's Info.plist"
	# Inject the proper version into the Info.plist file -- this may not be required for every version; specifically for v24.0.0.2, it was needed
	/usr/bin/sed -Ei '' 's/'"${majorVersion}.0.0.[0-9]"'/'"${version}"'/g' "${appPath}/Contents/Info.plist"
fi

# Setting permissions to resolve issues seen in:  https://www-01.ibm.com/support/docview.wss?uid=swg21966637
echo "Setting permissions on SPSS ${majorVersion} files..."
/usr/sbin/chown -R root:admin "${installPath}"

echo "Upgrade complete!"
echo "*****  Upgrade SPSS process:  COMPLETE  *****"
exit 0