#!/bin/sh

###################################################################################################
# Script Name:  update_Maple.sh
# By:  Zack Thompson / Created:  3/2/2017
# Version:  1.3 / Updated:  1/17/2018 / By:  ZT
#
# Description:  This script silently installs a Maple update.
#
###################################################################################################

/bin/echo "*****  Update Maple process:  START  *****"

##################################################
# Define Variables

# Set working directory
	pkgDir=$(/usr/bin/dirname $0)
# Version that's being updated (this will be set by the build_Maple.sh script)
	version=
	majorVersion=$(/bin/echo "${version}" | /usr/bin/awk -F "." '{print $1}')
# Get the location of Maple.app
	appPath=$(/usr/bin/find /Applications -iname "Maple ${majorVersion}.app" -maxdepth 1 -type d)
# Get the current Maple version
	currentVersion=$(/usr/bin/defaults read "${appPath}/Contents/Info.plist" CFBundleShortVersionString)

##################################################
# Bits staged...

/bin/echo "Current version:  ${currentVersion}"
/bin/echo "Updating to version:  ${version}"

# Install Maple
/bin/echo "Installing Maple..."
	"${pkgDir}/Maple${version}MacInstaller.app/Contents/MacOS/installbuilder.sh" --mode unattended
	$exitCode=$?
	/bin/echo "Exit code is:  ${exitCode}"
/bin/echo "Install complete!"

if [[ $(/usr/bin/defaults read "${appPath}/Contents/Info.plist" CFBundleShortVersionString) != "${version}" ]]; then
	/bin/echo "Injecting the proper version string into Maple's Info.plist"
	# Inject the proper version into the Info.plist file -- this may not be required for every version; but was not done in 2016.0X updates
		/usr/bin/sed -i '' 's/${currentVersion}/${version}/' "${appPath}/Contents/Info.plist"
fi

/bin/echo "*****  Update Maple process:  COMPLETE  *****"

exit 0