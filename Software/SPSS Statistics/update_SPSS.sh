#!/bin/bash

###################################################################################################
# Script Name:  update_SPSS.sh
# By:  Zack Thompson / Created:  11/22//2017
# Version:  1.4 / Updated:  1/18/2018 / By:  ZT
#
# Description:  This script grabs the current location of the SPSSStatistics.app and injects it into the installer.properties file and then will upgrade an SPSS Installation.
#
###################################################################################################

/bin/echo "*****  Upgrade SPSS process:  START  *****"

##################################################
# Define Variables

# Set working directory
	pkgDir=$(/usr/bin/dirname $0)
# Version that's being updated (this will be set by the build_SPSS.sh script)
	version=
	majorVersion=$(/bin/echo $version | /usr/bin/awk -F "." '{print $1}')
# Get the location of SPSSStatistics.app
	appPath=$(/usr/bin/find -E /Applications -iregex ".*[${majorVersion}].*[/](SPSS) ?(Statistics) ?(${majorVersion})?[.]app" -type d -prune)
# Get the App Bundle name
	appName=$(/bin/echo $appPath | /usr/bin/awk -F "/" '{print $NF}')
# Get only the install path
	installPath=$(/bin/echo $appPath | /usr/bin/awk -F "/$appName" '{print $1}')
# Get the current SPSS version
	currentVersion=$(/usr/bin/defaults read "${appPath}/Contents/Info.plist" CFBundleShortVersionString)

##################################################
# Bits staged...

# Inject the location to the installer.properties file
	LANG=C /usr/bin/sed -i '' 's,USER_INSTALL_DIR=,&'"${installPath}"',' "${pkgDir}/installer.properties"

# Make sure the Patch.bin file is executable
	/bin/chmod x+ "${pkgDir}/SPSS_Statistics_Installer_Mac_Patch.bin"

# Silent upgrade using information in the installer.properties file
/bin/echo "Upgrading SPSS..."
	"${pkgDir}/SPSS_Statistics_Installer_Mac_Patch.bin" -f "${pkgDir}/installer.properties"
	exitStatus=$?
/bin/echo "Exit Status:  ${exitStatus}"

if [[ $exitStatus != 0 ]]; then
	/bin/echo "ERROR:  Upgrade failed!"
	/bin/echo "*****  Upgrade SPSS process:  FAILED  *****"
	exit 1
elif [[ $(/usr/bin/defaults read "${appPath}/Contents/Info.plist" CFBundleShortVersionString) != "${version}" ]]; then
	/bin/echo "Injecting the proper version string into SPSS's Info.plist"
	# Inject the proper version into the Info.plist file -- this may not be required for every version; specifically v24.0.0.2, it was needed
	/usr/bin/sed -i '' 's/${currentVersion}/${version}/' "${appPath}/Contents/Info.plist"
fi

/bin/echo "Upgrade complete!"
/bin/echo "*****  Upgrade SPSS process:  COMPLETE  *****"

exit 0
