#!/bin/bash

###################################################################################################
# Script Name:  update_Maple.sh
# By:  Zack Thompson / Created:  3/2/2017
# Version:  1.5.1 / Updated:  3/30/2018 / By:  ZT
#
# Description:  This script silently installs a Maple update.
#
###################################################################################################

echo "*****  Update Maple process:  START  *****"

##################################################
# Define Variables

# Set working directory
	pkgDir=$(/usr/bin/dirname "${0}")
# Version that's being updated (this will be set by the build_Maple.sh script)
	version=
	majorVersion=$(echo "${version}" | /usr/bin/awk -F "." '{print $1}')
# Get the location of Maple.app
	appPath=$(/usr/bin/find /Applications -iname "Maple ${majorVersion}.app" -maxdepth 3 -type d -prune)
# Get the current Maple version
	currentVersion=$(/usr/bin/defaults read "${appPath}/Contents/Info.plist" CFBundleShortVersionString)

##################################################
# Bits staged...

echo "Current version:  ${currentVersion}"
echo "Updating to version:  ${version}"

# Update Maple
echo "Updating Maple..."
	exitStatus=$("${pkgDir}/Maple${version}MacUpgrade.app/Contents/MacOS/installbuilder.sh" --mode unattended)
	exitCode=$?

if [[ $exitCode != 0 ]]; then
	echo "ERROR:  Update failed!"
	echo "Exit code was:  ${exitCode}"
	echo "Exit status was:  ${exitStatus}"
	echo "*****  Update Maple process:  FAILED  *****"
	exit 1
elif [[ $(/usr/bin/defaults read "${appPath}/Contents/Info.plist" CFBundleShortVersionString) != "${version}" ]]; then
	echo "Injecting the proper version string into Maple's Info.plist"
	# Inject the proper version into the Info.plist file -- this may not be required for every version; but was not done in 2016.0X updates
		/usr/bin/sed -i '' 's/'"${currentVersion}"'/'"${version}"'/g;s/2016.00/'"${version}"'/g' "${appPath}/Contents/Info.plist"
fi

echo "Update complete!"
echo "*****  Update Maple process:  COMPLETE  *****"

exit 0